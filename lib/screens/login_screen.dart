import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/fcm_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
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
    final result = await ApiService.instance.login(baseUrl, username);

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
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your username to receive notifications.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
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
