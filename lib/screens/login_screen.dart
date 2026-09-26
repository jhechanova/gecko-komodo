import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/fcm_service.dart';
import '../widgets/school_logo.dart';
import 'home_screen.dart';
import 'url_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final url = await DatabaseService.instance.getBaseUrl();
    if (!mounted) return;
    setState(() => _baseUrl = url);
  }

  Future<void> _editServerUrl() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UrlSetupScreen(initialUrl: _baseUrl ?? ''),
      ),
    );
    if (!mounted) return;
    setState(() => _error = null);
    await _loadBaseUrl();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final baseUrl = await DatabaseService.instance.getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Server URL is not configured.';
      });
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final result = await ApiService.instance.login(baseUrl, username, password);

    if (!mounted) return;

    switch (result) {
      case LoginSuccess(:final user):
        await DatabaseService.instance.saveUser(user);
        try {
          await FcmService.instance.getAndSyncToken();
        } catch (e) {
          debugPrint('FCM token registration failed: $e');
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      case LoginFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Change server URL',
          onPressed: _loading ? null : _editServerUrl,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SchoolLogo(url: _baseUrl, size: 96),
                ),
                const SizedBox(height: 24),
                Text(
                  'Enter your credentials to receive notifications.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_baseUrl != null && _baseUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _baseUrl!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
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
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
