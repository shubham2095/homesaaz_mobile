// lib/app/tokens.dart
//
// HomeSaaz design tokens — mirrors the web app's palette
// (public/assets/css/homesaaz.css + Bootstrap 5 defaults).
import 'package:flutter/material.dart';

abstract final class Hs {
  // Signature background yellow (web: --hs-yellow / --hs-yellow-deep)
  static const yellow = Color(0xFFFFF7A8);
  static const yellowDeep = Color(0xFFFCEE7E);
  static const yellowBorder = Color(0xFFE7D977);

  // Primary action colour — Bootstrap `--bs-primary` (buttons, links, focus
  // rings across every page). NOT literally blue any more — the name is
  // kept because it's referenced throughout the app as "the" accent colour.
  static const blue = Color(0xFF5F9786);
  static const blueDark = Color(0xFF4C796B); // ~20% darker, for pressed states
  static const secondary = Color(0xFF015571); // Bootstrap `--bs-secondary`

  // Login landing-screen entry buttons (web: --hs-blue/-pink/-green +
  // matching *-border). Distinct from the teal primary above — used only
  // on the login screen's 4 entry buttons.
  static const blueSoft = Color(0xFFB7E2F3);
  static const blueBorder = Color(0xFF3E9CC9);
  static const pinkSoft = Color(0xFFF5C0C0);
  static const pinkBorder = Color(0xFFD9534F);
  static const greenSoft = Color(0xFFCBEBA6);
  static const greenBorder = Color(0xFF7CB342);

  // Bootstrap danger — form validation errors (web: .hs-input-error / .hs-error-text).
  static const red = Color(0xFFDC3545);
  // Brand red — Logoff button (web: --hs-red, dashboard-only, darker than the
  // validation red above).
  static const brandRed = Color(0xFFC62027);

  // Semantic
  static const green = Color(0xFF198754); // Bootstrap --bs-success
  static const amber = Color(0xFFFFC107); // Bootstrap --bs-warning
  static const teal = Color(0xFF5F9786);

  // Neutrals (web: --hs-text)
  static const ink = Color(0xFF223344);
  static const inkSoft = Color(0xFF3D4B5C);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9AA4B2);
  static const border = Color(0xFFE3E6EA);
  static const hairline = Color(0xFFF0F2F4);
  static const tableHeader = Color(0xFFF6F7F9);
  static const surface = Colors.white;

  // Shape
  static const radius = 12.0;
  static const radiusSm = 8.0;
  static const radiusLg = 16.0;

  // Spacing scale (4-pt)
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const gap = 12.0;

  static const pagePad = EdgeInsets.fromLTRB(16, 12, 16, 28);

  // Elevation — soft, low-contrast card shadow
  static const cardShadow = [
    BoxShadow(color: Color(0x0F1F2A37), blurRadius: 14, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A1F2A37), blurRadius: 3, offset: Offset(0, 1)),
  ];

  // Standard motion
  static const fast = Duration(milliseconds: 150);
  static const med = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
  static const curveBouncy = Curves.easeOutBack;

  /// Rotating accent palette for dashboard tiles / avatars — purely
  /// decorative, keeps the hub grid from reading as one flat colour.
  static const tileAccents = [
    Color(0xFF5F9786), // teal
    Color(0xFF0052CC), // blue
    Color(0xFFB8860B), // amber-gold
    Color(0xFF7C5CBF), // violet
    Color(0xFF2E9E6E), // green
    Color(0xFFCC5A3B), // terracotta
    Color(0xFF3E8FB0), // sky
    Color(0xFFB0508C), // rose
  ];
}
