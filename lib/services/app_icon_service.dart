import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/school_branding.dart';

class AppIconService {
  AppIconService._();
  static final AppIconService instance = AppIconService._();

  /// Apply the OS home-screen icon for [brand]. No-ops on unsupported platforms.
  Future<void> applyBrand(SchoolBrand brand) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final supported =
          await DynamicAppIconFlutterPlus.supportsAlternateIcons;
      if (!supported) {
        debugPrint('App icon change skipped: alternate icons unsupported');
        return;
      }

      // Short alias key (hijas, scsc, …) or null for the primary icon.
      final target = brand.alternateIconName;
      final current = await DynamicAppIconFlutterPlus.getAlternateIconName();
      final currentKey = (current == null || current.isEmpty) ? null : current;
      if (currentKey == target) return;

      debugPrint(
        'App icon change: current=$currentKey target=$target brand=${brand.id}',
      );

      await DynamicAppIconFlutterPlus.setAlternateIconName(target);
    } on PlatformException catch (e) {
      debugPrint('App icon change failed: $e');
    } catch (e) {
      debugPrint('App icon change failed: $e');
    }
  }

  Future<void> applyForUrl(String? url) async {
    await applyBrand(resolveSchoolBrand(url));
  }
}
