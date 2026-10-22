import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders a `<src>URL</src>` message body inside a list row.
class MessageHtmlPreview extends StatefulWidget {
  final String url;

  /// Caps tall pages so one HTML message does not own the whole list.
  static const double maxHeight = 120;

  const MessageHtmlPreview({
    super.key,
    required this.url,
  });

  @override
  State<MessageHtmlPreview> createState() => _MessageHtmlPreviewState();
}

class _MessageHtmlPreviewState extends State<MessageHtmlPreview> {
  late final WebViewController _controller;
  var _loading = true;
  var _initialPageLoaded = false;

  /// Lets the platform WebView win vertical drags over the parent ListView.
  static final Set<Factory<OneSequenceGestureRecognizer>> _gestures =
      <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            _initialPageLoaded = true;
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    // Keep iframe / subresource loads inside the preview.
    if (!request.isMainFrame) return NavigationDecision.navigate;
    // First load (and redirects before it finishes) stay in the WebView.
    if (!_initialPageLoaded) return NavigationDecision.navigate;

    _openInBrowser(request.url);
    return NavigationDecision.prevent;
  }

  @override
  void didUpdateWidget(covariant MessageHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _initialPageLoaded = false;
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MessageHtmlPreview.maxHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
              gestureRecognizers: _gestures,
            ),
            if (_loading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
