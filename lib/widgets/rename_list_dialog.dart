import 'package:flutter/material.dart';

class RenameListDialog extends StatefulWidget {
  final String currentName;

  const RenameListDialog({super.key, required this.currentName});

  @override
  State<RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<RenameListDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Rename List'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        onSubmitted: (_) => _save(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
