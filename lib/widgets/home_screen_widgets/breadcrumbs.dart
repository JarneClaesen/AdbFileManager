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
                    padding: EdgeInsets.only(top: 3, bottom: 5, left: 8, right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      parts[i].isEmpty ? 'Root' : parts[i],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (i < parts.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
