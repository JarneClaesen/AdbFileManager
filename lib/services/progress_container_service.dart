import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../widgets/home_screen_widgets/progress_container.dart';

class ProgressContainerService extends StatefulWidget {
  @override
  _ProgressContainerServiceState createState() => _ProgressContainerServiceState();
}

class _ProgressContainerServiceState extends State<ProgressContainerService> {
  bool _showContainer = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    appState.addListener(_checkTransfers);
  }

  @override
  void dispose() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_checkTransfers);
    super.dispose();
  }

  void _checkTransfers() {
    final appState = Provider.of<AppState>(context, listen: false);
    final hasTransfers = appState.activeTransfers.isNotEmpty || appState.completedTransfers.isNotEmpty;

    if (hasTransfers && !_showContainer) {
      setState(() {
        _showContainer = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final hasTransfers = appState.activeTransfers.isNotEmpty || appState.completedTransfers.isNotEmpty;

    if (!hasTransfers) {
      return SizedBox.shrink();
    }

    if (!_showContainer) {
      return SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 16,
      child: ProgressContainer(
        transfers: [...appState.activeTransfers, ...appState.completedTransfers],
        totalProgress: appState.totalProgress,
        onDismiss: () {
          setState(() {
            _showContainer = false;
          });
        },
      ),
    );
  }
}
