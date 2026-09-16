import 'package:flutter/material.dart';

import '../config/school_branding.dart';

/// Displays the school logo for [url], falling back to the default gecko icon.
class SchoolLogo extends StatelessWidget {
  final String? url;
  final double size;

  const SchoolLogo({
    super.key,
    required this.url,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final brand = resolveSchoolBrand(url);
    return Image.asset(
      brand.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Image.asset(
        defaultSchoolBrand.assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
