import 'package:flutter/material.dart';

import 'push_notification_route.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.data,
    required this.onOpenSection,
    this.loadDetails,
  });

  final Map<String, dynamic> data;
  final VoidCallback onOpenSection;
  final Future<Map<String, dynamic>> Function()? loadDetails;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late Map<String, dynamic> _data;
  var _isLoadingDetails = false;
  var _detailsFailed = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final loader = widget.loadDetails;
    if (loader == null) {
      return;
    }
    setState(() => _isLoadingDetails = true);
    try {
      final details = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = {..._data, ...details};
        _isLoadingDetails = false;
        _detailsFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _detailsFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = notificationPageForData(_data);
    final presentation = _presentation(page);
    final title = _text(_data['title'], fallback: presentation.fallbackTitle);
    final body = _text(_data['body'], fallback: presentation.fallbackBody);
    final facts = _facts(_data, page);
    final highlights = _highlights(_data, page);
    final logoUrl = _text(_data['institute_logo_url']);
    final instituteName = _text(_data['institute_name']);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text(
          'Notification details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [presentation.color, presentation.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: presentation.color.withValues(alpha: 0.24),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InstituteLogoBadge(
                        logoUrl: logoUrl,
                        fallbackIcon: presentation.icon,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (instituteName.isNotEmpty) ...[
                              Text(
                                instituteName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              presentation.label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (highlights.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final highlight in highlights)
                          _HighlightPill(
                            label: highlight.label,
                            value: highlight.value,
                            icon: highlight.icon,
                          ),
                      ],
                    ),
                  ],
                  if (_text(_data['created_at']).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _formatTimestamp(_text(_data['created_at'])),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_isLoadingDetails) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
            ],
            if (_detailsFailed) ...[
              const SizedBox(height: 16),
              Material(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: _loadDetails,
                  borderRadius: BorderRadius.circular(18),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: Color(0xFFC2410C)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Could not load the full notice. Tap to retry.',
                            style: TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDCE4F8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick details',
                      style: TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final fact in facts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              fact.icon,
                              color: presentation.color,
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                fact.label,
                                style: const TextStyle(
                                  color: Color(0xFF65708A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                fact.value,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF111640),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: widget.onOpenSection,
              style: FilledButton.styleFrom(
                backgroundColor: presentation.color,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(presentation.icon),
              label: Text(
                'Open ${presentation.destinationLabel}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPresentation {
  const _NotificationPresentation({
    required this.label,
    required this.destinationLabel,
    required this.fallbackTitle,
    required this.fallbackBody,
    required this.icon,
    required this.color,
    required this.secondaryColor,
  });

  final String label;
  final String destinationLabel;
  final String fallbackTitle;
  final String fallbackBody;
  final IconData icon;
  final Color color;
  final Color secondaryColor;
}

class _InstituteLogoBadge extends StatelessWidget {
  const _InstituteLogoBadge({
    required this.logoUrl,
    required this.fallbackIcon,
  });

  final String logoUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: logoUrl.isEmpty
          ? Icon(fallbackIcon, color: const Color(0xFF0700A8), size: 31)
          : ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  fallbackIcon,
                  color: const Color(0xFF0700A8),
                  size: 31,
                ),
              ),
            ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF111640), size: 20),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF65708A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

_NotificationPresentation _presentation(PushNotificationPage page) {
  return switch (page) {
    PushNotificationPage.fees => const _NotificationPresentation(
      label: 'PAYMENT CONFIRMATION',
      destinationLabel: 'Fees & Receipts',
      fallbackTitle: 'Fee payment received',
      fallbackBody: 'Your latest payment and receipt are now available.',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF15803D),
      secondaryColor: Color(0xFF22C55E),
    ),
    PushNotificationPage.notices => const _NotificationPresentation(
      label: 'INSTITUTE NOTICE',
      destinationLabel: 'Notice Board',
      fallbackTitle: 'New institute notice',
      fallbackBody: 'Open the notice board to read the complete update.',
      icon: Icons.campaign_rounded,
      color: Color(0xFFBE123C),
      secondaryColor: Color(0xFFFF5D8F),
    ),
    PushNotificationPage.results => const _NotificationPresentation(
      label: 'ACADEMIC RESULT',
      destinationLabel: 'Results',
      fallbackTitle: 'Result declared',
      fallbackBody: 'Your latest exam result is available.',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFF6D28D9),
      secondaryColor: Color(0xFF8B5CF6),
    ),
    PushNotificationPage.exams => const _NotificationPresentation(
      label: 'EXAM UPDATE',
      destinationLabel: 'Exams',
      fallbackTitle: 'Exam update',
      fallbackBody: 'There is a new update in your examinations.',
      icon: Icons.quiz_rounded,
      color: Color(0xFFB91C1C),
      secondaryColor: Color(0xFFEF4444),
    ),
    _ => const _NotificationPresentation(
      label: 'STUDENT UPDATE',
      destinationLabel: 'Dashboard',
      fallbackTitle: 'New notification',
      fallbackBody: 'You have a new update from your institute.',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF0700A8),
      secondaryColor: Color(0xFF4F46E5),
    ),
  };
}

class _NotificationFact {
  const _NotificationFact(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

List<_NotificationFact> _highlights(
  Map<String, dynamic> data,
  PushNotificationPage page,
) {
  final highlights = <_NotificationFact>[];
  switch (page) {
    case PushNotificationPage.fees:
      final amount = _text(data['amount']);
      final receipt = _text(data['receipt_number']);
      if (amount.isNotEmpty) {
        highlights.add(
          _NotificationFact(Icons.currency_rupee_rounded, 'Amount', amount),
        );
      }
      if (receipt.isNotEmpty) {
        highlights.add(
          _NotificationFact(Icons.receipt_long_rounded, 'Receipt', receipt),
        );
      }
    case PushNotificationPage.results:
      final marks = _text(data['marks_obtained']);
      final total = _text(data['total_marks']);
      if (marks.isNotEmpty && total.isNotEmpty) {
        highlights.add(
          _NotificationFact(Icons.score_rounded, 'Marks', '$marks / $total'),
        );
      }
    default:
      break;
  }
  return highlights;
}

List<_NotificationFact> _facts(
  Map<String, dynamic> data,
  PushNotificationPage page,
) {
  final facts = <_NotificationFact>[];
  void add(IconData icon, String label, Object? value) {
    final text = _text(value);
    if (text.isNotEmpty) {
      facts.add(_NotificationFact(icon, label, text));
    }
  }

  switch (page) {
    case PushNotificationPage.fees:
      add(Icons.currency_rupee_rounded, 'Amount', data['amount']);
      add(Icons.receipt_long_rounded, 'Receipt', data['receipt_number']);
    case PushNotificationPage.notices:
      add(Icons.category_rounded, 'Category', data['category_label']);
      add(Icons.priority_high_rounded, 'Priority', data['priority_label']);
    case PushNotificationPage.results:
      final marks = _text(data['marks_obtained']);
      final total = _text(data['total_marks']);
      if (marks.isNotEmpty && total.isNotEmpty) {
        facts.add(
          _NotificationFact(Icons.score_rounded, 'Marks', '$marks / $total'),
        );
      }
    default:
      break;
  }
  return facts;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _formatTimestamp(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final period = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${parsed.day}/${parsed.month}/${parsed.year} at $hour:$minute $period';
}
