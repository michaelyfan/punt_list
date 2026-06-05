import 'package:flutter/material.dart';
import '../models/punt_list.dart';

class ListCard extends StatelessWidget {
  final PuntList list;
  final VoidCallback onTap;
  final int? dragHandleIndex;

  const ListCard({super.key, required this.list, required this.onTap, this.dragHandleIndex});

  @override
  Widget build(BuildContext context) {
    // Preview of the list's contents: the active (unchecked) item texts in
    // order, joined into a single line. Falls back to a status string when
    // there's nothing meaningful to preview.
    final activeTexts = list.activeItems
        .map((i) => i.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    String subtitle;
    if (list.items.isEmpty) {
      subtitle = 'No items';
    } else if (activeTexts.isEmpty) {
      subtitle = 'All done';
    } else {
      subtitle = activeTexts.join(' · ');
    }

    final handle = dragHandleIndex != null
        ? ReorderableDragStartListener(
            index: dragHandleIndex!,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_indicator, color: Colors.grey),
            ),
          )
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(list.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: handle,
        onTap: onTap,
      ),
    );
  }
}
