import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../widgets/home_screen_widgets/progress_container.dart';

class ProgressContainerService extends StatefulWidget {
  @override
  _ProgressContainerServiceState createState() => _ProgressContainerServiceState();
}

class _ProgressContainerServiceState extends State<ProgressContainerService> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final hasTransfers = appState.activeTransfers.isNotEmpty || appState.completedTransfers.isNotEmpty;

    if (!hasTransfers || !appState.showProgressContainer) {
      return SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 16,
      child: ProgressContainer(
        transfers: [...appState.activeTransfers, ...appState.completedTransfers],
        totalProgress: appState.totalProgress,
        onDismiss: () {
          appState.dismissProgressContainer();
        },
      ),
    );
  }
}
