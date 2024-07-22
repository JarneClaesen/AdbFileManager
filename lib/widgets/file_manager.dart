import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:contextmenu/contextmenu.dart';
import '../models/file_system_entity.dart';

class FileManager extends StatefulWidget {
  final List<FileSystemEntity> entities;
  final Function(FileSystemEntity) onEntityTap;
  final Function(List<FileSystemEntity>, FileSystemEntity?) onEntitiesDrop;
  final FileSystemEntity currentDirectory;
  final bool isPhoneFileSystem;
  final VoidCallback onPaste;
  final Function(List<FileSystemEntity>) onCopy;
  final List<FileSystemEntity> copiedFiles;
  final Function(List<FileSystemEntity>, bool) onDelete;

  FileManager({
    required this.entities,
    required this.onEntityTap,
    required this.onEntitiesDrop,
    required this.currentDirectory,
    required this.isPhoneFileSystem,
    required this.onPaste,
    required this.onCopy,
    required this.copiedFiles,
    required this.onDelete,
  }) : super(key: ObjectKey(currentDirectory.path));

  @override
  _FileManagerState createState() => _FileManagerState();
}

class _FileManagerState extends State<FileManager> {
  Set<String> selectedEntityPaths = {};
  int? lastSelectedIndex;
  int? lastTapIndex;
  DateTime? lastTapTime;
  bool isCtrlPressed = false;
  bool isShiftPressed = false;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    setState(() {
      if (event is RawKeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.controlRight) {
          isCtrlPressed = true;
        } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          isShiftPressed = true;
        } else if (event.logicalKey == LogicalKeyboardKey.delete) {
          _handleDelete();
        }
      } else if (event is RawKeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.controlRight) {
          isCtrlPressed = false;
        } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          isShiftPressed = false;
        }
      }
    });
  }

  void _handleDelete() {
    if (selectedEntityPaths.isNotEmpty) {
      widget.onDelete(
          widget.entities.where((e) => selectedEntityPaths.contains(e.path)).toList(),
          isShiftPressed
      );
    }
  }

  void _handleTap(FileSystemEntity entity, int index) {
    final now = DateTime.now();

    if (lastTapIndex == index &&
        lastTapTime != null &&
        now.difference(lastTapTime!) < Duration(milliseconds: 500)) {
      // Double tap detected
      if (entity.isDirectory) {
        widget.onEntityTap(entity);
      }
      lastTapIndex = null;
      lastTapTime = null;
    } else {
      // Single tap
      setState(() {
        if (isCtrlPressed) {
          if (selectedEntityPaths.contains(entity.path)) {
            selectedEntityPaths.remove(entity.path);
          } else {
            selectedEntityPaths.add(entity.path);
          }
        } else if (isShiftPressed && lastSelectedIndex != null) {
          final start = lastSelectedIndex!.compareTo(index) < 0 ? lastSelectedIndex! : index;
          final end = lastSelectedIndex!.compareTo(index) < 0 ? index : lastSelectedIndex!;
          for (var i = start; i <= end; i++) {
            selectedEntityPaths.add(widget.entities[i].path);
          }
        } else {
          selectedEntityPaths.clear();
          selectedEntityPaths.add(entity.path);
        }
        lastSelectedIndex = index;
      });
      lastTapIndex = index;
      lastTapTime = now;
    }
  }

  Widget _buildListTile(FileSystemEntity entity, int index, {bool isDragging = false, bool isGhost = false}) {
    final isSelected = selectedEntityPaths.contains(entity.path);
    return Opacity(
      opacity: isGhost ? 0.5 : 1.0,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ContextMenuArea(
          builder: (context) => [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copy'),
              onTap: () {
                widget.onCopy(selectedEntityPaths.isEmpty ? [entity] : widget.entities.where((e) => selectedEntityPaths.contains(e.path)).toList());
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: Icon(Icons.paste),
              title: Text('Paste'),
              onTap: () {
                widget.onPaste();
                Navigator.of(context).pop();
              },
              enabled: widget.copiedFiles.isNotEmpty,
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                _handleDelete();
                Navigator.of(context).pop();
              },
            ),
          ],
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleTap(entity, index),
              child: Ink(
                decoration: BoxDecoration(
                  color: isDragging
                      ? Theme.of(context).colorScheme.surfaceContainerLowest
                      : (isSelected ? Theme.of(context).colorScheme.surfaceContainerHigh : Theme.of(context).colorScheme.surface),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    entity.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: entity.isDirectory ? Colors.amber : Colors.blue,
                  ),
                  title: Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(entity.name),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(bottom: 0),
                    child: Text(
                        '${entity.size != null ? '${(entity.size! / 1024).toStringAsFixed(2)} KB' : ''}'
                            '${entity.lastModified != null ? ' - ${entity.lastModified!.toString()}' : ''}'
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
              ),
            ),
          ),
        ),
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
        return ContextMenuArea(
          builder: (context) => [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copy'),
              onTap: () {
                widget.onCopy(widget.entities.where((e) => selectedEntityPaths.contains(e.path)).toList());
                Navigator.of(context).pop();
              },
              enabled: selectedEntityPaths.isNotEmpty,
            ),
            ListTile(
              leading: Icon(Icons.paste),
              title: Text('Paste'),
              onTap: () {
                widget.onPaste();
                Navigator.of(context).pop();
              },
              enabled: widget.copiedFiles.isNotEmpty,
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                _handleDelete();
                Navigator.of(context).pop();
              },
              enabled: selectedEntityPaths.isNotEmpty,
            ),
          ],
          child: ListView.builder(
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
                    data: selectedEntityPaths.isEmpty ? [entity] : widget.entities.where((e) => selectedEntityPaths.contains(e.path)).toList(),
                    child: _buildListTile(entity, index),
                    feedback: Material(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
                        child: _buildListTile(entity, index, isDragging: true),
                      ),
                    ),
                    childWhenDragging: _buildListTile(entity, index, isGhost: true),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
