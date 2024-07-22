import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/progress_container_service.dart';
import '../widgets/home_screen_widgets/file_system_column.dart';
import '../widgets/home_screen_widgets/pc_locations.dart';
import '../widgets/home_screen_widgets/phone_locations.dart';
import '../widgets/home_screen_widgets/breadcrumbs.dart';
import '../widgets/home_screen_widgets/progress_container.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.loadPcDirectory(appState.currentPcPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Stack(
          children: [
            Column(
              children: [
                if (appState.transferProgress > 0 && appState.transferProgress < 1)
                  LinearProgressIndicator(
                    value: appState.transferProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                Expanded(
                  child: appState.isLoading
                      ? Center(child: CircularProgressIndicator())
                      : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PcLocations(),
                      VerticalDivider(width: 1),
                      FileSystemColumn(
                        isPC: true,
                        appState: appState,
                      ),
                      VerticalDivider(width: 1),
                      PhoneLocations(),
                      VerticalDivider(width: 1),
                      FileSystemColumn(
                        isPC: false,
                        appState: appState,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ProgressContainerService(),
          ],
        );
      },
    );
  }
}
