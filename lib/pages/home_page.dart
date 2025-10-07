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
  String? _lastResult; // solo per debug/errori

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

    setState(() => _uploading = true);
    try {
      final res = await WpApi.uploadFile(path);

      if (res['ok'] == true &&
          res['remoteUrl'] is String &&
          (res['remoteUrl'] as String).isNotEmpty) {
        final remoteUrl = res['remoteUrl'] as String;

        // 1) salva in history
        await AppStorage.addUploadedUrl(remoteUrl);

        // 2) copia negli appunti
        await Clipboard.setData(ClipboardData(text: remoteUrl));

        // 3) domanda all’utente
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
          // apri client email di default con body precompilato
          final uri = Uri(
            scheme: 'mailto',
            // puoi lasciare to/subject vuoti o precompilarli:
            // path: 'destinatario@example.com',
            queryParameters: {
              // 'subject': 'File caricato',
              'body': remoteUrl,
            },
          );
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload riuscito')));
        setState(
          () => _lastResult = null,
        ); // non mostriamo il body in caso di successo
      } else {
        final status = res['status'];
        final body = res['body'];
        setState(() => _lastResult = 'HTTP $status — $body');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload fallito: HTTP $status')));
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
