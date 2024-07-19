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
    final tempDir = await getTemporaryDirectory();
    _adbPath = '${tempDir.path}/adb.exe';

    // Copy ADB executable from assets to temp directory
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

      process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((String line) {
        debugPrint('ADB output: $line');
        onProgress(-1); // We can't get accurate progress for pull operations
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
      await ensureDirectoryExists(destinationPath.substring(0, destinationPath.lastIndexOf('/')));

      final process = await Process.start(_adbPath, ['push', '-p', sourcePath, destinationPath]);

      process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((String line) {
        debugPrint('ADB output: $line');
        final progressMatch = RegExp(r'\[(\d+)%\]').firstMatch(line);
        if (progressMatch != null) {
          final progressPercentage = int.parse(progressMatch.group(1)!);
          onProgress(progressPercentage / 100);
        }
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw Exception('ADB push failed with exit code $exitCode');
      }
    } catch (e) {
      debugPrint('Exception during push operation: $e');
      rethrow;
    }
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

}
