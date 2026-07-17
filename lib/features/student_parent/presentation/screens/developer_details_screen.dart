import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_notification.dart';

class DeveloperDetailsScreen extends StatelessWidget {
  const DeveloperDetailsScreen({super.key});

  static final Uri _websiteUri = Uri.parse('https://www.ultoxy.com');
  static final Uri _whatsAppAppUri = Uri.parse(
    'whatsapp://send?phone=917776824564&text=Hello%20Ultoxy%20Technologies',
  );
  static final Uri _whatsAppWebUri = Uri.parse(
    'https://wa.me/917776824564?text=Hello%20Ultoxy%20Technologies',
  );
  static final Uri _phoneUri = Uri.parse('tel:7776824564');
  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: 'ultoxy.tech@gmail.com',
    queryParameters: {'subject': 'Enquiry from UltraCoachMatrix'},
  );

  Future<void> _openUri(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppNotification(
        context,
        title: 'Action unavailable',
        message: 'Unable to open this action on your device.',
        type: AppNotificationType.error,
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final opened = await launchUrl(
      _whatsAppAppUri,
      mode: LaunchMode.externalApplication,
    );
    if (opened) {
      return;
    }
    if (context.mounted) {
      await _openUri(context, _whatsAppWebUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE7FA),
      appBar: AppBar(
        title: const Text(
          'Developer Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFDCE7FA),
        foregroundColor: const Color(0xFF17204F),
        elevation: 0,
        centerTitle: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _SoftBluePainter())),
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 34 : 16,
                    10,
                    isWide ? 34 : 16,
                    30,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 12 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeroPanel(isWide: isWide),
                            const SizedBox(height: 16),
                            _QuickActions(
                              isWide: isWide,
                              onWhatsApp: () => _openWhatsApp(context),
                              onCall: () => _openUri(context, _phoneUri),
                              onWebsite: () => _openUri(context, _websiteUri),
                              onEmail: () => _openUri(context, _emailUri),
                            ),
                            const SizedBox(height: 16),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    flex: 7,
                                    child: _CompanyDetailsCard(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _ProfessionalCard(
                                      onWebsite: () =>
                                          _openUri(context, _websiteUri),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              const _CompanyDetailsCard(),
                              const SizedBox(height: 16),
                              _ProfessionalCard(
                                onWebsite: () => _openUri(context, _websiteUri),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5558C9),
                      Color(0xFF3432A3),
                      Color(0xFF1E236B),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _HeroCurvePainter())),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 28 : 20,
                isWide ? 28 : 22,
                isWide ? 28 : 20,
                isWide ? 30 : 28,
              ),
              child: isWide
                  ? Row(
                      children: [
                        const _LogoCard(size: 150),
                        const SizedBox(width: 28),
                        Expanded(child: _HeroText(isWide: isWide)),
                      ],
                    )
                  : Column(
                      children: [
                        const _LogoCard(size: 128),
                        const SizedBox(height: 20),
                        _HeroText(isWide: isWide),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330A1550),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Image.asset(
        'assets/ultoxy_logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'Ultoxy Technologies logo',
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isWide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const Text(
          'ULTOXY',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Professional software partner for UltraCoachMatrix',
          textAlign: isWide ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isWide ? 31 : 24,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Mobile apps, web platforms, and institute management systems designed with clarity and care.',
          textAlign: isWide ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE8EDFF),
            fontSize: 14,
            height: 1.42,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 9,
          runSpacing: 9,
          children: const [
            _HeroPill(icon: Icons.phone_android_rounded, label: 'Mobile Apps'),
            _HeroPill(icon: Icons.language_rounded, label: 'Web Systems'),
            _HeroPill(icon: Icons.support_agent_rounded, label: 'Support'),
          ],
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.isWide,
    required this.onWhatsApp,
    required this.onCall,
    required this.onWebsite,
    required this.onEmail,
  });

  final bool isWide;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  final VoidCallback onWebsite;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        icon: Icons.chat_rounded,
        title: 'WhatsApp',
        subtitle: 'Message',
        color: const Color(0xFF169B62),
        onTap: onWhatsApp,
      ),
      _ActionItem(
        icon: Icons.call_rounded,
        title: 'Call',
        subtitle: 'Connect',
        color: const Color(0xFF3356C9),
        onTap: onCall,
      ),
      _ActionItem(
        icon: Icons.language_rounded,
        title: 'Website',
        subtitle: 'Visit',
        color: const Color(0xFF544EC4),
        onTap: onWebsite,
      ),
      _ActionItem(
        icon: Icons.email_rounded,
        title: 'Email',
        subtitle: 'Enquire',
        color: const Color(0xFFD43F6A),
        onTap: onEmail,
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isWide ? 2.35 : 1.55,
      ),
      itemBuilder: (context, index) => _ActionTile(item: actions[index]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final _ActionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: item.onTap,
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3EAF8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x170A1550),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17204F),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7B86A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyDetailsCard extends StatelessWidget {
  const _CompanyDetailsCard();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.business_center_rounded,
            title: 'Company Information',
          ),
          SizedBox(height: 18),
          _DetailRow(
            icon: Icons.apartment_rounded,
            label: 'Company',
            value: 'Ultoxy Technologies',
          ),
          _Divider(),
          _DetailRow(
            icon: Icons.person_rounded,
            label: 'Developer',
            value: 'Rameshwar Pawar',
          ),
          _Divider(),
          _DetailRow(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'www.ultoxy.com',
          ),
          _Divider(),
          _DetailRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: 'ultoxy.tech@gmail.com',
          ),
          _Divider(),
          _DetailRow(
            icon: Icons.phone_rounded,
            label: 'Mobile',
            value: '7776824564',
          ),
        ],
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.onWebsite});

  final VoidCallback onWebsite;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.verified_rounded,
            title: 'Development Focus',
          ),
          const SizedBox(height: 16),
          const Text(
            'A focused technology team for clean interfaces, reliable workflows, and practical business systems.',
            style: TextStyle(
              color: Color(0xFF46516B),
              fontSize: 14,
              height: 1.48,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const _FocusItem(icon: Icons.design_services_rounded, text: 'UI/UX'),
          const SizedBox(height: 10),
          const _FocusItem(icon: Icons.code_rounded, text: 'Development'),
          const SizedBox(height: 10),
          const _FocusItem(icon: Icons.cloud_done_rounded, text: 'Deployment'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWebsite,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Visit Website'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3432A3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5066A4),
            blurRadius: 26,
            offset: Offset(0, 13),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF3432A3), size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFF17204F),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF4B55C5), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7B86A1),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17204F),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusItem extends StatelessWidget {
  const _FocusItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3432A3), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF17204F),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Divider(height: 1, color: Color(0xFFE7ECF6)),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _SoftBluePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.32);
    canvas.drawCircle(Offset(size.width * 0.08, 110), 118, paint);
    canvas.drawCircle(Offset(size.width * 0.92, 54), 152, paint);
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.86),
      172,
      paint,
    );

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.62)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.52,
        size.width * 0.48,
        size.height * 0.72,
        size.width,
        size.height * 0.56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF222272).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.48, 0)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.16,
        size.width * 0.66,
        size.height * 0.78,
        size.width,
        size.height * 0.92,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.42, size.height)
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.72,
        size.width * 0.43,
        size.height * 0.35,
        size.width * 0.48,
        0,
      )
      ..close();
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (final offset in [
      Offset(size.width * 0.78, size.height * 0.2),
      Offset(size.width * 0.87, size.height * 0.38),
      Offset(size.width * 0.72, size.height * 0.68),
      Offset(size.width * 0.92, size.height * 0.76),
    ]) {
      canvas.drawCircle(offset, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
