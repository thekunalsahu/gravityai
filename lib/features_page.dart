import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _featureAccent = Color(0xFF39FF14);
const Color _featureCyan = Color(0xFF23F6FF);
const Color _featureBackground = Color(0xFF020914);

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  static const List<_FeatureItem> _features = [
    _FeatureItem(
      icon: Icons.satellite_alt_rounded,
      title: 'Satellite Monitoring',
      description:
          'High-resolution satellite imagery from ISRO BHUVAN for accurate land monitoring.',
    ),
    _FeatureItem(
      icon: Icons.memory_rounded,
      title: 'AI Analysis',
      description:
          'Advanced machine learning models detect unauthorized activity with high precision.',
    ),
    _FeatureItem(
      icon: Icons.warning_amber_rounded,
      title: 'Encroachment Detection',
      description:
          'Instantly identify suspicious changes and encroachments in land use.',
    ),
    _FeatureItem(
      icon: Icons.notifications_none_rounded,
      title: 'Real-time Alerts',
      description:
          'Get instant notifications and alerts for new encroachments.',
    ),
    _FeatureItem(
      icon: Icons.description_rounded,
      title: 'Detailed Reports',
      description:
          'Generate comprehensive reports with maps, evidence and insights.',
    ),
    _FeatureItem(
      icon: Icons.dashboard_customize_rounded,
      title: 'Analytics Dashboard',
      description:
          'Visualize data with interactive dashboards and real-time insights.',
    ),
    _FeatureItem(
      icon: Icons.shield_rounded,
      title: 'Secure & Reliable',
      description:
          'Enterprise-grade security to protect your data and ensure privacy.',
    ),
    _FeatureItem(
      icon: Icons.cloud_download_rounded,
      title: 'Data Archive',
      description:
          'Store and access historical data and reports whenever needed.',
    ),
    _FeatureItem(
      icon: Icons.groups_rounded,
      title: 'Multi-user Access',
      description:
          'Role-based access for teams, departments and organizations.',
    ),
    _FeatureItem(
      icon: Icons.phone_android_rounded,
      title: 'Mobile Friendly',
      description:
          'Access reports, alerts and dashboard from any device, anywhere.',
    ),
    _FeatureItem(
      icon: Icons.settings_suggest_rounded,
      title: 'Easy Integration',
      description: 'Seamlessly integrate with existing systems and workflows.',
    ),
  ];

  static const List<_AudienceItem> _audiences = [
    _AudienceItem(Icons.location_city_rounded, 'Municipal\nCorporation'),
    _AudienceItem(Icons.account_balance_rounded, 'Revenue\nDepartment'),
    _AudienceItem(Icons.hub_rounded, 'Smart City\nProgram'),
    _AudienceItem(Icons.domain_rounded, 'Urban\nDevelopment'),
    _AudienceItem(Icons.forest_rounded, 'Forest\nDepartment'),
    _AudienceItem(Icons.engineering_rounded, 'Public Works\nDepartment'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _featureBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _FeatureBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final contentWidth = math.min(width, 1536.0);
                final isMobile = contentWidth < 700;
                final isTablet = contentWidth >= 700 && contentWidth < 1080;
                final horizontalPadding = isMobile
                    ? 20.0
                    : isTablet
                        ? 38.0
                        : 54.0;
                final maxContentWidth =
                    math.min(contentWidth - (horizontalPadding * 2), 1424.0);
                final useIntroRow = !isMobile && maxContentWidth >= 1050;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    isMobile ? 12 : 24,
                    horizontalPadding,
                    isMobile ? 28 : 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 1424, minWidth: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FeatureTopBar(isMobile: isMobile),
                          SizedBox(height: isMobile ? 20 : 12),
                          _FeatureIntro(
                            isMobile: isMobile,
                            useRow: useIntroRow,
                          ),
                          SizedBox(height: isMobile ? 22 : 68),
                          _FeatureGrid(
                            availableWidth: maxContentWidth,
                            isMobile: isMobile,
                          ),
                          SizedBox(height: isMobile ? 16 : 18),
                          _AudienceRail(
                            audiences: _audiences,
                            isMobile: isMobile,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIntro extends StatelessWidget {
  final bool isMobile;
  final bool useRow;

  const _FeatureIntro({
    required this.isMobile,
    required this.useRow,
  });

  @override
  Widget build(BuildContext context) {
    if (!useRow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeatureHero(isMobile: isMobile),
          SizedBox(height: isMobile ? 26 : 34),
          _FeatureMetrics(isMobile: isMobile),
        ],
      );
    }

    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _FeatureHero(isMobile: false)),
        SizedBox(width: 40),
        SizedBox(
          width: 600,
          child: _FeatureMetrics(isMobile: false),
        ),
      ],
    );
  }
}

class _FeatureTopBar extends StatelessWidget {
  final bool isMobile;

  const _FeatureTopBar({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Back',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: isMobile ? 40 : 44,
              height: isMobile ? 40 : 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'FEATURES',
          style: TextStyle(
            color: _featureAccent,
            fontSize: isMobile ? 13 : 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _FeatureHero extends StatelessWidget {
  final bool isMobile;

  const _FeatureHero({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 40 : 56,
                height: 1.07,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
              children: const [
                TextSpan(text: 'Powerful Features.\nSmarter '),
                TextSpan(
                  text: 'Protection.',
                  style: TextStyle(color: _featureAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'GravityAI combines advanced AI, satellite technology & real-time analytics to deliver unmatched accuracy and fast encroachment detection.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: isMobile ? 15 : 17,
              height: 1.48,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureMetrics extends StatelessWidget {
  final bool isMobile;

  const _FeatureMetrics({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _MetricCard(
        icon: Icons.speed_rounded,
        title: 'Real-time Alerts',
        value: 'Live',
        detail: 'Active scan alerts\nand field updates.',
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          children: [
            Expanded(child: cards[0]),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _NeonIconFrame(icon: icon, size: 66, iconSize: 34),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: _featureAccent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  final double availableWidth;
  final bool isMobile;

  const _FeatureGrid({
    required this.availableWidth,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final columns = availableWidth >= 1240
        ? 4
        : availableWidth >= 920
            ? 3
            : availableWidth >= 620
                ? 2
                : 1;
    final spacing = isMobile ? 12.0 : 16.0;
    final cardHeight = columns == 1 ? 160.0 : 168.0;

    return GridView.builder(
      itemCount: FeaturesPage._features.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: cardHeight,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemBuilder: (context, index) {
        final feature = FeaturesPage._features[index];
        return _FeatureCard(
          feature: feature,
          compact: columns == 1,
        )
            .animate(delay: Duration(milliseconds: 35 * index))
            .fadeIn(duration: 420.ms, curve: Curves.easeOut)
            .slideY(begin: 0.05, end: 0, duration: 420.ms);
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem feature;
  final bool compact;

  const _FeatureCard({required this.feature, required this.compact});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NeonIconFrame(
              icon: feature.icon,
              size: compact ? 60 : 82,
              iconSize: compact ? 30 : 42,
            ),
            SizedBox(width: compact ? 14 : 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    feature.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: compact ? 14 : 15.5,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceRail extends StatelessWidget {
  final List<_AudienceItem> audiences;
  final bool isMobile;

  const _AudienceRail({
    required this.audiences,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, isMobile ? 18 : 10, 22, 20),
        child: Column(
          children: [
            Text(
              'BUILT FOR EVERYONE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _featureAccent,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = isMobile
                    ? math.max(136.0, (constraints.maxWidth - 16) / 2)
                    : 178.0;
                return Wrap(
                  spacing: isMobile ? 14 : 28,
                  runSpacing: isMobile ? 16 : 12,
                  alignment: isMobile
                      ? WrapAlignment.start
                      : WrapAlignment.spaceBetween,
                  children: [
                    for (final audience in audiences)
                      SizedBox(
                        width: itemWidth,
                        child: _AudienceTile(audience: audience),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceTile extends StatelessWidget {
  final _AudienceItem audience;

  const _AudienceTile({required this.audience});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(audience.icon, color: Colors.white, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            audience.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _NeonIconFrame extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const _NeonIconFrame({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _featureAccent.withValues(alpha: 0.18),
            _featureAccent.withValues(alpha: 0.04),
          ],
        ),
        border:
            Border.all(color: _featureAccent.withValues(alpha: 0.75), width: 1),
        boxShadow: [
          BoxShadow(
            color: _featureAccent.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: _featureAccent, size: iconSize),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF061928).withValues(alpha: 0.66),
            border: Border.all(
                color: const Color(0xFF31566E).withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FeatureBackdrop extends StatelessWidget {
  const _FeatureBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020711),
            Color(0xFF061622),
            Color(0xFF020914),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _FeatureGridBackdrop()),
          Positioned.fill(child: _FeatureVignette()),
        ],
      ),
    );
  }
}

class _FeatureGridBackdrop extends StatelessWidget {
  const _FeatureGridBackdrop();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _FeatureGridPainter());
  }
}

class _FeatureGridPainter extends CustomPainter {
  const _FeatureGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _featureAccent.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;
    const gap = 48.0;

    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), gridPaint);
    }
    for (double x = 0; x < size.width + size.height; x += gap) {
      canvas.drawLine(
          Offset(x, 0), Offset(x - size.height, size.height), gridPaint);
    }

    final horizonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          _featureAccent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.12, 0.36, 0.84],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, horizonPaint);

    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          _featureCyan.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureVignette extends StatelessWidget {
  const _FeatureVignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.34),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _AudienceItem {
  final IconData icon;
  final String label;

  const _AudienceItem(this.icon, this.label);
}
