import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'app_storage.dart';

// ---- Modello semplice per un file ----
class WpFileItem {
  final String name;
  final String url;
  final int? size;
  final String? mime;
  final int? modified; // epoch seconds, lato server

  WpFileItem({
    required this.name,
    required this.url,
    this.size,
    this.mime,
    this.modified,
  });

  bool get isImage => (mime ?? '').startsWith('image/');

  factory WpFileItem.fromJson(Map<String, dynamic> json) {
    return WpFileItem(
      name: (json['name'] ?? json['file'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      size: (json['size'] is int) ? json['size'] as int : null,
      mime: json['mime'] as String?,
      modified: (json['modified'] is int) ? json['modified'] as int : null,
    );
  }
}

class WpFilesResponse {
  final bool ok;
  final List<WpFileItem> items;
  final int? total;

  WpFilesResponse({required this.ok, required this.items, this.total});

  factory WpFilesResponse.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true;
    final rawItems = (json['items'] is List)
        ? (json['items'] as List)
        : <dynamic>[];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((e) => WpFileItem.fromJson(e))
        .toList();
    return WpFilesResponse(
      ok: ok,
      items: items,
      total: (json['total'] is int) ? json['total'] as int : items.length,
    );
  }
}

class WpApi {
  static Future<WpFilesResponse> fetchFiles() async {
    final baseUrl = await AppStorage.getUrl();
    final username = await AppStorage.getUsername();
    final password = await AppStorage.getPassword();

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('URL non configurato');
    }
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      throw Exception('Credenziali mancanti');
    }

    final uri = Uri.parse('$baseUrl/wp-json/fileuploader/v1/files');
    final auth = base64Encode(utf8.encode('$username:$password'));
    final res = await http.get(uri, headers: {'Authorization': 'Basic $auth'});

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    return WpFilesResponse.fromJson(json);
  }

  /// Esegue l'upload del file come multipart su:
  /// {baseUrl}/wp-json/fileuploader/v1/upload
  ///
  /// Salva la URL del server in storage
  static Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final baseUrl = await AppStorage.getUrl();
    final username = await AppStorage.getUsername();
    final password = await AppStorage.getPassword();

    if (baseUrl == null || baseUrl.isEmpty) {
      return {'ok': false, 'status': 0, 'body': 'URL non configurato'};
    }
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return {'ok': false, 'status': 0, 'body': 'Credenziali mancanti'};
    }

    final uri = Uri.parse('$baseUrl/wp-json/fileuploader/v1/upload');
    final req = http.MultipartRequest('POST', uri);

    // Basic Auth
    final auth = base64Encode(utf8.encode('$username:$password'));
    req.headers['Authorization'] = 'Basic $auth';

    // Se vuoi: deduci mime; se non vuoi complicare, puoi omettere contentType.
    req.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      final ok = res.statusCode >= 200 && res.statusCode < 300;
      String? remoteUrl;

      // Proviamo a estrarre l'URL dalla risposta
      final body = res.body.trim();
      // 1) JSON noto
      try {
        final obj = jsonDecode(body);
        if (obj is Map) {
          // copriamo vari casi comuni
          remoteUrl =
              (obj['url'] ?? obj['link'] ?? obj['source_url']) as String?;
          if (remoteUrl == null &&
              obj['guid'] is Map &&
              obj['guid']['rendered'] is String) {
            remoteUrl = obj['guid']['rendered'] as String;
          }
          if (remoteUrl == null && obj['guid'] is String) {
            remoteUrl = obj['guid'] as String;
          }
        } else if (obj is String) {
          // se il server ritorna direttamente la stringa URL
          remoteUrl = obj;
        }
      } catch (_) {
        // 2) non JSON: prova a riconoscere un URL “nudo” nel testo
        final match = RegExp(r'https?://\S+').firstMatch(body);
        if (match != null) remoteUrl = match.group(0);
      }

      return {
        'ok': ok,
        'status': res.statusCode,
        'body': body,
        'remoteUrl': remoteUrl,
      };
    } on SocketException catch (e) {
      return {'ok': false, 'status': 0, 'body': 'Errore di rete: $e'};
    } catch (e) {
      return {'ok': false, 'status': 0, 'body': 'Errore: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteFile(String fileName) async {
    final baseUrl = await AppStorage.getUrl();
    final username = await AppStorage.getUsername();
    final password = await AppStorage.getPassword();

    if (baseUrl == null || baseUrl.isEmpty) {
      return {'ok': false, 'status': 0, 'body': 'URL non configurato'};
    }
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return {'ok': false, 'status': 0, 'body': 'Credenziali mancanti'};
    }

    final encoded = Uri.encodeComponent(fileName);
    final uri = Uri.parse('$baseUrl/wp-json/fileuploader/v1/files/$encoded');
    final auth = base64Encode(utf8.encode('$username:$password'));

    final res = await http.delete(
      uri,
      headers: {'Authorization': 'Basic $auth'},
    );

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return {'ok': ok, 'status': res.statusCode, 'body': res.body};
  }
}
