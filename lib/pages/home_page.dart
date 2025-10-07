import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Carica nuovi file su WordPress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: qui aggiungeremo il file picker e l'upload
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upload: da implementare')),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Carica file'),
            ),
          ],
        ),
      ),
    );
  }
}
