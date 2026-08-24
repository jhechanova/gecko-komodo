import 'package:flutter_test/flutter_test.dart';

import 'package:notif_app/main.dart';

void main() {
  testWidgets('App builds MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const NotifApp());
    expect(find.byType(NotifApp), findsOneWidget);
  });
}
