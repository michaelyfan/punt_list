import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/destination_dropdown.dart';
import '../widgets/help_dialog.dart';

class SettingsScreen extends StatelessWidget {
  final AppState appState;
  final void Function(VoidCallback) update;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.update,
  });

  void _showHelp(BuildContext context) {
    showDialog(context: context, builder: (_) => const HelpDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme section
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: appState.themeMode,
              onChanged: (v) {
                if (v != null) update(() => appState.setThemeMode(v));
              },
              child: Column(
                children: const [
                  RadioListTile<ThemeMode>(
                    title: Text('Light'),
                    secondary: Icon(Icons.light_mode_outlined),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Dark'),
                    secondary: Icon(Icons.dark_mode_outlined),
                    value: ThemeMode.dark,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('System'),
                    secondary: Icon(Icons.desktop_mac_outlined),
                    value: ThemeMode.system,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Move Settings section
          Text('Move Settings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Configure where items go when you tap the move arrow (→) on each list.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (appState.lists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No lists yet.'),
            )
          else
            ...appState.lists.map((list) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              list.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'moves to:',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DestinationDropdown(
                          sourceList: list,
                          allLists: appState.lists,
                          appState: appState,
                          update: update,
                        ),
                      ],
                    ),
                  ),
                )),

          const SizedBox(height: 24),

          // Account section
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
