
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';
import 'models/file_system_entity.dart';
import 'services/adb_service.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

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
    }
  }

  Future<void> loadPhoneDirectory(String path) async {
    isPhoneLoading = true;
    notifyListeners();
    try {
      final files = await adbService.listFiles(path);
      files.forEach(print);

      phoneFileSystem.entities = files.map((file) {
        final parts = file.split(RegExp(r'\s+'));
        if (parts.length < 7) {
          return null;
        }

        final permissions = parts[0];
        final isDirectory = permissions.startsWith('d');

        final name = parts.sublist(7).join(' ').trim();

        if (name.isEmpty || name == '.' || name == '..') {
          return null;
        }


        return FileSystemEntity(
          name: name,
          path: '$path/$name',
          isDirectory: isDirectory,
          isPhoneFileSystem: true,
        );
      }).whereType<FileSystemEntity>().toList();


      phoneFileSystem.entities.forEach((entity) => print('${entity.name} - ${entity.path}'));

      if (path != currentPhonePath) {
        phonePathHistory.add(currentPhonePath);
      }
      currentPhonePath = path;
    } catch (e) {
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
    try {
      transferProgress = 0;

      if (toPhone) {
        await adbService.pushFile(
            source.path,
            '$destinationPath/${source.name}',
                (progress) {
              transferProgress = progress;
            }
        );
        await loadPhoneDirectory(currentPhonePath);
      } else {
        await adbService.pullFile(
            source.path,
            '$destinationPath/${source.name}',
                (progress) {
              transferProgress = progress;
            }
        );
        await loadPcDirectory(currentPcPath);
      }
      transferProgress = -1;
    } catch (e) {
      transferProgress = -1;
      rethrow;
    }
  }

  Future<void> transferFiles(List<FileSystemEntity> sources, bool toPhone, String destinationPath) async {
    try {
      // Check if the transfer is from phone to phone and prevent it
      if (sources.any((source) => source.isPhoneFileSystem) && toPhone) {
        throw Exception('Phone-to-phone transfer is not allowed');
      }

      transferProgress = 0;
      int completedTransfers = 0;

      for (var source in sources) {
        if (toPhone) {
          await adbService.pushFile(
              source.path,
              '$destinationPath/${source.name}',
                  (progress) {
                transferProgress = (completedTransfers + progress) / sources.length;
              }
          );
        } else {
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

      if (toPhone) {
        await loadPhoneDirectory(currentPhonePath);
      } else {
        await loadPcDirectory(currentPcPath);
      }
      transferProgress = -1;
    } catch (e) {
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

  List<FileSystemEntity> _copiedFiles = [];

  List<FileSystemEntity> get copiedFiles => _copiedFiles;



  Future<void> copyFiles(List<FileSystemEntity> entities) async {
    _copiedFiles = entities;
    notifyListeners();
  }

  Future<void> pasteFiles(String destinationPath) async {
    if (_copiedFiles.isEmpty) {
      throw Exception('No files to paste');
    }

    for (var file in _copiedFiles) {
      await transferFile(file, !file.isPhoneFileSystem, destinationPath);
    }

    _copiedFiles.clear();
    notifyListeners();

    // Refresh the current directory
    if (destinationPath == currentPcPath) {
      await loadPcDirectory(currentPcPath);
    } else if (destinationPath == currentPhonePath) {
      await loadPhoneDirectory(currentPhonePath);
    }
  }

  Future<void> deleteFiles(List<FileSystemEntity> entities, bool permanent) async {
    List<String> failedDeletions = [];

    for (var entity in entities) {
      try {
        if (entity.isPhoneFileSystem) {
          await _deletePhoneFile(entity.path);
        } else {
          await _deletePcFile(entity, permanent);
        }
      } catch (e) {
        failedDeletions.add(entity.path);
      }
    }

    // Refresh the current directory
    if (entities.first.isPhoneFileSystem) {
      await loadPhoneDirectory(currentPhonePath);
    } else {
      await loadPcDirectory(currentPcPath);
    }

    // Report any failed deletions
    if (failedDeletions.isNotEmpty) {
      throw Exception('Failed to delete the following files/folders:\n${failedDeletions.join('\n')}');
    }
  }

  Future<void> _deletePhoneFile(String path) async {
    final result = await adbService.deleteFile(path);
    if (!result.success) {
      throw Exception('Failed to delete on phone: ${result.errorMessage}');
    }
  }

  Future<void> _deletePcFile(FileSystemEntity entity, bool permanent) async {
    if (permanent) {
      await _permanentlyDeleteFile(entity);
    } else {
      await _moveToRecycleBin(entity.path);
    }
  }


  Future<void> _permanentlyDeleteFile(FileSystemEntity entity) async {
    if (entity.isDirectory) {
      await Directory(entity.path).delete(recursive: true);
    } else {
      await File(entity.path).delete();
    }
  }

  Future<void> _moveToRecycleBin(String path) async {
    // Ensure the path is null-terminated and double-null-terminated
    final pathPointer = calloc<Uint16>(path.length + 2);
    for (var i = 0; i < path.length; i++) {
      pathPointer[i] = path.codeUnitAt(i);
    }
    pathPointer[path.length] = 0; // Null-terminate

    final fileOp = calloc<SHFILEOPSTRUCT>();

    try {
      final attributes = GetFileAttributes(pathPointer as Pointer<Utf16>);
      final isDirectory = attributes & FILE_ATTRIBUTE_DIRECTORY != 0;

      fileOp.ref.wFunc = FO_DELETE;
      fileOp.ref.pFrom = pathPointer.cast<Utf16>();
      fileOp.ref.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT;

      final result = SHFileOperation(fileOp);

      if (result != 0) {
        final error = GetLastError();
        throw Exception('Failed to delete ${isDirectory ? "folder" : "file"}. SHFileOperation error: $result, GetLastError: $error');
      }

      if (fileOp.ref.fAnyOperationsAborted != 0) {
        throw Exception('Delete operation was aborted by the user');
      }

      // Verify deletion
      final existsAfter = GetFileAttributes(pathPointer as Pointer<Utf16>) != 0xFFFFFFFF; // INVALID_FILE_ATTRIBUTES
      if (existsAfter) {
        throw Exception('${isDirectory ? "Folder" : "File"} still exists after deletion attempt');
      }
    } finally {
      free(pathPointer);
      free(fileOp);
    }
  }

}
