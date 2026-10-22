import 'package:flutter_test/flutter_test.dart';
import 'package:notif_app/config/message_body.dart';

void main() {
  group('interpretMessageBody', () {
    test('body that is only a src tag is an HTML page URL', () {
      final result = interpretMessageBody(
        '<src>https://example.com/page.html</src>',
      );

      expect(result, isA<MessageBodyHtmlSrc>());
      expect(
        (result as MessageBodyHtmlSrc).url,
        'https://example.com/page.html',
      );
    });

    test('src tag may have surrounding whitespace', () {
      final result = interpretMessageBody(
        '  <src> http://school.app/notice </src>  ',
      );

      expect(result, isA<MessageBodyHtmlSrc>());
      expect((result as MessageBodyHtmlSrc).url, 'http://school.app/notice');
    });

    test('mixed text keeps http links for the browser', () {
      final result = interpretMessageBody(
        'hello click http://www.google.com to view the full message',
      );

      expect(result, isA<MessageBodyPlain>());
      final plain = result as MessageBodyPlain;
      expect(plain.links, hasLength(1));
      expect(plain.links.single.url, 'http://www.google.com');
      expect(
        plain.text.substring(plain.links.single.start, plain.links.single.end),
        'http://www.google.com',
      );
    });

    test('trailing punctuation is not part of the link', () {
      final result = interpretMessageBody('See https://example.com/path.');

      expect(result, isA<MessageBodyPlain>());
      final plain = result as MessageBodyPlain;
      expect(plain.links.single.url, 'https://example.com/path');
    });

    test('body without a URL stays plain text', () {
      final result = interpretMessageBody('Class is cancelled tomorrow.');

      expect(result, isA<MessageBodyPlain>());
      final plain = result as MessageBodyPlain;
      expect(plain.text, 'Class is cancelled tomorrow.');
      expect(plain.links, isEmpty);
    });

    test('src tag with extra text is not treated as HTML src', () {
      final result = interpretMessageBody(
        'Open <src>https://example.com</src> later',
      );

      expect(result, isA<MessageBodyPlain>());
    });
  });

  group('messageBodyPreview', () {
    test('shows the URL for a src-only body', () {
      expect(
        messageBodyPreview('<src>https://example.com/a</src>'),
        'https://example.com/a',
      );
    });

    test('shows the raw body otherwise', () {
      expect(
        messageBodyPreview('hello http://a.com'),
        'hello http://a.com',
      );
    });
  });
}
