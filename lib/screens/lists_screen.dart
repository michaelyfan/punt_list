import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/list_card.dart';
import 'list_view_screen.dart';
import 'settings_screen.dart';

class ListsScreen extends StatelessWidget {
  final AppState appState;
  final void Function(VoidCallback) update;

  const ListsScreen({
    super.key,
    required this.appState,
    required this.update,
  });

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(appState: appState, update: update),
      ),
    );
  }

  void _createList(BuildContext context) {
    late final dynamic newList;
    update(() {
      newList = appState.addList();
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListViewScreen(
          listId: newList.id,
          appState: appState,
          update: update,
        ),
      ),
    );
  }

  void _openList(BuildContext context, String listId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListViewScreen(
          listId: listId,
          appState: appState,
          update: update,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: appState.lists.isEmpty
          ? const Center(child: Text('No lists yet. Tap + to create one!'))
          : ReorderableListView(
              padding: const EdgeInsets.only(top: 8),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) => update(() {
                appState.reorderList(oldIndex, newIndex);
              }),
              children: [
                for (int i = 0; i < appState.lists.length; i++)
                  ListCard(
                    key: ValueKey(appState.lists[i].id),
                    list: appState.lists[i],
                    dragHandleIndex: i,
                    onTap: () => _openList(context, appState.lists[i].id),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createList(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
