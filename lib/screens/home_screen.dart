import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/message_body.dart';
import '../models/app_message.dart';
import '../services/database_service.dart';
import '../services/fcm_service.dart';
import '../widgets/message_html_preview.dart';
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
  int _retention = DatabaseService.messageRetentionDefault;
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
    final retention = await DatabaseService.instance.getMessageRetention();
    await DatabaseService.instance.trimMessagesToRetention(retention);
    if (!mounted) return;
    setState(() {
      _userLabel = user?.displayName;
      _baseUrl = baseUrl;
      _retention = retention;
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
    final retention = await DatabaseService.instance.getMessageRetention();
    await DatabaseService.instance.trimMessagesToRetention(retention);
    final messages = await DatabaseService.instance.getMessages();
    if (!mounted || request != _messagesRequest) return;
    setState(() {
      _retention = retention;
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _onRetentionSelected(int? value) async {
    if (value == null || value == _retention) return;
    await DatabaseService.instance.setMessageRetention(value);
    if (!mounted) return;
    setState(() => _retention = value);
    await _loadMessagesOnly();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$month/$day/${dt.year}';
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _markRead(AppMessage msg) async {
    if (msg.id == null || msg.isRead) return;
    await DatabaseService.instance.markMessageRead(msg.id!);
    await _loadMessagesOnly();
  }

  Future<void> _openMessage(AppMessage msg) async {
    await _markRead(msg);
    if (!mounted) return;

    // Src HTML messages already show their page in the list row.
    if (interpretMessageBody(msg.body) is MessageBodyHtmlSrc) return;

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
                _MessageBodyText(
                  body: msg.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                  onOpenUrl: _openExternalUrl,
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

  Widget _buildMessageTile(AppMessage msg) {
    final bodyView = interpretMessageBody(msg.body);
    final timeLabel = _formatTime(msg.receivedAt);
    final titleStyle = TextStyle(
      fontWeight: msg.isRead ? FontWeight.normal : FontWeight.bold,
    );

    if (bodyView is MessageBodyHtmlSrc) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _markRead(msg),
              child: Row(
                children: [
                  Icon(
                    msg.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: msg.isRead
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      msg.title.isEmpty ? 'Notification' : msg.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            MessageHtmlPreview(
              key: ValueKey('html-${msg.id}-${bodyView.url}'),
              url: bodyView.url,
            ),
          ],
        ),
      );
    }

    return ListTile(
      leading: Icon(
        msg.isRead ? Icons.notifications_none : Icons.notifications_active,
        color: msg.isRead ? null : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        msg.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      ),
      subtitle: Text(
        messageBodyPreview(msg.body),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        timeLabel,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => _openMessage(msg),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text(
                  _loading
                      ? '…'
                      : '${_messages.length} '
                          '${_messages.length == 1 ? 'message' : 'messages'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _retention,
                    isDense: true,
                    onChanged: _onRetentionSelected,
                    items: [
                      for (final option
                          in DatabaseService.messageRetentionOptions)
                        DropdownMenuItem(
                          value: option,
                          child: Text('Keep $option'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
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
                            return _buildMessageTile(_messages[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MessageBodyText extends StatefulWidget {
  final String body;
  final TextStyle? style;
  final Future<void> Function(String url) onOpenUrl;

  const _MessageBodyText({
    required this.body,
    required this.style,
    required this.onOpenUrl,
  });

  @override
  State<_MessageBodyText> createState() => _MessageBodyTextState();
}

class _MessageBodyTextState extends State<_MessageBodyText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.body.isEmpty) {
      return Text('(No content)', style: widget.style);
    }

    final view = interpretMessageBody(widget.body);
    if (view is! MessageBodyPlain || view.links.isEmpty) {
      return Text(widget.body, style: widget.style);
    }

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final linkStyle = (widget.style ?? const TextStyle()).copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final link in view.links) {
      if (link.start > cursor) {
        spans.add(TextSpan(text: widget.body.substring(cursor, link.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          widget.onOpenUrl(link.url);
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: widget.body.substring(link.start, link.end),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = link.end;
    }
    if (cursor < widget.body.length) {
      spans.add(TextSpan(text: widget.body.substring(cursor)));
    }

    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
