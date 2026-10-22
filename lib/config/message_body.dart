/// How the in-app message list should present a stored notification body.
sealed class MessageBodyView {
  const MessageBodyView();
}

/// Body is only `<src>http(s)://...</src>` — open this URL in a WebView.
class MessageBodyHtmlSrc extends MessageBodyView {
  final String url;
  const MessageBodyHtmlSrc(this.url);
}

/// Ordinary text; [links] are `http`/`https` spans to open in the browser.
class MessageBodyPlain extends MessageBodyView {
  final String text;
  final List<MessageBodyLink> links;
  const MessageBodyPlain(this.text, {this.links = const []});
}

class MessageBodyLink {
  final int start;
  final int end;
  final String url;
  const MessageBodyLink({
    required this.start,
    required this.end,
    required this.url,
  });
}

final _srcOnlyPattern = RegExp(
  r'^\s*<src>\s*(https?://[^\s<>]+)\s*</src>\s*$',
  caseSensitive: false,
);

/// Matches http(s) URLs; trailing sentence punctuation is not part of the URL.
final _httpUrlPattern = RegExp(
  r'https?://[^\s<>]+',
  caseSensitive: false,
);

/// Classify [body] for in-app display. Notification payloads are unchanged.
MessageBodyView interpretMessageBody(String body) {
  final srcMatch = _srcOnlyPattern.firstMatch(body);
  if (srcMatch != null) {
    return MessageBodyHtmlSrc(srcMatch.group(1)!);
  }

  final links = <MessageBodyLink>[];
  for (final match in _httpUrlPattern.allMatches(body)) {
    var url = match.group(0)!;
    var end = match.end;
    while (url.isNotEmpty && _trailingPunctuation.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
      end--;
    }
    if (url.isEmpty) continue;
    links.add(MessageBodyLink(start: match.start, end: end, url: url));
  }

  return MessageBodyPlain(body, links: links);
}

const _trailingPunctuation = {'.', ',', ';', ':', '!', '?', ')', ']', '}'};

/// List-row preview: show the src URL, otherwise the raw body.
String messageBodyPreview(String body) {
  return switch (interpretMessageBody(body)) {
    MessageBodyHtmlSrc(:final url) => url,
    MessageBodyPlain(:final text) => text,
  };
}
