import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform, Directory;

import '../../app_state.dart';
//import '../app_state.dart';

class PcLocations extends StatelessWidget {
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
              child: Text('PC Locations', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._buildPcLocations(appState),
            if (Platform.isWindows) Divider(),
            if (Platform.isWindows) Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Drives', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (Platform.isWindows)
              FutureBuilder<List<String>>(
                future: _getWindowsDrives(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  return Column(
                    children: snapshot.data!.map((drive) => ListTile(
                      dense: true,
                      title: Text(drive, style: TextStyle(fontSize: 14)),
                      onTap: () => appState.loadPcDirectory('$drive\\'),
                    )).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPcLocations(AppState appState) {
    final List<Map<String, String>> pcLocations = [
      {'name': 'Desktop', 'path': '${Platform.environment['USERPROFILE']}\\Desktop'},
      {'name': 'Documents', 'path': '${Platform.environment['USERPROFILE']}\\Documents'},
      {'name': 'Downloads', 'path': '${Platform.environment['USERPROFILE']}\\Downloads'},
      {'name': 'Pictures', 'path': '${Platform.environment['USERPROFILE']}\\Pictures'},
    ];

    return pcLocations.map((location) => ListTile(
      dense: true,
      title: Text(location['name']!, style: TextStyle(fontSize: 14)),
      onTap: () => appState.loadPcDirectory(location['path']!),
    )).toList();
  }

  Future<List<String>> _getWindowsDrives() async {
    List<String> drives = [];
    for (var letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      String path = '$letter:\\';
      if (await Directory(path).exists()) {
        drives.add(path);
      }
    }
    return drives;
  }
}