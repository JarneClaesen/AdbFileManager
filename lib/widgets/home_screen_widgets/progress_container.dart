import 'package:flutter/material.dart';
import '../../models/file_transfer.dart';

class ProgressContainer extends StatelessWidget {
  final List<FileTransfer> transfers;
  final double totalProgress;
  final VoidCallback onDismiss;

  const ProgressContainer({
    Key? key,
    required this.transfers,
    required this.totalProgress,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sortedTransfers = List<FileTransfer>.from(transfers)
      ..sort((a, b) => b.progress < 1.0 ? 1 : -1);

    return Container(
      width: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Progress: ${(totalProgress >= 0 ? totalProgress * 100 : 0).toStringAsFixed(2)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (transfers.any((t) => t.progress < 1.0))
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: onDismiss,
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalProgress >= 0 ? totalProgress : null,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
          SizedBox(height: 16),
          if (sortedTransfers.isNotEmpty)
            Container(
              height: 200,
              child: ListView.builder(
                itemCount: sortedTransfers.length,
                itemBuilder: (context, index) {
                  final transfer = sortedTransfers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                transfer.fileName,
                                style: TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (transfer.progress < 1.0)
                              SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: transfer.progress >= 0 ? transfer.progress : null,
                            minHeight: 8,
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          transfer.progress >= 0
                              ? '${(transfer.progress * 100).toStringAsFixed(2)}%'
                              : 'In progress...',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Text('No active transfers', style: TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
