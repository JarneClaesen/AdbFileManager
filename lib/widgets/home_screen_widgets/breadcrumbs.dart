import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class Breadcrumbs extends StatelessWidget {
  final String path;
  final Function(String) onTap;
  final String? separator;

  Breadcrumbs({required this.path, required this.onTap, this.separator});

  @override
  Widget build(BuildContext context) {
    final parts = path.split(separator ?? Platform.pathSeparator);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < parts.length; i++)
            Row(
              children: [
                InkWell(
                  onTap: () => onTap(parts.sublist(0, i + 1).join(separator ?? Platform.pathSeparator)),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      parts[i].isEmpty ? 'Root' : parts[i],
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (i < parts.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
