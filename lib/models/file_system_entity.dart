import 'dart:io';

class FileSystemEntity {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? lastModified;
  final bool isPhoneFileSystem;

  FileSystemEntity({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.lastModified,
    this.isPhoneFileSystem = false,
  });
}

class FileSystem {
  List<FileSystemEntity> entities = [];

  Future<void> loadDirectory(String path) async {
    entities.clear();
    final dir = Directory(path);
    await for (var entity in dir.list()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      entities.add(FileSystemEntity(
        name: name,
        path: entity.path,
        isDirectory: entity is Directory,
      ));
    }
  }
}
