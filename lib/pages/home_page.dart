import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/wp_api.dart';
import '../services/app_storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _uploading = false;
  String? _lastResult; // per mostrare messaggi di errore
  String? _lastFilePath; // <- ultimo file selezionato (per retry)

  Future<void> _pickAndUpload() async {
    setState(() => _lastResult = null);

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selezione file non valida')),
      );
      return;
    }

    _lastFilePath = path; // <- memorizziamo il path per eventuale retry
    await _uploadFromPath(path);
  }

  Future<void> _uploadFromPath(String path) async {
    // opzionale: verifica che il file esista ancora
    if (!await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il file non è più disponibile sul dispositivo'),
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _lastResult = null;
    });

    try {
      final res = await WpApi.uploadFile(path);

      if (res['ok'] == true &&
          res['remoteUrl'] is String &&
          (res['remoteUrl'] as String).isNotEmpty) {
        final remoteUrl = res['remoteUrl'] as String;

        await AppStorage.addUploadedUrl(remoteUrl);
        await Clipboard.setData(ClipboardData(text: remoteUrl));

        if (!mounted) return;
        final wantEmail = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Upload riuscito'),
            content: const Text(
              'Indirizzo del file copiato negli appunti.\nVuoi inviarlo per email?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sì'),
              ),
            ],
          ),
        );

        if (wantEmail == true) {
          final uri = Uri(
            scheme: 'mailto',
            queryParameters: {'body': remoteUrl},
          );
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload riuscito')));
        setState(() => _lastResult = null);
      } else {
        // Fallimento: offri "Riprova" senza riselezione
        final status = res['status'];
        final body = (res['body'] ?? '').toString();
        setState(() => _lastResult = 'HTTP $status — $body');

        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Upload fallito'),
            content: Text(
              'Errore: HTTP $status\n\nVuoi riprovare ad inviare lo stesso file?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (_lastFilePath != null) {
                    await _uploadFromPath(_lastFilePath!); // <- retry immediato
                  }
                },
                child: const Text('Riprova'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

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
              onPressed: _uploading ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: Text(_uploading ? 'Caricamento…' : 'Carica file'),
            ),
            const SizedBox(height: 8),
            // Pulsante Riprova rapido (se abbiamo già un file selezionato e non stiamo caricando)
            if (_lastFilePath != null && !_uploading)
              OutlinedButton.icon(
                onPressed: () => _uploadFromPath(_lastFilePath!),
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova ultimo file'),
              ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              SelectableText(_lastResult!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
