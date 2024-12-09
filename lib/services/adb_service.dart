import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:async/async.dart' show unawaited;
import 'package:path/path.dart' as path;

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
    final fileName = sourcePath.split('/').last;
    debugPrint('$fileName - $sourcePath');
    debugPrint('Starting transfer for: $fileName');

    // Ensure destination path includes filename
    final fullDestinationPath = path.join(destinationPath, fileName);
    final absoluteDestinationPath = File(fullDestinationPath).absolute.path;
    debugPrint('Absolute destination path: $absoluteDestinationPath');

    // Get the file size from the device
    final sizeResult = await Process.run(_adbPath, ['shell', 'stat', '-c', '%s', sourcePath]);
    if (sizeResult.exitCode != 0) {
      throw Exception('Failed to get source file size: ${sizeResult.stderr}');
    }
    final totalBytes = int.tryParse(sizeResult.stdout.toString().trim()) ?? 0;
    if (totalBytes <= 0) {
      throw Exception('Invalid source file size: $totalBytes');
    }

    debugPrint('Total file size: $totalBytes bytes');

    // Delete destination file if it exists
    final destinationFile = File(absoluteDestinationPath);
    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    // Start the transfer process
    final process = await Process.start(
        _adbPath,
        ['pull', sourcePath, absoluteDestinationPath],
        runInShell: true
    );

    bool isCompleted = false;
    final completer = Completer<void>();

    // Function to check file size
    Future<void> checkFileSize() async {
      try {
        if (await destinationFile.exists()) {
          final currentSize = await destinationFile.length();
          final progress = currentSize / totalBytes;
          debugPrint('Transferred: $currentSize of $totalBytes bytes (${(progress * 100).toStringAsFixed(2)}%)');
          onProgress(progress.clamp(0.0, 1.0));
        } else {
          debugPrint('Waiting for file creation at: ${destinationFile.path}');
        }
      } catch (e) {
        debugPrint('Error checking file size: $e');
      }
    }

    // Set up periodic file check
    Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (isCompleted) {
        timer.cancel();
        return;
      }
      await checkFileSize();
    });

    // Process stdout for any information
    process.stdout.transform(utf8.decoder).listen(
            (data) => debugPrint('ADB stdout: $data'),
        onError: (error) => debugPrint('stdout error: $error')
    );

    // Process stderr for errors
    process.stderr.transform(utf8.decoder).listen(
            (data) => debugPrint('ADB stderr: $data'),
        onError: (error) => debugPrint('stderr error: $error')
    );

    try {
      final exitCode = await process.exitCode;
      isCompleted = true;

      if (exitCode == 0) {
        // Final size check
        if (await destinationFile.exists()) {
          final finalSize = await destinationFile.length();
          debugPrint('Transfer completed. Final size: $finalSize bytes');
          onProgress(1.0);
        }
      } else {
        throw Exception('ADB pull failed with exit code $exitCode');
      }
    } catch (e) {
      debugPrint('Error during transfer: $e');
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

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist: $sourcePath');
    }
    int totalBytes = await sourceFile.length();

    // Keep track of the last reported progress
    double lastProgress = 0.0;

    final process = await Process.start(_adbPath, ['push', sourcePath, destinationPath]);

    Timer? timer;
    timer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      int transferredBytes = await _getRemoteFileSize(destinationPath);

      if (transferredBytes >= 0 && totalBytes > 0) {
        double progress = transferredBytes / totalBytes;
        progress = progress.clamp(0.0, 1.0);

        // Only update if the progress has increased
        if (progress > lastProgress) {
          lastProgress = progress;
          onProgress(progress);
        }
      }
    });

    try {
      final exitCode = await process.exitCode;
      timer?.cancel();

      if (exitCode != 0) {
        final errorOutput = await process.stderr.transform(utf8.decoder).join();
        throw Exception('ADB push failed with exit code $exitCode. Error: $errorOutput');
      }

      // Only call onProgress(1.0) if we haven't reached 100% yet
      if (lastProgress < 1.0) {
        onProgress(1.0);
      }
    } catch (e) {
      timer?.cancel();
      rethrow;
    }

    process.stderr.transform(utf8.decoder).listen((data) {
      print('ADB error: $data');
    });
  }

  Future<int> _getRemoteFileSize(String path) async {
    try {
      final sizeResult = await Process.run(_adbPath, ['shell', 'stat', '-c', '%s', path]);
      if (sizeResult.exitCode == 0) {
        return int.tryParse(sizeResult.stdout.toString().trim()) ?? -1;
      }
    } catch (e) {
      // Don't print error during size checking as it might be checking before file exists
    }
    return -1;
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

    // Escape spaces in the path for shell commands
    //final Path = path.replaceAll(' ', '\\ ');
    // Or alternatively, wrap the path in quotes:
    final Path = '"$path"';

    print('AdbService: Attempting to delete on phone: $path');

    // First, check if the file/directory exists
    final checkResult = await Process.run(_adbPath, ['shell', 'ls', Path]);
    print('AdbService: Check result: ${checkResult.stdout}, Exit code: ${checkResult.exitCode}');
    if (checkResult.exitCode != 0) {
      return DeleteResult(false, 'File or directory not found: $path');
    }

    // If it exists, try to delete it
    final result = await Process.run(_adbPath, ['shell', 'rm', '-rf', Path]);
    print('AdbService: Delete result: ${result.stdout}, Error: ${result.stderr}, Exit code: ${result.exitCode}');
    if (result.exitCode != 0) {
      final errorMessage = result.stderr.toString().trim();
      return DeleteResult(false, 'Failed to delete: $errorMessage (Exit code: ${result.exitCode})');
    }

    // Double-check that it's been deleted
    final verifyResult = await Process.run(_adbPath, ['shell', 'ls', Path]);
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