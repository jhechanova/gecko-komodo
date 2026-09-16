import 'package:flutter_test/flutter_test.dart';
import 'package:notif_app/config/school_branding.dart';

void main() {
  group('resolveSchoolBrand', () {
    test('matches known hosts', () {
      expect(
        resolveSchoolBrand('https://sancarlos.app').id,
        'scsc',
      );
      expect(
        resolveSchoolBrand('https://shs-hijas.app/').id,
        'hijas',
      );
      expect(
        resolveSchoolBrand('https://online.stccebu.edu.ph').id,
        'stccebu',
      );
      expect(
        resolveSchoolBrand('https://online.sbcec.edu.ph').id,
        'sbcec',
      );
      expect(
        resolveSchoolBrand('https://admissions.pcgs.edu.ph').id,
        'pcgs',
      );
    });

    test('strips www and trailing slash', () {
      expect(
        resolveSchoolBrand('https://www.sancarlos.app/').id,
        'scsc',
      );
      expect(
        resolveSchoolBrand('https://WWW.SHS-HIJAS.APP').id,
        'hijas',
      );
    });

    test('matches host even with path', () {
      expect(
        resolveSchoolBrand('https://sancarlos.app/foo/bar').id,
        'scsc',
      );
      expect(
        resolveSchoolBrand('https://online.stccebu.edu.ph/app').id,
        'stccebu',
      );
    });

    test('falls back to full URL match when host unknown', () {
      // Bare host without scheme still maps via full-URL / host fallback.
      expect(resolveSchoolBrand('sancarlos.app').id, 'scsc');
      expect(resolveSchoolBrand('online.sbcec.edu.ph/').id, 'sbcec');
    });

    test('unknown URL uses default gecko brand', () {
      final brand = resolveSchoolBrand('https://unknown.example.com');
      expect(brand.id, defaultBrandId);
      expect(brand.assetPath, defaultSchoolBrand.assetPath);
      expect(brand.alternateIconName, isNull);
    });

    test('null and empty use default', () {
      expect(resolveSchoolBrand(null).id, defaultBrandId);
      expect(resolveSchoolBrand('').id, defaultBrandId);
      expect(resolveSchoolBrand('   ').id, defaultBrandId);
    });

    test('exposes alternate icon names for tenants', () {
      expect(resolveSchoolBrand('https://sancarlos.app').alternateIconName, 'scsc');
      expect(
        resolveSchoolBrand('https://admissions.pcgs.edu.ph').assetPath,
        'assets/icon/tenants/pcgs.png',
      );
    });

    test('hijas URL maps to hijas brand', () {
      expect(resolveSchoolBrand('https://shs-hijas.app/').id, 'hijas');
      expect(
        resolveSchoolBrand('https://shs-hijas.app/').alternateIconName,
        'hijas',
      );
    });
  });
}
