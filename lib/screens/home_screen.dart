import 'package:flutter/material.dart';

import '../models/app_message.dart';
import '../services/database_service.dart';
import '../services/fcm_service.dart';
import '../widgets/school_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppMessage> _messages = [];
  bool _loading = true;
  String? _userLabel;
  String? _baseUrl;
  int _messagesRequest = 0;

  @override
  void initState() {
    super.initState();
    messageListRevision.addListener(_onRevisionChanged);
    _load();
  }

  @override
  void dispose() {
    messageListRevision.removeListener(_onRevisionChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    _loadMessagesOnly();
  }

  Future<void> _load() async {
    final request = ++_messagesRequest;
    setState(() => _loading = true);
    final user = await DatabaseService.instance.getUser();
    final baseUrl = await DatabaseService.instance.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _userLabel = user?.displayName;
      _baseUrl = baseUrl;
    });
    final messages = await DatabaseService.instance.getMessages();
    if (!mounted || request != _messagesRequest) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _loadMessagesOnly() async {
    final request = ++_messagesRequest;
    final messages = await DatabaseService.instance.getMessages();
    if (!mounted || request != _messagesRequest) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openMessage(AppMessage msg) async {
    if (msg.id != null && !msg.isRead) {
      await DatabaseService.instance.markMessageRead(msg.id!);
      await _loadMessagesOnly();
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(msg.title.isEmpty ? 'Notification' : msg.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.receivedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  msg.body.isEmpty ? '(No content)' : msg.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: SchoolLogo(url: _baseUrl, size: 32),
        ),
        title: const Text('Messages'),
        actions: [
          if (_userLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _userLabel!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(
                  child: Text('No notifications yet.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadMessagesOnly,
                  child: ListView.separated(
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return ListTile(
                        leading: Icon(
                          msg.isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: msg.isRead
                              ? null
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          msg.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                msg.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          msg.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatTime(msg.receivedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _openMessage(msg),
                      );
                    },
                  ),
                ),
    );
  }
}
