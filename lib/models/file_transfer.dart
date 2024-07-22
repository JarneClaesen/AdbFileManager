import 'package:flutter/cupertino.dart';

class FileTransfer extends ChangeNotifier {
  final String fileName;
  double _progress;
  final String sourcePath;
  final String destinationPath;

  FileTransfer({
    required this.fileName,
    double progress = 0.0,
    required this.sourcePath,
    required this.destinationPath,
  }) : _progress = progress;

  double get progress => _progress;

  void updateProgress(double newProgress) {
    _progress = newProgress;
    notifyListeners();
  }
}
