// lib/window_manager_helper.dart

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowManagerHelper extends ChangeNotifier implements WindowListener {
  bool _isMaximized = false;

  bool get isMaximized => _isMaximized;

  WindowManagerHelper() {
    _setupWindowManager();
  }

  void _setupWindowManager() async {
    windowManager.addListener(this);
    _isMaximized = await windowManager.isMaximized();
    notifyListeners();
  }

  Future<void> toggleMaximize() async {
    if (_isMaximized) {
      await windowManager.restore();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // Implement WindowListener methods
  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowClose() {}

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    notifyListeners();
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    notifyListeners();
  }

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {
    _isMaximized = false;
    notifyListeners();
  }

  @override
  void onWindowResize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}

  // Corrected method signatures
  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}
}
