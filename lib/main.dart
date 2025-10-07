import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/uploads_page.dart';
import 'pages/info_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WP Uploader',
      theme: ThemeData(useMaterial3: true),
      home: const AppScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _index = 0;

  final List<Widget> _pages = const [
    HomePage(), // 0
    UploadsPage(), // 1
    SettingsPage(), // 2 (penultima)
    InfoPage(), // 3 (ultima)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // 👈 aggiunto
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (int i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.selected,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: Text('Uploads'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.info_outline),
                  selectedIcon: Icon(Icons.info),
                  label: Text('Info'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_index]),
          ],
        ),
      ),
    );
  }
}
