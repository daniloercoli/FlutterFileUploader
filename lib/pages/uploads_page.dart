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
    // es: 154979 -> "151.4 KB"
  }

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
          // In produzione potresti usare un URL thumbnail se disponibile
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
                      'Errore: ${snap.error}',
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
                    child: Text('Nessun file caricato.'),
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
                onTap: () => _copyUrl(item.url),
                onLongPress: () => _copyUrl(item.url),
                trailing: IconButton(
                  tooltip: 'Copia URL',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyUrl(item.url),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
