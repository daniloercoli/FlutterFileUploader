import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  // Chiavi
  static const _keyUrl = 'wp_url';
  static const _keyUser = 'wp_username';
  static const _keyPass = 'wp_password'; // secure
  static const _keyUploads = 'wp_uploaded_urls';

  // Secure storage (Keychain/Keystore)
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  // ---------- GET ----------
  static Future<String?> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUrl);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUser);
  }

  static Future<String?> getPassword() async {
    return await _secure.read(key: _keyPass);
  }

  // ---------- SET ----------
  static Future<void> setUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, value);
  }

  static Future<void> setUsername(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, value);
  }

  static Future<void> setPassword(String value) async {
    await _secure.write(key: _keyPass, value: value);
  }

  // ---------- RESET (cancella tutto ciò che riguarda WP) ----------
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUrl);
    await prefs.remove(_keyUser);
    await _secure.delete(key: _keyPass);
  }

  // --- Uploads history ---
  static Future<List<String>> getUploadedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyUploads) ?? <String>[];
  }

  static Future<void> addUploadedUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyUploads) ?? <String>[];
    // Evita duplicati consecutivi
    if (list.isEmpty || list.first != url) {
      list.insert(0, url);
      // mantieni al massimo 100
      if (list.length > 100) list.removeRange(100, list.length);
      await prefs.setStringList(_keyUploads, list);
    }
  }

  static Future<void> clearUploadedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUploads);
  }
}
