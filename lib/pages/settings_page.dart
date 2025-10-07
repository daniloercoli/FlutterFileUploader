import 'package:flutter/material.dart';
import '../services/app_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStoredValues();
  }

  Future<void> _loadStoredValues() async {
    // Carica i valori salvati (se ci sono)
    final url = await AppStorage.getUrl() ?? '';
    final user = await AppStorage.getUsername() ?? '';
    final pass = await AppStorage.getPassword() ?? '';

    _urlCtrl.text = url;
    _userCtrl.text = user;
    _passCtrl.text = pass;

    setState(() => _loading = false);
  }

  Future<void> _onSave() async {
    // Validazione semplice: URL e credenziali non vuoti
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await AppStorage.setUrl(_urlCtrl.text.trim());
      await AppStorage.setUsername(_userCtrl.text.trim());
      await AppStorage.setPassword(_passCtrl.text);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Impostazioni salvate')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onReset() async {
    setState(() => _saving = true);
    try {
      await AppStorage.resetAll();
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impostazioni ripristinate')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore reset: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Impostazioni WordPress',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // URL
                TextFormField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL del sito (es. http://localhost:8888/wp1)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Inserisci l’URL';
                    // validazione molto basica
                    if (!s.startsWith('http://') && !s.startsWith('https://')) {
                      return 'L’URL deve iniziare con http:// o https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // USERNAME
                TextFormField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Inserisci lo username' : null,
                ),
                const SizedBox(height: 12),

                // PASSWORD (secure)
                TextFormField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Inserisci la password' : null,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _onSave,
                        icon: const Icon(Icons.save),
                        label: _saving
                            ? const Text('Salvataggio…')
                            : const Text('Salva'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _onReset,
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
