import 'package:flutter/material.dart';
import '../../models/file_system_entity.dart';
import '../../app_state.dart';
import '../file_manager.dart';
import 'breadcrumbs.dart';

class FileSystemColumn extends StatelessWidget {
  final bool isPC;
  final AppState appState;

  FileSystemColumn({required this.isPC, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded),
                onPressed: isPC
                    ? (appState.pcPathHistory.isEmpty ? null : appState.goBackPc)
                    : (appState.phonePathHistory.isEmpty ? null : appState.goBackPhone),
              ),
              Expanded(
                child: Breadcrumbs(
                  path: isPC ? appState.currentPcPath : appState.currentPhonePath,
                  onTap: isPC ? appState.loadPcDirectory : appState.loadPhoneDirectory,
                  separator: isPC ? null : '/',
                ),
              ),
              if (!isPC)
                IconButton(
                  icon: Icon(Icons.refresh_rounded),
                  onPressed: appState.refreshPhoneDirectory,
                ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                FileManager(
                  entities: isPC ? appState.pcFileSystem.entities : appState.phoneFileSystem.entities,
                  currentDirectory: FileSystemEntity(
                    name: (isPC ? appState.currentPcPath : appState.currentPhonePath).split(isPC ? '\\' : '/').last,
                    path: isPC ? appState.currentPcPath : appState.currentPhonePath,
                    isDirectory: true,
                  ),
                  onEntityTap: (entity) {
                    if (entity.isDirectory) {
                      isPC ? appState.loadPcDirectory(entity.path) : appState.loadPhoneDirectory(entity.path);
                    }
                  },
                  onEntitiesDrop: (sources, target) {
                    final destinationPath = target?.path ?? (isPC ? appState.currentPcPath : appState.currentPhonePath);
                    appState.transferFiles(sources, !isPC, destinationPath).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Files transferred ${isPC ? 'to PC' : 'to phone'} successfully')),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error transferring files ${isPC ? 'to PC' : 'to phone'}: $error')),
                      );
                    });
                  },
                  isPhoneFileSystem: !isPC,
                  onPaste: () {
                    appState.pasteFiles(isPC ? appState.currentPcPath : appState.currentPhonePath).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Files pasted successfully')),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error pasting files: $error')),
                      );
                    });
                  },
                  onCopy: (entities) {
                    appState.copyFiles(entities).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Files copied to clipboard')),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error copying files: $error')),
                      );
                    });
                  },
                  onDelete: (entities, permanent) {
                    appState.deleteFiles(entities, permanent).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Files deleted successfully')),
                      );
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting files: $error')),
                      );
                    });
                  },
                  copiedFiles: appState.copiedFiles,
                ),
                if (!isPC && appState.isPhoneLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}