import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AdbService {
  late String _adbPath;
  bool _serverStarted = false;

  Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _adbPath = '${appDir.path}/adb_${DateTime.now().millisecondsSinceEpoch}.exe';

    // Copy ADB executable from assets to app support directory
    final adbData = await rootBundle.load('assets/platform-tools/adb.exe');
    final adbFile = File(_adbPath);
    await adbFile.writeAsBytes(adbData.buffer.asUint8List());
  }


  Future<void> ensureServerStarted() async {
    if (!_serverStarted) {
      try {
        await Process.run(_adbPath, ['start-server']);
        _serverStarted = true;
      } catch (e) {
        print('Error starting ADB server: $e');
      }
    }
  }

  Future<List<String>> listFiles(String path) async {
    await ensureServerStarted();
    try {
      var result = await Process.run(_adbPath, ['shell', 'ls', '-la', path]);
      if (result.exitCode != 0) {
        print('Error listing files: ${result.stderr}');
        return [];
      }
      return result.stdout.toString().split('\n')
          .where((line) => line.trim().isNotEmpty)
          .where((line) => !line.endsWith('.') && !line.endsWith('..'))
          .toList();
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }


  Future<void> pullFile(String sourcePath, String destinationPath, Function(double) onProgress) async {
    await ensureServerStarted();
    final fullCommand = '$_adbPath pull "$sourcePath" "$destinationPath"';
    debugPrint('Executing ADB command: $fullCommand');

    try {
      final process = await Process.start(_adbPath, ['pull', sourcePath, destinationPath]);

      int totalBytes = 0;
      int transferredBytes = 0;

      // First, get the file size
      final sizeProcess = await Process.run(_adbPath, ['shell', 'stat', '-c', '%s', sourcePath]);
      if (sizeProcess.exitCode == 0) {
        totalBytes = int.tryParse(sizeProcess.stdout.toString().trim()) ?? 0;
      }

      process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((String line) {
        debugPrint('ADB output: $line');
        final bytesMatch = RegExp(r'(\d+) bytes').firstMatch(line);
        if (bytesMatch != null) {
          transferredBytes = int.parse(bytesMatch.group(1)!);
          if (totalBytes > 0) {
            onProgress(transferredBytes / totalBytes);
          }
        }
      });

      process.stderr.transform(utf8.decoder).transform(LineSplitter()).listen((String line) {
        debugPrint('ADB error: $line');
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception('ADB pull failed with exit code $exitCode');
      }
    } catch (e) {
      debugPrint('Exception during pull operation: $e');
      rethrow;
    }
  }

  Future<void> ensureDirectoryExists(String path) async {
    await ensureServerStarted();
    var result = await Process.run(_adbPath, ['shell', 'mkdir', '-p', path]);
    if (result.exitCode != 0) {
      throw Exception('Failed to create directory: ${result.stderr}');
    }
  }

  Future<void> pushFile(String sourcePath, String destinationPath, Function(double) onProgress) async {
    await ensureServerStarted();
    final fullCommand = '$_adbPath push -p "$sourcePath" "$destinationPath"';
    debugPrint('Executing ADB command: $fullCommand');

    try {
      // Ensure the parent directory exists
      final parentDir = destinationPath.substring(0, destinationPath.lastIndexOf('/'));
      await ensureDirectoryExists(parentDir);

      final process = await Process.start(_adbPath, ['push', '-p', sourcePath, destinationPath]);

      int totalBytes = 0;
      int transferredBytes = 0;

      // Get total size of files to be transferred
      if (FileSystemEntity.isDirectorySync(sourcePath)) {
        totalBytes = await _getTotalSize(sourcePath);
      } else {
        totalBytes = await File(sourcePath).length();
      }

      process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((String line) {
        debugPrint('ADB output: $line');
        final bytesMatch = RegExp(r'(\d+)/(\d+) files? pushed').firstMatch(line);
        if (bytesMatch != null) {
          transferredBytes = int.parse(bytesMatch.group(1)!);
          final progress = transferredBytes / totalBytes;
          onProgress(progress);
          debugPrint('Progress update: $progress');
        }
      });

      process.stderr.transform(utf8.decoder).transform(LineSplitter()).listen((String line) {
        debugPrint('ADB error: $line');
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception('ADB push failed with exit code $exitCode');
      }

      onProgress(1.0);
      debugPrint('Transfer completed: $sourcePath');
    } catch (e) {
      debugPrint('Exception during push operation: $e');
      rethrow;
    }
  }

  Future<int> _getTotalSize(String path) async {
    int total = 0;
    await for (final entity in Directory(path).list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }






  Future<void> printDebugInfo(String path) async {
    try {
      var result = await Process.run(_adbPath, ['shell', 'ls', '-la', path]);
      print('Debug: ADB command output for $path:');
      print(result.stdout);
      print(result.stderr);
    } catch (e) {
      print('Debug: Error executing ADB command: $e');
    }
  }

  Future<DeleteResult> deleteFile(String path) async {
    await ensureServerStarted();

    print('AdbService: Attempting to delete on phone: $path');

    // First, check if the file/directory exists
    final checkResult = await Process.run(_adbPath, ['shell', 'ls', path]);
    print('AdbService: Check result: ${checkResult.stdout}, Exit code: ${checkResult.exitCode}');
    if (checkResult.exitCode != 0) {
      return DeleteResult(false, 'File or directory not found: $path');
    }

    // If it exists, try to delete it
    final result = await Process.run(_adbPath, ['shell', 'rm', '-rf', path]);
    print('AdbService: Delete result: ${result.stdout}, Error: ${result.stderr}, Exit code: ${result.exitCode}');
    if (result.exitCode != 0) {
      final errorMessage = result.stderr.toString().trim();
      return DeleteResult(false, 'Failed to delete: $errorMessage (Exit code: ${result.exitCode})');
    }

    // Double-check that it's been deleted
    final verifyResult = await Process.run(_adbPath, ['shell', 'ls', path]);
    print('AdbService: Verify result: ${verifyResult.stdout}, Exit code: ${verifyResult.exitCode}');
    if (verifyResult.exitCode == 0) {
      return DeleteResult(false, 'File or directory still exists after deletion attempt');
    }

    return DeleteResult(true, '');
  }

}

class DeleteResult {
  final bool success;
  final String errorMessage;

  DeleteResult(this.success, this.errorMessage);
}
