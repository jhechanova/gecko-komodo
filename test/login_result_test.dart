import 'package:flutter_test/flutter_test.dart';
import 'package:notif_app/services/api_service.dart';

void main() {
  group('interpretLoginResponse', () {
    test('HTTP 404 means the site or tpl is unavailable', () {
      final result = interpretLoginResponse(404, 'not found', 'teacher');

      expect(result, isA<LoginFailure>());
      expect(
        (result as LoginFailure).message,
        'The URL is not accessible.',
      );
    });

    test('HTTP 200 with body status_code 404 means the user was not found', () {
      final result = interpretLoginResponse(
        200,
        '{"status_code":404}',
        'teacher',
      );

      expect(result, isA<LoginFailure>());
      expect((result as LoginFailure).message, 'User not found.');
    });

    test('HTTP 200 with body status_code 200 means the user was found', () {
      final result = interpretLoginResponse(
        200,
        '{"status_code":200,"id":"7","email":"a@b.com","first_name":"Ada","last_name":"Lovelace"}',
        'teacher',
      );

      expect(result, isA<LoginSuccess>());
      final user = (result as LoginSuccess).user;
      expect(user.id, '7');
      expect(user.username, 'teacher');
      expect(user.firstName, 'Ada');
    });
  });
}
