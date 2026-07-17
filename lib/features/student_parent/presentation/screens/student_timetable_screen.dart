import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/student_profile_model.dart';
import '../providers/student_profile_provider.dart';

class StudentTimetableScreen extends ConsumerWidget {
  const StudentTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    final selectedSessionId = ref.watch(selectedAcademicSessionIdProvider);

    return profile.when(
      loading: () => const _TimetableLoadingView(),
      error: (error, _) => _TimetableErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(studentProfileProvider),
      ),
      data: (data) {
        final sessionId = selectedSessionId ?? data.activeSession?.id;
        final enrollments = data.enrollments
            .where(
              (enrollment) =>
                  sessionId == null ||
                  enrollment.academicSessionId == sessionId,
            )
            .toList();
        return _TimetableContent(
          enrollments: enrollments,
          academicYear:
              data.academicSessions
                  .where((session) => session.id == sessionId)
                  .map((session) => session.academicYear)
                  .firstOrNull ??
              data.activeSession?.academicYear ??
              '',
        );
      },
    );
  }
}

class _TimetableContent extends StatelessWidget {
  const _TimetableContent({
    required this.enrollments,
    required this.academicYear,
  });

  final List<StudentEnrollmentModel> enrollments;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    final scheduledBatches = enrollments
        .where((enrollment) => enrollment.weeklyTimetable.isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimetableSummary(
          batchCount: enrollments.length,
          scheduledBatchCount: scheduledBatches,
          academicYear: academicYear,
        ),
        const SizedBox(height: 18),
        if (enrollments.isEmpty)
          const _TimetableEmptyView()
        else
          for (var index = 0; index < enrollments.length; index++) ...[
            _BatchTimetableCard(
              enrollment: enrollments[index],
              accent: _batchColors[index % _batchColors.length],
            ),
            if (index != enrollments.length - 1) const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _TimetableSummary extends StatelessWidget {
  const _TimetableSummary({
    required this.batchCount,
    required this.scheduledBatchCount,
    required this.academicYear,
  });

  final int batchCount;
  final int scheduledBatchCount;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0700A8), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330700A8),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Weekly Timetable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                academicYear.isEmpty
                    ? 'Class timings for all your enrolled batches'
                    : '$academicYear class timings for all enrolled batches',
                style: const TextStyle(
                  color: Color(0xFFD8DCFF),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              '$scheduledBatchCount of $batchCount scheduled',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 16), badge],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              badge,
            ],
          );
        },
      ),
    );
  }
}

class _BatchTimetableCard extends StatelessWidget {
  const _BatchTimetableCard({required this.enrollment, required this.accent});

  final StudentEnrollmentModel enrollment;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final schedule = _weekDays
        .where((day) => enrollment.weeklyTimetable.containsKey(day.key))
        .map((day) => (day: day, slot: enrollment.weeklyTimetable[day.key]!))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BatchHeading(enrollment: enrollment, accent: accent),
          const SizedBox(height: 18),
          if (schedule.isEmpty)
            _NoBatchSchedule(accent: accent)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final spacing = 12.0;
                final width =
                    (constraints.maxWidth - (columns - 1) * spacing) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in schedule)
                      SizedBox(
                        width: width,
                        child: _DayScheduleTile(
                          day: item.day,
                          slot: item.slot,
                          accent: accent,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BatchHeading extends StatelessWidget {
  const _BatchHeading({required this.enrollment, required this.accent});

  final StudentEnrollmentModel enrollment;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final icon = Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(Icons.groups_rounded, color: accent),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              enrollment.batchName.isEmpty
                  ? 'Unnamed batch'
                  : enrollment.batchName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (enrollment.courses.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                enrollment.courses.join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF68738E),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
        final status = Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _formatStatus(enrollment.status),
            style: const TextStyle(
              color: Color(0xFF15803D),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: copy),
                ],
              ),
              const SizedBox(height: 12),
              status,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 13),
            Expanded(child: copy),
            const SizedBox(width: 12),
            status,
          ],
        );
      },
    );
  }
}

class _DayScheduleTile extends StatelessWidget {
  const _DayScheduleTile({
    required this.day,
    required this.slot,
    required this.accent,
  });

  final _WeekDay day;
  final TimetableSlotModel slot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().weekday == day.weekday;
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isToday
            ? accent.withValues(alpha: 0.1)
            : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isToday
              ? accent.withValues(alpha: 0.45)
              : const Color(0xFFE7EAF3),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isToday ? accent : Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                day.shortLabel,
                style: TextStyle(
                  color: isToday ? Colors.white : accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        day.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111640),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 7),
                      Text(
                        'TODAY',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 16, color: accent),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_formatTime(slot.start)} – ${_formatTime(slot.end)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5F6B85),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBatchSchedule extends StatelessWidget {
  const _NoBatchSchedule({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7EAF3)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, color: accent, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'The weekly timetable has not been added for this batch yet.',
              style: TextStyle(
                color: Color(0xFF68738E),
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimetableEmptyView extends StatelessWidget {
  const _TimetableEmptyView();

  @override
  Widget build(BuildContext context) {
    return const _TimetableStateCard(
      icon: Icons.calendar_month_rounded,
      title: 'No batch enrollments',
      message:
          'There are no batch enrollments available for the selected academic session.',
    );
  }
}

class _TimetableLoadingView extends StatelessWidget {
  const _TimetableLoadingView();

  @override
  Widget build(BuildContext context) {
    return const _TimetableStateCard(
      icon: Icons.schedule_rounded,
      title: 'Loading timetable',
      message: 'Getting the latest batch schedules...',
      showProgress: true,
    );
  }
}

class _TimetableErrorView extends StatelessWidget {
  const _TimetableErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _TimetableStateCard(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load timetable',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    );
  }
}

class _TimetableStateCard extends StatelessWidget {
  const _TimetableStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E9F3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: const Color(0xFF4F46E5)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF68738E),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 18),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

String _formatTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return value;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return value;
  }
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

String _formatStatus(String value) {
  if (value.isEmpty) {
    return 'Enrolled';
  }
  final lower = value.replaceAll('_', ' ').toLowerCase();
  return lower
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

const _batchColors = [
  Color(0xFF4F46E5),
  Color(0xFF0891B2),
  Color(0xFFEA580C),
  Color(0xFF7C3AED),
  Color(0xFF0F766E),
];

const _weekDays = [
  _WeekDay('monday', 'Monday', 'MON', DateTime.monday),
  _WeekDay('tuesday', 'Tuesday', 'TUE', DateTime.tuesday),
  _WeekDay('wednesday', 'Wednesday', 'WED', DateTime.wednesday),
  _WeekDay('thursday', 'Thursday', 'THU', DateTime.thursday),
  _WeekDay('friday', 'Friday', 'FRI', DateTime.friday),
  _WeekDay('saturday', 'Saturday', 'SAT', DateTime.saturday),
  _WeekDay('sunday', 'Sunday', 'SUN', DateTime.sunday),
];

class _WeekDay {
  const _WeekDay(this.key, this.label, this.shortLabel, this.weekday);

  final String key;
  final String label;
  final String shortLabel;
  final int weekday;
}
