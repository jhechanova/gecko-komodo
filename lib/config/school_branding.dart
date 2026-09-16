/// School branding resolved from the configured notification server URL.
class SchoolBrand {
  final String id;
  final String assetPath;
  /// Android activity-alias / iOS CFBundleAlternateIcons key.
  /// Null means the primary (default) app icon.
  final String? alternateIconName;

  const SchoolBrand({
    required this.id,
    required this.assetPath,
    this.alternateIconName,
  });

  bool get isDefault => id == defaultBrandId;
}

const defaultBrandId = 'default';

const SchoolBrand defaultSchoolBrand = SchoolBrand(
  id: defaultBrandId,
  assetPath: 'assets/icon/app_icon.png',
  alternateIconName: null,
);

const Map<String, SchoolBrand> _brandsById = {
  'scsc': SchoolBrand(
    id: 'scsc',
    assetPath: 'assets/icon/tenants/scsc.png',
    alternateIconName: 'scsc',
  ),
  'hijas': SchoolBrand(
    id: 'hijas',
    assetPath: 'assets/icon/tenants/hijas.png',
    alternateIconName: 'hijas',
  ),
  'stccebu': SchoolBrand(
    id: 'stccebu',
    assetPath: 'assets/icon/tenants/stccebu.png',
    alternateIconName: 'stccebu',
  ),
  'sbcec': SchoolBrand(
    id: 'sbcec',
    assetPath: 'assets/icon/tenants/sbcec.png',
    alternateIconName: 'sbcec',
  ),
  'pcgs': SchoolBrand(
    id: 'pcgs',
    assetPath: 'assets/icon/tenants/pcgs.png',
    alternateIconName: 'pcgs',
  ),
};

/// Known hosts → brand id (lowercase, without www.).
const Map<String, String> _hostToBrandId = {
  'sancarlos.app': 'scsc',
  'shs-hijas.app': 'hijas',
  'online.stccebu.edu.ph': 'stccebu',
  'online.sbcec.edu.ph': 'sbcec',
  'admissions.pcgs.edu.ph': 'pcgs',
};

/// Known full base URLs (normalized) → brand id, used when host matching fails.
const Map<String, String> _fullUrlToBrandId = {
  'https://sancarlos.app': 'scsc',
  'http://sancarlos.app': 'scsc',
  'sancarlos.app': 'scsc',
  'https://shs-hijas.app': 'hijas',
  'http://shs-hijas.app': 'hijas',
  'shs-hijas.app': 'hijas',
  'https://online.stccebu.edu.ph': 'stccebu',
  'http://online.stccebu.edu.ph': 'stccebu',
  'online.stccebu.edu.ph': 'stccebu',
  'https://online.sbcec.edu.ph': 'sbcec',
  'http://online.sbcec.edu.ph': 'sbcec',
  'online.sbcec.edu.ph': 'sbcec',
  'https://admissions.pcgs.edu.ph': 'pcgs',
  'http://admissions.pcgs.edu.ph': 'pcgs',
  'admissions.pcgs.edu.ph': 'pcgs',
};

String _stripWww(String host) {
  final lower = host.toLowerCase();
  return lower.startsWith('www.') ? lower.substring(4) : lower;
}

/// Trim, lowercase, strip trailing slash; keep path for host-based Uri parsing.
String normalizeUrlKey(String raw) {
  var s = raw.trim().toLowerCase();
  while (s.endsWith('/') && s.length > 1) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Resolve a school brand from a typed or saved server URL.
///
/// 1. Match host (case-insensitive, strip `www.`).
/// 2. Else match normalized full URL (with and without scheme).
/// 3. Else default gecko brand.
SchoolBrand resolveSchoolBrand(String? url) {
  if (url == null || url.trim().isEmpty) {
    return defaultSchoolBrand;
  }

  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host.isNotEmpty) {
    final host = _stripWww(uri.host);
    final brandId = _hostToBrandId[host];
    if (brandId != null) {
      return _brandsById[brandId] ?? defaultSchoolBrand;
    }
  }

  final normalized = normalizeUrlKey(trimmed);
  final byFull = _fullUrlToBrandId[normalized];
  if (byFull != null) {
    return _brandsById[byFull] ?? defaultSchoolBrand;
  }

  // Try without scheme if present.
  final withoutScheme = normalized.replaceFirst(RegExp(r'^https?://'), '');
  final byBare = _fullUrlToBrandId[withoutScheme];
  if (byBare != null) {
    return _brandsById[byBare] ?? defaultSchoolBrand;
  }

  // Host-only input that Uri may not parse as having a host.
  final bareHost = _stripWww(withoutScheme.split('/').first);
  final byHostFallback = _hostToBrandId[bareHost];
  if (byHostFallback != null) {
    return _brandsById[byHostFallback] ?? defaultSchoolBrand;
  }

  return defaultSchoolBrand;
}
