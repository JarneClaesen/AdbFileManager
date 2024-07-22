import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'window_manager_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    //size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => WindowManagerHelper()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Visual ADB File Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.dark, // Set to dark mode by default
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size(double.maxFinite, 50),
            child: DragToMoveArea(
              child: Consumer<WindowManagerHelper>(
                builder: (context, windowHelper, child) {
                  return AppBar(
                    title: Text("Adb Manager"),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      IconButton(
                        onPressed: () => windowManager.minimize(),
                        icon: const Icon(Icons.minimize),
                      ),
                      IconButton(
                        onPressed: windowHelper.toggleMaximize,
                        icon: Icon(windowHelper.isMaximized ? Icons.content_copy_rounded : Icons.crop_square_rounded),
                      ),
                      IconButton(
                        onPressed: () => windowManager.close(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          body: HomeScreen(),
        ),
      ),
    );
  }
}
