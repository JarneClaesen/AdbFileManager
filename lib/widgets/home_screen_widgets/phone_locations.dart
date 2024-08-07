import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

class PhoneLocations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return SizedBox(
      width: 150,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._buildPhoneLocations(appState),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPhoneLocations(AppState appState) {
    final List<Map<String, String>> phoneLocations = [
      {'name': 'Home', 'path': '/storage/emulated/0'},
      {'name': 'DCIM', 'path': '/storage/emulated/0/DCIM'},
      {'name': 'Downloads', 'path': '/storage/emulated/0/Download'},
      {'name': 'Pictures', 'path': '/storage/emulated/0/Pictures'},
      {'name': 'Movies', 'path': '/storage/emulated/0/Movies'},
    ];

    return phoneLocations.map((location) => ListTile(
      dense: true,
      title: Text(location['name']!, style: TextStyle(fontSize: 14)),
      onTap: () => appState.loadPhoneDirectory(location['path']!),
    )).toList();
  }
}
