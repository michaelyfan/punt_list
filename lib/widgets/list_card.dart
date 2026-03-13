import 'package:flutter/material.dart';
import '../models/punt_list.dart';

class ListCard extends StatelessWidget {
  final PuntList list;
  final VoidCallback onTap;
  final int? dragHandleIndex;

  const ListCard({super.key, required this.list, required this.onTap, this.dragHandleIndex});

  @override
  Widget build(BuildContext context) {
    final active = list.activeItems.length;
    final checked = list.checkedItems.length;

    String subtitle;
    if (active == 0 && checked == 0) {
      subtitle = 'No items';
    } else if (checked == 0) {
      subtitle = '$active active';
    } else if (active == 0) {
      subtitle = '$checked completed';
    } else {
      subtitle = '$active active, $checked completed';
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
        subtitle: Text(subtitle),
        trailing: handle,
        onTap: onTap,
      ),
    );
  }
}
