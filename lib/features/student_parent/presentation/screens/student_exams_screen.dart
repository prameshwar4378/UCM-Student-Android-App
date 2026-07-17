import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/app_notification.dart';
import '../../data/models/exam_model.dart';
import '../providers/exam_provider.dart';
import '../providers/student_profile_provider.dart';

class StudentExamsScreen extends ConsumerWidget {
  const StudentExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsProvider);
    return exams.when(
      loading: () => const _ExamLoadingView(),
      error: (error, _) => _ExamErrorView(
        message: error.toString(),
        onRetry: () => refreshPublishedExams(ref),
      ),
      data: (data) => _ExamListView(
        data: data,
        onRefresh: () => refreshPublishedExams(ref),
      ),
    );
  }
}

class _ExamListView extends ConsumerWidget {
  const _ExamListView({required this.data, required this.onRefresh});

  final ExamListModel data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 840;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExamHero(summary: data.summary),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ),
        const SizedBox(height: 12),
        if (data.exams.isEmpty)
          _NoExamCard(onRefresh: onRefresh)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = isWide ? 2 : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final exam in data.exams)
                    SizedBox(
                      width: columns == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2,
                      child: _ExamCard(
                        exam: exam,
                        onStart: () => _confirmStart(context, ref, exam),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmStart(
    BuildContext context,
    WidgetRef ref,
    ExamModel exam,
  ) async {
    if (exam.attempt.isSubmitted) {
      if (!exam.attempt.canViewResult || exam.attempt.id == null) {
        await _showExamMessageDialog(
          context,
          title: 'Result Pending',
          message:
              'Your exam is submitted. Result will be visible after your teacher publishes it.',
          icon: Icons.hourglass_top_rounded,
          type: _ExamMessageType.warning,
        );
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final result = await ref
            .read(examRepositoryProvider)
            .fetchResultReview(exam.attempt.id!);
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
        await showDialog<void>(
          context: context,
          builder: (_) => ResultReviewDialog(result: result),
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        Navigator.of(context).pop();
        await refreshPublishedExams(ref);
        if (!context.mounted) {
          return;
        }
        await _showExamMessageDialog(
          context,
          title: 'Unable to Load Result',
          message: error.toString(),
          icon: Icons.error_outline_rounded,
          type: _ExamMessageType.error,
        );
      }
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StartExamDialog(exam: exam),
    );
    if (shouldStart != true || !context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final academicSessionId = await ref.read(
        effectiveAcademicSessionIdProvider.future,
      );
      final attempt = await ref
          .read(examRepositoryProvider)
          .startExam(exam.id, academicSessionId: academicSessionId);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ExamAttemptScreen(attempt: attempt),
        ),
      );
      await refreshPublishedExams(ref);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      await refreshPublishedExams(ref);
      if (!context.mounted) {
        return;
      }
      await _showExamMessageDialog(
        context,
        title: 'Unable to Start Exam',
        message: error.toString(),
        icon: Icons.error_outline_rounded,
        type: _ExamMessageType.error,
      );
    }
  }
}

class ExamAttemptScreen extends ConsumerStatefulWidget {
  const ExamAttemptScreen({super.key, required this.attempt});

  final ExamAttemptModel attempt;

  @override
  ConsumerState<ExamAttemptScreen> createState() => _ExamAttemptScreenState();
}

class _ExamAttemptScreenState extends ConsumerState<ExamAttemptScreen>
    with WidgetsBindingObserver {
  late int _remainingSeconds;
  Timer? _timer;
  final Map<int, int> _answers = {};
  final Map<int, List<ExamRoughWorkUploadModel>> _roughWorkUploads = {};
  final Set<int> _roughWorkUploadingQuestionIds = {};
  final Set<int> _roughWorkDeletingUploadIds = {};
  final List<ExamActivityEventModel> _activities = [];
  final ImagePicker _imagePicker = ImagePicker();
  var _questionIndex = 0;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.attempt.exam.durationMinutes * 60;
    for (final question in widget.attempt.questions) {
      if (question.roughWorkUploads.isNotEmpty) {
        _roughWorkUploads[question.id] = List.of(question.roughWorkUploads);
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _recordActivity('app_backgrounded', 'App state changed to ${state.name}');
    }
    if (state == AppLifecycleState.resumed) {
      _recordActivity('app_resumed', 'Student returned to exam screen');
    }
  }

  void _tick(Timer timer) {
    if (_remainingSeconds <= 1) {
      timer.cancel();
      _recordActivity('timer_finished', 'Exam countdown reached zero');
      _submit(autoSubmit: true);
      return;
    }
    setState(() => _remainingSeconds -= 1);
  }

  void _recordActivity(String eventType, String detail) {
    _activities.add(
      ExamActivityEventModel(
        eventType: eventType,
        detail: detail,
        occurredAt: DateTime.now(),
      ),
    );
  }

  Future<void> _submit({bool autoSubmit = false}) async {
    if (_isSubmitting) {
      return;
    }
    if (_roughWorkUploadingQuestionIds.isNotEmpty) {
      if (autoSubmit) {
        _timer?.cancel();
        return;
      }
      await _showExamMessageDialog(
        context,
        title: 'Upload in Progress',
        message:
            'Please wait for your solution or rough-work image to finish uploading before submitting.',
        icon: Icons.cloud_upload_rounded,
        type: _ExamMessageType.info,
      );
      return;
    }
    if (!autoSubmit) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _SubmitConfirmDialog(
          answered: _answers.length,
          total: widget.attempt.questions.length,
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() => _isSubmitting = true);
    _timer?.cancel();
    try {
      final result = await ref
          .read(examRepositoryProvider)
          .submitExam(
            attemptId: widget.attempt.attemptId,
            answers: _answers,
            activities: _activities,
          );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _SubmissionSuccessDialog(result: result),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      await _showExamMessageDialog(
        context,
        title: 'Submission Failed',
        message: error.toString(),
        icon: Icons.cloud_off_rounded,
        type: _ExamMessageType.error,
      );
    }
  }

  Future<void> _pickAndUploadRoughWork({
    required ExamQuestionModel question,
    required ImageSource source,
  }) async {
    if (_isSubmitting || _roughWorkUploadingQuestionIds.contains(question.id)) {
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() => _roughWorkUploadingQuestionIds.add(question.id));
      final upload = await ref
          .read(examRepositoryProvider)
          .uploadRoughWork(
            attemptId: widget.attempt.attemptId,
            questionId: question.id,
            bytes: bytes,
            fileName: image.name,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _roughWorkUploadingQuestionIds.remove(question.id);
        _roughWorkUploads.update(
          question.id,
          (uploads) => [...uploads, upload],
          ifAbsent: () => [upload],
        );
      });
      _recordActivity(
        'rough_work_uploaded',
        'Solution or rough-work image uploaded for question ${question.id}',
      );
      showAppNotification(
        context,
        title: 'Upload complete',
        message:
            'Solution / rough-work image uploaded for Question ${question.order}.',
        type: AppNotificationType.success,
      );
      if (_remainingSeconds <= 1) {
        await _submit(autoSubmit: true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _roughWorkUploadingQuestionIds.remove(question.id));
      await _showExamMessageDialog(
        context,
        title: 'Upload Failed',
        message: error.toString(),
        icon: Icons.cloud_off_rounded,
        type: _ExamMessageType.error,
      );
      if (_remainingSeconds <= 1) {
        await _submit(autoSubmit: true);
      }
    }
  }

  Future<void> _deleteRoughWork({
    required ExamQuestionModel question,
    required ExamRoughWorkUploadModel upload,
  }) async {
    if (_isSubmitting || _roughWorkDeletingUploadIds.contains(upload.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteRoughWorkDialog(questionOrder: question.order),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _roughWorkDeletingUploadIds.add(upload.id));
    try {
      await ref
          .read(examRepositoryProvider)
          .deleteRoughWork(
            attemptId: widget.attempt.attemptId,
            uploadId: upload.id,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _roughWorkDeletingUploadIds.remove(upload.id);
        final uploads = [...?_roughWorkUploads[question.id]]
          ..removeWhere((item) => item.id == upload.id);
        if (uploads.isEmpty) {
          _roughWorkUploads.remove(question.id);
        } else {
          _roughWorkUploads[question.id] = uploads;
        }
      });
      _recordActivity(
        'rough_work_deleted',
        'Solution or rough-work image deleted for question ${question.id}',
      );
      showAppNotification(
        context,
        title: 'Image deleted',
        message: 'Rough-work image removed from Question ${question.order}.',
        type: AppNotificationType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _roughWorkDeletingUploadIds.remove(upload.id));
      await _showExamMessageDialog(
        context,
        title: 'Delete Failed',
        message: error.toString(),
        icon: Icons.delete_outline_rounded,
        type: _ExamMessageType.error,
      );
    }
  }

  void _previewRoughWork(ExamRoughWorkUploadModel upload) {
    if (upload.imageUrl.isEmpty) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => _QuestionImageViewerDialog(
        imageUrl: upload.imageUrl,
        heroTag: 'rough-work-upload-${upload.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attempt.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.quiz_outlined,
                    color: Color(0xFF0700A8),
                    size: 46,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No questions available',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please contact your teacher before attempting this exam.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF69718A)),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Exams'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final question = widget.attempt.questions[_questionIndex];
    final selectedOptionId = _answers[question.id];
    final isLast = _questionIndex == widget.attempt.questions.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _recordActivity('back_blocked', 'Back navigation was attempted');
          _showExamMessageDialog(
            context,
            title: 'Navigation Locked',
            message:
                'Back navigation is disabled while the exam is running. This attempt has been recorded.',
            icon: Icons.lock_rounded,
            type: _ExamMessageType.info,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FF),
        body: SafeArea(
          child: Column(
            children: [
              _AttemptHeader(
                title: widget.attempt.exam.title,
                remainingSeconds: _remainingSeconds,
                answered: _answers.length,
                total: widget.attempt.questions.length,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                  children: [
                    _QuestionCard(
                      question: question,
                      selectedOptionId: selectedOptionId,
                      onSelect: (optionId) {
                        setState(() => _answers[question.id] = optionId);
                      },
                      allowRoughWorkUploads:
                          widget.attempt.exam.allowRoughWorkUploads,
                      isUploadingRoughWork: _roughWorkUploadingQuestionIds
                          .contains(question.id),
                      roughWorkUploads:
                          _roughWorkUploads[question.id] ?? const [],
                      deletingUploadIds: _roughWorkDeletingUploadIds,
                      onPickCamera: () => _pickAndUploadRoughWork(
                        question: question,
                        source: ImageSource.camera,
                      ),
                      onPickGallery: () => _pickAndUploadRoughWork(
                        question: question,
                        source: ImageSource.gallery,
                      ),
                      onPreviewRoughWork: _previewRoughWork,
                      onDeleteRoughWork: (upload) => _deleteRoughWork(
                        question: question,
                        upload: upload,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _QuestionStepper(
                      count: widget.attempt.questions.length,
                      currentIndex: _questionIndex,
                      answeredQuestionIds: _answers.keys.toSet(),
                      questions: widget.attempt.questions,
                      onSelect: (index) =>
                          setState(() => _questionIndex = index),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _questionIndex == 0
                            ? null
                            : () => setState(() => _questionIndex -= 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                        label: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _isSubmitting ||
                                _roughWorkUploadingQuestionIds.isNotEmpty
                            ? null
                            : isLast
                            ? () => _submit()
                            : () => setState(() => _questionIndex += 1),
                        icon: Icon(
                          isLast
                              ? Icons.cloud_done_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        label: Text(isLast ? 'Submit' : 'Next'),
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

class _SubmissionSuccessDialog extends StatelessWidget {
  const _SubmissionSuccessDialog({required this.result});

  final ExamSubmitResponseModel result;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F8EF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Exam Submitted',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111640),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.canViewResult
                  ? 'Your response has been saved successfully.'
                  : 'Your response has been saved. Result will be available after teacher publishes it.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF69718A),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1E7F5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF0700A8),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Score',
                      style: TextStyle(
                        color: Color(0xFF69718A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    result.canViewResult
                        ? '${result.score} / ${result.totalMarks}'
                        : 'Pending',
                    style: const TextStyle(
                      color: Color(0xFF111640),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0700A8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to My Exams',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartExamDialog extends StatelessWidget {
  const _StartExamDialog({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    const type = _ExamMessageType.warning;
    final color = type.color;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: type.softColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.play_circle_rounded, color: color, size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start Exam?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111640),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              exam.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF69718A),
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: type.softColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
              child: Column(
                children: [
                  _WarningRow(
                    icon: Icons.timer_rounded,
                    text: 'Countdown starts immediately after you begin.',
                    color: color,
                  ),
                  _WarningRow(
                    icon: Icons.no_accounts_rounded,
                    text:
                        'Back button and screen switching attempts are recorded.',
                    color: color,
                  ),
                  _WarningRow(
                    icon: Icons.check_circle_rounded,
                    text: 'Submit only after selecting your final answers.',
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111640),
                      side: const BorderSide(color: Color(0xFFE1E7F5)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Start Now',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitConfirmDialog extends StatelessWidget {
  const _SubmitConfirmDialog({required this.answered, required this.total});

  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    const type = _ExamMessageType.warning;
    final color = type.color;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: type.softColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                color: color,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Submit Exam?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111640),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You answered $answered of $total questions. Once submitted, answers cannot be changed.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF69718A),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteRoughWorkDialog extends StatelessWidget {
  const _DeleteRoughWorkDialog({required this.questionOrder});

  final int questionOrder;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete rough-work image?'),
      content: Text(
        'This image will be removed from Question $questionOrder before submission.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
      ],
    );
  }
}

Future<void> _showExamMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required _ExamMessageType type,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ExamMessageDialog(
      title: title,
      message: message,
      icon: icon,
      type: type,
    ),
  );
}

enum _ExamMessageType { success, warning, error, info }

extension _ExamMessageTypeStyle on _ExamMessageType {
  Color get color {
    return switch (this) {
      _ExamMessageType.success => const Color(0xFF16A34A),
      _ExamMessageType.warning => const Color(0xFFF59E0B),
      _ExamMessageType.error => const Color(0xFFE11D48),
      _ExamMessageType.info => const Color(0xFF0700A8),
    };
  }

  Color get softColor {
    return switch (this) {
      _ExamMessageType.success => const Color(0xFFE7F8EF),
      _ExamMessageType.warning => const Color(0xFFFFF7D6),
      _ExamMessageType.error => const Color(0xFFFFE4E6),
      _ExamMessageType.info => const Color(0xFFE9ECFF),
    };
  }
}

class _ExamMessageDialog extends StatelessWidget {
  const _ExamMessageDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.type,
  });

  final String title;
  final String message;
  final IconData icon;
  final _ExamMessageType type;

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: type.softColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF69718A),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Okay',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultReviewDialog extends StatefulWidget {
  const ResultReviewDialog({super.key, required this.result});

  final ExamResultReviewModel result;

  @override
  State<ResultReviewDialog> createState() => _ResultReviewDialogState();
}

class _ResultReviewDialogState extends State<ResultReviewDialog> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final questions = widget.result.questions;
    final question = questions.isEmpty ? null : questions[_index];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FF),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFF0700A8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  const _SoftIcon(
                    icon: Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.result.exam.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Score ${widget.result.result.score} / ${widget.result.result.totalMarks}',
                          style: const TextStyle(
                            color: Color(0xFFD8DEFF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (question == null)
              const Expanded(
                child: Center(child: Text('No review data available.')),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Question ${_index + 1} of ${questions.length}',
                            style: const TextStyle(
                              color: Color(0xFF0700A8),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _ReviewStatusChip(question: question),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (question.text.isNotEmpty)
                            Text(
                              question.text,
                              style: const TextStyle(
                                color: Color(0xFF111640),
                                fontSize: 17,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (question.imageUrl.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ZoomableQuestionImage(
                              imageUrl: question.imageUrl,
                              heroTag: 'review-question-image-${question.id}',
                            ),
                          ],
                          const SizedBox(height: 16),
                          for (final option in question.options)
                            _ReviewOptionTile(
                              question: question,
                              option: option,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index == 0
                          ? null
                          : () => setState(() => _index -= 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _index >= questions.length - 1
                          ? null
                          : () => setState(() => _index += 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Next'),
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

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip({required this.question});

  final ExamReviewQuestionModel question;

  @override
  Widget build(BuildContext context) {
    final color = question.isCorrect
        ? const Color(0xFF16A34A)
        : const Color(0xFFE11D48);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        question.isCorrect ? 'Correct' : 'Wrong',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReviewOptionTile extends StatelessWidget {
  const _ReviewOptionTile({required this.question, required this.option});

  final ExamReviewQuestionModel question;
  final ExamOptionModel option;

  @override
  Widget build(BuildContext context) {
    final isSelected = question.selectedOptionId == option.id;
    final isCorrect = question.correctOptionId == option.id;
    final label = String.fromCharCode(64 + option.order);
    final color = isCorrect
        ? const Color(0xFF16A34A)
        : isSelected
        ? const Color(0xFFE11D48)
        : const Color(0xFF8A93A8);
    final bg = isCorrect
        ? const Color(0xFFE7F8EF)
        : isSelected
        ? const Color(0xFFFFE4E6)
        : const Color(0xFFF8FAFF);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              option.text,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isCorrect)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A))
          else if (isSelected)
            const Icon(Icons.cancel_rounded, color: Color(0xFFE11D48)),
        ],
      ),
    );
  }
}

class _ZoomableQuestionImage extends StatelessWidget {
  const _ZoomableQuestionImage({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          showDialog<void>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.88),
            builder: (_) => _QuestionImageViewerDialog(
              imageUrl: imageUrl,
              heroTag: heroTag,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Hero(
                tag: heroTag,
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in_map_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Tap to zoom',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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

class _QuestionImageViewerDialog extends StatefulWidget {
  const _QuestionImageViewerDialog({
    required this.imageUrl,
    required this.heroTag,
  });

  final String imageUrl;
  final String heroTag;

  @override
  State<_QuestionImageViewerDialog> createState() =>
      _QuestionImageViewerDialogState();
}

class _QuestionImageViewerDialogState
    extends State<_QuestionImageViewerDialog> {
  final TransformationController _controller = TransformationController();
  var _scale = 1.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setScale(double nextScale) {
    final clamped = nextScale.clamp(1.0, 4.0).toDouble();
    setState(() {
      _scale = clamped;
      _controller.value = Matrix4.identity()
        ..scaleByDouble(clamped, clamped, clamped, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: 4,
                panEnabled: true,
                clipBehavior: Clip.none,
                onInteractionEnd: (_) {
                  final scale = _controller.value.getMaxScaleOnAxis();
                  setState(() => _scale = scale.clamp(1.0, 4.0).toDouble());
                },
                child: Center(
                  child: Hero(
                    tag: widget.heroTag,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Pinch or use controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _ImageViewerButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ImageViewerButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: () => _setScale(_scale - 0.5),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 76,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${(_scale * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ImageViewerButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: () => _setScale(_scale + 0.5),
                    ),
                    const SizedBox(width: 10),
                    _ImageViewerButton(
                      icon: Icons.restart_alt_rounded,
                      tooltip: 'Reset zoom',
                      onPressed: () => _setScale(1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerButton extends StatelessWidget {
  const _ImageViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ExamHero extends StatelessWidget {
  const _ExamHero({required this.summary});

  final ExamSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0700A8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const _SoftIcon(icon: Icons.quiz_rounded, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Exams',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${summary.examCount} exam(s), ${summary.pendingCount} pending',
                  style: const TextStyle(
                    color: Color(0xFFD8DEFF),
                    fontWeight: FontWeight.w700,
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

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onStart});

  final ExamModel exam;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isSubmitted = exam.attempt.isSubmitted;
    final canOpen = !isSubmitted || exam.attempt.canViewResult;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: canOpen ? onStart : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SoftIcon(
                    icon: Icons.assignment_turned_in_rounded,
                    color: const Color(0xFF0700A8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111640),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exam.subject.name,
                          style: const TextStyle(
                            color: Color(0xFF69718A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.group_rounded, label: exam.batch.name),
                  _InfoChip(
                    icon: Icons.timer_rounded,
                    label: '${exam.durationMinutes} min',
                  ),
                  _InfoChip(
                    icon: Icons.help_rounded,
                    label: '${exam.questionCount} Q',
                  ),
                  _InfoChip(
                    icon: Icons.workspace_premium_rounded,
                    label: '${exam.totalMarks} marks',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(exam: exam),
                        if (isSubmitted) _ResultVisibilityPill(exam: exam),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: canOpen ? onStart : null,
                    child: Text(
                      isSubmitted
                          ? exam.attempt.canViewResult
                                ? 'Result'
                                : 'Result Pending'
                          : exam.attempt.isInProgress
                          ? 'Resume'
                          : 'Start',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptHeader extends StatelessWidget {
  const _AttemptHeader({
    required this.title,
    required this.remainingSeconds,
    required this.answered,
    required this.total,
  });

  final String title;
  final int remainingSeconds;
  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final isDanger = remainingSeconds <= 300;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0700A8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$answered of $total answered',
                  style: const TextStyle(
                    color: Color(0xFFD8DEFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDanger ? const Color(0xFFFFE4E6) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isDanger
                    ? const Color(0xFFE11D48)
                    : const Color(0xFF0700A8),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.selectedOptionId,
    required this.onSelect,
    required this.allowRoughWorkUploads,
    required this.isUploadingRoughWork,
    required this.roughWorkUploads,
    required this.deletingUploadIds,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onPreviewRoughWork,
    required this.onDeleteRoughWork,
  });

  final ExamQuestionModel question;
  final int? selectedOptionId;
  final ValueChanged<int> onSelect;
  final bool allowRoughWorkUploads;
  final bool isUploadingRoughWork;
  final List<ExamRoughWorkUploadModel> roughWorkUploads;
  final Set<int> deletingUploadIds;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final ValueChanged<ExamRoughWorkUploadModel> onPreviewRoughWork;
  final ValueChanged<ExamRoughWorkUploadModel> onDeleteRoughWork;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${question.order}',
            style: const TextStyle(
              color: Color(0xFF0700A8),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (question.text.isNotEmpty)
            Text(
              question.text,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (question.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ZoomableQuestionImage(
              imageUrl: question.imageUrl,
              heroTag: 'attempt-question-image-${question.id}',
            ),
          ],
          if (allowRoughWorkUploads) ...[
            const SizedBox(height: 16),
            _RoughWorkUploadPanel(
              isUploading: isUploadingRoughWork,
              uploads: roughWorkUploads,
              deletingUploadIds: deletingUploadIds,
              onPickCamera: onPickCamera,
              onPickGallery: onPickGallery,
              onPreview: onPreviewRoughWork,
              onDelete: onDeleteRoughWork,
            ),
          ],
          const SizedBox(height: 18),
          for (final option in question.options)
            _OptionTile(
              option: option,
              isSelected: selectedOptionId == option.id,
              onTap: () => onSelect(option.id),
            ),
        ],
      ),
    );
  }
}

class _RoughWorkUploadPanel extends StatelessWidget {
  const _RoughWorkUploadPanel({
    required this.isUploading,
    required this.uploads,
    required this.deletingUploadIds,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onPreview,
    required this.onDelete,
  });

  final bool isUploading;
  final List<ExamRoughWorkUploadModel> uploads;
  final Set<int> deletingUploadIds;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final ValueChanged<ExamRoughWorkUploadModel> onPreview;
  final ValueChanged<ExamRoughWorkUploadModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final countText = uploads.isEmpty
        ? 'No solution images uploaded'
        : uploads.length == 1
        ? '1 image uploaded'
        : '${uploads.length} images uploaded';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFE1E7F5)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.draw_rounded,
                  color: Color(0xFF0700A8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Solution / rough work',
                      style: TextStyle(
                        color: Color(0xFF111640),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      countText,
                      style: const TextStyle(
                        color: Color(0xFF69718A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUploading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
          if (uploads.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: uploads.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final upload = uploads[index];
                  return _RoughWorkThumb(
                    upload: upload,
                    isDeleting: deletingUploadIds.contains(upload.id),
                    onPreview: () => onPreview(upload),
                    onDelete: () => onDelete(upload),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onPickCamera,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onPickGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoughWorkThumb extends StatelessWidget {
  const _RoughWorkThumb({
    required this.upload,
    required this.isDeleting,
    required this.onPreview,
    required this.onDelete,
  });

  final ExamRoughWorkUploadModel upload;
  final bool isDeleting;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isDeleting ? null : onPreview,
                child: Hero(
                  tag: 'rough-work-upload-${upload.id}',
                  child: Image.network(
                    upload.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Color(0xFF69718A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'View',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: Material(
              color: const Color(0xFFFFE4E6),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isDeleting ? null : onDelete,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: isDeleting
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: Color(0xFFE11D48),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ExamOptionModel option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = String.fromCharCode(64 + option.order);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0700A8)
                    : const Color(0xFFE1E7F5),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isSelected
                      ? const Color(0xFF0700A8)
                      : const Color(0xFFE4E9F8),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF111640),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: const TextStyle(
                      color: Color(0xFF111640),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionStepper extends StatelessWidget {
  const _QuestionStepper({
    required this.count,
    required this.currentIndex,
    required this.answeredQuestionIds,
    required this.questions,
    required this.onSelect,
  });

  final int count;
  final int currentIndex;
  final Set<int> answeredQuestionIds;
  final List<ExamQuestionModel> questions;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < count; index++)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(index),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: currentIndex == index
                    ? const Color(0xFF0700A8)
                    : answeredQuestionIds.contains(questions[index].id)
                    ? const Color(0xFFDFFFE7)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: currentIndex == index
                      ? Colors.white
                      : const Color(0xFF111640),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    final label = _examAttemptStatusLabel(exam);
    final color = exam.attempt.isSubmitted
        ? const Color(0xFF16A34A)
        : const Color(0xFF0700A8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResultVisibilityPill extends StatelessWidget {
  const _ResultVisibilityPill({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    final isPublished = exam.attempt.canViewResult;
    final color = isPublished
        ? const Color(0xFF16A34A)
        : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPublished ? 'Result Published' : 'Result Pending',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _examAttemptStatusLabel(ExamModel exam) {
  if (exam.attempt.isSubmitted) {
    return 'Submitted';
  }
  if (exam.attempt.isInProgress) {
    return 'In Progress';
  }
  return 'Not Started';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0700A8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF0700A8),
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == Colors.white ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _NoExamCard extends StatelessWidget {
  const _NoExamCard({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.published_with_changes_rounded,
            color: Color(0xFF0700A8),
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text(
            'No published exams yet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 5),
          const Text(
            'When your teacher publishes an exam for this session, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF69718A)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check again'),
          ),
        ],
      ),
    );
  }
}

class _ExamLoadingView extends StatelessWidget {
  const _ExamLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ExamErrorView extends StatelessWidget {
  const _ExamErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
