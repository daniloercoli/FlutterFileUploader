import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wp_api.dart';

class UploadsPage extends StatefulWidget {
  const UploadsPage({super.key});

  @override
  State<UploadsPage> createState() => _UploadsPageState();
}

class _UploadsPageState extends State<UploadsPage> {
  late Future<WpFilesResponse> _future;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _future = WpApi.fetchFiles();
  }

  Future<void> _reload() async {
    setState(() {
      _future = WpApi.fetchFiles();
    });
    await _future;
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('URL copiata negli appunti')));
  }

  String _humanSize(int? bytes) {
    if (bytes == null) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  String _humanDate(int? epochSeconds) {
    if (epochSeconds == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: false,
    );
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Widget _leadingThumb(WpFileItem item) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _placeholderIcon(item),
        ),
      );
    }
    return _placeholderIcon(item);
  }

  Widget _placeholderIcon(WpFileItem item) {
    final mime = (item.mime ?? '').toLowerCase();
    final isPdf =
        mime == 'application/pdf' || item.name.toLowerCase().endsWith('.pdf');
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      child: Icon(isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file),
    );
  }

  Future<void> _showDetails(WpFileItem item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Name: ${item.name}'),
            const SizedBox(height: 6),
            SelectableText('MIME: ${item.mime ?? '—'}'),
            const SizedBox(height: 6),
            SelectableText('Size: ${_humanSize(item.size)}'),
            const SizedBox(height: 6),
            SelectableText('Modified: ${_humanDate(item.modified)}'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            const Text('Remote URL:'),
            const SizedBox(height: 4),
            SelectableText(
              item.url,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () async {
              await _copyUrl(item.url);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(WpFileItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file'),
        content: Text('Do you want to delete “${item.name}” from the server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      final res = await WpApi.deleteFile(item.name);
      if (!mounted) return;

      if (res['ok'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted: ${item.name}')));
        await _reload(); // ricarica la lista dal server
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed (HTTP ${res['status']})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<WpFilesResponse>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error: ${snap.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final data = snap.data!;
              final items = data.items;

              if (items.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No files found.'),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final size = _humanSize(item.size);
                  final subtitle = [
                    if (item.mime != null && item.mime!.isNotEmpty) item.mime,
                    if (size.isNotEmpty) size,
                  ].whereType<String>().join(' • ');

                  return ListTile(
                    leading: _leadingThumb(item),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    // TAP → dettaglio (modal)
                    onTap: () => _showDetails(item),
                    // LONG PRESS → conferma cancellazione
                    onLongPress: () => _confirmAndDelete(item),
                    trailing: IconButton(
                      tooltip: 'Copy URL',
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyUrl(item.url),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Piccolo overlay quando stiamo cancellando
        if (_deleting)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                color: Colors.black.withOpacity(0.05),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 8),
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            ),
          ),
      ],
    );
  }
}
