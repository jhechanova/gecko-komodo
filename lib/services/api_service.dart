import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';

sealed class LoginResult {}

class LoginSuccess extends LoginResult {
  final AppUser user;
  LoginSuccess(this.user);
}

class LoginFailure extends LoginResult {
  final String message;
  LoginFailure(this.message);
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Tries https, then http. Returns the base URL that responds, or null.
  Future<String?> resolveAccessibleBaseUrl(String host) async {
    for (final scheme in ['https', 'http']) {
      final base = '$scheme://$host';
      try {
        final response = await http
            .get(_apiUri(base, const {}))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode > 0) return base;
      } catch (_) {}
    }
    return null;
  }

  Uri _apiUri(String baseUrl, Map<String, String> query) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized/app/api.cf').replace(queryParameters: query);
  }

  Future<LoginResult> login(
    String baseUrl,
    String username,
    String password,
  ) async {
    final uri = _apiUri(baseUrl, {
      'tpl': 'login',
      'username': username,
      'password': password,
    });

    try {
      final response = await http.get(uri);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final statusCode = body['status_code']?.toString() ?? '';

      if (statusCode == '200') {
        return LoginSuccess(AppUser.fromLoginJson(body, username));
      }

      return LoginFailure('The URL is not accessible.');
    } catch (_) {
      return LoginFailure('The URL is not accessible.');
    }
  }

  Future<void> registerFcmToken({
    required String baseUrl,
    required String userId,
    required String fcmToken,
    required String deviceId,
  }) async {
    final uri = _apiUri(baseUrl, {
      'tpl': 'fcm_token',
      'tph': 'set_fcm_token',
      'user_id': userId,
      'fcm_token': fcmToken,
      'device_id': deviceId,
    });

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('The URL is not accessible.');
    }
  }
}
