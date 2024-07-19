import 'package:flutter/material.dart';
import '../models/file_system_entity.dart';

class FileManager extends StatefulWidget {
  final List<FileSystemEntity> entities;
  final Function(FileSystemEntity) onEntityTap;
  final Function(List<FileSystemEntity>, FileSystemEntity?) onEntitiesDrop;
  final FileSystemEntity currentDirectory;
  final bool isPhoneFileSystem;

  FileManager({
    required this.entities,
    required this.onEntityTap,
    required this.onEntitiesDrop,
    required this.currentDirectory,
    required this.isPhoneFileSystem,
  }) : super(key: ObjectKey(currentDirectory.path));

  @override
  _FileManagerState createState() => _FileManagerState();
}

class _FileManagerState extends State<FileManager> {
  Set<FileSystemEntity> selectedEntities = {};

  @override
  void didUpdateWidget(FileManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentDirectory.path != oldWidget.currentDirectory.path) {
      setState(() {
        selectedEntities.clear();
      });
    }
  }

  Widget _buildListTile(FileSystemEntity entity, {bool isDragging = false, bool isGhost = false}) {
    final isSelected = selectedEntities.contains(entity);
    return Opacity(
      opacity: isGhost ? 0.5 : 1.0,
      child: ListTile(
        leading: Icon(
          entity.isDirectory ? Icons.folder : Icons.insert_drive_file,
          color: entity.isDirectory ? Colors.amber : Colors.blue,
        ),
        title: Text(entity.name),
        subtitle: Text(
            '${entity.size != null ? '${(entity.size! / 1024).toStringAsFixed(2)} KB' : ''}'
                '${entity.lastModified != null ? ' - ${entity.lastModified!.toString()}' : ''}'
        ),
        onTap: () {
          if (selectedEntities.isNotEmpty) {
            setState(() {
              if (isSelected) {
                selectedEntities.remove(entity);
              } else {
                selectedEntities.add(entity);
              }
            });
          } else {
            widget.onEntityTap(entity);
          }
        },
        onLongPress: () {
          setState(() {
            if (isSelected) {
              selectedEntities.remove(entity);
            } else {
              selectedEntities.add(entity);
            }
          });
        },
        tileColor: isDragging ? Colors.grey.withOpacity(0.3) : (isSelected ? Colors.blue.withOpacity(0.1) : null),
        trailing: isSelected ? Icon(Icons.check_circle, color: Colors.blue) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<List<FileSystemEntity>>(
      onWillAccept: (data) => data != null && data.isNotEmpty,
      onAccept: (draggedEntities) {
        widget.onEntitiesDrop(draggedEntities, widget.currentDirectory);
      },
      builder: (context, candidateData, rejectedData) {
        return ListView.builder(
          itemCount: widget.entities.length,
          itemBuilder: (context, index) {
            final entity = widget.entities[index];
            return DragTarget<List<FileSystemEntity>>(
              onWillAccept: (data) => data != null && entity.isDirectory,
              onAccept: (draggedEntities) {
                widget.onEntitiesDrop(draggedEntities, entity);
              },
              builder: (context, candidateData, rejectedData) {
                return Draggable<List<FileSystemEntity>>(
                  data: selectedEntities.isEmpty ? [entity] : selectedEntities.toList(),
                  child: _buildListTile(entity),
                  feedback: Material(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
                      child: _buildListTile(entity, isDragging: true),
                    ),
                  ),
                  childWhenDragging: _buildListTile(entity, isGhost: true),
                );
              },
            );
          },
        );
      },
    );
  }
}