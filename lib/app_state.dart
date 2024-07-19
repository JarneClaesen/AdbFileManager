import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'models/file_system_entity.dart';
import 'services/adb_service.dart';

class AppState with ChangeNotifier {
  FileSystem pcFileSystem = FileSystem();
  FileSystem phoneFileSystem = FileSystem();
  AdbService adbService = AdbService();

  String currentPcPath = Platform.isWindows ? 'C:\\' : '/';
  String currentPhonePath = '/storage/emulated/0';
  bool isLoading = false;
  bool isPhoneLoading = false;

  List<String> pcPathHistory = [];
  List<String> phonePathHistory = [];

  AppState() {
    _initAdb();
  }

  Future<void> _initAdb() async {
    isLoading = true;
    notifyListeners();
    await adbService.init();
    await adbService.ensureServerStarted();
    await loadPhoneDirectory(currentPhonePath);
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadPcDirectory(String path) async {
    try {
      await pcFileSystem.loadDirectory(path);
      if (path != currentPcPath) {
        pcPathHistory.add(currentPcPath);
      }
      currentPcPath = path;
      notifyListeners();
    } catch (e) {
      print('Error loading PC directory: $e');
    }
  }

  Future<void> loadPhoneDirectory(String path) async {
    isPhoneLoading = true;
    notifyListeners();
    try {
      final files = await adbService.listFiles(path);
      print('Debug: Raw files list for path $path:');
      files.forEach(print);

      phoneFileSystem.entities = files.map((file) {
        final parts = file.split(RegExp(r'\s+'));
        if (parts.length < 7) {
          print('Debug: Skipping invalid entry: $file');
          return null;
        }

        final permissions = parts[0];
        final isDirectory = permissions.startsWith('d');

        final name = parts.sublist(7).join(' ').trim();

        if (name.isEmpty || name == '.' || name == '..') {
          print('Debug: Skipping entry: $name');
          return null;
        }

        print('Debug: Parsed entry - Name: $name, IsDirectory: $isDirectory');

        return FileSystemEntity(
          name: name,
          path: '$path/$name',
          isDirectory: isDirectory,
        );
      }).whereType<FileSystemEntity>().toList();

      print('Debug: Parsed entities:');
      phoneFileSystem.entities.forEach((entity) => print('${entity.name} - ${entity.path}'));

      if (path != currentPhonePath) {
        phonePathHistory.add(currentPhonePath);
      }
      currentPhonePath = path;
    } catch (e) {
      print('Error loading phone directory: $e');
    } finally {
      isPhoneLoading = false;
      notifyListeners();
    }
  }

  double _transferProgress = -1;
  double get transferProgress => _transferProgress;

  set transferProgress(double value) {
    _transferProgress = value;
    notifyListeners();
  }

  Future<void> transferFile(FileSystemEntity source, bool toPhone, String destinationPath) async {
    debugPrint('transferFile called: ${source.path} to ${toPhone ? 'Phone' : 'PC'} at $destinationPath');
    try {
      transferProgress = 0;

      if (toPhone) {
        debugPrint('Pushing file from PC to phone');
        await adbService.pushFile(
            source.path,
            '$destinationPath/${source.name}',
                (progress) {
              transferProgress = progress;
            }
        );
        debugPrint('Push completed, reloading phone directory');
        await loadPhoneDirectory(currentPhonePath);
      } else {
        debugPrint('Pulling file from phone to PC');
        await adbService.pullFile(
            source.path,
            '$destinationPath/${source.name}',
                (progress) {
              transferProgress = progress;
            }
        );
        debugPrint('Pull completed, reloading PC directory');
        await loadPcDirectory(currentPcPath);
      }
      debugPrint('File transfer completed successfully');
      transferProgress = -1;
    } catch (e) {
      debugPrint('Error transferring file: $e');
      transferProgress = -1;
      rethrow;
    }
  }

  Future<void> transferFiles(List<FileSystemEntity> sources, bool toPhone, String destinationPath) async {
    debugPrint('transferFiles called: ${sources.length} files to ${toPhone ? 'Phone' : 'PC'} at $destinationPath');
    try {
      // Check if the transfer is from phone to phone and prevent it
      if (sources.any((source) => source.isPhoneFileSystem) && toPhone) {
        debugPrint('Phone-to-phone transfer is not allowed');
        throw Exception('Phone-to-phone transfer is not allowed');
      }

      transferProgress = 0;
      int completedTransfers = 0;

      for (var source in sources) {
        if (toPhone) {
          debugPrint('Pushing file from PC to phone: ${source.name}');
          await adbService.pushFile(
              source.path,
              '$destinationPath/${source.name}',
                  (progress) {
                transferProgress = (completedTransfers + progress) / sources.length;
              }
          );
        } else {
          debugPrint('Pulling file from phone to PC: ${source.name}');
          await adbService.pullFile(
              source.path,
              '$destinationPath/${source.name}',
                  (progress) {
                transferProgress = (completedTransfers + progress) / sources.length;
              }
          );
        }
        completedTransfers++;
      }

      debugPrint('Files transfer completed successfully');
      if (toPhone) {
        await loadPhoneDirectory(currentPhonePath);
      } else {
        await loadPcDirectory(currentPcPath);
      }
      transferProgress = -1;
    } catch (e) {
      debugPrint('Error transferring files: $e');
      transferProgress = -1;
      rethrow;
    }
  }


  Future<void> refreshDirectories() async {
    isLoading = true;
    notifyListeners();
    await loadPcDirectory(currentPcPath);
    await loadPhoneDirectory(currentPhonePath);
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshPhoneDirectory() async {
    await loadPhoneDirectory(currentPhonePath);
  }

  void goBackPc() {
    if (pcPathHistory.isNotEmpty) {
      final previousPath = pcPathHistory.removeLast();
      loadPcDirectory(previousPath);
    }
  }

  void goBackPhone() {
    if (phonePathHistory.isNotEmpty) {
      final previousPath = phonePathHistory.removeLast();
      loadPhoneDirectory(previousPath);
    }
  }
}
