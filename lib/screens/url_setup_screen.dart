import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_icon_service.dart';
import '../services/database_service.dart';
import '../widgets/school_logo.dart';
import 'login_screen.dart';

class UrlSetupScreen extends StatefulWidget {
  const UrlSetupScreen({super.key, this.initialUrl = ''});

  final String initialUrl;

  @override
  State<UrlSetupScreen> createState() => _UrlSetupScreenState();
}

class _UrlSetupScreenState extends State<UrlSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _saving = false;
  String _previewUrl = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final host = _hostnameOnly(widget.initialUrl);
    _urlController.text = host;
    _previewUrl = host;
    _urlController.addListener(_onUrlChanged);
  }

  String _hostnameOnly(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    final hasProtocol = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
    final candidate = hasProtocol ? value : 'https://$value';
    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host.split(RegExp(r'[/?#&]')).first;
    }

    value = value.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
    final cut = value.indexOf(RegExp(r'[/?#&]'));
    if (cut >= 0) value = value.substring(0, cut);
    return value;
  }

  void _onUrlChanged() {
    final text = _urlController.text;
    if (RegExp(r'://|[/?#&]').hasMatch(text)) {
      final host = _hostnameOnly(text);
      if (host != text) {
        _urlController.value = TextEditingValue(
          text: host,
          selection: TextSelection.collapsed(offset: host.length),
        );
        return;
      }
    }
    setState(() => _previewUrl = text.trim());
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final raw = _hostnameOnly(value ?? '');
    if (raw.isEmpty) return 'URL is required';
    if (raw.contains(' ')) {
      return 'Enter a valid hostname (e.g. my.server.com)';
    }
    final host = RegExp(
      r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?::\d{1,5})?$',
    );
    if (!host.hasMatch(raw)) {
      return 'Enter a valid hostname (e.g. my.server.com)';
    }
    return null;
  }

  Future<void> _save() async {
    final host = _hostnameOnly(_urlController.text);
    if (host != _urlController.text) {
      _urlController.text = host;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final normalized =
        await ApiService.instance.resolveAccessibleBaseUrl(host);

    if (!mounted) return;
    if (normalized == null) {
      setState(() {
        _saving = false;
        _error = 'The URL is not accessible.';
      });
      return;
    }

    await DatabaseService.instance.setBaseUrl(normalized);
    await AppIconService.instance.applyForUrl(normalized);

    if (!mounted) return;
    setState(() => _saving = false);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server URL')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SchoolLogo(url: _previewUrl, size: 96),
                ),
                const SizedBox(height: 24),
                Text(
                  'Enter the address of your notification server.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Notification Server',
                    hintText: 'my.server.com',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateUrl,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving || _urlController.text.trim().isEmpty
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
