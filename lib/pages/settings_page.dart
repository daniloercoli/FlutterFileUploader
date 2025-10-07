import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Settings (URL, username, password)\n'
          '— placeholder: tra poco aggiungiamo i campi e il salvataggio',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
