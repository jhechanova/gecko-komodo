---
name: add-school-brand
description: Adds a school tenant to Komodo (notif_app) so a server URL resolves to an in-app logo and iOS/Android alternate icon. Use when adding a school, tenant, brand, host, or alternate app icon.
---

# Add a school brand

One id (lowercase, no spaces) is used everywhere. Example id: `hijas`.

## Checklist

- [ ] `assets/icon/tenants/{id}.png` (in-app logo; folder is already in `pubspec.yaml`)
- [ ] `lib/config/school_branding.dart` — `_brandsById`, `_hostToBrandId`, and `_fullUrlToBrandId` (https, http, and bare host)
- [ ] `test/school_branding_test.dart` — known host, `www.`, trailing slash, and `alternateIconName`
- [ ] Android mipmaps `ic_{id}.png` in `mipmap-mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`
- [ ] Android launcher alias in `android/app/src/main/AndroidManifest.xml`
- [ ] iOS PNGs in `ios/Runner/` and `CFBundleAlternateIcons` in both icon dicts in `ios/Runner/Info.plist`
- [ ] iOS PNGs registered in `ios/Runner.xcodeproj/project.pbxproj` the same way existing tenant PNGs are

Do not enable the new Android alias. Do not edit `android/app/src/debug/AndroidManifest.xml`. Do not change `AppIconService` unless the plugin API itself changes.

## Dart

```dart
'{id}': SchoolBrand(
  id: '{id}',
  assetPath: 'assets/icon/tenants/{id}.png',
  alternateIconName: '{id}',
),
```

`_fullUrlToBrandId` needs `https://host`, `http://host`, and `host` for every host in `_hostToBrandId`.

## Android alias

Copy an existing tenant `activity-alias` (`hijas` is the template). Set:

- `android:icon` and `android:roundIcon` to `@mipmap/ic_{id}`
- `android:name` to `${applicationId}.MainActivity.{id}`
- `android:enabled` to `false`
- `android:targetActivity` to `.MainActivity`
- MAIN / LAUNCHER intent-filter, same as the other aliases

## iOS

Add `{id}@2x.png`, `{id}@3x.png`, `{id}@2x~ipad.png`, `{id}@3x~ipad.png` under `ios/Runner/`.

In `Info.plist`, duplicate one tenant block under `CFBundleIcons` → `CFBundleAlternateIcons` and under `CFBundleIcons~ipad` → `CFBundleAlternateIcons`. The key and the `CFBundleIconFiles` string are both `{id}`.

In `project.pbxproj`, mirror an existing tenant (for example `hijas@2x.png`): `PBXFileReference`, `PBXBuildFile`, the Runner group, and the Resources build phase. New ids must not collide with existing `B1000001…` ids.

## Verify

`flutter test test/school_branding_test.dart`
