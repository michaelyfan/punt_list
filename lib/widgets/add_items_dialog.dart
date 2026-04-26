import 'package:flutter/material.dart';

class AddItemsDialog extends StatefulWidget {
  const AddItemsDialog({super.key});

  @override
  State<AddItemsDialog> createState() => _AddItemsDialogState();
}

class _AddItemsDialogState extends State<AddItemsDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _hasNewline = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasNewline = _controller.text.contains('\n');
      if (hasNewline != _hasNewline) {
        setState(() => _hasNewline = hasNewline);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final lines = _controller.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    Navigator.pop(context, lines);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Add items'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            minLines: 1,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(
              hintText: 'Add new item...',
              border: OutlineInputBorder(),
            ),
          ),
          if (_hasNewline)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Line breaks will become different items.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
