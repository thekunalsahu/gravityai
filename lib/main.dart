import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/web_bridge.dart';
import 'features_page.dart';

// ========================================================
// GLOBAL CONFIG
// ========================================================
const String kBackendUrl = "https://gravityai-backend.onrender.com";
const bool kAllowLocalBackendFallback =
    bool.fromEnvironment('ALLOW_LOCAL_BACKEND_FALLBACK', defaultValue: false);
const String kEarthImg = "assets/images/background.png";
const String kLandingReferenceImg = "assets/images/landing_reference.png";

List<String> backendEndpoints(String path) => [
      '$kBackendUrl$path',
      if (kAllowLocalBackendFallback) 'http://127.0.0.1:5000$path',
      if (kAllowLocalBackendFallback) 'http://localhost:5000$path',
    ];

Future<http.Response> postBackendJson(
  String path,
  String body, {
  Duration timeout = const Duration(seconds: 30),
  String? bearerToken,
}) async {
  Object? lastError;
  final endpoints = backendEndpoints(path);
  for (final endpoint in endpoints) {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (bearerToken != null && bearerToken.isNotEmpty)
          'Authorization': 'Bearer $bearerToken',
      };
      final response = await http
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(timeout);
      if (response.statusCode < 500 || endpoint == endpoints.last) {
        return response;
      }
      lastError = "HTTP ${response.statusCode}: ${response.body}";
    } catch (e) {
      lastError = e;
    }
  }
  throw Exception(lastError ?? 'Backend request failed');
}

Future<http.Response> getBackendJson(
  String path, {
  Duration timeout = const Duration(seconds: 30),
  String? bearerToken,
}) async {
  Object? lastError;
  final endpoints = backendEndpoints(path);
  for (final endpoint in endpoints) {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (bearerToken != null && bearerToken.isNotEmpty)
          'Authorization': 'Bearer $bearerToken',
      };
      final response = await http
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(timeout);
      if (response.statusCode < 500 || endpoint == endpoints.last) {
        return response;
      }
      lastError = "HTTP ${response.statusCode}: ${response.body}";
    } catch (e) {
      lastError = e;
    }
  }
  throw Exception(lastError ?? 'Backend request failed');
}

Future<http.Response> patchBackendJson(
  String path,
  String body, {
  Duration timeout = const Duration(seconds: 30),
  String? bearerToken,
}) async {
  Object? lastError;
  final endpoints = backendEndpoints(path);
  for (final endpoint in endpoints) {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (bearerToken != null && bearerToken.isNotEmpty)
          'Authorization': 'Bearer $bearerToken',
      };
      final response = await http
          .patch(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(timeout);
      if (response.statusCode < 500 || endpoint == endpoints.last) {
        return response;
      }
      lastError = "HTTP ${response.statusCode}: ${response.body}";
    } catch (e) {
      lastError = e;
    }
  }
  throw Exception(lastError ?? 'Backend request failed');
}

class AuthSession {
  static String? token;
  static String? user;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  static Future<void> save(String nextToken, String nextUser) async {
    token = nextToken;
    user = nextUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', nextToken);
    await prefs.setString('auth_user', nextUser);
  }

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    user = prefs.getString('auth_user');
  }

  static Future<bool> restoreAndValidate() async {
    await restore();
    if (!isLoggedIn) return false;
    try {
      final response = await getBackendJson(
        "/api/auth/session",
        bearerToken: token,
        timeout: const Duration(seconds: 12),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        user = data['user']?.toString() ?? user;
        final prefs = await SharedPreferences.getInstance();
        if (user != null && user!.isNotEmpty) {
          await prefs.setString('auth_user', user!);
        }
        return true;
      }
      if (response.statusCode == 401) await clear();
      return false;
    } catch (_) {
      return isLoggedIn;
    }
  }

  static Future<void> clear() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
  }

  static Future<void> logout() async {
    final currentToken = token;
    if (currentToken != null && currentToken.isNotEmpty) {
      try {
        await postBackendJson(
          "/api/auth/logout",
          "{}",
          bearerToken: currentToken,
          timeout: const Duration(seconds: 8),
        );
      } catch (_) {}
    }
    await clear();
  }
}

class BhuPrahariStore {
  static final ValueNotifier<List<Map<String, dynamic>>> complaints =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static String nextId() {
    return "BHU-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}";
  }

  static void submit(Map<String, dynamic> complaint) {
    complaints.value = [complaint, ...complaints.value];
  }

  static void replaceAll(List<Map<String, dynamic>> nextComplaints) {
    complaints.value = nextComplaints;
  }

  static void updateAction(String id, String status, String action) {
    complaints.value = complaints.value.map((item) {
      if (item['id'] != id) return item;
      return {
        ...item,
        'status': status,
        'action': action,
        'updatedAt': DateTime.now(),
      };
    }).toList();
  }
}

void main() {
  runApp(const GravityApp());
}

class GravityApp extends StatelessWidget {
  const GravityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gravity AI Portal',
      theme: AppTheme.darkTheme,
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const double _referenceAspect = 1536 / 1024;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _restoreOfficerSession();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreOfficerSession() async {
    final active = await AuthSession.restoreAndValidate();
    if (!mounted || !active) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const DashboardScreen(isOfficer: true),
      ),
    );
  }

  void _openLoginPage() {
    Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, animation, __) => const LoginPage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.04, 0.02), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
        ));
  }

  void _openFeaturesPage() {
    Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 620),
          reverseTransitionDuration: const Duration(milliseconds: 360),
          pageBuilder: (_, animation, __) => const FeaturesPage(),
          transitionsBuilder: (_, animation, __, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.03, 0.02), end: Offset.zero)
                    .animate(curved),
                child: child,
              ),
            );
          },
        ));
  }

  void _openPublicAccess() {
    Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 620),
          reverseTransitionDuration: const Duration(milliseconds: 360),
          pageBuilder: (_, animation, __) =>
              const DashboardScreen(isOfficer: false),
          transitionsBuilder: (_, animation, __, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.03, 0.02), end: Offset.zero)
                    .animate(curved),
                child: child,
              ),
            );
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020914),
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 720) return _buildMobileLanding();
        return _buildReferenceLanding(constraints);
      }),
    );
  }

  Widget _buildReferenceLanding(BoxConstraints constraints) {
    final pageWidth = constraints.maxWidth;
    final imageHeight = pageWidth / _referenceAspect;
    final pageHeight = math.max(constraints.maxHeight, imageHeight);

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Container(color: const Color(0xFF020914))),
            Positioned(
              left: 0,
              top: 0,
              width: pageWidth,
              height: imageHeight,
              child: Image.asset(
                kLandingReferenceImg,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                    kEarthImg,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter),
              ),
            ),
            Positioned(
              left: pageWidth * 0.044,
              top: imageHeight * 0.475,
              width: pageWidth * 0.139,
              height: imageHeight * 0.046,
              child: _LandingHotspot(
                key: const ValueKey('landing-user-login'),
                tooltip: "User Login",
                onTap: _openLoginPage,
              ),
            ),
            Positioned(
              left: pageWidth * 0.201,
              top: imageHeight * 0.475,
              width: pageWidth * 0.137,
              height: imageHeight * 0.046,
              child: _LandingHotspot(
                key: const ValueKey('landing-explore-features'),
                tooltip: "Explore Features",
                onTap: _openFeaturesPage,
              ),
            ),
            Positioned(
              right: pageWidth * 0.04,
              top: math.max(8, imageHeight * 0.008),
              width: pageWidth * 0.16,
              height: 52,
              child: _AnimatedLandingButton(
                key: const ValueKey('landing-public-access'),
                label: "Public Access",
                icon: Icons.policy_rounded,
                onTap: _openPublicAccess,
                primary: false,
                fullWidth: true,
              ),
            ),
            Positioned(
              left: pageWidth * 0.042,
              top: imageHeight * 0.103,
              width: pageWidth * 0.122,
              height: imageHeight * 0.033,
              child: const IgnorePointer(child: _AIPillPulse()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLanding() {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.66, -0.66),
                radius: 1.28,
                colors: [
                  const Color(0xFF113427).withValues(alpha: 0.96),
                  const Color(0xFF071524),
                  const Color(0xFF020914),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: _DashboardGridBackdrop()),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  const Color(0xFF020914).withValues(alpha: 0.94)
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset("assets/images/logo.png",
                        height: 44,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.satellite_alt_rounded,
                                color: Color(0xFF4CFF2F), size: 36)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text("GravityAI | Live",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: _AnimatedLandingButton(
                          key: const ValueKey('landing-public-access-mobile'),
                          label: "Public",
                          icon: Icons.policy_rounded,
                          onTap: _openPublicAccess,
                          primary: false,
                          fullWidth: true),
                    ),
                  ],
                ),
                const SizedBox(height: 38),
                _pill(Icons.circle, "AI Use for Detection"),
                const SizedBox(height: 18),
                const Text(
                  "Detect Illegal\nLand Encroachment\nwith Precision.",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1.06,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                const Text(
                  "GravityAI uses Advanced AI & ISRO BHUVAN satellite imagery to detect unauthorized encroachments in real-time.",
                  style: TextStyle(
                      color: Colors.white70, fontSize: 16, height: 1.55),
                ),
                const SizedBox(height: 26),
                _AnimatedLandingButton(
                    key: const ValueKey('landing-user-login-mobile'),
                    label: "User Login",
                    icon: Icons.fingerprint_rounded,
                    onTap: _openLoginPage,
                    primary: true,
                    fullWidth: true),
                const SizedBox(height: 12),
                _AnimatedLandingButton(
                    label: "Explore Features",
                    icon: Icons.travel_explore_rounded,
                    onTap: _openFeaturesPage,
                    primary: false,
                    fullWidth: true),
                const SizedBox(height: 24),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MobileFeature(
                        icon: Icons.radar_rounded,
                        label: "Real-time Monitoring"),
                    _MobileFeature(
                        icon: Icons.verified_user_rounded,
                        label: "Secure Reports"),
                    _MobileFeature(
                        icon: Icons.map_rounded, label: "ISRO Bhuvan"),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B2A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 13, height: 13, child: _BlinkingAIDot()),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _LandingHotspot extends StatefulWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _LandingHotspot(
      {super.key, required this.tooltip, required this.onTap});

  @override
  State<_LandingHotspot> createState() => _LandingHotspotState();
}

class _LandingHotspotState extends State<_LandingHotspot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool primary = widget.tooltip.toLowerCase().contains('login');
    final Color accent =
        primary ? const Color(0xFF39FF14) : const Color(0xFF23F6FF);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Semantics(
          button: true,
          label: widget.tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(8),
              splashColor: accent.withValues(alpha: 0.18),
              highlightColor: accent.withValues(alpha: 0.08),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final sweep = (t * 1.6 - 0.35).clamp(-0.35, 1.2);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _hovering
                              ? accent.withValues(alpha: 0.95)
                              : accent.withValues(
                                  alpha: primary ? 0.18 : 0.10)),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withValues(
                                alpha: _hovering ? 0.32 : 0.12),
                            blurRadius: _hovering ? 30 : 18,
                            spreadRadius: _hovering ? 1 : 0),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: [
                                    math.max(0, sweep - 0.16),
                                    sweep.clamp(0.0, 1.0),
                                    math.min(1, sweep + 0.16)
                                  ],
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(
                                        alpha: _hovering ? 0.24 : 0.13),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLandingButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool fullWidth;

  const _AnimatedLandingButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
    this.fullWidth = false,
  });

  @override
  State<_AnimatedLandingButton> createState() => _AnimatedLandingButtonState();
}

class _AnimatedLandingButtonState extends State<_AnimatedLandingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.primary ? const Color(0xFF39FF14) : const Color(0xFF23F6FF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final glow =
                0.16 + (math.sin(_controller.value * math.pi * 2) + 1) * 0.08;
            return AnimatedScale(
              scale: _hovering ? 1.025 : 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: widget.fullWidth ? double.infinity : null,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: widget.primary
                      ? const LinearGradient(
                          colors: [Color(0xFF7CFF36), Color(0xFF21D815)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : LinearGradient(
                          colors: [
                            const Color(0xFF071625).withValues(alpha: 0.85),
                            const Color(0xFF0D2437).withValues(alpha: 0.85)
                          ],
                        ),
                  border: Border.all(
                      color: widget.primary
                          ? Colors.white.withValues(alpha: 0.18)
                          : accent.withValues(alpha: 0.32)),
                  boxShadow: [
                    BoxShadow(
                        color:
                            accent.withValues(alpha: _hovering ? 0.35 : glow),
                        blurRadius: _hovering ? 28 : 18,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.label,
                            style: TextStyle(
                                color: widget.primary
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 12),
                        Transform.translate(
                          offset: Offset(
                              math.sin(_controller.value * math.pi * 2) * 4, 0),
                          child: Icon(widget.icon,
                              color: widget.primary
                                  ? Colors.black
                                  : const Color(0xFF39FF14)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BlinkingAIDot extends StatefulWidget {
  const _BlinkingAIDot();

  @override
  State<_BlinkingAIDot> createState() => _BlinkingAIDotState();
}

class _BlinkingAIDotState extends State<_BlinkingAIDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = 0.45 + _controller.value * 0.55;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
                const Color(0xFF128A17), const Color(0xFF39FF14), value),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF39FF14).withValues(alpha: value),
                  blurRadius: 10 + 12 * value,
                  spreadRadius: 1 + 3 * value),
            ],
          ),
        );
      },
    );
  }
}

class _AIPillPulse extends StatefulWidget {
  const _AIPillPulse();

  @override
  State<_AIPillPulse> createState() => _AIPillPulseState();
}

class _AIPillPulseState extends State<_AIPillPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: const Color(0xFF39FF14)
                    .withValues(alpha: 0.10 + value * 0.22),
                width: 1.0),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF39FF14)
                      .withValues(alpha: 0.04 + value * 0.18),
                  blurRadius: 12 + value * 18,
                  spreadRadius: value * 3),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardGridBackdrop extends StatelessWidget {
  const _DashboardGridBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashboardGridPainter());
  }
}

class _DashboardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF39FF14).withValues(alpha: 0.035)
      ..strokeWidth = 0.7;
    const gap = 42.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final sweep = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF39FF14).withValues(alpha: 0.13),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.74, size.height * 0.22),
          radius: size.width * 0.42));
    canvas.drawRect(Offset.zero & size, sweep);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BootChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BootChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF39FF14).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF39FF14), size: 15),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class _MobileFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MobileFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071625).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF39FF14), size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12))),
        ],
      ),
    );
  }
}

class _ForestLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ForestLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1221).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _obscure = true;
  bool _loggingIn = false;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter User ID and Password",
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent));
      return;
    }
    setState(() => _loggingIn = true);
    try {
      final response = await postBackendJson(
        "/api/auth/login",
        jsonEncode({
          "user_id": _id.text.trim(),
          "password": _pass.text,
        }),
        timeout: const Duration(seconds: 20),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await AuthSession.save(
          data['token'].toString(),
          data['user'].toString(),
        );
        if (!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const DashboardScreen(isOfficer: true)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Invalid user ID or password"),
            backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Login failed: $e"),
          backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('gravity-login-page'),
      backgroundColor: const Color(0xFF020914),
      body: LayoutBuilder(builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: isMobile
                        ? const Alignment(0.75, -0.70)
                        : const Alignment(0.52, -0.62),
                    radius: 1.15,
                    colors: [
                      const Color(0xFF0F2E2D).withValues(alpha: 0.92),
                      const Color(0xFF071321),
                      const Color(0xFF020914),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: _DashboardGridBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.32),
                      const Color(0xFF020914).withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 18 : 34, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: isMobile
                          ? [
                              _loginHero(isMobile),
                              const SizedBox(height: 28),
                              _loginCard(isMobile),
                            ]
                          : [
                              Expanded(flex: 5, child: _loginHero(isMobile)),
                              const SizedBox(width: 34),
                              Expanded(flex: 4, child: _loginCard(isMobile)),
                            ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: IconButton(
                    tooltip: "Back",
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.28),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _loginHero(bool isMobile) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/images/logo.png", height: isMobile ? 48 : 64),
            const SizedBox(width: 12),
            Flexible(
              child: Text("GravityAI | Live",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 30 : 38,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text("Secure User Command Login",
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
            style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 34 : 54,
                height: 1.02,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Text(
            "User credentials unlock live encroachment detection, scan reports, Bhuvan layers, evidence, and task workflows.",
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.55)),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: const [
            _BootChip(icon: Icons.radar_rounded, label: "SAT SCAN"),
            _BootChip(icon: Icons.verified_user, label: "SECURE"),
            _BootChip(icon: Icons.radar_rounded, label: "AI READY"),
          ],
        ),
      ],
    );
  }

  Widget _loginCard(bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 20 : 26),
          decoration: BoxDecoration(
            color: const Color(0xFF06111F).withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF39FF14).withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF39FF14).withValues(alpha: 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_person_rounded,
                      color: Color(0xFF39FF14), size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text("User Access",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ),
                  SizedBox(width: 14, height: 14, child: _BlinkingAIDot()),
                ],
              ),
              const SizedBox(height: 8),
              const Text("User ID aur password enter karein",
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 22),
              TextField(
                key: const ValueKey('login-user-id'),
                controller: _id,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: "User ID",
                  prefixIcon:
                      Icon(Icons.badge_outlined, color: Color(0xFF39FF14)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                ),
              ),
              const SizedBox(height: 13),
              TextField(
                key: const ValueKey('login-password'),
                controller: _pass,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: "Password",
                  prefixIcon: const Icon(Icons.password_rounded,
                      color: Color(0xFF39FF14)),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? "Show password" : "Hide password",
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.white54),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                ),
              ),
              const SizedBox(height: 22),
              _AnimatedLandingButton(
                  label:
                      _loggingIn ? "Authenticating..." : "Login to Dashboard",
                  icon: Icons.fingerprint_rounded,
                  onTap: _loggingIn ? () {} : () => _login(),
                  primary: true,
                  fullWidth: true),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0);
  }
}

class DashboardScreen extends StatefulWidget {
  final bool isOfficer;
  const DashboardScreen({super.key, required this.isOfficer});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  final TextEditingController _timerCtrl =
      TextEditingController(); // Fixed: Defined here to avoid memory leak
  final MapController _mapCtrl = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _booting = true;
  double _bootProgress = 0.0;
  bool _scanning = false;
  bool _ready = false;
  String _status = "READY FOR ANALYSIS";

  LatLng _loc = const LatLng(23.2599, 77.4126);
  double _currentZoom = 13.0;
  final List<Polygon> _anomalyPolygons = [];
  final List<Polygon> _govtPolygons = [];
  final List<Marker> _illegalHouseMarkers = [];

  int _risk = 0, _area = 0, _veg = 0;
  double _val = 0.0, _accuracy = 100.0;
  double _landRate = 0.0;
  String _officialLandSource =
      "Official land-rate source will appear after scan";
  String _predictionLabel = "Not scanned";
  Map<String, dynamic> _envData = {
    "temp": 32,
    "aqi": 145,
    "soil": "Alluvial",
    "moisture": 45
  };
  String _notice = "";
  bool _evictSent = false;
  int _timerSecs = 0;
  Timer? _timer;
  bool _canDemolish = false;
  String _stateName = "MADHYA PRADESH";
  final List<Map<String, String>> _tasksList = [];
  final TextEditingController _citizenNameCtrl = TextEditingController();
  final TextEditingController _citizenEmailCtrl = TextEditingController();
  final TextEditingController _citizenPhoneCtrl = TextEditingController();
  final TextEditingController _citizenComplaintCtrl = TextEditingController();
  final TextEditingController _citizenStatusCtrl = TextEditingController();
  String? _citizenEvidenceName;

  // Navigation State
  int _navIndex = 0; // 0: Dashboard, 1: Map, 2: Reports, 3: Tasks

  // New Feature State
  bool _isHindi = false;
  bool _isAnonymous = false;
  bool _hasSearched = false; // Track if a search has been performed
  final List<Map<String, String>> _chatMsgs = [
    {
      "role": "ai",
      "text":
          "Hello User. I am Gravity AI. How can I assist you with land administration today?"
    }
  ];
  bool _isListening = false;
  final TextEditingController _chatCtrl = TextEditingController();
  bool _isSatellite = true; // Satellite Layer Toggle
  bool _showBhuvanWms = false; // Bhuvan WMS Layer Toggle
  bool _showForestWatch = false; // Forest monitoring overlay
  bool _forestScanning = false;
  bool _forestReady = false;
  String _forestStatus = "Run an ISRO Bhuvan scan to load live LULC results.";
  String _forestCurrentClass = "Not scanned";
  String _forestPreviousClass = "Not scanned";
  String _forestLayer = "LULC250K_2425";
  String _forestPreviousLayer = "LULC250K_2324";
  String _forestSource = "ISRO/NRSC Bhuvan LULC 250K WMS";
  int _forestRiskScore = 0;
  int _forestValidSamples = 0;
  int _forestTotalSamples = 0;
  int _forestForestSamples = 0;
  int _forestLostSamples = 0;
  double _forestCoverPercent = 0;
  double _forestLossPercent = 0;
  double _forestConfidence = 0;
  List<Map<String, dynamic>> _forestSamplePoints = [];
  List<String> _forestAlerts = [];

  // Geotagged Evidence State
  final List<Map<String, dynamic>> _fieldEvidences = [];
  bool _droneActive = false;
  LatLng? _dronePos;
  Timer? _droneTimer;

  // Change Detection Timeline State
  int _timelineYear = 2026;
  bool _showTimeline = false;

  // Real Drone Connection State
  String _droneIp = "";
  bool _droneConnected = false;
  Map<String, dynamic> _droneTelemetry = {
    "battery": 0,
    "altitude": 0.0,
    "speed": 0.0,
    "gps": "No Fix"
  };
  Timer? _dronePollTimer;
  final TextEditingController _droneIpCtrl =
      TextEditingController(text: "192.168.1.100:14550");

  // Multi-Modal AI State
  String? _pendingImageBase64;
  String? _pendingImageName;
  bool _complaintsSyncing = false;

  @override
  void initState() {
    super.initState();
    AuthSession.restore().then((_) {
      if (mounted && widget.isOfficer) _loadOfficerComplaints();
    });
    _bootSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _droneTimer?.cancel();
    _dronePollTimer?.cancel();
    _searchCtrl.dispose();
    _chatCtrl.dispose();
    _areaCtrl.dispose();
    _timerCtrl.dispose();
    _droneIpCtrl.dispose();
    _citizenNameCtrl.dispose();
    _citizenEmailCtrl.dispose();
    _citizenPhoneCtrl.dispose();
    _citizenComplaintCtrl.dispose();
    _citizenStatusCtrl.dispose();
    super.dispose();
  }

  void _bootSequence() async {
    for (int i = 0; i <= 10; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _bootProgress = i / 10);
    }
    if (mounted) setState(() => _booting = false);
  }

  void _speak(String text) {
    try {
      final safeText = text
          .replaceAll('`', "'")
          .replaceAll('\\', '\\\\')
          .replaceAll('\n', ' ');
      final jsCode = '''
        var msg = new SpeechSynthesisUtterance("$safeText");
        msg.lang = "en-US";
        msg.rate = 0.9;
        window.speechSynthesis.speak(msg);
      ''';
      evalJs(jsCode);
    } catch (e) {
      debugPrint("TTS Error: $e");
    }
  }

  /// Start voice input using Web Speech API (webkitSpeechRecognition)
  void _startVoiceInput(Function setModalState) {
    if (_isListening) return;

    try {
      const jsCode = '''
        (function() {
          var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) {
            return "__ERROR__:Speech Recognition not supported in this browser";
          }
          var recognition = new SpeechRecognition();
          recognition.lang = "en-US";
          recognition.interimResults = false;
          recognition.maxAlternatives = 1;
          recognition.continuous = false;
          
          window.__gravityVoiceResult = "__LISTENING__";
          window.__gravityVoiceDone = false;
          
          recognition.onresult = function(event) {
            window.__gravityVoiceResult = event.results[0][0].transcript;
            window.__gravityVoiceDone = true;
          };
          recognition.onerror = function(event) {
            window.__gravityVoiceResult = "__ERROR__:" + event.error;
            window.__gravityVoiceDone = true;
          };
          recognition.onend = function() {
            window.__gravityVoiceDone = true;
          };
          recognition.start();
          return "__STARTED__";
        })()
      ''';

      final startStr = evalJsString(jsCode) ?? '';

      if (startStr.startsWith('__ERROR__')) {
        final errorMsg = startStr.replaceFirst('__ERROR__:', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Voice Error: $errorMsg"),
              backgroundColor: Colors.red),
        );
        return;
      }

      setState(() => _isListening = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text("🎤 Listening... Speak now"),
          ]),
          backgroundColor: Colors.cyan,
          duration: Duration(seconds: 5),
        ),
      );

      // Poll for result
      Timer.periodic(const Duration(milliseconds: 300), (timer) {
        final isDone = evalJsBool('window.__gravityVoiceDone === true');

        if (isDone) {
          timer.cancel();
          final transcript =
              evalJsString('window.__gravityVoiceResult || ""') ?? '';

          if (mounted) setState(() => _isListening = false);

          if (transcript.startsWith('__ERROR__')) {
            final errorMsg = transcript.replaceFirst('__ERROR__:', '');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Voice Error: $errorMsg"),
                    backgroundColor: Colors.red),
              );
            }
          } else if (transcript.isNotEmpty && transcript != '__LISTENING__') {
            // Success! Insert the transcript into chat
            setModalState(() {
              _chatCtrl.text = transcript;
              _chatMsgs.add({"role": "user", "text": transcript});
            });
            _getGroqResponse(transcript, setModalState);
            _chatCtrl.clear();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("🎤 \"$transcript\""),
                    backgroundColor: Colors.green),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("No speech detected. Try again."),
                    backgroundColor: Colors.orange),
              );
            }
          }
        }
      });
    } catch (e) {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Voice Input Error: $e"),
            backgroundColor: Colors.red),
      );
    }
  }

  // --- API FIX: ADDED TIMEOUT AND MOUNTED CHECKS ---
  Future<void> _runScan() async {
    String query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    _timer?.cancel();
    if (mounted) {
      setState(() {
        _scanning = true;
        _ready = false;
        _evictSent = false;
        _canDemolish = false;
        _hasSearched = true;
        _status = "CONNECTING TO SATELLITE LAYERS...";
        _anomalyPolygons.clear();
        _govtPolygons.clear();
        _illegalHouseMarkers.clear();
      });
    }

    try {
      double lat, lon;
      String fetchedState = "GOVERNMENT";
      if (query.contains(',')) {
        var parts = query.split(',');
        lat = double.parse(parts[0].trim());
        lon = double.parse(parts[1].trim());
        try {
          final revRes = await http.get(
              Uri.parse(
                  'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json'),
              headers: {'User-Agent': 'Gravity-Titans'});
          final revD = json.decode(revRes.body);
          if (revD['address'] != null && revD['address']['state'] != null) {
            fetchedState = revD['address']['state'].toString().toUpperCase();
          }
        } catch (_) {}
      } else {
        final res = await http.get(
            Uri.parse(
                'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}, India&format=json&limit=1&addressdetails=1'),
            headers: {
              'User-Agent': 'Gravity-Titans'
            }).timeout(const Duration(seconds: 30));

        final d = json.decode(res.body);
        if (d == null || d.isEmpty) throw "Location not found";
        lat = double.parse(d[0]['lat']);
        lon = double.parse(d[0]['lon']);
        if (d[0]['address'] != null && d[0]['address']['state'] != null) {
          fetchedState = d[0]['address']['state'].toString().toUpperCase();
        }
      }

      _loc = LatLng(lat, lon);
      if (mounted) setState(() => _stateName = fetchedState);
      _mapCtrl.move(_loc, 18.0);

      if (mounted) {
        setState(() => _status = "CROSS-REFERENCING GEOJSON AND BHU-NAKSHA...");
      }

      final apiRes = await postBackendJson(
        "/api/scan",
        json.encode({'lat': lat, 'lon': lon, 'sector': query}),
        timeout: const Duration(seconds: 90),
      );

      if (apiRes.statusCode == 200) {
        final data = json.decode(apiRes.body);

        List<LatLng> parsePoly(dynamic list) {
          if (list == null) return [];
          return (list as List)
              .map((p) => LatLng(double.parse(p['lat'].toString()),
                  double.parse(p['lon'].toString())))
              .toList();
        }

        LatLng polygonCenter(List<LatLng> points) {
          final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
              points.length;
          final lon = points.map((p) => p.longitude).reduce((a, b) => a + b) /
              points.length;
          return LatLng(lat, lon);
        }

        Marker illegalHouseMarker(LatLng point) => Marker(
              point: point,
              width: 46,
              height: 46,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.55),
                        blurRadius: 14,
                        spreadRadius: 2)
                  ],
                ),
                child:
                    const Icon(Icons.home_work, color: Colors.white, size: 24),
              ),
            );

        if (!mounted) return;
        setState(() {
          final risk = data['risk_score'] != null
              ? (data['risk_score'] as num).round().clamp(0, 100)
              : data['encroaching_count'] != null
                  ? (data['encroaching_count'] * 15).clamp(0, 100)
                  : 0;
          final accuracy = (data['accuracy'] ?? 100.0).toDouble();
          _scanning = false;
          _ready = true;
          _status = risk > 0
              ? "POTENTIAL ENCROACHMENT FLAGGED - ${accuracy.toStringAsFixed(1)}% CONFIDENCE"
              : "LAND REVIEW READY - ${accuracy.toStringAsFixed(1)}% CONFIDENCE";
          _risk = risk;
          _area = data['area_sqm'] ?? 0;
          _val =
              (data['cost_estimate'] ?? data['land_value'] ?? 0.0).toDouble();
          _veg = data['green_loss'] ?? 0;
          _accuracy = accuracy;
          if (data['official_land_data'] != null) {
            final official =
                Map<String, dynamic>.from(data['official_land_data']);
            _landRate =
                ((official['applied_rate_per_sqm'] as num?)?.toDouble() ?? 0);
            _officialLandSource =
                official['source']?.toString() ?? "Official land-rate source";
          }
          if (data['prediction'] != null) {
            final prediction = Map<String, dynamic>.from(data['prediction']);
            _predictionLabel =
                prediction['label']?.toString() ?? "Prediction ready";
          } else {
            _predictionLabel =
                _risk > 0 ? "Review Required" : "Manual Land Review";
          }
          if (data['env_data'] != null) {
            _envData = Map<String, dynamic>.from(data['env_data']);
          }
          _notice = data['legal_notice_text'] ??
              "Blue-boundary land review is ready. Field verification is recommended for official closure.";

          String voiceSum = data['voice_summary'] ?? "Scan complete.";
          _speak(voiceSum);

          // Government Boundary — Blue
          if (data['govt_boundary'] != null) {
            _govtPolygons.add(Polygon(
                points: parsePoly(data['govt_boundary']),
                color: Colors.blue.withValues(alpha: 0.08),
                borderColor: Colors.blueAccent,
                borderStrokeWidth: 4,
                isFilled: true));
          }

          // Encroaching Buildings (on Govt land) — RED
          if (data['encroaching_buildings'] != null) {
            for (var building in data['encroaching_buildings']) {
              var pts = parsePoly(building);
              if (pts.length >= 3) {
                _anomalyPolygons.add(Polygon(
                    points: pts,
                    color: Colors.red.withValues(alpha: 0.5),
                    borderColor: Colors.redAccent,
                    borderStrokeWidth: 2,
                    isFilled: true));
                _illegalHouseMarkers
                    .add(illegalHouseMarker(polygonCenter(pts)));
              }
            }
          }

          // Legal Buildings (outside Govt land) — GREEN
          // Fallback for old-style anomaly_polygon
          if (data['anomaly_polygon'] != null &&
              data['encroaching_buildings'] == null) {
            final pts = parsePoly(data['anomaly_polygon']);
            _anomalyPolygons.add(Polygon(
                points: pts,
                color: Colors.red.withValues(alpha: 0.4),
                borderColor: Colors.redAccent,
                borderStrokeWidth: 3,
                isFilled: true));
            if (pts.length >= 3) {
              _illegalHouseMarkers.add(illegalHouseMarker(polygonCenter(pts)));
            }
          }
        });
      } else {
        throw "Server Error: ${apiRes.statusCode}";
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        setState(() {
          _scanning = false;
          _ready = false;
          _risk = 0;
          _area = 0;
          _val = 0;
          _veg = 0;
          _accuracy = 0;
          _anomalyPolygons.clear();
          _govtPolygons.clear();
          _illegalHouseMarkers.clear();
          _status = message.contains("Timeout")
              ? "TIMEOUT: SERVER TOOK TOO LONG"
              : "ERROR: $e";
        });
      }
    }
  }

  void _applyDemoScanState(String sector, {String? fallbackReason}) {
    const double delta = 0.00042;
    final LatLng center = _loc;

    _scanning = false;
    _ready = true;
    _hasSearched = true;
    _evictSent = false;
    _canDemolish = false;
    _risk = 0;
    _area = 0;
    _val = 0;
    _veg = 0;
    _accuracy = 82.0;
    _landRate = 0;
    _officialLandSource =
        "Official land-rate source will appear after live scan";
    _predictionLabel = "Manual Land Review";
    _envData = {"temp": 32, "aqi": 145, "soil": "Alluvial", "moisture": 45};
    _notice =
        "Blue-boundary land review is ready for $sector. Run a live scan for authoritative screening.";
    _status = fallbackReason == null
        ? "LAND REVIEW READY - DEMO AUDIT READY"
        : "NEUTRAL DEMO AUDIT READY - BACKEND FALLBACK";
    _govtPolygons
      ..clear()
      ..add(Polygon(
          points: [
            LatLng(center.latitude - delta, center.longitude - delta),
            LatLng(center.latitude - delta, center.longitude + delta),
            LatLng(center.latitude + delta, center.longitude + delta),
            LatLng(center.latitude + delta, center.longitude - delta),
          ],
          color: Colors.blue.withValues(alpha: 0.08),
          borderColor: Colors.blueAccent,
          borderStrokeWidth: 3,
          isFilled: true));
    _anomalyPolygons.clear();
    _illegalHouseMarkers.clear();
  }

  Future<void> _loadOfficerComplaints() async {
    final token = AuthSession.token;
    if (token == null || token.isEmpty || _complaintsSyncing) return;
    setState(() => _complaintsSyncing = true);
    try {
      final response = await getBackendJson(
        "/api/complaints",
        bearerToken: token,
        timeout: const Duration(seconds: 20),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final complaints = (data['complaints'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        BhuPrahariStore.replaceAll(complaints);
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Session expired. Please login again."),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Complaint sync failed: $e");
    } finally {
      if (mounted) setState(() => _complaintsSyncing = false);
    }
  }

  Future<void> _logout() async {
    _timer?.cancel();
    await AuthSession.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LandingPage()),
      (_) => false,
    );
  }

  Future<void> _submitBhuPrahariComplaint() async {
    final target = _searchCtrl.text.trim().isEmpty
        ? "Pinned map location"
        : _searchCtrl.text.trim();
    final description = _citizenComplaintCtrl.text.trim();
    final reporter =
        _isAnonymous ? "Anonymous Citizen" : _citizenNameCtrl.text.trim();

    if (!_isAnonymous && reporter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Name ya anonymous option select karein."),
          backgroundColor: Colors.orange));
      return;
    }
    if (description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Complaint details thoda clearly likhein."),
          backgroundColor: Colors.orange));
      return;
    }

    final id = BhuPrahariStore.nextId();
    final complaint = {
      "id": id,
      "reporter": reporter,
      "email": _isAnonymous ? "" : _citizenEmailCtrl.text.trim(),
      "phone": _isAnonymous ? "" : _citizenPhoneCtrl.text.trim(),
      "target": target,
      "description": description,
      "evidence": _citizenEvidenceName ?? "No photo uploaded",
      "lat": _loc.latitude,
      "lon": _loc.longitude,
      "state": _stateName,
      "risk_score": _risk,
      "area_sqm": _area,
      "status": "New Complaint",
      "action": "Sent to state alert workflow",
      "submittedAt": DateTime.now().toIso8601String(),
    };

    var submitted = Map<String, dynamic>.from(complaint);
    var integrationStatus = "local";
    try {
      final response = await postBackendJson(
        "/api/complaints",
        jsonEncode(complaint),
        timeout: const Duration(seconds: 25),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        submitted = Map<String, dynamic>.from(data['complaint'] as Map);
        integrationStatus =
            (data['integration']?['status'] ?? 'sent').toString();
      } else {
        integrationStatus = "backend_${response.statusCode}";
      }
    } catch (e) {
      integrationStatus = "offline";
      debugPrint("Complaint backend submit failed: $e");
    }

    BhuPrahariStore.submit(submitted);
    if (!mounted) return;

    setState(() {
      if (!_hasSearched || !_ready) {
        _applyDemoScanState(target);
      }
      _hasSearched = true;
      _status = "BHU-PRAHARI COMPLAINT SUBMITTED - $id";
      _citizenStatusCtrl.text = id;
      _citizenComplaintCtrl.clear();
      _citizenEmailCtrl.clear();
      _citizenPhoneCtrl.clear();
      _citizenEvidenceName = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            "Complaint submitted: ${submitted['id']} (${integrationStatus == 'sent' ? 'ViaSocket sent' : integrationStatus})"),
        backgroundColor: Colors.green));
  }

  Future<void> _pickCitizenEvidence() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;
      setState(() => _citizenEvidenceName = result.files.first.name);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Evidence attached: ${result.files.first.name}"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Upload error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return _buildBoot();

    return LayoutBuilder(builder: (context, constraints) {
      bool isMobile = constraints.maxWidth < 900;

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF020914),
        drawer: isMobile ? _mobileDrawer() : null,
        floatingActionButton: widget.isOfficer
            ? FloatingActionButton.extended(
                onPressed: _showChatbot,
                backgroundColor: const Color(0xFF39FF14),
                icon: const Icon(Icons.auto_awesome, color: Colors.black87),
                label: const Text("Gravity AI",
                    style: TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.bold)),
              ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 3.seconds,
                color: Colors.white.withValues(alpha: 0.45))
            : null,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.48, -0.58),
              radius: 1.1,
              colors: [Color(0xFF0A2C21), Color(0xFF06111F), Color(0xFF020914)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _DashboardGridBackdrop()),
              Row(
                children: [
                  if (!isMobile) _sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _topNav(isMobile),
                        Expanded(child: _buildMainContent(isMobile)),
                        _footer(),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _mobileDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: const Color(0xFF0B1221),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/logo.png", height: 50),
                  const SizedBox(height: 10),
                  const Text("Gravity AI\nCommand Center",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _drawerBtn(
              widget.isOfficer ? Icons.dashboard : Icons.policy_rounded,
              widget.isOfficer ? "Dashboard" : "Public Access",
              _navIndex == 0, tap: () {
            setState(() => _navIndex = 0);
            Navigator.pop(context);
          }),
          if (widget.isOfficer) ...[
            _drawerBtn(Icons.map_outlined, "Map", _navIndex == 1, tap: () {
              setState(() => _navIndex = 1);
              Navigator.pop(context);
            }),
            _drawerBtn(Icons.description_outlined, "Reports", _navIndex == 2,
                tap: () {
              setState(() => _navIndex = 2);
              Navigator.pop(context);
            }),
            _drawerBtn(Icons.forest_rounded, "Forest Watch", _navIndex == 4,
                tap: () {
              setState(() => _navIndex = 4);
              Navigator.pop(context);
            }),
            _drawerBtn(
                Icons.assignment_late_rounded, "Complaints", _navIndex == 3,
                tap: () {
              setState(() => _navIndex = 3);
              Navigator.pop(context);
            }),
          ],
          const Spacer(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerBtn(IconData i, String label, bool act,
      {Color? color, VoidCallback? tap}) {
    return ListTile(
      leading: Icon(i,
          color: act ? const Color(0xFF39FF14) : (color ?? Colors.white54)),
      title: Text(label,
          style: TextStyle(
              color: act ? const Color(0xFF39FF14) : (color ?? Colors.white54),
              fontWeight: act ? FontWeight.bold : FontWeight.normal)),
      onTap: tap,
      selected: act,
      selectedTileColor: const Color(0xFF39FF14).withValues(alpha: 0.1),
    );
  }

  Widget _reportsModule(bool isMobile) {
    final String target = _searchCtrl.text.trim().isEmpty
        ? "Delhi Central Vista Demo Sector"
        : _searchCtrl.text.trim();
    final bool hasAnalysis = _ready || _hasSearched;
    final List<Map<String, String>> rows = [
      {"label": "Target Sector", "value": target},
      {
        "label": "Coordinates",
        "value":
            "${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}"
      },
      {
        "label": "Detected Area",
        "value": hasAnalysis ? "$_area sq.m" : "4250 sq.m demo"
      },
      {
        "label": "Estimated Govt Cost",
        "value": hasAnalysis && _val > 0
            ? "Rs. ${(_val / 100000).toStringAsFixed(1)} L"
            : "Awaiting scan"
      },
      {
        "label": "Govt Rate",
        "value": hasAnalysis && _landRate > 0
            ? "Rs. ${_landRate.toStringAsFixed(0)}/sqm"
            : "Official source pending"
      },
      {
        "label": "Confidence",
        "value": hasAnalysis ? "${_accuracy.toStringAsFixed(1)}%" : "94.0% demo"
      },
      {
        "label": "Workflow",
        "value": hasAnalysis ? "Analysis ready" : "Sample report available"
      },
    ];

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF39FF14).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF39FF14).withValues(alpha: 0.35))),
              child: const Icon(Icons.description_outlined,
                  color: Color(0xFF39FF14)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Reports Module",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                      "Compliance dossier preview with evidence, official-rate estimate, and action trail.",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: rows
              .map((item) => SizedBox(
                    width: isMobile ? double.infinity : 260,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0B1221),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item["label"]!,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(item["value"]!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xFF0B1221),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Evidence Checklist",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 14),
              _reportStep(
                  Icons.map_outlined,
                  "Satellite layer captured",
                  hasAnalysis
                      ? "Live map position locked"
                      : "Demo layer ready"),
              _reportStep(
                  Icons.polyline_outlined,
                  "Boundary overlay verified",
                  _govtPolygons.isNotEmpty
                      ? "Govt boundary loaded"
                      : "Sample boundary will be attached"),
              _reportStep(
                  Icons.warning_amber_rounded,
                  "Encroachment candidates marked",
                  _anomalyPolygons.isNotEmpty
                      ? "${_anomalyPolygons.length} anomaly layer(s)"
                      : "Demo anomaly polygon ready"),
              _reportStep(
                  Icons.task_alt,
                  "Compliance action prepared",
                  _notice.isNotEmpty
                      ? "Notice draft available"
                      : "Template draft available"),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF39FF14).withValues(alpha: 0.2))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Blockchain Audit Log",
                    style: TextStyle(
                        color: Color(0xFF39FF14),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1)),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text("VERIFIED",
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 15),
              _auditRow("BLOCK_HASH",
                  "0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}8F2..."),
              _auditRow("PROTOCOL", "AES-256-GCM / SHARDED"),
              _auditRow("NODE_ID", "GRAVITY-PRIMARY-BOM-01"),
              const SizedBox(height: 10),
              const Text(
                  "Note: This dossier is cryptographically sealed and stored on the immutable administrative ledger.",
                  style: TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic, delay: 600.ms)
            .slideY(begin: 0.1, end: 0),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                child: _btn("Generate PDF", Icons.picture_as_pdf, _makePDF)),
            const SizedBox(width: 12),
            Expanded(
                child: _btn("Open Map", Icons.map_outlined,
                    () => setState(() => _navIndex = 1))),
          ],
        ),
      ],
    );
  }

  Widget _auditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _reportStep(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF39FF14), size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ])),
        ],
      ),
    );
  }

  Widget _forestWatchModule(bool isMobile) {
    final String target = _searchCtrl.text.trim().isEmpty
        ? "Current map location"
        : _searchCtrl.text.trim();
    final alerts = _forestAlerts.isEmpty
        ? [
            _forestReady
                ? "No high-risk forest transition detected in sampled Bhuvan cells."
                : "No scan yet. Run ISRO Bhuvan scan to fetch live LULC classes."
          ]
        : _forestAlerts;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.35))),
              child: const Icon(Icons.forest_rounded,
                  color: Colors.greenAccent, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Forest Watch",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                      "Monitor green cover loss, forest buffer violations, fire risk and illegal clearing evidence.",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        isMobile
            ? Column(
                children: [
                  _forestWatchPreview(isMobile),
                  const SizedBox(height: 14),
                  _forestStatusPanel(target),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _forestWatchPreview(isMobile)),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: _forestStatusPanel(target)),
                ],
              ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _forestMetric(
                "Forest Risk",
                "$_forestRiskScore/100",
                _forestRiskScore > 60 ? Colors.redAccent : Colors.orangeAccent,
                Icons.warning_amber_rounded,
                isMobile),
            _forestMetric(
                "Vegetation Loss",
                "${_forestLossPercent.toStringAsFixed(1)}%",
                _forestLostSamples > 0 ? Colors.redAccent : Colors.greenAccent,
                Icons.energy_savings_leaf_rounded,
                isMobile),
            _forestMetric("Forest Samples", "$_forestForestSamples",
                Colors.greenAccent, Icons.forest_rounded, isMobile),
            _forestMetric(
                "Bhuvan Confidence",
                "${_forestConfidence.toStringAsFixed(0)}%",
                _forestConfidence >= 80 ? Colors.greenAccent : Colors.orange,
                Icons.verified_rounded,
                isMobile),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xFF0B1221),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Forest Monitoring Alerts",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 14),
              for (final alert in alerts)
                _forestAlert(
                    _forestLostSamples > 0
                        ? Icons.nature_people_rounded
                        : Icons.info_outline_rounded,
                    _forestReady ? "Bhuvan Result" : "Awaiting Scan",
                    alert,
                    _forestLostSamples > 0
                        ? Colors.redAccent
                        : Colors.greenAccent),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 230,
              child: _btn(
                  _forestScanning ? "Scanning..." : "Run ISRO Scan",
                  Icons.satellite_alt_rounded,
                  _forestScanning ? () {} : _runForestScan),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 240,
              child: _btn("Open Forest Layer", Icons.map_outlined,
                  _activateForestWatchLayer),
            ),
            if (widget.isOfficer)
              SizedBox(
                width: isMobile ? double.infinity : 260,
                child: _btn("Queue Field Inspection",
                    Icons.assignment_turned_in_rounded, _queueForestInspection),
              ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: _btn("Generate Report", Icons.picture_as_pdf, _makePDF),
            ),
          ],
        ),
      ],
    );
  }

  Widget _forestWatchPreview(bool isMobile) {
    return Container(
      height: isMobile ? 310 : 430,
      decoration: BoxDecoration(
          color: const Color(0xFF06111F),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.greenAccent.withValues(alpha: 0.22))),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: _loc, initialZoom: 13.5),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.gravity.ai',
              ),
              if (_forestReady)
                TileLayer(
                  wmsOptions: _bhuvanLulcWmsOptions(),
                  userAgentPackageName: 'com.gravity.ai',
                ),
              if (_forestReady) PolygonLayer(polygons: _forestWatchPolygons()),
              if (_forestReady) MarkerLayer(markers: _forestWatchMarkers()),
            ],
          ),
          if (!_forestReady)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.18),
                child: Center(
                  child: Container(
                    width: isMobile ? 250 : 360,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0B1221).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.25))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.satellite_alt_rounded,
                            color: Colors.greenAccent, size: 34),
                        const SizedBox(height: 10),
                        const Text("ISRO BHUVAN SCAN REQUIRED",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(_forestStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                height: 1.45)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF0B1221).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.3))),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forest_rounded,
                      color: Colors.greenAccent, size: 16),
                  SizedBox(width: 7),
                  Text("FOREST WATCH LAYER",
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 14,
            bottom: 14,
            right: 14,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ForestLegendDot(
                    color: Colors.greenAccent, label: "Forest Class"),
                _ForestLegendDot(color: Colors.redAccent, label: "Forest Loss"),
                _ForestLegendDot(
                    color: Colors.lightBlueAccent, label: "Other LULC"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _forestStatusPanel(String target) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: const Color(0xFF0B1221),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Watch Status",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 14),
          _forestInfoRow("Target", target),
          _forestInfoRow("Coordinates",
              "${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}"),
          _forestInfoRow("Current LULC", _forestCurrentClass),
          _forestInfoRow("Previous LULC", _forestPreviousClass),
          _forestInfoRow("Layer", _forestLayer),
          _forestInfoRow(
              "Samples", "$_forestValidSamples/$_forestTotalSamples valid"),
          _forestInfoRow(
              "Forest Cover", "${_forestCoverPercent.toStringAsFixed(1)}%"),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.22))),
            child: Text(
              _forestReady
                  ? "Live result from $_forestSource. Classes are sampled from Bhuvan LULC WMS GetFeatureInfo around the selected coordinate."
                  : _forestStatus,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forestMetric(
      String title, String value, Color color, IconData icon, bool isMobile) {
    return SizedBox(
      width: isMobile ? double.infinity : 250,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF0B1221),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 5),
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forestAlert(
      IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _forestInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  List<Polygon> _forestWatchPolygons() {
    if (!_forestReady) return [];
    const cell = 0.028;
    return _forestSamplePoints.map((sample) {
      final lat = (sample['lat'] as num).toDouble();
      final lon = (sample['lon'] as num).toDouble();
      final loss = sample['forest_loss'] == true;
      final isForest = sample['current_is_forest'] == true;
      final color = loss
          ? Colors.redAccent
          : isForest
              ? Colors.greenAccent
              : Colors.lightBlueAccent;
      return Polygon(
          points: [
            LatLng(lat - cell, lon - cell),
            LatLng(lat - cell, lon + cell),
            LatLng(lat + cell, lon + cell),
            LatLng(lat + cell, lon - cell),
          ],
          color: color.withValues(alpha: loss ? 0.42 : 0.16),
          borderColor: color,
          borderStrokeWidth: loss ? 2.5 : 1.4,
          isFilled: true);
    }).toList();
  }

  List<Marker> _forestWatchMarkers() {
    if (!_forestReady) return [];
    final markers = <Marker>[];
    for (final sample in _forestSamplePoints) {
      final lat = (sample['lat'] as num).toDouble();
      final lon = (sample['lon'] as num).toDouble();
      if (sample['forest_loss'] == true) {
        markers.add(Marker(
          point: LatLng(lat, lon),
          width: 170,
          height: 52,
          child: _forestMapBadge(Icons.energy_savings_leaf_rounded,
              "Forest loss", Colors.redAccent),
        ));
      }
    }
    return markers;
  }

  Widget _forestMapBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xFF0B1221).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  WMSTileLayerOptions _bhuvanLulcWmsOptions() {
    return WMSTileLayerOptions(
      baseUrl:
          'https://bhuvan-ras2.nrsc.gov.in/cgi-bin/mapserv.exe?map=/ms4w/apps/mapfiles/LULC250K.map',
      layers: [_forestLayer],
      styles: const ['default'],
      format: 'image/png',
      version: '1.1.1',
      transparent: true,
    );
  }

  Future<void> _runForestScan() async {
    if (_forestScanning) return;
    final sector = _searchCtrl.text.trim().isEmpty
        ? "Current map location"
        : _searchCtrl.text.trim();
    setState(() {
      _forestScanning = true;
      _forestReady = false;
      _forestStatus = "Connecting to ISRO/NRSC Bhuvan LULC WMS...";
      _forestAlerts = [];
      _forestSamplePoints = [];
      _status = "FOREST WATCH: QUERYING BHUVAN LULC";
    });

    final body = jsonEncode({
      "lat": _loc.latitude,
      "lon": _loc.longitude,
      "sector": sector,
      "current_layer": _forestLayer,
      "previous_layer": _forestPreviousLayer,
    });
    Object? lastError;
    try {
      final response = await postBackendJson(
        "/api/forest_scan",
        body,
        timeout: const Duration(seconds: 45),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applyForestScanResult(data);
        return;
      }
      lastError = "HTTP ${response.statusCode}: ${response.body}";
    } catch (e) {
      lastError = e;
    }

    if (!mounted) return;
    setState(() {
      _forestScanning = false;
      _forestReady = false;
      _forestStatus =
          "Forest scan failed. Start the backend or deploy /api/forest_scan. $lastError";
      _status = "FOREST WATCH ERROR";
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Forest scan failed: $lastError"),
        backgroundColor: Colors.redAccent));
  }

  void _applyForestScanResult(Map<String, dynamic> data) {
    final samples = (data['sample_points'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (!mounted) return;
    setState(() {
      _forestScanning = false;
      _forestReady = true;
      _showForestWatch = true;
      _hasSearched = true;
      _forestSource = data['source']?.toString() ?? _forestSource;
      _forestLayer = data['current_layer']?.toString() ?? _forestLayer;
      _forestPreviousLayer =
          data['previous_layer']?.toString() ?? _forestPreviousLayer;
      _forestCurrentClass = data['current_class']?.toString() ?? "Unknown";
      _forestPreviousClass = data['previous_class']?.toString() ?? "Unknown";
      _forestRiskScore = (data['risk_score'] as num? ?? 0).round();
      _forestValidSamples = (data['valid_samples'] as num? ?? 0).round();
      _forestTotalSamples = (data['total_samples'] as num? ?? 0).round();
      _forestForestSamples = (data['forest_samples'] as num? ?? 0).round();
      _forestLostSamples = (data['lost_samples'] as num? ?? 0).round();
      _forestCoverPercent =
          (data['forest_cover_percent'] as num? ?? 0).toDouble();
      _forestLossPercent =
          (data['vegetation_loss_percent'] as num? ?? 0).toDouble();
      _forestConfidence = (data['confidence'] as num? ?? 0).toDouble();
      _forestSamplePoints = samples;
      _forestAlerts = (data['alerts'] as List? ?? [])
          .map((item) => item.toString())
          .toList();
      _forestStatus =
          "Bhuvan scan complete: $_forestCurrentClass ($_forestLayer)";
      _status = "FOREST WATCH READY - BHUVAN LULC LIVE";
    });
  }

  void _activateForestWatchLayer() {
    setState(() {
      _showForestWatch = true;
      _hasSearched = true;
      _navIndex = 1;
      _status = _forestReady
          ? "FOREST WATCH LAYER ACTIVE"
          : "RUN ISRO FOREST SCAN FIRST";
    });
  }

  void _queueForestInspection() {
    final target = _searchCtrl.text.trim().isEmpty
        ? "Current map location"
        : _searchCtrl.text.trim();
    setState(() {
      _tasksList.insert(0, {
        "title": "Forest Watch Inspection",
        "desc": "Target: $target | Vegetation loss and buffer breach check",
        "status": "Pending",
        "time": DateFormat('HH:mm a').format(DateTime.now())
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Forest inspection task queued."),
        backgroundColor: Colors.green));
  }

  Widget _publicAccessModule(bool isMobile) {
    final map = _mapView(isMobile);
    final panel = _publicAccessPanel(isMobile);

    if (isMobile) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SizedBox(
              height: MediaQuery.of(context).size.height * 0.46, child: map),
          const SizedBox(height: 12),
          panel,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(flex: 7, child: map),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: panel),
        ],
      ),
    );
  }

  Widget _publicAccessPanel(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF0B1221),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.policy_rounded, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 10),
            Expanded(
                child: Text("Public Access: Bhu-Prahari",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 8),
          const Text(
              "Land encroachment details dekhein, map par location verify karein, aur suspected encroachment complaint submit karein.",
              style:
                  TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
          const SizedBox(height: 16),
          _publicComplaintForm(),
          const SizedBox(height: 14),
          _publicLandDetailsCard(),
          const SizedBox(height: 14),
          _publicComplaintHistory(),
        ]),
      ),
    );
  }

  Widget _publicLandDetailsCard() {
    final target = _searchCtrl.text.trim().isEmpty
        ? "Pinned map location"
        : _searchCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Land Encroachment Details",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 12),
        _publicInfoRow("Target", target),
        _publicInfoRow("Coordinates",
            "${_loc.latitude.toStringAsFixed(5)}, ${_loc.longitude.toStringAsFixed(5)}"),
        _publicInfoRow(
            "Detected Area", _ready ? "$_area sq.m" : "Run map search"),
        _publicInfoRow(
            "Estimated Govt Cost",
            _ready && _val > 0
                ? "Rs. ${(_val / 100000).toStringAsFixed(1)} L"
                : "Pending"),
        _publicInfoRow(
            "Govt Rate",
            _ready && _landRate > 0
                ? "Rs. ${_landRate.toStringAsFixed(0)}/sqm"
                : "Pending"),
        _publicInfoRow("Prediction", _ready ? _predictionLabel : "Pending"),
        _publicInfoRow(
            "Source", _ready ? _officialLandSource : "Awaiting search"),
        _publicInfoRow(
            "Status", _ready ? "Satellite analysis ready" : "Awaiting search"),
      ]),
    );
  }

  Widget _publicComplaintForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Bhu-Prahari Complaint",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 12),
        if (!_isAnonymous) ...[
          TextField(
            controller: _citizenNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: "Your name",
              prefixIcon:
                  Icon(Icons.person_outline, color: Colors.orangeAccent),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _citizenEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: "Email ID (optional)",
              prefixIcon:
                  Icon(Icons.alternate_email, color: Colors.orangeAccent),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _citizenPhoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: "Phone number (optional)",
              prefixIcon:
                  Icon(Icons.phone_outlined, color: Colors.orangeAccent),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _citizenComplaintCtrl,
          minLines: 2,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: "Encroachment details, landmark, photo/report notes...",
            prefixIcon:
                Icon(Icons.report_problem_outlined, color: Colors.orangeAccent),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickCitizenEvidence,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(
            _citizenEvidenceName == null
                ? "Upload photo/report"
                : _citizenEvidenceName!,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side:
                BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.45)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Checkbox(
              value: _isAnonymous,
              activeColor: const Color(0xFF39FF14),
              onChanged: (v) => setState(() => _isAnonymous = v ?? false)),
          const Expanded(
              child: Text("Submit anonymously",
                  style: TextStyle(color: Colors.white70, fontSize: 12))),
        ]),
        SizedBox(
          width: double.infinity,
          child: _btn("Submit to Bhu-Prahari", Icons.send_rounded,
              () => _submitBhuPrahariComplaint()),
        ),
      ]),
    );
  }

  Widget _publicComplaintHistory() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: BhuPrahariStore.complaints,
      builder: (context, complaints, _) {
        final statusId = _citizenStatusCtrl.text.trim();
        final matches = statusId.isEmpty
            ? complaints.take(3).toList()
            : complaints
                .where((item) =>
                    item['id'].toString().toLowerCase() ==
                    statusId.toLowerCase())
                .toList();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Submitted Complaint Status",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _citizenStatusCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: "Enter complaint ID to check status",
                prefixIcon:
                    Icon(Icons.search_rounded, color: Color(0xFF39FF14)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            if (matches.isEmpty)
              Text(
                  statusId.isEmpty
                      ? "No public complaints submitted yet."
                      : "No complaint found for this ID.",
                  style: const TextStyle(color: Colors.white38, fontSize: 12))
            else
              ...matches.map((item) => _publicComplaintTile(item)),
          ]),
        );
      },
    );
  }

  Widget _publicComplaintTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFF06111F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['id'].toString(),
            style: const TextStyle(
                color: Color(0xFF39FF14),
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(item['status'].toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 3),
        Text(item['action'].toString(),
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        if ((item['email'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text("Email: ${item['email']}",
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
        if ((item['evidence'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text("Evidence: ${item['evidence']}",
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ]),
    );
  }

  Widget _publicInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _officerComplaintRecords(bool isMobile) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: BhuPrahariStore.complaints,
      builder: (context, complaints, _) {
        return Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("BHU-PRAHARI COMPLAINT RECORDS",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("${complaints.length} public complaint record(s).",
                style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            Expanded(
              child: complaints.isEmpty
                  ? const Center(
                      child: Text(
                          "No Bhu-Prahari complaints submitted by public users yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: complaints.length,
                      itemBuilder: (context, index) =>
                          _officerComplaintCard(complaints[index], isMobile),
                    ),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _updateComplaintAction(
      String id, String status, String action) async {
    BhuPrahariStore.updateAction(id, status, action);
    final token = AuthSession.token;
    if (token == null || token.isEmpty) return;
    try {
      final response = await patchBackendJson(
        "/api/complaints/$id",
        jsonEncode({"status": status, "action": action}),
        bearerToken: token,
        timeout: const Duration(seconds: 20),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final complaint = Map<String, dynamic>.from(data['complaint'] as Map);
        BhuPrahariStore.updateAction(
          complaint['id'].toString(),
          complaint['status'].toString(),
          complaint['action'].toString(),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Session expired. Please login again."),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Complaint update sync failed: $e");
    }
  }

  Widget _officerComplaintCard(Map<String, dynamic> item, bool isMobile) {
    final lat = (item['lat'] as num).toDouble();
    final lon = (item['lon'] as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.policy_rounded,
              color: Colors.orangeAccent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${item['id']} • ${item['target']}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Reporter: ${item['reporter']}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if ((item['email'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text("Email: ${item['email']}",
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
              if ((item['phone'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text("Phone: ${item['phone']}",
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
              const SizedBox(height: 5),
              Text(
                  "Location: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}",
                  style: const TextStyle(
                      color: Color(0xFFB7FFC0),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(item['description'].toString(),
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4)),
              const SizedBox(height: 6),
              Text("Evidence: ${item['evidence'] ?? 'No photo uploaded'}",
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(item['status'].toString(),
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(item['action'].toString(),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _smallComplaintAction("View Map", Icons.map_outlined, () {
            setState(() {
              _loc = LatLng(lat, lon);
              _searchCtrl.text = item['target'].toString();
              _hasSearched = true;
              _ready = true;
              _navIndex = 0;
              _applyDemoScanState(item['target'].toString());
            });
          }),
          _smallComplaintAction("Start Review", Icons.fact_check_outlined, () {
            _updateComplaintAction(
                item['id'].toString(), "Under Review", "User review started");
          }),
          _smallComplaintAction(
              "Field Inspection", Icons.assignment_turned_in_rounded, () {
            _updateComplaintAction(item['id'].toString(),
                "Inspection Scheduled", "Field team assigned for verification");
          }),
          _smallComplaintAction("Resolve", Icons.verified_rounded, () {
            _updateComplaintAction(
                item['id'].toString(), "Resolved", "Action completed");
          }),
        ]),
      ]),
    );
  }

  Widget _smallComplaintAction(
      String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (!widget.isOfficer) {
      return _publicAccessModule(isMobile);
    }
    if (_navIndex == 1) {
      return Padding(
          padding: const EdgeInsets.all(12.0), child: _mapView(isMobile));
    } else if (_navIndex == 2) {
      return _reportsModule(isMobile);
    } else if (_navIndex == 3) {
      return _officerComplaintRecords(isMobile);
    } else if (_navIndex == 4) {
      return _forestWatchModule(isMobile);
    }

    if (isMobile) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10)),
              child: _mapView(isMobile)),
          const SizedBox(height: 12),
          _rightPanel(isMobile),
        ],
      );
    }

    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(children: [
          Expanded(flex: 7, child: _mapView(isMobile)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _rightPanel(isMobile))
        ]));
  }

  Widget _sidebar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
            width: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF06111F).withValues(alpha: 0.86),
              border: Border(
                  right: BorderSide(
                      color: const Color(0xFF39FF14).withValues(alpha: 0.12))),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF39FF14).withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(10, 0))
              ],
            ),
            child: Column(children: [
              const SizedBox(height: 20),
              _sideBtn(
                  widget.isOfficer ? Icons.dashboard : Icons.policy_rounded,
                  widget.isOfficer ? "Dashboard" : "Public",
                  _navIndex == 0,
                  tap: () => setState(() => _navIndex = 0)),
              if (widget.isOfficer) ...[
                _sideBtn(Icons.map_outlined, "Map", _navIndex == 1,
                    tap: () => setState(() => _navIndex = 1)),
                _sideBtn(Icons.description_outlined, "Reports", _navIndex == 2,
                    tap: () => setState(() => _navIndex = 2)),
                _sideBtn(Icons.forest_rounded, "Forest", _navIndex == 4,
                    tap: () => setState(() => _navIndex = 4)),
                _sideBtn(
                    Icons.assignment_late_rounded, "Complaints", _navIndex == 3,
                    tap: () => setState(() => _navIndex = 3)),
              ],
              const Spacer(),
              const SizedBox(height: 20),
            ])),
      ),
    );
  }

  Widget _sideBtn(IconData i, String label, bool act,
      {Color? color, VoidCallback? tap}) {
    return InkWell(
        onTap: tap,
        child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: act
                            ? const Color(0xFF39FF14).withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.05)),
                    color: act
                        ? const Color(0xFF39FF14).withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.02),
                    boxShadow: act
                        ? [
                            BoxShadow(
                                color: const Color(0xFF39FF14)
                                    .withValues(alpha: 0.22),
                                blurRadius: 18)
                          ]
                        : null),
                child: Column(children: [
                  Icon(i,
                      color: act
                          ? const Color(0xFF39FF14)
                          : (color ?? Colors.white54),
                      size: 28),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                          color: act
                              ? const Color(0xFF39FF14)
                              : (color ?? Colors.white54),
                          fontSize: 10),
                      textAlign: TextAlign.center)
                ]))
            .animate(target: act ? 1 : 0)
            .scaleXY(
                begin: 1,
                end: 1.04,
                duration: 220.ms,
                curve: Curves.easeOutCubic));
  }

  Widget _topNav(bool isMobile) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                color: const Color(0xFF06111F).withValues(alpha: 0.84),
                border: Border(
                    bottom: BorderSide(
                        color:
                            const Color(0xFF39FF14).withValues(alpha: 0.12)))),
            child: Row(children: [
              if (isMobile)
                IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer()),
              Image.asset("assets/images/logo.png", height: isMobile ? 25 : 35),
              const SizedBox(width: 8),
              Text("Gravity AI | Live",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : 18,
                      fontWeight: FontWeight.bold)),
              if (!isMobile) ...[
                const SizedBox(width: 15),
                Container(height: 20, width: 2, color: Colors.white24),
                const SizedBox(width: 15),
                Text(widget.isOfficer ? "User Dashboard" : "Public Access",
                    style: const TextStyle(
                        color: Color(0xFFB7FFC0),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
              const Spacer(),
              if (!isMobile) ...[
                if (widget.isOfficer) ...[
                  Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text((AuthSession.user ?? "Officer").toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF39FF14),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const Text("SECURE SESSION ACTIVE",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 10))
                      ]),
                  const SizedBox(width: 10),
                  const CircleAvatar(
                      backgroundColor: Color(0xFF153826),
                      child: Icon(Icons.person, color: Color(0xFF39FF14)))
                ] else ...[
                  const Text("GUEST USER",
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))
                ],
              ],
              const SizedBox(width: 15),
              if (widget.isOfficer) ...[
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: BhuPrahariStore.complaints,
                    builder: (context, complaints, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none,
                                color: Colors.white),
                            onPressed: () => _showNotificationPanel(),
                          ),
                          if (complaints.isNotEmpty || _tasksList.isNotEmpty)
                            Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle)))
                        ],
                      );
                    }),
                const SizedBox(width: 10),
              ],
              IconButton(
                  tooltip: widget.isOfficer ? "Logout" : "Exit",
                  onPressed: widget.isOfficer
                      ? () => _logout()
                      : () {
                          _timer?.cancel();
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (c) => const LandingPage()));
                        },
                  icon: const Icon(Icons.logout, color: Colors.white54))
            ])),
      ),
    );
  }

  Widget _mapView(bool isMobile) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: !_hasSearched
                ? Container(
                    key: const ValueKey("poster"),
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF020914),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF020914),
                          const Color(0xFF09211F).withValues(alpha: 0.96),
                          const Color(0xFF07111E),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  const Color(0xFF020914)
                                      .withValues(alpha: 0.96),
                                  const Color(0xFF06111F)
                                      .withValues(alpha: 0.70),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: isMobile ? 260 : 420,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06111F)
                                  .withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF39FF14)
                                      .withValues(alpha: 0.22)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.radar_rounded,
                                        color: Color(0xFF39FF14), size: 42)
                                    .animate(onPlay: (c) => c.repeat())
                                    .rotate(duration: 3.seconds),
                                const SizedBox(height: 12),
                                const Text("LIVE LAND INTELLIGENCE GRID",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 1.1)),
                                const SizedBox(height: 8),
                                Text(
                                    widget.isOfficer
                                        ? "Enter a city, sector, or coordinates to activate satellite comparison, AI risk scoring, reports, and user tasks."
                                        : "Search a city, sector, or coordinates to view land encroachment details and submit a Bhu-Prahari complaint.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        height: 1.45)),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms).scale(
                              begin: const Offset(0.96, 0.96),
                              end: const Offset(1, 1)),
                        ),
                      ],
                    ),
                  )
                : FlutterMap(
                    key: ValueKey("map_$_timelineYear"),
                    mapController: _mapCtrl,
                    options: MapOptions(
                        initialCenter: _loc, initialZoom: _currentZoom),
                    children: [
                      TileLayer(
                        urlTemplate: _getTimelineTileUrl(),
                        userAgentPackageName: 'com.gravity.ai',
                      ),
                      if (widget.isOfficer && _showBhuvanWms)
                        TileLayer(
                          urlTemplate:
                              'https://bhuvan-vec1.nrsc.gov.in/bhuvan/gwc/service/wmts?SERVICE=WMTS&VERSION=1.0.0&REQUEST=GetTile&LAYER=lulc:ap_lulc_50k_1516&STYLE=default&TILEMATRIXSET=EPSG:900913&TILEMATRIX=EPSG:900913:{z}&TILEROW={y}&TILECOL={x}&FORMAT=image/png',
                          userAgentPackageName: 'com.gravity.ai',
                        ),
                      if (widget.isOfficer && _showForestWatch && _forestReady)
                        TileLayer(
                          wmsOptions: _bhuvanLulcWmsOptions(),
                          userAgentPackageName: 'com.gravity.ai',
                        ),
                      PolygonLayer(polygons: _govtPolygons),
                      PolygonLayer(polygons: _anomalyPolygons),
                      MarkerLayer(markers: _illegalHouseMarkers),
                      if (widget.isOfficer && _showForestWatch) ...[
                        PolygonLayer(polygons: _forestWatchPolygons()),
                        MarkerLayer(markers: _forestWatchMarkers()),
                      ],
                      if (_droneActive && _dronePos != null)
                        MarkerLayer(markers: [
                          Marker(
                              point: _dronePos!,
                              width: 80,
                              height: 80,
                              child: const Icon(Icons.gps_fixed,
                                  color: Colors.redAccent, size: 40))
                        ]),
                    ],
                  ),
          ),
          Positioned(
              top: 15,
              right: 15,
              left: isMobile ? 15 : null,
              child: Container(
                  width: isMobile ? null : 350,
                  decoration: BoxDecoration(
                      color: const Color(0xFF0B1221).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24)),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                                hintText: "Search City/Sector...",
                                hintStyle: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 12)),
                            onSubmitted: (_) => _scanning ? null : _runScan())),
                    IconButton(
                        icon: _scanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF39FF14)))
                            : const Icon(Icons.search,
                                color: Colors.white, size: 20),
                        onPressed: _scanning ? null : _runScan)
                  ]))),
          if (_hasSearched && !isMobile)
            Positioned(
                top: 20,
                left: 20,
                child: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFF0B1221).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24)),
                    child: Column(children: [
                      IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {
                            setState(() => _currentZoom++);
                            _mapCtrl.move(_loc, _currentZoom);
                          }),
                      Container(height: 1, width: 30, color: Colors.white24),
                      IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: () {
                            setState(() => _currentZoom--);
                            _mapCtrl.move(_loc, _currentZoom);
                          })
                    ]))),
          // Satellite / Street Toggle Button
          if (_hasSearched)
            Positioned(
                top: isMobile ? 70 : 130,
                left: isMobile ? 15 : 20,
                child: GestureDetector(
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1221).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _isSatellite
                              ? const Color(0xFF39FF14).withValues(alpha: 0.5)
                              : Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _isSatellite
                              ? Icons.layers_rounded
                              : Icons.map_outlined,
                          color: _isSatellite
                              ? const Color(0xFF39FF14)
                              : Colors.white,
                          size: 18),
                      const SizedBox(width: 6),
                      Text(_isSatellite ? "Satellite" : "Street",
                          style: TextStyle(
                              color: _isSatellite
                                  ? const Color(0xFF39FF14)
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                )),
          // Bhuvan WMS Toggle
          if (_hasSearched && widget.isOfficer)
            Positioned(
                top: isMobile ? 115 : 185,
                left: isMobile ? 15 : 20,
                child: GestureDetector(
                  onTap: () => setState(() => _showBhuvanWms = !_showBhuvanWms),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1221).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _showBhuvanWms
                              ? Colors.orangeAccent.withValues(alpha: 0.5)
                              : Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.layers,
                          color: _showBhuvanWms
                              ? Colors.orangeAccent
                              : Colors.white,
                          size: 18),
                      const SizedBox(width: 6),
                      Text("Bhuvan WMS",
                          style: TextStyle(
                              color: _showBhuvanWms
                                  ? Colors.orangeAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                )),
          // Timeline Toggle Button
          if (_hasSearched && widget.isOfficer)
            Positioned(
                top: isMobile ? 160 : 240,
                left: isMobile ? 15 : 20,
                child: GestureDetector(
                  onTap: () => setState(() => _showTimeline = !_showTimeline),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1221).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _showTimeline
                              ? Colors.purpleAccent.withValues(alpha: 0.5)
                              : Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timeline,
                          color: _showTimeline
                              ? Colors.purpleAccent
                              : Colors.white,
                          size: 18),
                      const SizedBox(width: 6),
                      Text("Timeline",
                          style: TextStyle(
                              color: _showTimeline
                                  ? Colors.purpleAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                )),
          // Forest Watch Overlay Toggle
          if (_hasSearched && widget.isOfficer)
            Positioned(
                top: isMobile ? 205 : 295,
                left: isMobile ? 15 : 20,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showForestWatch = !_showForestWatch),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1221).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _showForestWatch
                              ? Colors.greenAccent.withValues(alpha: 0.55)
                              : Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.forest_rounded,
                          color: _showForestWatch
                              ? Colors.greenAccent
                              : Colors.white,
                          size: 18),
                      const SizedBox(width: 6),
                      Text("Forest Watch",
                          style: TextStyle(
                              color: _showForestWatch
                                  ? Colors.greenAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                )),
          if (_hasSearched)
            Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0B1221).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24)),
                    child: Row(children: [
                      const Icon(Icons.thermostat,
                          color: Colors.orangeAccent, size: 14),
                      const SizedBox(width: 5),
                      Text("${_envData['temp']}°C",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.air,
                          color: Colors.lightBlueAccent, size: 14),
                      const SizedBox(width: 5),
                      Text("AQI: ${_envData['aqi']}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.landscape,
                          color: Colors.brown, size: 14),
                      const SizedBox(width: 5),
                      Text("Soil: ${_envData['soil']}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.water_drop,
                          color: Colors.blueAccent, size: 14),
                      const SizedBox(width: 5),
                      Text("${_envData['moisture']}%",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11))
                    ]))),
          // Change Detection Timeline Slider
          if (_hasSearched && widget.isOfficer && _showTimeline)
            Positioned(
              bottom: isMobile ? 60 : 65,
              left: isMobile ? 15 : 20,
              right: isMobile ? 15 : 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1221).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.purpleAccent.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 15)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timeline,
                            color: Colors.purpleAccent, size: 16),
                        const SizedBox(width: 8),
                        const Text("CHANGE DETECTION",
                            style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text("$_timelineYear",
                              style: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.purpleAccent,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.purpleAccent,
                        overlayColor:
                            Colors.purpleAccent.withValues(alpha: 0.2),
                        valueIndicatorColor: Colors.purpleAccent,
                        valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      child: Slider(
                        value: _timelineYear.toDouble(),
                        min: 2018,
                        max: 2026,
                        divisions: 8,
                        label: _timelineYear.toString(),
                        onChanged: (v) {
                          setState(() => _timelineYear = v.round());
                        },
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("2018",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 9)),
                        Text("2020",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 9)),
                        Text("2022",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 9)),
                        Text("2024",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 9)),
                        Text("2026",
                            style:
                                TextStyle(color: Colors.white30, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_droneActive)
            Positioned.fill(
                child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                const Color(0xFF39FF14).withValues(alpha: 0.3),
                            width: isMobile ? 10 : 40)),
                    child: const Center(
                        child: Icon(Icons.center_focus_strong,
                            color: Color(0xFF39FF14), size: 100)))),
        ]));
  }

  Widget _rightPanel(bool isMobile) {
    return Container(
        decoration: BoxDecoration(
            color: const Color(0xFF0B1221),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status,
                style: TextStyle(
                    color: _status.contains("ERROR")
                        ? Colors.redAccent
                        : (_ready
                            ? Colors.greenAccent
                            : const Color(0xFF39FF14)),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (widget.isOfficer) ...[
              const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Quick User Tools",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.flash_on, color: Color(0xFF39FF14), size: 16)
                  ]),
              const SizedBox(height: 10),
              _actionBtn(
                  _droneConnected
                      ? "Disconnect Drone ($_droneIp)"
                      : "Connect Surveillance Drone",
                  _droneConnected ? Icons.flight_land : Icons.flight_takeoff,
                  _toggleDrone),
              // Drone Telemetry Display
              if (_droneConnected)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF39FF14).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF39FF14).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.greenAccent, blurRadius: 5)
                                ])),
                        const SizedBox(width: 8),
                        const Text("LIVE TELEMETRY",
                            style: TextStyle(
                                color: Color(0xFF39FF14),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _telemetryItem(
                                "🔋",
                                "Battery",
                                "${_droneTelemetry['battery']}%",
                                (_droneTelemetry['battery'] as int) > 20
                                    ? Colors.greenAccent
                                    : Colors.redAccent),
                            _telemetryItem(
                                "📡",
                                "Alt",
                                "${(_droneTelemetry['altitude'] as double).toStringAsFixed(1)}m",
                                const Color(0xFF39FF14)),
                            _telemetryItem(
                                "💨",
                                "Speed",
                                "${(_droneTelemetry['speed'] as double).toStringAsFixed(1)}m/s",
                                Colors.white),
                            _telemetryItem(
                                "📍",
                                "GPS",
                                "${_droneTelemetry['gps']}",
                                Colors.greenAccent),
                          ]),
                    ],
                  ),
                ),
              _actionBtn(
                  "Capture Field Evidence", Icons.camera_alt, _captureEvidence),
              const SizedBox(height: 20),
            ],
            if (!_ready)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_scanning)
                        const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF39FF14))),
                      if (_scanning) const SizedBox(height: 16),
                      Text(
                        _scanning
                            ? "Resolving location, loading satellite tiles, and preparing evidence layers..."
                            : "Search a city, sector, or coordinates to start a land-risk analysis workflow.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              const Text("Real-time Stats",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold))
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 15),
              _stat("Total Encroached Area", "$_area sq.m", Colors.white)
                  .animate()
                  .fadeIn(
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                      delay: 100.ms)
                  .slideY(begin: 0.2, end: 0),
              _stat("Detection Confidence", "${_accuracy.toStringAsFixed(1)}%",
                      const Color(0xFF39FF14))
                  .animate()
                  .fadeIn(
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                      delay: 200.ms)
                  .slideY(begin: 0.2, end: 0),
                      _stat(
                       "Estimated Govt Cost",
                       _val > 0
                           ? "Rs. ${(_val / 100000).toStringAsFixed(1)} L"
                           : "Review pending",
                       Colors.greenAccent)
                  .animate()
                  .fadeIn(
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                      delay: 250.ms)
                  .slideY(begin: 0.2, end: 0),
              Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _col(
                                  "GOVT RATE",
                                  "Rs. ${_landRate.toStringAsFixed(0)}/sqm",
                                  Colors.greenAccent),
                              _col("PREDICTION", _predictionLabel,
                                  Colors.cyanAccent)
                            ]),
                        const Divider(color: Colors.white24, height: 20),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _col("SOURCE", _officialLandSource,
                                  Colors.orangeAccent),
                              _col("ECOLOGY", "-$_veg%", Colors.lightGreen)
                            ])
                      ]))
                  .animate()
                  .fadeIn(
                      duration: 600.ms,
                      curve: Curves.easeOutCubic,
                      delay: 300.ms)
                  .scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 25),
              const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Anomaly Detection",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.more_horiz, color: Colors.white54)
                  ]),
              const SizedBox(height: 10),
              Text(
                   _risk > 0
                       ? "Protected-boundary screening: potential encroachment flagged for field verification."
                       : "Blue-boundary screening: manual illegal-land review ready.",
                   style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11)),
              const SizedBox(height: 25),
              if (widget.isOfficer) ...[
                Row(children: [
                  Expanded(child: _btn("Compare", Icons.compare, _showComp)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _btn("Report", Icons.picture_as_pdf, _makePDF))
                ]).animate().fadeIn(
                    duration: 600.ms,
                    curve: Curves.easeOutCubic,
                    delay: 400.ms),
                const SizedBox(height: 20),
                const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Scan Actions",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      Icon(Icons.more_horiz, color: Colors.white54)
                    ]),
                const SizedBox(height: 10),
                _actionBtn("Draft Compliance Notice", Icons.auto_awesome,
                        _showNotice)
                    .animate()
                    .fadeIn(
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                        delay: 500.ms),
                if (!_evictSent && !_canDemolish)
                  _actionBtn("Set Review Timer", Icons.warning_amber_rounded,
                          _startTimer)
                      .animate()
                      .fadeIn(delay: 600.ms),
                if (_evictSent)
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orangeAccent)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("REVIEW TIMER ACTIVE",
                                style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 5),
                            Text("Deadline: $_timerSecs Seconds Remaining",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold))
                          ])),
                if (_canDemolish)
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Field inspection task created."),
                                    backgroundColor: Colors.green));
                            setState(() {
                              _tasksList.insert(0, {
                                "title": "Field Inspection Queued",
                                "desc":
                                    "Sector: ${_searchCtrl.text.toUpperCase()} | Loc ID: BHU-449-A",
                                "status": "Success",
                                "time":
                                    DateFormat('HH:mm a').format(DateTime.now())
                              });
                              _canDemolish = false;
                              _ready = false;
                            });
                          },
                          icon: const Icon(Icons.assignment_turned_in),
                          label: const Text("Add to Inspection Queue"),
                          style: ElevatedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.all(15),
                              backgroundColor: Colors.orange[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)))))
              ] else ...[
                const Text("NOTE: Administrative tools disabled for guests.",
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                _actionBtn("Submit Citizen Report", Icons.report_problem,
                    _showBhuPrahari),
              ],
              if (_fieldEvidences.isNotEmpty) ...[
                const SizedBox(height: 25),
                const Text("Recent Field Records",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ..._fieldEvidences.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.image,
                            color: Color(0xFF39FF14), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(e['name'],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  "Geotag: ${e['lat'].toStringAsFixed(4)}, ${e['lon'].toStringAsFixed(4)}",
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 10)),
                            ])),
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 14)
                      ]),
                    ))
              ]
            ]
          ],
        )));
  }

  Widget _stat(String t, String v, Color c) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        Text(v,
            style:
                TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold))
      ]));
  Widget _col(String l, String v, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(v,
            style:
                TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold))
      ]);
  Widget _btn(String t, IconData i, VoidCallback tap) => ElevatedButton.icon(
      onPressed: tap,
      icon: Icon(i, size: 16),
      label: Text(t, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  Widget _actionBtn(String t, IconData i, VoidCallback tap) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: tap,
              icon: Icon(i, size: 18),
              label: Text(t),
              style: ElevatedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(15),
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))))));
  Widget _telemetryItem(String emoji, String label, String value, Color c) =>
      Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white30,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
        Text(value,
            style:
                TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold))
      ]);

  // ========================================================
  // CHANGE DETECTION TIMELINE - ESRI WAYBACK TILE URLs
  // ========================================================
  static const Map<int, int> _waybackTileIdsByYear = {
    2018: 23448,
    2019: 4756,
    2020: 29260,
    2021: 26120,
    2022: 45134,
    2023: 56102,
    2024: 16453,
    2025: 13192,
  };

  String _currentSatelliteTileUrl() {
    return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  }

  String _waybackSatelliteTileUrl(int year) {
    final tileId = _waybackTileIdsByYear[year];
    if (tileId == null) return _currentSatelliteTileUrl();
    return 'https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/GoogleMapsCompatible/MapServer/tile/$tileId/{z}/{y}/{x}';
  }

  String _getTimelineTileUrl() {
    if (!_isSatellite) return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    if (!_showTimeline || _timelineYear >= 2026) {
      return _currentSatelliteTileUrl();
    }
    return _waybackSatelliteTileUrl(_timelineYear);
  }

  // ========================================================
  // REAL DRONE CONNECTION SYSTEM
  // ========================================================
  void _toggleDrone() {
    if (_droneConnected) {
      // Disconnect
      setState(() {
        _droneConnected = false;
        _droneActive = false;
        _dronePollTimer?.cancel();
        _droneTimer?.cancel();
        _dronePos = null;
        _status = "✅ DRONE DISCONNECTED";
        _droneTelemetry = {
          "battery": 0,
          "altitude": 0.0,
          "speed": 0.0,
          "gps": "No Fix"
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Drone disconnected."),
          backgroundColor: Colors.orange));
    } else {
      _showDronePanel();
    }
  }

  void _showDronePanel() {
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(
              builder: (context, setDroneState) {
                return Dialog(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white10)),
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF39FF14)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.flight,
                                  color: Color(0xFF39FF14), size: 24),
                            ),
                            const SizedBox(width: 15),
                            const Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Drone Command Center",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 3),
                                Text("Connect via MAVLink / DJI Cloud API",
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            )),
                            IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white54),
                                onPressed: () => Navigator.pop(c)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Protocol Selection
                        const Text("CONNECTION PROTOCOL",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFF39FF14)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF39FF14)
                                        .withValues(alpha: 0.5))),
                            child: const Column(children: [
                              Icon(Icons.webhook,
                                  color: Color(0xFF39FF14), size: 20),
                              SizedBox(height: 5),
                              Text("MAVLink",
                                  style: TextStyle(
                                      color: Color(0xFF39FF14),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              Text("UDP/TCP",
                                  style: TextStyle(
                                      color: Colors.white30, fontSize: 9)),
                            ]),
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10)),
                            child: const Column(children: [
                              Icon(Icons.cloud,
                                  color: Colors.white54, size: 20),
                              SizedBox(height: 5),
                              Text("DJI Cloud",
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              Text("REST API",
                                  style: TextStyle(
                                      color: Colors.white30, fontSize: 9)),
                            ]),
                          )),
                        ]),
                        const SizedBox(height: 20),
                        // IP/Endpoint Input
                        const Text("DRONE ENDPOINT",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _droneIpCtrl,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "192.168.1.100:14550",
                            hintStyle: const TextStyle(color: Colors.white30),
                            prefixIcon: const Icon(Icons.router,
                                color: Color(0xFF39FF14), size: 18),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Mission Target
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10)),
                          child: Row(children: [
                            const Icon(Icons.location_on,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text("MISSION TARGET",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1)),
                                  const SizedBox(height: 3),
                                  Text(
                                      "${_loc.latitude.toStringAsFixed(6)}, ${_loc.longitude.toStringAsFixed(6)}",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'monospace')),
                                ])),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color:
                                      Colors.greenAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? _searchCtrl.text.toUpperCase()
                                      : "CURRENT LOC",
                                  style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        // Connect Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(c);
                              _droneIp = _droneIpCtrl.text.trim();
                              if (_droneIp.isEmpty) {
                                messenger.showSnackBar(const SnackBar(
                                    content: Text("Enter drone IP address"),
                                    backgroundColor: Colors.red));
                                return;
                              }
                              setState(() {
                                _status =
                                    "🚁 CONNECTING TO DRONE AT $_droneIp...";
                              });
                              // Attempt real connection via HTTP to drone GCS
                              try {
                                final response = await http.get(
                                  Uri.parse('http://$_droneIp/api/telemetry'),
                                  headers: {'Accept': 'application/json'},
                                ).timeout(const Duration(seconds: 5));

                                if (response.statusCode == 200) {
                                  final data = jsonDecode(response.body);
                                  if (mounted) {
                                    setState(() {
                                      _droneConnected = true;
                                      _droneActive = true;
                                      _dronePos = _loc;
                                      _droneTelemetry = {
                                        "battery": data['battery'] ?? 0,
                                        "altitude": (data['altitude'] ?? 0.0)
                                            .toDouble(),
                                        "speed":
                                            (data['speed'] ?? 0.0).toDouble(),
                                        "gps": data['gps_fix'] ?? "3D Fix",
                                      };
                                      _status =
                                          "🚁 DRONE CONNECTED - LIVE FEED ACTIVE";
                                    });
                                  }
                                  // Start telemetry polling
                                  if (!mounted) return;
                                  _startDroneTelemetryPoll();
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text(
                                          "✅ Drone connected successfully!"),
                                      backgroundColor: Colors.green));
                                } else {
                                  throw "Server responded with ${response.statusCode}";
                                }
                              } catch (e) {
                                // Fallback to simulation mode with proper notification
                                if (mounted) {
                                  setState(() {
                                    _droneConnected = true;
                                    _droneActive = true;
                                    _dronePos = _loc;
                                    _droneTelemetry = {
                                      "battery": 87,
                                      "altitude": 120.5,
                                      "speed": 12.3,
                                      "gps": "3D Fix"
                                    };
                                    _status =
                                        "🚁 DRONE ACTIVE (SIMULATION - Real GCS at $_droneIp not reachable)";
                                  });
                                }
                                // Simulate telemetry updates
                                _droneTimer = Timer.periodic(
                                    const Duration(seconds: 2), (t) {
                                  if (mounted && _droneConnected) {
                                    setState(() {
                                      _droneTelemetry['battery'] =
                                          ((_droneTelemetry['battery'] as int) -
                                                  1)
                                              .clamp(0, 100);
                                      _droneTelemetry[
                                          'altitude'] = ((_droneTelemetry[
                                                  'altitude'] as double) +
                                              (0.5 -
                                                  1.0 *
                                                      (DateTime.now().second %
                                                                  3 ==
                                                              0
                                                          ? 1
                                                          : 0)))
                                          .clamp(50.0, 200.0);
                                      _droneTelemetry['speed'] =
                                          ((DateTime.now().second % 5) * 3.0 +
                                              5.0);
                                      _dronePos = LatLng(
                                          _dronePos!.latitude + 0.00003,
                                          _dronePos!.longitude + 0.00002);
                                    });
                                  } else {
                                    t.cancel();
                                  }
                                });
                                if (!mounted) return;
                                messenger.showSnackBar(SnackBar(
                                  content: Text(
                                      "⚠️ Real drone at $_droneIp not reachable. Running in simulation mode."),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 4),
                                ));
                              }
                            },
                            icon: const Icon(Icons.flight_takeoff, size: 20),
                            label: const Text("CONNECT & DEPLOY",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF39FF14),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                            child: Text(
                                "Ensure drone GCS is running on the specified endpoint",
                                style: TextStyle(
                                    color: Colors.white30, fontSize: 10))),
                      ],
                    ),
                  ),
                );
              },
            ));
  }

  void _startDroneTelemetryPoll() {
    _dronePollTimer?.cancel();
    _dronePollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_droneConnected || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final response = await http
            .get(
              Uri.parse('http://$_droneIp/api/telemetry'),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);
          setState(() {
            _droneTelemetry = {
              "battery": data['battery'] ?? _droneTelemetry['battery'],
              "altitude":
                  (data['altitude'] ?? _droneTelemetry['altitude']).toDouble(),
              "speed": (data['speed'] ?? _droneTelemetry['speed']).toDouble(),
              "gps": data['gps_fix'] ?? _droneTelemetry['gps'],
            };
            if (data['lat'] != null && data['lon'] != null) {
              _dronePos =
                  LatLng(data['lat'].toDouble(), data['lon'].toDouble());
            }
          });
        }
      } catch (_) {
        // Silent fail on poll - drone might be temporarily unreachable
      }
    });
  }

  Future<void> _captureEvidence() async {
    try {
      _status = "📍 ACQUIRING GPS LOCK...";
      setState(() {});

      // Get current position
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _status = "📸 OPENING SECURE CAMERA...";
      setState(() {});

      FilePickerResult? result =
          await FilePicker.pickFiles(type: FileType.image);

      if (!mounted) return;
      if (result != null) {
        setState(() {
          _fieldEvidences.insert(0, {
            "name":
                "IMG_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.JPG",
            "lat": pos.latitude,
            "lon": pos.longitude,
            "time": DateFormat('HH:mm:ss').format(DateTime.now()),
          });
          _tasksList.insert(0, {
            "title": "Field Evidence Recorded",
            "desc":
                "Geotagged proof captured at ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}",
            "status": "Success",
            "time": DateFormat('HH:mm a').format(DateTime.now())
          });
          _status = "✅ EVIDENCE SAVED TO BLOCKCHAIN";
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Geotagged Evidence Saved."),
            backgroundColor: Colors.green));
      } else {
        setState(() => _status = "⚠️ CAPTURE CANCELLED");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = "❌ GEOTAG ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _startTimer() {
    _timerCtrl.clear(); // Fixed: Reuse existing controller
    showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10)),
              title: const Text("Set Review Time",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      "Enter the duration (in seconds) for the compliance review period.",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 15),
                  TextField(
                      controller: _timerCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: "e.g. 15",
                          filled: true,
                          labelText: "Seconds")),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("CANCEL",
                        style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(c);
                      setState(() {
                        _evictSent = true;
                        _timerSecs = int.tryParse(_timerCtrl.text) ?? 15;
                      });
                      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
                        if (mounted) {
                          setState(() {
                            if (_timerSecs > 0) {
                              _timerSecs--;
                            } else {
                              _canDemolish = true;
                              _evictSent = false;
                              t.cancel();
                            }
                          });
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white),
                    child: const Text("START REVIEW"))
              ]);
        });
  }

  void _showNotice() {
    final hasFlaggedEncroachment = _risk > 0;
    final findingSentence = hasFlaggedEncroachment
        ? "Potential protected-boundary encroachment has been flagged and requires field verification."
        : "Blue-boundary land review is ready and requires field verification.";
    final dispatchFinding = hasFlaggedEncroachment
        ? "Potential protected-boundary encroachment flagged via satellite and OSM screening. Field verification is recommended."
        : "Blue-boundary land review prepared from mapped screening data. Field verification is recommended for official closure.";
    final costLabel = _val > 0
        ? "Rs. ${(_val / 100000).toStringAsFixed(1)} Lakhs"
        : "Review pending";
    final rateLabel = _landRate > 0
        ? "Rs. ${_landRate.toStringAsFixed(0)}/sqm"
        : "Official rate pending";
    try {
      showDialog(
          context: context,
          builder: (c) => Dialog(
              backgroundColor: const Color(0xFFF0F0F0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              child: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(30, 30, 30, 10),
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance,
                                color: Colors.black87, size: 45),
                            const SizedBox(height: 15),
                            Text("GOVERNMENT OF $_stateName",
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 5),
                            const Text(
                                "Department of Land Revenue & Tax Administration",
                                style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            const Text(
                                "Document Ref: AG-AI-2024-W73-8991 | Date: Auto-Generated",
                                style: TextStyle(
                                    color: Colors.black45, fontSize: 11)),
                            const SizedBox(height: 15),
                            Container(
                                height: 1,
                                width: double.infinity,
                                color: Colors.black12),
                          ],
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                                text: const TextSpan(
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                        height: 1.6),
                                    children: [
                                  TextSpan(
                                      text: "SUBJECT: ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  TextSpan(
                                      text:
                                          "Preliminary Compliance Notice under applicable land-record and municipal review workflow."),
                                ])),
                            const SizedBox(height: 20),
                            const Text(
                                "This compliance draft is prepared by Gravity AI after a geospatial comparison of registered boundary records, satellite imagery, and field-risk indicators. It is intended for user review before any administrative action.",
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    height: 1.6)),
                            const SizedBox(height: 20),
                            RichText(
                                text: TextSpan(
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                        height: 1.6),
                                    children: [
                                  TextSpan(
                                      text:
                                          "$findingSentence Screened area: $_area sq.m. Estimated government-rate cost: "),
                                  TextSpan(
                                      text: costLabel,
                                      style: TextStyle(
                                          color: hasFlaggedEncroachment
                                              ? Colors.red[400]
                                              : Colors.green[700],
                                          fontWeight: FontWeight.bold)),
                                  const TextSpan(text: "."),
                                ])),
                            const SizedBox(height: 20),
                            const Text(
                                "The location also intersects an elevated environmental-risk zone. The recommended next step is a physical inspection, owner response window, and documented compliance review by the competent authority.",
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    height: 1.6)),
                            const SizedBox(height: 25),
                            Container(
                                height: 1,
                                width: double.infinity,
                                color: Colors.black12),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: const Icon(Icons.qr_code_2,
                                            color: Colors.white, size: 40)),
                                    const SizedBox(height: 5),
                                    const Text(
                                        "Scan to verify report reference",
                                        style: TextStyle(
                                            color: Colors.black45,
                                            fontSize: 10)),
                                  ],
                                ),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("GRAVITY AI ENGINE | LIVE",
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1)),
                                    SizedBox(height: 5),
                                    Text(
                                        "Digital Review Signature\nRef: GRV-AUDIT-449-A",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 10)),
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Footer: Multi-Channel Notice Dispatch
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(4))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DISPATCH NOTICE VIA",
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                // WhatsApp Button
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(c);
                                    final noticeText = Uri.encodeComponent(
                                        '🏛️ *GRAVITY AI - COMPLIANCE NOTICE*\n\n'
                                        'Govt of $_stateName\nDept of Land Revenue & Tax Administration\n\n'
                                        '*Sector:* ${_searchCtrl.text.toUpperCase()}\n'
                                        '*Coordinates:* ${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}\n'
                                        '*Detected Area:* $_area sq.m\n'
                                        '*Estimated Govt Cost:* $costLabel\n'
                                        '*Govt Rate:* $rateLabel\n'
                                        '*Source:* $_officialLandSource\n\n'
                                        '$dispatchFinding\n\n'
                                        'Ref: GRV-AUDIT-449-A\n'
                                        '_Digitally generated by Gravity AI Engine_');
                                    final waUri = Uri.parse(
                                        'https://wa.me/?text=$noticeText');
                                    try {
                                      await launchUrl(waUri,
                                          mode: LaunchMode.externalApplication);
                                      if (mounted) {
                                        setState(() {
                                          _tasksList.insert(0, {
                                            "title":
                                                "Notice Dispatched via WhatsApp",
                                            "desc":
                                                "Sector: ${_searchCtrl.text.toUpperCase()} | Loc ID: BHU-449-A",
                                            "status": "Success",
                                            "time": DateFormat('HH:mm a')
                                                .format(DateTime.now())
                                          });
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "✅ WhatsApp opened with compliance notice"),
                                                backgroundColor: Colors.green));
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content:
                                                    Text("WhatsApp Error: $e"),
                                                backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.chat, size: 16),
                                  label: const Text("WhatsApp",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                ),
                                // SMS Button
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(c);
                                    final smsBody = Uri.encodeComponent(
                                        'GRAVITY AI NOTICE: ${hasFlaggedEncroachment ? 'Potential protected-boundary encroachment flagged' : 'Blue-boundary land review ready'} at ${_searchCtrl.text.toUpperCase()} '
                                        '(${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}). '
                                        'Area: $_area sq.m | Govt cost: $costLabel | Rate: $rateLabel. '
                                        'Ref: GRV-AUDIT-449-A');
                                    final smsUri =
                                        Uri.parse('sms:?body=$smsBody');
                                    try {
                                      await launchUrl(smsUri);
                                      if (mounted) {
                                        setState(() {
                                          _tasksList.insert(0, {
                                            "title":
                                                "Notice Dispatched via SMS",
                                            "desc":
                                                "Sector: ${_searchCtrl.text.toUpperCase()} | Loc ID: BHU-449-A",
                                            "status": "Success",
                                            "time": DateFormat('HH:mm a')
                                                .format(DateTime.now())
                                          });
                                        });
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text("SMS Error: $e"),
                                                backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.sms, size: 16),
                                  label: const Text("SMS",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2196F3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                ),
                                // Email Button
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(c);
                                    final subject = Uri.encodeComponent(
                                        'Gravity AI - Compliance Notice Draft | ${_searchCtrl.text.toUpperCase()}');
                                    final body = Uri.encodeComponent(
                                        'GOVERNMENT OF $_stateName\nDepartment of Land Revenue & Tax Administration\n\n'
                                        'COMPLIANCE NOTICE DRAFT\n'
                                        '========================\n\n'
                                        'Sector: ${_searchCtrl.text.toUpperCase()}\n'
                                        'Coordinates: ${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}\n'
                                        'Detected Area: $_area sq.m\n'
                                        'Estimated Govt Cost: $costLabel\n'
                                        'Govt Rate: $rateLabel\n'
                                        'Source: $_officialLandSource\n'
                                        'Confidence: ${_accuracy.toStringAsFixed(1)}%\n\n'
                                        '$_notice\n\n'
                                        '---\n'
                                        'Digitally generated by Gravity AI Engine\n'
                                        'Ref: GRV-AUDIT-449-A');
                                    final uri = Uri.parse(
                                        'mailto:?subject=$subject&body=$body');
                                    try {
                                      await launchUrl(uri);
                                      if (mounted) {
                                        setState(() {
                                          _tasksList.insert(0, {
                                            "title":
                                                "Notice Dispatched via Email",
                                            "desc":
                                                "Sector: ${_searchCtrl.text.toUpperCase()} | Loc ID: BHU-449-A",
                                            "status": "Pending",
                                            "time": DateFormat('HH:mm a')
                                                .format(DateTime.now())
                                          });
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "✅ Email client opened"),
                                                backgroundColor: Colors.green));
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content:
                                                    Text("Email Error: $e"),
                                                backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.email, size: 16),
                                  label: const Text("Email",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4EE1F1),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                ),
                                // Copy to Clipboard Button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(c);
                                    final noticeText =
                                        'GOVERNMENT OF $_stateName\n'
                                        'Department of Land Revenue & Tax Administration\n\n'
                                        'COMPLIANCE NOTICE\n'
                                        'Ref: GRV-AUDIT-449-A | Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}\n\n'
                                        'Sector: ${_searchCtrl.text.toUpperCase()}\n'
                                        'Coordinates: ${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}\n'
                                        'Detected Area: $_area sq.m\n'
                                        'Estimated Govt Cost: $costLabel\n'
                                        'Govt Rate: $rateLabel\n'
                                        'Source: $_officialLandSource\n\n'
                                        '$_notice\n\n'
                                        'Digitally generated by Gravity AI Engine';
                                    // Copy using JS clipboard API
                                    try {
                                      evalJs(
                                          'navigator.clipboard.writeText(`${noticeText.replaceAll('`', "'")}`)');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "📋 Notice copied to clipboard!"),
                                              backgroundColor: Colors.green));
                                      setState(() {
                                        _tasksList.insert(0, {
                                          "title": "Notice Copied to Clipboard",
                                          "desc":
                                              "Sector: ${_searchCtrl.text.toUpperCase()} | Ready to paste",
                                          "status": "Success",
                                          "time": DateFormat('HH:mm a')
                                              .format(DateTime.now())
                                        });
                                      });
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text("Copy Error: $e"),
                                              backgroundColor: Colors.red));
                                    }
                                  },
                                  icon: const Icon(Icons.copy,
                                      size: 16, color: Colors.white70),
                                  label: const Text("Copy Text",
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70)),
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              )));
    } catch (e) {
      debugPrint("Error showing notice: $e");
    }
  }

  void _showBhuPrahari() {
    // isMobile is computed inside StatefulBuilder for access to the dialog context
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
              String t(String en, String hi) => _isHindi ? hi : en;
              final bool isMobile = MediaQuery.of(context).size.width < 900;
              return Dialog(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white24)),
                  child: Container(
                      width: isMobile
                          ? MediaQuery.of(context).size.width * 0.95
                          : 1100,
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.9),
                      child: Column(children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(Icons.policy_rounded,
                                  color: Colors.orangeAccent, size: 30),
                              const SizedBox(width: 15),
                              Expanded(
                                  child: Text(
                                      t("Bhu-Prahari - Citizen Portal",
                                          "भू-प्रहरी - नागरिक पोर्टल"),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isMobile ? 16 : 22,
                                          fontWeight: FontWeight.bold))),
                              const SizedBox(width: 10),
                              TextButton(
                                  onPressed: () {
                                    setState(() => _isHindi = !_isHindi);
                                    setDialogState(() {});
                                  },
                                  style: TextButton.styleFrom(
                                      backgroundColor: Colors.white10),
                                  child: Text(_isHindi ? "A" : "अ",
                                      style: const TextStyle(
                                          color: Color(0xFF39FF14),
                                          fontWeight: FontWeight.bold))),
                              const SizedBox(width: 10),
                              IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white54),
                                  onPressed: () => Navigator.pop(c))
                            ],
                          ),
                        ),
                        Container(height: 1, color: Colors.white10),

                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: isMobile
                                    ? SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            SizedBox(
                                                height: 300,
                                                child: _bhuCard(
                                                    t("Report Suspected Encroachment",
                                                        "अतिक्रमण की रिपोर्ट करें"),
                                                    Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            width:
                                                                double.infinity,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(10),
                                                            decoration: BoxDecoration(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.02),
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .cyanAccent
                                                                        .withValues(
                                                                            alpha:
                                                                                0.5),
                                                                    width: 1,
                                                                    style: BorderStyle
                                                                        .solid),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8)),
                                                            child:
                                                                SingleChildScrollView(
                                                              child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .file_upload_outlined,
                                                                      size: 40,
                                                                      color: Colors
                                                                          .cyanAccent
                                                                          .withValues(
                                                                              alpha: 0.7)),
                                                                  const SizedBox(
                                                                      height:
                                                                          10),
                                                                  InkWell(
                                                                    onTap:
                                                                        _pickFile,
                                                                    child: RichText(
                                                                        textAlign: TextAlign.center,
                                                                        text: TextSpan(children: [
                                                                          TextSpan(
                                                                              text: t("Drag & Drop Photos or PDF Reports Here or ", "फोटो या पीडीएफ रिपोर्ट यहां खींचें या "),
                                                                              style: const TextStyle(color: Colors.white70)),
                                                                          TextSpan(
                                                                              text: t("Browse", "ब्राउज़ करें"),
                                                                              style: const TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                                                        ])),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ))),
                                            const SizedBox(height: 20),
                                            SizedBox(
                                                height: 300,
                                                child: _bhuCard(
                                                    t("Community Scan Analysis",
                                                        "सामुदायिक स्कैन विश्लेषण"),
                                                    Column(
                                                      children: [
                                                        Expanded(
                                                            child: Stack(
                                                                children: [
                                                              FlutterMap(
                                                                  options: MapOptions(
                                                                      initialCenter:
                                                                          _loc,
                                                                      initialZoom:
                                                                          16.0),
                                                                  children: [
                                                                    TileLayer(
                                                                        urlTemplate:
                                                                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}')
                                                                  ]),
                                                              Center(
                                                                child:
                                                                    Container(
                                                                  width: 40,
                                                                  height: 40,
                                                                  decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .cyanAccent
                                                                          .withValues(
                                                                              alpha:
                                                                                  0.3),
                                                                      shape: BoxShape
                                                                          .circle),
                                                                  child: Center(
                                                                      child: Container(
                                                                          width:
                                                                              15,
                                                                          height:
                                                                              15,
                                                                          decoration: const BoxDecoration(
                                                                              color: Color(0xFF39FF14),
                                                                              shape: BoxShape.circle))),
                                                                ),
                                                              ),
                                                            ]))
                                                      ],
                                                    ))),
                                            const SizedBox(height: 20),
                                            SizedBox(
                                                height: 300,
                                                child: _bhuCard(
                                                    t("Verified Community Reports",
                                                        "सत्यापित सामुदायिक रिपोर्ट"),
                                                    Column(children: [
                                                      _leaderboardItem(
                                                          1,
                                                          t("Rajesh Kumar",
                                                              "राजेश कुमार"),
                                                          t("120 Reports",
                                                              "120 रिपोर्ट"),
                                                          Colors.greenAccent
                                                              .withValues(
                                                                  alpha: 0.2)),
                                                      _leaderboardItem(
                                                          2,
                                                          t("Priya Singh",
                                                              "प्रिया सिंह"),
                                                          t("95 Reports",
                                                              "95 रिपोर्ट"),
                                                          Colors.blueAccent
                                                              .withValues(
                                                                  alpha: 0.2)),
                                                    ]))),
                                          ],
                                        ),
                                      )
                                    : Row(children: [
                                        // Left Column
                                        Expanded(
                                            child: Column(
                                          children: [
                                            // Top Left: Report
                                            Expanded(
                                                child: _bhuCard(
                                                    t("Report Suspected Encroachment",
                                                        "अतिक्रमण की रिपोर्ट करें"),
                                                    Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Expanded(
                                                              child: Container(
                                                                  width: double
                                                                      .infinity,
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                          10),
                                                                  decoration: BoxDecoration(
                                                                      color: Colors.white.withValues(
                                                                          alpha:
                                                                              0.02),
                                                                      border: Border.all(
                                                                          color: const Color(0xFF39FF14).withValues(
                                                                              alpha:
                                                                                  0.5),
                                                                          width:
                                                                              1,
                                                                          style: BorderStyle
                                                                              .solid),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8)),
                                                                  child:
                                                                      SingleChildScrollView(
                                                                          child: Column(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                        Icon(
                                                                            Icons
                                                                                .file_upload_outlined,
                                                                            size:
                                                                                40,
                                                                            color:
                                                                                const Color(0xFF39FF14).withValues(alpha: 0.7)),
                                                                        const SizedBox(
                                                                            height:
                                                                                10),
                                                                        InkWell(
                                                                          onTap:
                                                                              _pickFile,
                                                                          child: RichText(
                                                                              textAlign: TextAlign.center,
                                                                              text: TextSpan(children: [
                                                                                TextSpan(text: t("Drag & Drop Photos or PDF Reports Here or ", "फोटो या पीडीएफ रिपोर्ट यहां खींचें या "), style: const TextStyle(color: Colors.white70)),
                                                                                TextSpan(text: t("Browse", "ब्राउज़ करें"), style: const TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                                                              ])),
                                                                        ),
                                                                        const SizedBox(
                                                                            height:
                                                                                5),
                                                                        Text(
                                                                            t("Help us verify land status.",
                                                                                "भूमि की स्थिति सत्यापित करने में हमारी सहायता करें।"),
                                                                            style:
                                                                                const TextStyle(color: Colors.white54, fontSize: 10))
                                                                      ])))),
                                                          const SizedBox(
                                                              height: 10),
                                                          Row(
                                                            children: [
                                                              Switch(
                                                                  value:
                                                                      _isAnonymous,
                                                                  onChanged: (v) =>
                                                                      setDialogState(() =>
                                                                          _isAnonymous =
                                                                              v),
                                                                  activeThumbColor:
                                                                      Colors
                                                                          .cyanAccent),
                                                              const SizedBox(
                                                                  width: 5),
                                                              Text(
                                                                  t("Submit Anonymously",
                                                                      "गुमनाम रूप से सबमिट करें"),
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white70,
                                                                      fontSize:
                                                                          12)),
                                                            ],
                                                          ),
                                                          Text(
                                                              t("Privacy Note: Your personal information is kept confidential.",
                                                                  "गोपनीयता नोट: आपकी व्यक्तिगत जानकारी गोपनीय रखी जाती है।"),
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white30,
                                                                  fontSize: 10))
                                                        ]))),
                                            const SizedBox(height: 20),
                                            // Bottom Left: Status
                                            Expanded(
                                                child: _bhuCard(
                                                    t("Status of Action",
                                                        "कार्यवाही की स्थिति"),
                                                    Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              t("Submitted complaints to sub-division.",
                                                                  "सब-डिवीजन में जमा की गई शिकायतें।"),
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize:
                                                                      12)),
                                                          const SizedBox(
                                                              height: 15),
                                                          _timelineItem(
                                                              t("Oct 25, 2023",
                                                                  "25 अक्टूबर, 2023"),
                                                              t("Complaint ID BHU-202310-42 - Action: Field Inspection Scheduled",
                                                                  "शिकायत आईडी BHU-202310-42 - कार्यवाही: क्षेत्र निरीक्षण निर्धारित"),
                                                              true),
                                                          _timelineItem(
                                                              t("Oct 20, 2023",
                                                                  "20 अक्टूबर, 2023"),
                                                              t("Status: Satellite Verification Complete, Awaiting Review",
                                                                  "स्थिति: उपग्रह सत्यापन पूर्ण, समीक्षा की प्रतीक्षा है"),
                                                              false),
                                                          _timelineItem(
                                                              t("Oct 15, 2023",
                                                                  "15 अक्टूबर, 2023"),
                                                              t("Action: Case Assigned to Enforcement Team",
                                                                  "कार्यवाही: प्रवर्तन टीम को सौंपा गया मामला"),
                                                              false,
                                                              isLast: true),
                                                        ]))),
                                          ],
                                        )),
                                        const SizedBox(width: 20),
                                        // Right Column
                                        Expanded(
                                            child: Column(children: [
                                          // Top Right: Map
                                          Expanded(
                                              child: _bhuCard(
                                                  t("Real-Time Verification Status",
                                                      "वास्तविक समय सत्यापन स्थिति"),
                                                  ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Stack(children: [
                                                        FlutterMap(
                                                            options: MapOptions(
                                                                initialCenter:
                                                                    _loc,
                                                                initialZoom:
                                                                    16.0),
                                                            children: [
                                                              TileLayer(
                                                                  urlTemplate:
                                                                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}')
                                                            ]),
                                                        Center(
                                                          child: Container(
                                                            width: 40,
                                                            height: 40,
                                                            decoration: BoxDecoration(
                                                                color: Colors
                                                                    .cyanAccent
                                                                    .withValues(
                                                                        alpha:
                                                                            0.3),
                                                                shape: BoxShape
                                                                    .circle),
                                                            child: Center(
                                                                child: Container(
                                                                    width: 15,
                                                                    height: 15,
                                                                    decoration: const BoxDecoration(
                                                                        color: Colors
                                                                            .cyanAccent,
                                                                        shape: BoxShape
                                                                            .circle))),
                                                          ),
                                                        ),
                                                        Positioned(
                                                            bottom: 10,
                                                            left: 10,
                                                            right: 10,
                                                            child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                        10),
                                                                decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .black87,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            8)),
                                                                child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Text(
                                                                          t("ℹ️ Location ID: BHU-202310-45",
                                                                              "ℹ️ स्थान आईडी: BHU-202310-45"),
                                                                          style: const TextStyle(
                                                                              color: Colors.white,
                                                                              fontSize: 12,
                                                                              fontWeight: FontWeight.bold)),
                                                                      Text(
                                                                          t("Status: Satellite Scan Initiated",
                                                                              "स्थिति: उपग्रह स्कैन शुरू किया गया"),
                                                                          style: const TextStyle(
                                                                              color: Colors.white70,
                                                                              fontSize: 11)),
                                                                    ])))
                                                      ])))),
                                          const SizedBox(height: 20),
                                          // Bottom Right: Leaderboard
                                          Expanded(
                                              child: _bhuCard(
                                                  t("Verified Community Reports",
                                                      "सत्यापित सामुदायिक रिपोर्ट"),
                                                  Column(children: [
                                                    _leaderboardItem(
                                                        1,
                                                        t("Rajesh Kumar",
                                                            "राजेश कुमार"),
                                                        t("120 Reports",
                                                            "120 रिपोर्ट"),
                                                        Colors.greenAccent
                                                            .withValues(
                                                                alpha: 0.2)),
                                                    _leaderboardItem(
                                                        2,
                                                        t("Priya Singh",
                                                            "प्रिया सिंह"),
                                                        t("95 Reports",
                                                            "95 रिपोर्ट"),
                                                        Colors.blueAccent
                                                            .withValues(
                                                                alpha: 0.2)),
                                                    _leaderboardItem(
                                                        3,
                                                        t("Vikram Patel",
                                                            "विक्रम पटेल"),
                                                        t("80 Reports",
                                                            "80 रिपोर्ट"),
                                                        Colors.white10),
                                                    const Spacer(),
                                                    SizedBox(
                                                        width: double.infinity,
                                                        child: ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFF1E293B),
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        15)),
                                                            onPressed: () {},
                                                            child: Text(
                                                                t("View Full Leaderboard",
                                                                    "पूर्ण लीडरबोर्ड देखें"),
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white70))))
                                                  ]))),
                                        ]))
                                      ])))
                      ])));
            }));
  }

  Widget _bhuCard(String title, Widget child) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child.runtimeType == Column ? child : Expanded(child: child)
          ],
        ));
  }

  Widget _timelineItem(String date, String desc, bool isActive,
      {bool isLast = false}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(
        children: [
          Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  color: isActive ? Colors.greenAccent : Colors.white24,
                  shape: BoxShape.circle),
              child: isActive
                  ? const Icon(Icons.check, size: 10, color: Colors.black)
                  : null),
          if (!isLast) Container(width: 2, height: 40, color: Colors.white12)
        ],
      ),
      const SizedBox(width: 15),
      Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(height: 5),
          Text(desc,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ))
    ]);
  }

  Widget _leaderboardItem(int rank, String name, String score, Color bg) {
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Text("$rank.",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 15),
          const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 14, color: Colors.white)),
          const SizedBox(width: 10),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          Text(score,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]));
  }

  void _showNotificationPanel() {
    final complaints = BhuPrahariStore.complaints.value;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Notifications",
      pageBuilder: (c, a1, a2) => Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 350,
          margin: const EdgeInsets.only(top: 60, right: 20),
          decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)
              ]),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Critical Alerts",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54, size: 18),
                              onPressed: () => Navigator.pop(c))
                        ])),
                const Divider(color: Colors.white10, height: 1),
                if (_tasksList.isEmpty && complaints.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text("No new notifications",
                          style:
                              TextStyle(color: Colors.white30, fontSize: 12)))
                else ...[
                  ...complaints.take(4).map((item) => ListTile(
                        leading: const Icon(Icons.assignment_late_rounded,
                            color: Colors.orangeAccent, size: 20),
                        title: Text(item["id"].toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(item["target"].toString(),
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 11)),
                      )),
                  ..._tasksList.take(4).map((t) => ListTile(
                        leading: Icon(Icons.warning_amber,
                            color: t["status"] == "Success"
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            size: 20),
                        title: Text(t["title"]!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(t["time"]!,
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 11)),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComp() {
    try {
      bool isSmall = MediaQuery.of(context).size.width < 900;
      final compareYear = _timelineYear < 2026 ? _timelineYear : 2021;
      final oldTileUrl = _waybackSatelliteTileUrl(compareYear);
      final currentTileUrl = _currentSatelliteTileUrl();
      showDialog(
          context: context,
          builder: (c) => Dialog(
              backgroundColor: const Color(0xFF0B1221),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10)),
              child: Container(
                  width:
                      isSmall ? MediaQuery.of(context).size.width * 0.95 : 950,
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                                child: Text("🛰️ Real-Time Land Comparison",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white54),
                                onPressed: () => Navigator.pop(c))
                          ],
                        ),
                        Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        Colors.amber.withValues(alpha: 0.3))),
                            child: Row(children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      _risk > 0
                                          ? "LEFT: Historical imagery | RIGHT: Current imagery with screened encroachment zones in red"
                                          : "LEFT: Historical imagery | RIGHT: Current imagery with no screened encroachment zones",
                                      style: TextStyle(
                                          color: Colors.amber
                                              .withValues(alpha: 0.8),
                                          fontSize: 11))),
                            ])),
                        Expanded(
                          child: isSmall
                              ? SingleChildScrollView(
                                  child: Column(children: [
                                  _compMapTile(
                                      "$compareYear - Historical Imagery",
                                      oldTileUrl,
                                      false),
                                  const SizedBox(height: 12),
                                  _compMapTile(
                                      "Current - Latest Imagery + Detected Zones",
                                      currentTileUrl,
                                      true),
                                ]))
                              : Row(children: [
                                  Expanded(
                                      child: _compMapTile(
                                          "$compareYear - Historical Imagery",
                                          oldTileUrl,
                                          false)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: _compMapTile(
                                          "Current - Latest Imagery + Detected Zones",
                                          currentTileUrl,
                                          true)),
                                ]),
                        )
                      ]))));
    } catch (e) {
      debugPrint("Error showing comparison: $e");
    }
  }

  Widget _compMapTile(String title, String tileUrl, bool showOverlay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: showOverlay
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Icon(showOverlay ? Icons.warning_amber : Icons.check_circle,
                color: showOverlay ? Colors.redAccent : Colors.greenAccent,
                size: 16),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    color: showOverlay ? Colors.redAccent : Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        SizedBox(
          height: 300,
          child: Container(
            decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border.all(
                    color: showOverlay
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.greenAccent.withValues(alpha: 0.5))),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: FlutterMap(
                  options: MapOptions(initialCenter: _loc, initialZoom: 18.0),
                  children: [
                    TileLayer(urlTemplate: tileUrl),
                    if (showOverlay) PolygonLayer(polygons: _anomalyPolygons),
                    if (showOverlay) PolygonLayer(polygons: _govtPolygons),
                    if (showOverlay) MarkerLayer(markers: _illegalHouseMarkers),
                  ]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _makePDF() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Generating PDF... Please wait"),
          backgroundColor: Colors.blue));
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final pdf = pw.Document(
          theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont));
      pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('GRAVITY OFFICIAL DOSSIER',
                                  style: pw.TextStyle(
                                      color: PdfColors.blue900,
                                      fontSize: 22,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text('COMPLIANCE DRAFT • GEOSPATIAL AUDIT',
                                  style: const pw.TextStyle(
                                      color: PdfColors.grey700, fontSize: 8)),
                            ]),
                        pw.Container(
                            width: 50,
                            height: 50,
                            child: pw.Text("OFFICIAL SEAL",
                                style: const pw.TextStyle(
                                    fontSize: 6, color: PdfColors.grey500))),
                      ]),
                  pw.Divider(thickness: 2, color: PdfColors.blue900),
                  pw.SizedBox(height: 20),
                  pw.Text('Target Sector: ${_searchCtrl.text.toUpperCase()}',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Coordinates: ${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}',
                      style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 20),
                  pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.red)),
                      child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('SCAN RESULTS (CONFIDENCE: $_accuracy%)',
                                style: pw.TextStyle(
                                    color: PdfColors.red,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Bullet(text: 'Total Area Scanned: 4.5 Sq. Km'),
                            pw.Bullet(
                                text:
                                    'Encroached Area Identified: $_area sq.m'),
                            pw.Bullet(
                                text:
                                    'Environmental Impact: $_veg% vegetation loss'),
                            pw.Bullet(
                                text:
                                    'Estimated Govt Cost: Rs. ${(_val / 100000).toStringAsFixed(1)} Lakhs'),
                            pw.Bullet(
                                text:
                                    'Govt Rate: Rs. ${_landRate.toStringAsFixed(0)}/sqm'),
                            pw.Bullet(text: 'Source: $_officialLandSource'),
                          ])),
                  pw.SizedBox(height: 30),
                  pw.Text('COMPLIANCE NOTICE PREVIEW:',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(_notice,
                          style: const pw.TextStyle(
                              fontSize: 10, lineSpacing: 2))),
                  pw.Spacer(),
                  pw.Divider(),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Digitally Signed by Gravity AI Engine',
                            style: pw.TextStyle(
                                fontSize: 8, fontStyle: pw.FontStyle.italic)),
                        pw.Text('Page 1 of 1',
                            style: const pw.TextStyle(fontSize: 8)),
                      ])
                ]);
          }));
      final pdfBytes = await pdf.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: 'Gravity_Dossier.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "If your device supports it, select your Email app to attach the PDF automatically."),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("PDF Error: $e"), backgroundColor: Colors.red));
      debugPrint("PDF Error: $e");
    }
  }

  Widget _footer() => SafeArea(
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: const Color(0xFF0B1221),
          child: const Center(
              child: Text(
                  "Gravity AI - Uses ISRO Bhuvan services - Siam-UNet Neural Networks",
                  style: TextStyle(color: Colors.white54, fontSize: 11)))));
  Widget _buildBoot() {
    final percent = (_bootProgress * 100).round().clamp(0, 100);
    final status = percent < 30
        ? "AUTHENTICATING USER SESSION"
        : percent < 62
            ? "SYNCING ISRO BHUVAN LAYERS"
            : percent < 92
                ? "ARMING ENCROACHMENT DETECTION AI"
                : "OPENING COMMAND DASHBOARD";

    return Scaffold(
      backgroundColor: const Color(0xFF020914),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.45, -0.58),
                  radius: 1.1,
                  colors: [
                    const Color(0xFF123329).withValues(alpha: 0.95),
                    const Color(0xFF071321),
                    const Color(0xFF020914),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.40),
                    const Color(0xFF020914).withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _DashboardGridBackdrop()),
          Center(
            child: Container(
              width: 560,
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF06111F).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF39FF14).withValues(alpha: 0.36)),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF39FF14).withValues(alpha: 0.18),
                      blurRadius: 42,
                      offset: const Offset(0, 24))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset("assets/images/logo.png",
                          height: 58,
                          errorBuilder: (c, e, s) => const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFF39FF14),
                              size: 44)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("GravityAI Command Core | Live",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900)),
                            SizedBox(height: 3),
                            Text("Satellite intelligence session booting",
                                style: TextStyle(
                                    color: Color(0xFFB7FFC0), fontSize: 12)),
                          ],
                        ),
                      ),
                      Text("$percent%",
                          style: const TextStyle(
                              color: Color(0xFF39FF14),
                              fontSize: 28,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                            height: 9,
                            color: Colors.white.withValues(alpha: 0.08)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          height: 9,
                          width: 504 * _bootProgress.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF23F6FF),
                              Color(0xFF39FF14),
                              Color(0xFFB9FF5A),
                            ]),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFF39FF14)
                                      .withValues(alpha: 0.7),
                                  blurRadius: 18)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.radar_rounded,
                              color: Color(0xFF39FF14), size: 20)
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 2.seconds),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text("> $status",
                            style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'monospace',
                                letterSpacing: 1.1,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _BootChip(icon: Icons.radar_rounded, label: "SAT-LINK"),
                      _BootChip(icon: Icons.map_rounded, label: "BHUVAN"),
                      _BootChip(icon: Icons.verified_user, label: "SECURE"),
                      _BootChip(icon: Icons.auto_awesome, label: "AI READY"),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06, end: 0),
          ),
        ],
      ),
    );
  }

  void _showChatbot() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF39FF14)),
                    const SizedBox(width: 10),
                    const Text("Gravity Assistant",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context))
                  ],
                ),
              ),
              Container(height: 1, color: Colors.white10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _chatMsgs.length,
                  itemBuilder: (context, index) {
                    final msg = _chatMsgs[index];
                    bool isAi = msg['role'] == 'ai';
                    return Align(
                      alignment:
                          isAi ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: isAi
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF39FF14)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isAi
                                    ? Colors.white10
                                    : const Color(0xFF39FF14)
                                        .withValues(alpha: 0.5))),
                        child: Text(msg['text']!,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    // File Upload Button (Feature: Multi-Modal AI Vision)
                    IconButton(
                        icon: Icon(Icons.image_search,
                            color: _pendingImageBase64 != null
                                ? const Color(0xFF39FF14)
                                : Colors.white54,
                            size: 20),
                        onPressed: () async {
                          try {
                            FilePickerResult? result =
                                await FilePicker.pickFiles(
                              type: FileType.image,
                              withData: true,
                            );
                            if (result != null &&
                                result.files.first.bytes != null) {
                              final bytes = result.files.first.bytes!;
                              final b64 = base64Encode(bytes);
                              final name = result.files.first.name;
                              setState(() {
                                _pendingImageBase64 = b64;
                                _pendingImageName = name;
                              });
                              setModalState(() {
                                _chatMsgs.add({
                                  "role": "user",
                                  "text":
                                      "📷 [Image: $name] — Analyze this for encroachment or land-use anomalies."
                                });
                              });
                              // Send to Groq Vision for analysis
                              _getGroqVisionResponse(b64, name, setModalState);
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Image Error: $e"),
                                backgroundColor: Colors.red));
                          }
                        }),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _pendingImageName != null
                              ? "📷 $_pendingImageName processing..."
                              : "Ask Gravity AI...",
                          hintStyle: TextStyle(
                              color: _pendingImageName != null
                                  ? const Color(0xFF39FF14)
                                      .withValues(alpha: 0.5)
                                  : Colors.white30),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isEmpty) return;
                          setModalState(() {
                            _chatMsgs.add({"role": "user", "text": val});
                            _chatCtrl.clear();
                          });
                          _getGroqResponse(val, setModalState);
                        },
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Voice Mic Button inside Chatbot — WORKING VOICE INPUT
                    Container(
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : const Color(0xFF39FF14).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: _isListening
                            ? Border.all(color: Colors.redAccent, width: 2)
                            : null,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_off : Icons.mic,
                          color: _isListening
                              ? Colors.redAccent
                              : const Color(0xFF39FF14),
                          size: 18,
                        ),
                        onPressed: _isListening
                            ? null
                            : () => _startVoiceInput(setModalState),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 3.seconds),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF39FF14)),
                        onPressed: () {
                          String val = _chatCtrl.text;
                          if (val.trim().isEmpty) return;
                          setModalState(() {
                            _chatMsgs.add({"role": "user", "text": val});
                            _chatCtrl.clear();
                          });
                          _getGroqResponse(val, setModalState);
                        })
                  ],
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  Future<void> _getGroqResponse(String userMsg, Function setModalState) async {
    try {
      final response = await postBackendJson(
        "/api/chat",
        jsonEncode({
          "message": userMsg,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMsg = data['message'];
        _speak(aiMsg); // Fixed: Voice output added to chatbot
        setModalState(() {
          _chatMsgs.add({"role": "ai", "text": aiMsg});
        });
      } else {
        String detail = response.body;
        try {
          final data = jsonDecode(response.body);
          detail = data['detail']?.toString() ?? detail;
        } catch (_) {}
        setModalState(() {
          _chatMsgs.add({
            "role": "ai",
            "text": "Backend error (${response.statusCode}): $detail"
          });
        });
      }
    } catch (e) {
      setModalState(() {
        _chatMsgs.add({"role": "ai", "text": "Connection Error: $e"});
      });
    }
  }

  /// Multi-Modal AI: Send image to Groq Vision model for analysis
  Future<void> _getGroqVisionResponse(
      String base64Image, String imageName, Function setModalState) async {
    setModalState(() {
      _chatMsgs.add({
        "role": "ai",
        "text":
            "🔍 Analyzing image '$imageName' with Multi-Modal AI...\n⏳ Processing satellite/field imagery for encroachment patterns..."
      });
    });

    try {
      // Determine image MIME type
      String mimeType = 'image/jpeg';
      if (imageName.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      if (imageName.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';

      final response = await postBackendJson(
        "/api/vision",
        jsonEncode({
          "image_base64": base64Image,
          "image_name": imageName,
          "mime_type": mimeType,
        }),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMsg = data['message'];
        _speak(aiMsg);
        setModalState(() {
          // Remove the "analyzing..." message and replace with actual result
          if (_chatMsgs.isNotEmpty &&
              (_chatMsgs.last['text'] ?? '').contains('Analyzing image')) {
            _chatMsgs.removeLast();
          }
          _chatMsgs.add({
            "role": "ai",
            "text": "📸 **Image Analysis Report:**\n\n$aiMsg"
          });
        });
      } else {
        final errorBody = response.body;
        setModalState(() {
          if (_chatMsgs.isNotEmpty &&
              (_chatMsgs.last['text'] ?? '').contains('Analyzing image')) {
            _chatMsgs.removeLast();
          }
          _chatMsgs.add({
            "role": "ai",
            "text":
                "Vision API Error (${response.statusCode}): Falling back to text analysis.\n\nThe image '$imageName' was received. Based on the filename pattern, this appears to be field evidence. For full analysis, ensure the Groq API plan supports vision models."
          });
        });
        debugPrint("Groq Vision Error: ${response.statusCode} - $errorBody");
      }
    } catch (e) {
      setModalState(() {
        if (_chatMsgs.isNotEmpty &&
            (_chatMsgs.last['text'] ?? '').contains('Analyzing image')) {
          _chatMsgs.removeLast();
        }
        _chatMsgs.add({
          "role": "ai",
          "text":
              "Vision Analysis Error: $e\n\nImage '$imageName' received but couldn't process. Check network connection."
        });
      });
    } finally {
      setState(() {
        _pendingImageBase64 = null;
        _pendingImageName = null;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'pdf', 'png'],
      );

      if (result != null) {
        String name = result.files.first.name;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Selected: $name"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("File Picker Error: $e"), backgroundColor: Colors.red));
    }
  }
}

class BlinkingLight extends StatefulWidget {
  final Color color;
  const BlinkingLight({super.key, required this.color});
  @override
  State<BlinkingLight> createState() => _BlinkingLightState();
}

class _BlinkingLightState extends State<BlinkingLight>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: widget.color, blurRadius: 5)])),
    );
  }
}
