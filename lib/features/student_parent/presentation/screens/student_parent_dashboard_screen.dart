import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/notifications/local_notification_service.dart';
import '../../../../core/notifications/notification_detail_screen.dart';
import '../../../../core/notifications/push_notification_route.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/fee_details_model.dart';
import '../../data/models/homework_planner_model.dart';
import '../../data/models/notice_model.dart';
import '../../data/models/push_notification_model.dart';
import '../../data/models/student_profile_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/fees_provider.dart';
import '../providers/homework_provider.dart';
import '../providers/notices_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/student_bootstrap_provider.dart';
import '../providers/student_profile_provider.dart';
import '../utils/binary_document_saver.dart';
import 'developer_details_screen.dart';
import 'document_viewer_screen.dart';
import 'student_exams_screen.dart';
import 'student_timetable_screen.dart';

final _brandAccessTokenProvider = FutureProvider<String>((ref) async {
  return await ref.watch(secureStorageServiceProvider).getAccessToken() ?? '';
});

class StudentParentDashboardScreen extends ConsumerStatefulWidget {
  const StudentParentDashboardScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<StudentParentDashboardScreen> createState() =>
      _StudentParentDashboardScreenState();
}

class _BackgroundUpdatingIndicator extends StatelessWidget {
  const _BackgroundUpdatingIndicator({required this.apiClient});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: apiClient.backgroundRefreshes,
      builder: (context, activeRefreshes, _) {
        final isUpdating = activeRefreshes.any(
          (key) => key.contains('/api/mobile/'),
        );
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          reverseDuration: const Duration(milliseconds: 140),
          child: isUpdating
              ? IgnorePointer(
                  key: const ValueKey('updating'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDDE4F5)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x160A1B60),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF21B6E8),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Updating...',
                          style: TextStyle(
                            color: Color(0xFF59647E),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('idle')),
        );
      },
    );
  }
}

class _StudentParentDashboardScreenState
    extends ConsumerState<StudentParentDashboardScreen> {
  static const _accountIndex = 99;
  static const _settingsIndex = 98;
  int _selectedIndex = 0;
  final List<int> _selectedIndexHistory = [];
  DateTime? _lastBackPressedAt;
  var _isPushRegistered = false;
  bool _isLoggingOut = false;
  bool _isNavigationMenuOpen = false;
  late final ApiClient _apiClient;
  Set<String> _activeBackgroundRefreshes = const {};

  static const _destinations = [
    _Destination('Dashboard', Icons.dashboard_rounded),
    _Destination('Attendance', Icons.fact_check_rounded),
    _Destination('Fees', Icons.account_balance_wallet_rounded),
    _Destination('Homework', Icons.assignment_rounded),
    _Destination('Exams', Icons.quiz_rounded),
    _Destination('Results', Icons.workspace_premium_rounded),
    _Destination('Reports', Icons.analytics_rounded),
    _Destination('Timetable', Icons.calendar_month_rounded),
    _Destination('Notices', Icons.campaign_rounded),
    _Destination('Profile', Icons.badge_rounded),
    _Destination('Teachers', Icons.forum_rounded),
    _Destination('Notifications', Icons.notifications_rounded),
    _Destination('Documents', Icons.folder_copy_rounded),
  ];

  static const _mobileDestinations = [0, 1, 2, 3, 4, 9];

  @override
  void initState() {
    super.initState();
    _apiClient = ref.read(apiClientProvider);
    _activeBackgroundRefreshes = {..._apiClient.backgroundRefreshes.value};
    _apiClient.backgroundRefreshes.addListener(
      _handleBackgroundRefreshesChanged,
    );
    Future<void>.microtask(() {
      ref.read(studentBootstrapProvider(null).future);
      _registerPushDevice();
    });
  }

  @override
  void dispose() {
    _apiClient.backgroundRefreshes.removeListener(
      _handleBackgroundRefreshesChanged,
    );
    super.dispose();
  }

  void _handleBackgroundRefreshesChanged() {
    final current = {..._apiClient.backgroundRefreshes.value};
    final completed = _activeBackgroundRefreshes.difference(current);
    _activeBackgroundRefreshes = current;
    if (completed.isEmpty || !mounted) {
      return;
    }
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      for (final cacheKey in completed) {
        if (_apiClient.hasFreshCachedResponse(cacheKey)) {
          _invalidateProviderForRefreshedCache(cacheKey);
        }
      }
    });
  }

  void _invalidateProviderForRefreshedCache(String cacheKey) {
    if (cacheKey.contains('/api/mobile/bootstrap/')) {
      ref.invalidate(studentBootstrapProvider);
    } else if (cacheKey.contains('/api/mobile/fees/')) {
      ref.invalidate(feeDetailsProvider);
    } else if (cacheKey.contains('/api/mobile/attendance/')) {
      ref.invalidate(attendanceProvider);
    } else if (cacheKey.contains('/api/mobile/homework/')) {
      ref.invalidate(homeworkPlannerProvider);
    } else if (cacheKey.contains('/api/mobile/notices/')) {
      ref.invalidate(noticesProvider);
    } else if (cacheKey.contains('/api/mobile/exams/')) {
      ref.invalidate(examsProvider);
    } else if (cacheKey.contains('/api/mobile/profile/')) {
      ref.invalidate(studentProfileProvider);
      ref.invalidate(effectiveAcademicSessionIdProvider);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() => _isLoggingOut = true);
    try {
      try {
        await ref
            .read(pushNotificationServiceProvider)
            .unregisterCurrentDevice()
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Local logout must not be blocked by Firebase or network cleanup.
      }
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      // AuthNotifier clears local state in finally, so the auth gate still exits.
    }
  }

  void _select(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndexHistory.remove(index);
      _selectedIndexHistory.add(_selectedIndex);
      _selectedIndex = index;
    });
  }

  void _setNavigationMenuOpen(bool isOpen) {
    if (_isNavigationMenuOpen == isOpen || !mounted) {
      return;
    }
    setState(() => _isNavigationMenuOpen = isOpen);
  }

  void _handleBackNavigation() {
    if (_selectedIndexHistory.isNotEmpty) {
      setState(() => _selectedIndex = _selectedIndexHistory.removeLast());
      return;
    }
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressedAt = now;
    showAppNotification(
      context,
      title: 'Exit application',
      message: 'Press back again to exit.',
      type: AppNotificationType.info,
      duration: const Duration(seconds: 2),
    );
  }

  void _openDeveloperDetails() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DeveloperDetailsScreen()),
    );
  }

  Future<void> _refreshData() async {
    if (_selectedIndex == 0) {
      ref
          .read(apiClientProvider)
          .clearGetCache(contains: '/api/mobile/bootstrap/');
      final sessionId = ref.read(selectedAcademicSessionIdProvider);
      final refreshed = ref.refresh(studentBootstrapProvider(sessionId).future);
      await refreshed;
      return;
    }
    if (_selectedIndex == 3) {
      await refreshHomeworkPlanner(ref);
      return;
    }
    if (_selectedIndex == 4 || _selectedIndex == 5) {
      await refreshPublishedExams(ref);
      return;
    }
    await _refreshStudentParentData(ref);
    if (!_isPushRegistered) {
      await _registerPushDevice();
    }
  }

  Future<bool> _registerPushDevice() async {
    if (_isPushRegistered) {
      return true;
    }
    final pushEnabled = await ref
        .read(secureStorageServiceProvider)
        .getPushNotificationsEnabled();
    if (!pushEnabled) {
      return false;
    }
    final registered = await ref
        .read(pushNotificationServiceProvider)
        .registerCurrentDevice(
          onDataChanged: _refreshChangedDataFromPush,
          onNotificationOpened: _openPageFromPush,
        )
        .catchError((_) => false);
    if (registered && mounted) {
      setState(() => _isPushRegistered = true);
    }
    return registered;
  }

  Future<void> _unregisterPushDevice() async {
    await ref.read(pushNotificationServiceProvider).unregisterCurrentDevice();
    if (mounted) {
      setState(() => _isPushRegistered = false);
    }
  }

  void _openPageFromPush(Map<String, dynamic> data) {
    if (!mounted) {
      return;
    }
    final page = notificationPageForData(data);
    _markPushNotificationRead(data);
    if (page == PushNotificationPage.notices) {
      _markPushNoticeRead(data);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailScreen(
          data: data,
          loadDetails: page == PushNotificationPage.notices
              ? () => _loadNoticeNotificationDetails(data)
              : null,
          onOpenSection: () => _openNotificationDestination(data, page),
        ),
      ),
    );
  }

  Future<void> _openNotificationDestination(
    Map<String, dynamic> data,
    PushNotificationPage page,
  ) async {
    if (page == PushNotificationPage.results) {
      final opened = await _openResultFromNotification(data);
      if (opened) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    _select(page.dashboardIndex);
  }

  Future<bool> _openResultFromNotification(Map<String, dynamic> data) async {
    final attemptId = int.tryParse(data['attempt_id']?.toString() ?? '');
    if (attemptId == null) {
      return false;
    }
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await ref
          .read(examRepositoryProvider)
          .fetchResultReview(attemptId);
      if (!mounted) {
        return true;
      }
      navigator.pop();
      navigator.pop();
      await showDialog<void>(
        context: context,
        builder: (_) => ResultReviewDialog(result: result),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return true;
      }
      navigator.pop();
      showAppNotification(
        context,
        title: 'Unable to load result',
        message: error.toString(),
        type: AppNotificationType.error,
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> _loadNoticeNotificationDetails(
    Map<String, dynamic> data,
  ) async {
    final noticeId = int.tryParse(data['notice_id']?.toString() ?? '');
    if (noticeId == null) {
      return data;
    }
    final notice = await ref
        .read(noticesRepositoryProvider)
        .fetchNotice(noticeId);
    return notice.notificationDetailData;
  }

  Future<void> _markPushNotificationRead(Map<String, dynamic> data) async {
    final notificationId = int.tryParse(
      data['notification_id']?.toString() ?? '',
    );
    if (notificationId != null) {
      final optimisticIds = ref.read(
        optimisticallyReadNotificationIdsProvider.notifier,
      );
      optimisticIds.state = {...optimisticIds.state, notificationId};
    }
    try {
      await ref.read(notificationsRepositoryProvider).markRead(data);
      final refreshed = ref.refresh(notificationsProvider.future);
      await refreshed;
    } catch (_) {
      if (notificationId != null) {
        final optimisticIds = ref.read(
          optimisticallyReadNotificationIdsProvider.notifier,
        );
        optimisticIds.state = {...optimisticIds.state}..remove(notificationId);
      }
    }
  }

  Future<void> _markPushNoticeRead(Map<String, dynamic> data) async {
    final noticeId = int.tryParse(data['notice_id']?.toString() ?? '');
    if (noticeId == null) {
      return;
    }
    try {
      await ref.read(noticesRepositoryProvider).markRead(noticeId);
      ref
          .read(apiClientProvider)
          .clearGetCache(contains: '/api/mobile/bootstrap/');
      ref.invalidate(studentBootstrapProvider);
      final refreshedNotices = ref.refresh(noticesProvider.future);
      await refreshedNotices;
    } catch (_) {
      // The notice still opens; its unread state can retry on the next sync.
    }
  }

  Future<void> _refreshChangedDataFromPush(Map<String, dynamic> data) async {
    if (!mounted) {
      return;
    }
    final apiClient = ref.read(apiClientProvider);
    apiClient.clearGetCache(contains: '/api/mobile/notifications/');
    ref.invalidate(notificationsProvider);
    final target = _pushRefreshTarget(data);
    if (target == null) {
      return;
    }
    try {
      apiClient.clearGetCache(contains: target.cachePath);
      apiClient.clearGetCache(contains: '/api/mobile/bootstrap/');
      ref.invalidate(studentBootstrapProvider);

      late final Future<dynamic> refreshed;
      switch (target) {
        case _PushRefreshTarget.fees:
          refreshed = ref.refresh(feeDetailsProvider.future);
        case _PushRefreshTarget.attendance:
          refreshed = ref.refresh(attendanceProvider.future);
        case _PushRefreshTarget.homework:
          refreshed = ref.refresh(homeworkPlannerProvider.future);
        case _PushRefreshTarget.notices:
          refreshed = ref.refresh(noticesProvider.future);
        case _PushRefreshTarget.exams:
          refreshed = ref.refresh(examsProvider.future);
        case _PushRefreshTarget.profile:
          ref.invalidate(effectiveAcademicSessionIdProvider);
          refreshed = ref.refresh(studentProfileProvider.future);
      }
      await refreshed;
    } catch (_) {
      // Provider error states will render on their respective pages.
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 980;
    final title = switch (_selectedIndex) {
      _accountIndex => 'Account',
      _settingsIndex => 'Settings',
      _ => _destinations[_selectedIndex].label,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF0FF),
        body: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  if (isDesktop)
                    _DesktopSidebar(
                      user: widget.user,
                      selectedIndex: _selectedIndex,
                      destinations: _destinations,
                      onSelect: _select,
                      onLogout: _logout,
                      onBrandTap: _openDeveloperDetails,
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshData,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _DashboardHeader(
                              user: widget.user,
                              title: title,
                              isDesktop: isDesktop,
                              selectedIndex: _selectedIndex,
                              onSelect: _select,
                              onLogout: _logout,
                              onBrandTap: _openDeveloperDetails,
                              onMenuOpened: () => _setNavigationMenuOpen(true),
                              onMenuClosed: () => _setNavigationMenuOpen(false),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              isDesktop ? 30 : 18,
                              isDesktop ? 24 : 18,
                              isDesktop ? 30 : 18,
                              isDesktop ? 30 : 150,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _DashboardBody(
                                  key: ValueKey(_selectedIndex),
                                  selectedIndex: _selectedIndex,
                                  user: widget.user,
                                  onSelect: _select,
                                  onLogout: _logout,
                                  onEnablePush: _registerPushDevice,
                                  onDisablePush: _unregisterPushDevice,
                                  onOpenNotification: _openPageFromPush,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isNavigationMenuOpen)
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: const Color(0xFF101242).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: isDesktop ? 22 : 224,
                right: isDesktop ? 30 : 22,
                child: _BackgroundUpdatingIndicator(
                  apiClient: ref.watch(apiClientProvider),
                ),
              ),
              if (!isDesktop)
                Positioned(
                  right: 24,
                  bottom: 18,
                  child: _FloatingNoticeShortcut(
                    isSelected: _selectedIndex == 8,
                    onTap: () => _select(8),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: isDesktop
            ? null
            : _MobileBottomNav(
                selectedIndex: _selectedIndex,
                destinations: _mobileDestinations,
                onSelect: _select,
              ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.user,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
    required this.onLogout,
    required this.onBrandTap,
  });

  final UserModel user;
  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onBrandTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0700A8),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33101A70),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: 170,
                  height: 360,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BrandLockup(
                          size: 48,
                          isOnDark: true,
                          showSubtitle: true,
                          onTap: onBrandTap,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final item = destinations[index];
                      final isSelected = selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _SidebarItem(
                          label: item.label,
                          icon: item.icon,
                          isSelected: isSelected,
                          onTap: () => onSelect(index),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SidebarProfile(user: user),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: onLogout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Logout'),
                        ),
                      ),
                    ],
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0700A8) : Colors.white,
                size: 22,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0700A8) : Colors.white,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarProfile extends StatelessWidget {
  const _SidebarProfile({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _Avatar(user: user, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(user),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Institute ${user.instituteId}',
                  style: const TextStyle(
                    color: Color(0xFFC8D0FF),
                    fontSize: 12,
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

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({
    required this.user,
    required this.title,
    required this.isDesktop,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.onBrandTap,
    required this.onMenuOpened,
    required this.onMenuClosed,
  });

  final UserModel user;
  final String title;
  final bool isDesktop;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onBrandTap;
  final VoidCallback onMenuOpened;
  final VoidCallback onMenuClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF101242),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live student-parent workspace for ${_displayName(user)}',
                    style: const TextStyle(
                      color: Color(0xFF65708A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _SearchBox(),
            const SizedBox(width: 14),
            const _SessionSelector(isOnDark: false),
            const SizedBox(width: 10),
            _HeaderIconButton(
              tooltip: 'Notifications',
              icon: Icons.notifications_none_rounded,
              onTap: () => onSelect(11),
            ),
            const SizedBox(width: 10),
            _AccountMenuWithDeveloperButton(
              user: user,
              selectedIndex: selectedIndex,
              onSelect: onSelect,
              onLogout: onLogout,
              onDeveloperTap: onBrandTap,
              onMenuOpened: onMenuOpened,
              onMenuClosed: onMenuClosed,
            ),
          ],
        ),
      );
    }

    return _MobileHeader(
      user: user,
      title: title,
      selectedIndex: selectedIndex,
      onSelect: onSelect,
      onLogout: onLogout,
      onBrandTap: onBrandTap,
      onMenuOpened: onMenuOpened,
      onMenuClosed: onMenuClosed,
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.user,
    required this.title,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.onBrandTap,
    required this.onMenuOpened,
    required this.onMenuClosed,
  });

  final UserModel user;
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onBrandTap;
  final VoidCallback onMenuOpened;
  final VoidCallback onMenuClosed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0700A8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33101A70),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              top: -88,
              right: -35,
              child: Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: 160,
                  height: 380,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -90,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFF29C7F6).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _BrandLockup(
                          size: 42,
                          isOnDark: true,
                          showSubtitle: false,
                          onTap: onBrandTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _SessionSelector(isOnDark: true),
                      const SizedBox(width: 8),
                      _AccountMenu(
                        user: user,
                        selectedIndex: selectedIndex,
                        onSelect: onSelect,
                        onLogout: onLogout,
                        isOnDark: true,
                        onMenuOpened: onMenuOpened,
                        onMenuClosed: onMenuClosed,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Last update ${_todayLabel()}',
                    style: const TextStyle(
                      color: Color(0xFFC8D0FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _displayName(user),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 22,
              top: 67,
              child: _DeveloperDetailsIconButton(
                onTap: onBrandTap,
                isOnDark: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    super.key,
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
    required this.onLogout,
    required this.onEnablePush,
    required this.onDisablePush,
    required this.onOpenNotification,
  });

  final int selectedIndex;
  final UserModel user;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final Future<bool> Function() onEnablePush;
  final Future<void> Function() onDisablePush;
  final ValueChanged<Map<String, dynamic>> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == _StudentParentDashboardScreenState._accountIndex) {
      return _AccountPage(user: user, onLogout: onLogout);
    }

    if (selectedIndex == _StudentParentDashboardScreenState._settingsIndex) {
      return _SettingsPage(
        user: user,
        onLogout: onLogout,
        onEnablePush: onEnablePush,
        onDisablePush: onDisablePush,
      );
    }

    if (selectedIndex == 0) {
      return _DashboardOverview(user: user, onSelect: onSelect);
    }

    if (selectedIndex == 2) {
      return const _FeesPage();
    }

    if (selectedIndex == 1) {
      return const _AttendancePage();
    }

    if (selectedIndex == 3) {
      return const _HomeworkPlannerPage();
    }

    if (selectedIndex == 4) {
      return const StudentExamsScreen();
    }

    if (selectedIndex == 5) {
      return const _ResultsPage();
    }

    if (selectedIndex == 7) {
      return const StudentTimetableScreen();
    }

    if (selectedIndex == 8) {
      return const _NoticesPage();
    }

    if (selectedIndex == 9) {
      return const _StudentProfilePage();
    }

    if (selectedIndex == 12) {
      return const _StudentDocumentsPage();
    }

    if (selectedIndex == 11) {
      return _NotificationsPage(onOpenNotification: onOpenNotification);
    }

    return _FeaturePage(data: _FeatureCatalog.items[selectedIndex - 1]);
  }
}

class _NotificationsPage extends ConsumerWidget {
  const _NotificationsPage({required this.onOpenNotification});

  final ValueChanged<Map<String, dynamic>> onOpenNotification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final optimisticReadIds = ref.watch(
      optimisticallyReadNotificationIdsProvider,
    );
    return notifications.when(
      loading: () => const _ProfileLoadingView(title: 'Notifications'),
      error: (error, _) => _ProfileErrorView(
        title: 'Could not load notifications',
        message: error.toString(),
        onRetry: () {
          ref
              .read(apiClientProvider)
              .clearGetCache(contains: '/api/mobile/notifications/');
          ref.invalidate(notificationsProvider);
        },
      ),
      data: (data) => _NotificationsContent(
        data: data,
        optimisticReadIds: optimisticReadIds,
        onOpenNotification: onOpenNotification,
        onRefresh: () async {
          ref
              .read(apiClientProvider)
              .clearGetCache(contains: '/api/mobile/notifications/');
          final refreshed = ref.refresh(notificationsProvider.future);
          await refreshed;
        },
      ),
    );
  }
}

class _NotificationsContent extends StatelessWidget {
  const _NotificationsContent({
    required this.data,
    required this.optimisticReadIds,
    required this.onOpenNotification,
    required this.onRefresh,
  });

  final PushNotificationFeedModel data;
  final Set<int> optimisticReadIds;
  final ValueChanged<Map<String, dynamic>> onOpenNotification;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final optimisticUnreadReduction = data.notifications
        .where(
          (notification) =>
              !notification.isRead &&
              optimisticReadIds.contains(notification.id),
        )
        .length;
    final unreadCount = (data.unreadCount - optimisticUnreadReduction).clamp(
      0,
      data.unreadCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SoftCard(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const _IconBadge(
                icon: Icons.notifications_active_rounded,
                color: Color(0xFFE11D48),
                size: 62,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Center',
                      style: TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$unreadCount unread of ${data.totalCount} notifications',
                      style: const TextStyle(
                        color: Color(0xFF65708A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh notifications',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SoftCard(
          padding: const EdgeInsets.all(18),
          child: data.notifications.isEmpty
              ? const _EmptyLine(text: 'No notifications received yet.')
              : Column(
                  children: [
                    for (final notification in data.notifications)
                      _NotificationFeedCard(
                        notification: notification,
                        isRead:
                            notification.isRead ||
                            optimisticReadIds.contains(notification.id),
                        onTap: () =>
                            onOpenNotification(notification.detailData),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NotificationFeedCard extends StatelessWidget {
  const _NotificationFeedCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final PushNotificationItemModel notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final page = notificationPageForData(notification.detailData);
    final data = notification.detailData;
    final logoUrl = data['institute_logo_url']?.toString().trim() ?? '';
    final instituteName = data['institute_name']?.toString().trim() ?? '';
    final highlights = _notificationHighlights(data, page);
    final (icon, color, label) = switch (page) {
      PushNotificationPage.fees => (
        Icons.account_balance_wallet_rounded,
        const Color(0xFF16A34A),
        'Fees',
      ),
      PushNotificationPage.notices => (
        Icons.campaign_rounded,
        const Color(0xFFE11D48),
        'Notice',
      ),
      PushNotificationPage.results => (
        Icons.workspace_premium_rounded,
        const Color(0xFF7C3AED),
        'Result',
      ),
      PushNotificationPage.exams => (
        Icons.quiz_rounded,
        const Color(0xFFDC2626),
        'Exam',
      ),
      _ => (Icons.notifications_rounded, const Color(0xFF0700A8), 'Update'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead
                ? const Color(0xFFF8FAFF)
                : color.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? const Color(0xFFDDE4F7)
                  : color.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationLogoBadge(
                logoUrl: logoUrl,
                fallbackIcon: icon,
                color: color,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (instituteName.isNotEmpty)
                                Text(
                                  instituteName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              Text(
                                notification.title,
                                style: const TextStyle(
                                  color: Color(0xFF111640),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF76809B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (highlights.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final highlight in highlights)
                            _NotificationHighlightChip(
                              label: highlight.label,
                              value: highlight.value,
                              icon: highlight.icon,
                              color: color,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF65708A),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(label: label, color: color),
                        _StatusPill(
                          label: isRead ? 'Read' : 'Unread',
                          color: isRead
                              ? const Color(0xFF64748B)
                              : const Color(0xFFE11D48),
                        ),
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: _formatDate(notification.createdAt),
                        ),
                      ],
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

class _NotificationLogoBadge extends StatelessWidget {
  const _NotificationLogoBadge({
    required this.logoUrl,
    required this.fallbackIcon,
    required this.color,
  });

  final String logoUrl;
  final IconData fallbackIcon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: logoUrl.isEmpty
          ? Icon(fallbackIcon, color: color, size: 27)
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(fallbackIcon, color: color, size: 27),
              ),
            ),
    );
  }
}

class _NotificationHighlightChip extends StatelessWidget {
  const _NotificationHighlightChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFact {
  const _NotificationFact(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

List<_NotificationFact> _notificationHighlights(
  Map<String, dynamic> data,
  PushNotificationPage page,
) {
  final highlights = <_NotificationFact>[];
  switch (page) {
    case PushNotificationPage.fees:
      final amount = data['amount']?.toString().trim() ?? '';
      final receipt = data['receipt_number']?.toString().trim() ?? '';
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
      final marks = data['marks_obtained']?.toString().trim() ?? '';
      final total = data['total_marks']?.toString().trim() ?? '';
      if (marks.isNotEmpty && total.isNotEmpty) {
        highlights.add(
          _NotificationFact(Icons.score_rounded, 'Marks', '$marks/$total'),
        );
      }
    default:
      break;
  }
  return highlights;
}

class _DashboardOverview extends ConsumerWidget {
  const _DashboardOverview({required this.user, required this.onSelect});

  final UserModel user;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(selectedAcademicSessionIdProvider);
    final bootstrap = ref.watch(studentBootstrapProvider(sessionId));
    final attendance = bootstrap.whenData((data) => data.recentAttendance);
    final fees = bootstrap.whenData((data) => data.feeSummary);
    final homework = bootstrap.whenData((data) => data.recentHomework);
    final notices = bootstrap.whenData((data) => data.notices);
    final exams = bootstrap.whenData((data) => data.upcomingExams);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TodayFocusCard(
              homework: homework.asData?.value,
              notices: notices.asData?.value,
              fees: fees.asData?.value,
              isLoading:
                  homework.isLoading || notices.isLoading || fees.isLoading,
            ),
            const SizedBox(height: 18),
            _MetricStrip(
              isWide: isWide,
              attendance: attendance,
              fees: fees,
              homework: homework,
              notices: notices,
            ),
            const SizedBox(height: 18),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _FeatureTiles(
                      onSelect: onSelect,
                      attendance: attendance,
                      fees: fees,
                      homework: homework,
                      exams: exams,
                      notices: notices,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 4,
                    child: _ActivityTimeline(
                      attendance: attendance.asData?.value,
                      fees: fees.asData?.value,
                      homework: homework.asData?.value,
                      notices: notices.asData?.value,
                      isLoading:
                          attendance.isLoading ||
                          fees.isLoading ||
                          homework.isLoading ||
                          notices.isLoading,
                    ),
                  ),
                ],
              )
            else ...[
              _FeatureTiles(
                onSelect: onSelect,
                attendance: attendance,
                fees: fees,
                homework: homework,
                exams: exams,
                notices: notices,
              ),
              const SizedBox(height: 16),
              _ActivityTimeline(
                attendance: attendance.asData?.value,
                fees: fees.asData?.value,
                homework: homework.asData?.value,
                notices: notices.asData?.value,
                isLoading:
                    attendance.isLoading ||
                    fees.isLoading ||
                    homework.isLoading ||
                    notices.isLoading,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TodayFocusCard extends StatelessWidget {
  const _TodayFocusCard({
    required this.homework,
    required this.notices,
    required this.fees,
    required this.isLoading,
  });

  final HomeworkPlannerModel? homework;
  final NoticeBoardModel? notices;
  final FeeDetailsModel? fees;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final focusRows = _buildFocusRows(
      homework: homework,
      notices: notices,
      fees: fees,
      isLoading: isLoading,
    );

    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _IconBadge(
                icon: Icons.event_available_rounded,
                color: Color(0xFF21B6E8),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Today focus',
                  style: TextStyle(
                    color: Color(0xFF111640),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final row in focusRows)
            _FocusRow(
              color: row.color,
              title: row.title,
              subtitle: row.subtitle,
            ),
        ],
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF76809B),
                    fontWeight: FontWeight.w600,
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

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.isWide,
    required this.attendance,
    required this.fees,
    required this.homework,
    required this.notices,
  });

  final bool isWide;
  final AsyncValue<AttendanceModel> attendance;
  final AsyncValue<FeeDetailsModel> fees;
  final AsyncValue<HomeworkPlannerModel> homework;
  final AsyncValue<NoticeBoardModel> notices;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        'Attendance',
        _attendanceMetricValue(attendance),
        _attendanceMetricCaption(attendance),
        Icons.trending_up_rounded,
        const Color(0xFF21B6E8),
      ),
      _Metric(
        'Fees',
        _feesMetricValue(fees),
        _feesMetricCaption(fees),
        Icons.verified_rounded,
        const Color(0xFF36C321),
      ),
      _Metric(
        'Homework',
        _homeworkMetricValue(homework),
        _homeworkMetricCaption(homework),
        Icons.edit_note_rounded,
        const Color(0xFFFF8B3D),
      ),
      _Metric(
        'Alerts',
        _noticeMetricValue(notices),
        _noticeMetricCaption(notices),
        Icons.notifications_active_rounded,
        const Color(0xFFFF5D8F),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isWide
            ? 4
            : constraints.maxWidth < 330
            ? 1
            : 2;
        final childAspectRatio = isWide
            ? 1.55
            : crossAxisCount == 1
            ? 2.05
            : constraints.maxWidth < 380
            ? 1.08
            : 1.18;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            return _MetricCard(metric: metrics[index]);
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 168;
        final badgeSize = isCompact ? 42.0 : 48.0;
        return _SoftCard(
          padding: EdgeInsets.all(isCompact ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                icon: metric.icon,
                color: metric.color,
                size: badgeSize,
              ),
              const Spacer(),
              _MetricValueText(value: metric.value, isCompact: isCompact),
              const SizedBox(height: 4),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF111640),
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF76809B),
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 11 : 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricValueText extends StatelessWidget {
  const _MetricValueText({required this.value, required this.isCompact});

  final String value;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xFF111640),
            fontSize: isCompact ? 24 : 27,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _FeatureTiles extends StatelessWidget {
  const _FeatureTiles({
    required this.onSelect,
    required this.attendance,
    required this.fees,
    required this.homework,
    required this.exams,
    required this.notices,
  });

  final ValueChanged<int> onSelect;
  final AsyncValue<AttendanceModel> attendance;
  final AsyncValue<FeeDetailsModel> fees;
  final AsyncValue<HomeworkPlannerModel> homework;
  final AsyncValue<ExamListModel> exams;
  final AsyncValue<NoticeBoardModel> notices;

  @override
  Widget build(BuildContext context) {
    final badges = _buildFeatureBadges(
      attendance: attendance,
      fees: fees,
      homework: homework,
      exams: exams,
      notices: notices,
    );
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Student services',
            subtitle: 'Tap a module to manage details',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _FeatureCatalog.items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final item = _FeatureCatalog.items[index];
                  return _FeatureTile(
                    item: item,
                    badge: badges[item.title] ?? item.badge,
                    onTap: () => onSelect(index + 1),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.item,
    required this.badge,
    required this.onTap,
  });

  final _Feature item;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120A1B60),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(item.icon, color: item.color, size: 34),
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A94AD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({
    required this.attendance,
    required this.fees,
    required this.homework,
    required this.notices,
    required this.isLoading,
  });

  final AttendanceModel? attendance;
  final FeeDetailsModel? fees;
  final HomeworkPlannerModel? homework;
  final NoticeBoardModel? notices;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final activities = _buildActivities(
      attendance: attendance,
      fees: fees,
      homework: homework,
      notices: notices,
      isLoading: isLoading,
    );

    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Recent updates',
            subtitle: 'Latest activity from school',
          ),
          const SizedBox(height: 18),
          for (final activity in activities)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: activity.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activity.color.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            color: Color(0xFF111640),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          activity.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF76809B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

List<_Activity> _buildFocusRows({
  required HomeworkPlannerModel? homework,
  required NoticeBoardModel? notices,
  required FeeDetailsModel? fees,
  required bool isLoading,
}) {
  if (isLoading && homework == null && notices == null && fees == null) {
    return const [
      _Activity(
        'Loading homework',
        'Fetching latest assignments',
        Color(0xFF21B6E8),
      ),
      _Activity('Loading fees', 'Checking payment status', Color(0xFF36C321)),
      _Activity(
        'Loading notices',
        'Syncing institute updates',
        Color(0xFFFF5D8F),
      ),
    ];
  }

  final rows = <_Activity>[];
  final nextHomework = homework?.homework.isNotEmpty == true
      ? homework!.homework.first
      : null;
  final latestNotice = notices?.notices.isNotEmpty == true
      ? notices!.notices.first
      : null;
  final dueFee = fees?.fees.where((fee) => fee.dueAmount > 0).toList()
    ?..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  if (nextHomework != null) {
    rows.add(
      _Activity(
        nextHomework.title.isEmpty ? 'Homework assigned' : nextHomework.title,
        '${_homeworkSubjectCourseLabel(nextHomework)} - Due ${_formatDate(nextHomework.dueDate)}',
        const Color(0xFF21B6E8),
      ),
    );
  }

  if (dueFee != null && dueFee.isNotEmpty) {
    final fee = dueFee.first;
    rows.add(
      _Activity(
        '${fee.title} due',
        '${_formatCurrency(fee.dueAmount)} pending${fee.dueDate.isEmpty ? '' : ' - Due ${_formatDate(fee.dueDate)}'}',
        const Color(0xFFFF8B3D),
      ),
    );
  } else if (fees != null) {
    rows.add(
      _Activity(
        'Fees clear',
        '${_formatCurrency(fees.summary.totalPaidAmount)} paid',
        const Color(0xFF36C321),
      ),
    );
  }

  if (latestNotice != null) {
    rows.add(
      _Activity(
        latestNotice.title.isEmpty ? 'Institute notice' : latestNotice.title,
        '${latestNotice.categoryLabel} - ${latestNotice.isRead ? 'Read' : 'Unread'}',
        _noticePriorityColor(latestNotice.priority),
      ),
    );
  }

  if (rows.isEmpty) {
    rows.add(
      const _Activity(
        'All caught up',
        'No homework, notices or fee follow-ups right now',
        Color(0xFF36C321),
      ),
    );
  }

  return rows.take(3).toList();
}

List<_Activity> _buildActivities({
  required AttendanceModel? attendance,
  required FeeDetailsModel? fees,
  required HomeworkPlannerModel? homework,
  required NoticeBoardModel? notices,
  required bool isLoading,
}) {
  if (isLoading &&
      attendance == null &&
      fees == null &&
      homework == null &&
      notices == null) {
    return const [
      _Activity(
        'Loading dashboard',
        'Getting latest institute data',
        Color(0xFF21B6E8),
      ),
    ];
  }

  final activities = <_Activity>[];
  final latestHomework = homework?.homework.isNotEmpty == true
      ? homework!.homework.first
      : null;
  final latestPayment = fees?.paymentHistory.isNotEmpty == true
      ? fees!.paymentHistory.first
      : null;
  final latestAttendance = attendance?.records.isNotEmpty == true
      ? attendance!.records.first
      : null;
  final latestNotice = notices?.notices.isNotEmpty == true
      ? notices!.notices.first
      : null;

  if (latestHomework != null) {
    activities.add(
      _Activity(
        latestHomework.title.isEmpty
            ? 'Homework updated'
            : latestHomework.title,
        '${_homeworkSubjectCourseLabel(latestHomework)} - ${latestHomework.teacherName.isEmpty ? 'Teacher update' : latestHomework.teacherName}',
        const Color(0xFF21B6E8),
      ),
    );
  }

  if (latestPayment != null) {
    activities.add(
      _Activity(
        'Payment recorded',
        '${_formatCurrency(latestPayment.amount)} for ${latestPayment.invoiceTitle}',
        const Color(0xFF36C321),
      ),
    );
  } else if (fees != null && fees.summary.totalDueAmount > 0) {
    activities.add(
      _Activity(
        'Fee follow-up',
        '${_formatCurrency(fees.summary.totalDueAmount)} pending',
        const Color(0xFFFF8B3D),
      ),
    );
  }

  if (latestAttendance != null) {
    activities.add(
      _Activity(
        'Attendance ${_formatCodeLabel(latestAttendance.status)}',
        '${_formatDate(latestAttendance.date)} - ${latestAttendance.batch.name}',
        _attendanceStatusColor(latestAttendance.status),
      ),
    );
  }

  if (latestNotice != null) {
    activities.add(
      _Activity(
        latestNotice.title.isEmpty ? 'Notice published' : latestNotice.title,
        '${latestNotice.priorityLabel} - ${latestNotice.categoryLabel}',
        _noticePriorityColor(latestNotice.priority),
      ),
    );
  }

  if (activities.isEmpty) {
    activities.add(
      const _Activity(
        'No recent updates',
        'Your dashboard will update when new records arrive',
        Color(0xFF76809B),
      ),
    );
  }

  return activities.take(4).toList();
}

String _attendanceMetricValue(AsyncValue<AttendanceModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Retry' : '...';
  }
  return '${_formatPercent(data.summary.attendanceRate)}%';
}

String _attendanceMetricCaption(AsyncValue<AttendanceModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Could not load' : 'Loading';
  }
  return '${data.summary.attendedCount}/${data.summary.totalCount} attended';
}

String _feesMetricValue(AsyncValue<FeeDetailsModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Retry' : '...';
  }
  return data.summary.totalDueAmount <= 0
      ? 'Clear'
      : _formatCurrency(data.summary.totalDueAmount);
}

String _feesMetricCaption(AsyncValue<FeeDetailsModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Could not load' : 'Loading';
  }
  return data.summary.totalDueAmount <= 0
      ? '${_formatCurrency(data.summary.totalPaidAmount)} paid'
      : 'Pending due amount';
}

String _homeworkMetricValue(AsyncValue<HomeworkPlannerModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Retry' : '...';
  }
  return data.summary.homeworkCount.toString();
}

String _homeworkMetricCaption(AsyncValue<HomeworkPlannerModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Could not load' : 'Loading';
  }
  return '${data.summary.subjectCount} subjects';
}

String _noticeMetricValue(AsyncValue<NoticeBoardModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Retry' : '...';
  }
  return data.summary.unreadCount.toString();
}

String _noticeMetricCaption(AsyncValue<NoticeBoardModel> value) {
  final data = value.asData?.value;
  if (data == null) {
    return value.hasError ? 'Could not load' : 'Loading';
  }
  return data.summary.unreadCount == 1 ? 'Unread notice' : 'Unread notices';
}

Map<String, String> _buildFeatureBadges({
  required AsyncValue<AttendanceModel> attendance,
  required AsyncValue<FeeDetailsModel> fees,
  required AsyncValue<HomeworkPlannerModel> homework,
  required AsyncValue<ExamListModel> exams,
  required AsyncValue<NoticeBoardModel> notices,
}) {
  final attendanceData = attendance.asData?.value;
  final feeData = fees.asData?.value;
  final homeworkData = homework.asData?.value;
  final examData = exams.asData?.value;
  final noticeData = notices.asData?.value;
  final publishedResults = examData?.exams
      .where((exam) => exam.attempt.isSubmitted && exam.attempt.canViewResult)
      .length;

  return {
    'Attendance': attendanceData == null
        ? _loadingBadge(attendance)
        : attendanceData.summary.totalCount == 0
        ? '0 records'
        : '${_formatPercent(attendanceData.summary.attendanceRate)}%',
    'Fees': feeData == null
        ? _loadingBadge(fees)
        : feeData.summary.totalDueAmount <= 0
        ? 'No dues'
        : '${_formatCurrency(feeData.summary.totalDueAmount)} due',
    'Homework': homeworkData == null
        ? _loadingBadge(homework)
        : _countBadge(homeworkData.summary.homeworkCount, 'homework'),
    'Exams': examData == null
        ? _loadingBadge(exams)
        : examData.summary.pendingCount > 0
        ? _countBadge(examData.summary.pendingCount, 'pending', 'pending')
        : _countBadge(examData.summary.examCount, 'exam', 'exams'),
    'Results': examData == null
        ? _loadingBadge(exams)
        : _countBadge(
            publishedResults ?? 0,
            'published result',
            'published results',
          ),
    'Reports': 'Open',
    'Timetable': 'Open',
    'Notices': noticeData == null
        ? _loadingBadge(notices)
        : noticeData.summary.unreadCount > 0
        ? _countBadge(noticeData.summary.unreadCount, 'unread', 'unread')
        : _countBadge(noticeData.summary.totalCount, 'notice', 'notices'),
    'Profile': 'Student info',
    'Teachers': 'Open',
    'Notifications': noticeData == null
        ? _loadingBadge(notices)
        : noticeData.summary.urgentCount > 0
        ? _countBadge(noticeData.summary.urgentCount, 'urgent', 'urgent')
        : 'No urgent',
    'Documents': 'Open',
  };
}

String _loadingBadge<T>(AsyncValue<T> value) {
  return value.hasError ? 'Could not load' : 'Loading';
}

String _countBadge(int count, String singular, [String? plural]) {
  if (count == 1) {
    return '1 $singular';
  }
  return '$count ${plural ?? '${singular}s'}';
}

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({required this.data});

  final _Feature data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final moduleCard = _SoftCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBadge(icon: data.icon, color: data.color, size: 62),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Color(0xFF111640),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.summary,
                          style: const TextStyle(
                            color: Color(0xFF68738E),
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final chip in data.chips)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          color: data.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _ModulePreview(color: data.color),
            ],
          ),
        );

        final sideCard = _SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Ready for API',
                subtitle: 'The UI shell is prepared for real data',
              ),
              const SizedBox(height: 18),
              _FocusRow(
                color: data.color,
                title: 'List endpoint',
                subtitle: 'Connect module data here',
              ),
              _FocusRow(
                color: const Color(0xFF21B6E8),
                title: 'Detail page',
                subtitle: 'Open records from this module',
              ),
              _FocusRow(
                color: const Color(0xFFFFC857),
                title: 'Notifications',
                subtitle: 'Trigger alerts for updates',
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: moduleCard),
              const SizedBox(width: 18),
              Expanded(flex: 3, child: sideCard),
            ],
          );
        }

        return Column(
          children: [moduleCard, const SizedBox(height: 16), sideCard],
        );
      },
    );
  }
}

class _AttendancePage extends ConsumerWidget {
  const _AttendancePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceProvider);
    return attendance.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const _AttendanceLoadingView(),
      error: (error, _) => _FeesErrorView(
        message: error.toString(),
        onRetry: () => _refreshStudentParentData(ref),
      ),
      data: (data) => _AttendanceContent(
        data: data,
        onRefresh: () => _refreshStudentParentData(ref),
        onStatusChanged: (status) {
          final query = ref.read(attendanceQueryProvider);
          ref.read(attendanceQueryProvider.notifier).state = query.copyWith(
            status: status,
          );
        },
        onBatchChanged: (batchId) {
          final query = ref.read(attendanceQueryProvider);
          ref.read(attendanceQueryProvider.notifier).state = query.copyWith(
            batchId: batchId,
          );
        },
        onDateRangeChanged: (dateFrom, dateTo) {
          final query = ref.read(attendanceQueryProvider);
          ref.read(attendanceQueryProvider.notifier).state = query.copyWith(
            dateFrom: dateFrom,
            dateTo: dateTo,
            limit: _attendanceLimitForRange(dateFrom, dateTo),
          );
        },
        onRecent30Days: () {
          final query = ref.read(attendanceQueryProvider);
          final recent = AttendanceQuery.recent30Days();
          ref.read(attendanceQueryProvider.notifier).state = query.copyWith(
            dateFrom: recent.dateFrom,
            dateTo: recent.dateTo,
            limit: recent.limit,
          );
        },
      ),
    );
  }
}

class _AttendanceContent extends StatelessWidget {
  const _AttendanceContent({
    required this.data,
    required this.onRefresh,
    required this.onStatusChanged,
    required this.onBatchChanged,
    required this.onDateRangeChanged,
    required this.onRecent30Days,
  });

  final AttendanceModel data;
  final VoidCallback onRefresh;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onBatchChanged;
  final void Function(String dateFrom, String dateTo) onDateRangeChanged;
  final VoidCallback onRecent30Days;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttendanceHero(
              data: data,
              onRefresh: onRefresh,
              onStatusChanged: onStatusChanged,
              onBatchChanged: onBatchChanged,
              onDateRangeChanged: onDateRangeChanged,
              onRecent30Days: onRecent30Days,
            ),
            const SizedBox(height: 16),
            _AttendanceMetrics(summary: data.summary, isWide: isWide),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AttendanceBatchCard(batches: data.batchWise),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _AttendanceLogCard(records: data.records)),
                ],
              )
            else ...[
              _AttendanceBatchCard(batches: data.batchWise),
              const SizedBox(height: 16),
              _AttendanceLogCard(records: data.records),
            ],
          ],
        );
      },
    );
  }
}

class _AttendanceHero extends StatelessWidget {
  const _AttendanceHero({
    required this.data,
    required this.onRefresh,
    required this.onStatusChanged,
    required this.onBatchChanged,
    required this.onDateRangeChanged,
    required this.onRecent30Days,
  });

  final AttendanceModel data;
  final VoidCallback onRefresh;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onBatchChanged;
  final void Function(String dateFrom, String dateTo) onDateRangeChanged;
  final VoidCallback onRecent30Days;

  @override
  Widget build(BuildContext context) {
    final filter = data.filters;
    return _SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBadge(
                icon: Icons.fact_check_rounded,
                color: Color(0xFF21B6E8),
                size: 58,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance',
                      style: TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(filter.dateFrom)} to ${_formatDate(filter.dateTo)}',
                      style: const TextStyle(
                        color: Color(0xFF76809B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Refresh attendance',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AttendanceFilterChip(
                label: 'All',
                selected: filter.status.isEmpty,
                onTap: () => onStatusChanged(''),
              ),
              for (final choice in data.statusChoices)
                _AttendanceFilterChip(
                  label: choice.label,
                  selected: filter.status == choice.value,
                  onTap: () => onStatusChanged(choice.value),
                ),
            ],
          ),
          if (data.batchWise.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AttendanceFilterChip(
                  label: 'All batches',
                  selected: filter.batchId.isEmpty,
                  onTap: () => onBatchChanged(''),
                ),
                for (final batch in data.batchWise)
                  _AttendanceFilterChip(
                    label: batch.name,
                    selected: filter.batchId == batch.id.toString(),
                    onTap: () => onBatchChanged(batch.id.toString()),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _AttendanceDateFilters(
            dateFrom: filter.dateFrom,
            dateTo: filter.dateTo,
            onDateRangeChanged: onDateRangeChanged,
            onRecent30Days: onRecent30Days,
          ),
        ],
      ),
    );
  }
}

class _AttendanceDateFilters extends StatelessWidget {
  const _AttendanceDateFilters({
    required this.dateFrom,
    required this.dateTo,
    required this.onDateRangeChanged,
    required this.onRecent30Days,
  });

  final String dateFrom;
  final String dateTo;
  final void Function(String dateFrom, String dateTo) onDateRangeChanged;
  final VoidCallback onRecent30Days;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _AttendanceDateButton(
          label: 'Start date',
          value: dateFrom,
          onTap: () => _pickDate(context, isStart: true),
        ),
        _AttendanceDateButton(
          label: 'End date',
          value: dateTo,
          onTap: () => _pickDate(context, isStart: false),
        ),
        TextButton.icon(
          onPressed: onRecent30Days,
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Recent 30 days'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0369A1),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final currentStart = _parseDateParam(dateFrom) ?? now;
    final currentEnd = _parseDateParam(dateTo) ?? now;
    final initialDate = isStart ? currentStart : currentEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;

    var nextStart = currentStart;
    var nextEnd = currentEnd;
    if (isStart) {
      nextStart = picked;
      if (nextStart.isAfter(nextEnd)) {
        nextEnd = picked;
      }
    } else {
      nextEnd = picked;
      if (nextEnd.isBefore(nextStart)) {
        nextStart = picked;
      }
    }
    onDateRangeChanged(_formatDateParam(nextStart), _formatDateParam(nextEnd));
  }
}

class _AttendanceDateButton extends StatelessWidget {
  const _AttendanceDateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text('$label: ${_formatDate(value)}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF111640),
        side: const BorderSide(color: Color(0xFFDDE5F3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AttendanceFilterChip extends StatelessWidget {
  const _AttendanceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFE0F7FF),
      backgroundColor: const Color(0xFFF6F8FF),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0369A1) : const Color(0xFF68738E),
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _AttendanceMetrics extends StatelessWidget {
  const _AttendanceMetrics({required this.summary, required this.isWide});

  final AttendanceSummaryModel summary;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        'Attendance',
        '${summary.attendanceRate.toStringAsFixed(1)}%',
        '${summary.attendedCount}/${summary.totalCount} attended',
        Icons.trending_up_rounded,
        const Color(0xFF21B6E8),
      ),
      _Metric(
        'Present',
        summary.presentCount.toString(),
        'On time',
        Icons.check_circle_rounded,
        const Color(0xFF36C321),
      ),
      _Metric(
        'Late',
        summary.lateCount.toString(),
        'Marked late',
        Icons.schedule_rounded,
        const Color(0xFFFF8B3D),
      ),
      _Metric(
        'Absent',
        summary.absentCount.toString(),
        'Missed',
        Icons.cancel_rounded,
        const Color(0xFFE11D48),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 390;
        final crossAxisCount = isWide ? 4 : (isSingleColumn ? 1 : 2);
        final aspectRatio = isWide ? 1.78 : (isSingleColumn ? 3.4 : 1.38);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) =>
              _AttendanceMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _AttendanceMetricCard extends StatelessWidget {
  const _AttendanceMetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isHorizontal = constraints.maxWidth >= 170;
          final content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF111640),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111640),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF76809B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

          if (isHorizontal) {
            return Row(
              children: [
                _IconBadge(icon: metric.icon, color: metric.color, size: 42),
                const SizedBox(width: 12),
                Expanded(child: content),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: metric.icon, color: metric.color, size: 38),
              const Spacer(),
              content,
            ],
          );
        },
      ),
    );
  }
}

class _AttendanceBatchCard extends StatelessWidget {
  const _AttendanceBatchCard({required this.batches});

  final List<AttendanceBatchSummaryModel> batches;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Batch wise',
            subtitle: 'Attendance performance by enrolled batch',
          ),
          const SizedBox(height: 16),
          if (batches.isEmpty)
            const _EmptyLine(text: 'No attendance batches found.')
          else
            for (final batch in batches) _AttendanceBatchRow(batch: batch),
        ],
      ),
    );
  }
}

class _AttendanceBatchRow extends StatelessWidget {
  const _AttendanceBatchRow({required this.batch});

  final AttendanceBatchSummaryModel batch;

  @override
  Widget build(BuildContext context) {
    final progress = (batch.attendanceRate / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  batch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallBadge(label: '${batch.attendanceRate.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: const Color(0xFFE5EAF6),
            color: _attendanceRateColor(batch.attendanceRate),
          ),
          const SizedBox(height: 8),
          Text(
            '${batch.presentCount} present, ${batch.lateCount} late, ${batch.absentCount} absent',
            style: const TextStyle(
              color: Color(0xFF76809B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceLogCard extends StatelessWidget {
  const _AttendanceLogCard({required this.records});

  final List<AttendanceRecordModel> records;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Daily log',
            subtitle: 'Recent marked attendance records',
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const _EmptyLine(
              text: 'No attendance records found for this filter.',
            )
          else
            for (final record in records) _AttendanceRecordRow(record: record),
        ],
      ),
    );
  }
}

class _AttendanceRecordRow extends StatelessWidget {
  const _AttendanceRecordRow({required this.record});

  final AttendanceRecordModel record;

  @override
  Widget build(BuildContext context) {
    final color = _attendanceStatusColor(record.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(
            icon: _attendanceStatusIcon(record.status),
            color: color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(record.date),
                        style: const TextStyle(
                          color: Color(0xFF111640),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StatusPill(label: record.statusLabel, color: color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.batch.name} - ${record.academicSession.academicYear}',
                  style: const TextStyle(
                    color: Color(0xFF76809B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (record.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.note,
                    style: const TextStyle(
                      color: Color(0xFF68738E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AttendanceLoadingView extends StatelessWidget {
  const _AttendanceLoadingView();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _IconBadge(
                icon: Icons.fact_check_rounded,
                color: Color(0xFF21B6E8),
                size: 54,
              ),
              SizedBox(width: 14),
              Expanded(
                child: _SectionTitle(
                  title: 'Attendance',
                  subtitle: 'Loading attendance records',
                ),
              ),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 5; i++)
            Container(
              height: i == 0 ? 110 : 68,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4FB),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeesPage extends ConsumerWidget {
  const _FeesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fees = ref.watch(feeDetailsProvider);
    return fees.when(
      loading: () => const _FeesLoadingView(),
      error: (error, _) => _FeesErrorView(
        message: error.toString(),
        onRetry: () => _refreshStudentParentData(ref),
      ),
      data: (data) => _FeesContent(
        data: data,
        onRefresh: () => _refreshStudentParentData(ref),
      ),
    );
  }
}

class _FeesContent extends ConsumerStatefulWidget {
  const _FeesContent({required this.data, required this.onRefresh});

  final FeeDetailsModel data;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_FeesContent> createState() => _FeesContentState();
}

class _FeesContentState extends ConsumerState<_FeesContent> {
  int? _generatingReceiptPaymentId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final data = widget.data;
        final summary = data.summary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SoftCard(
              padding: const EdgeInsets.all(22),
              child: isWide
                  ? Row(
                      children: [
                        Expanded(
                          child: _FeesHeader(
                            data: data,
                            onRefresh: widget.onRefresh,
                          ),
                        ),
                        const SizedBox(width: 18),
                        _FeeDuePill(amount: summary.totalDueAmount),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeesHeader(data: data, onRefresh: widget.onRefresh),
                        const SizedBox(height: 16),
                        _FeeDuePill(amount: summary.totalDueAmount),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _FeesSummaryGrid(summary: summary, isWide: isWide),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FeeGroupCard(
                      title: 'Category wise',
                      groups: data.categoryWise,
                      icon: Icons.category_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _FeeGroupCard(
                      title: 'Batch wise',
                      groups: data.batchWise,
                      icon: Icons.groups_rounded,
                    ),
                  ),
                ],
              )
            else ...[
              _FeeGroupCard(
                title: 'Category wise',
                groups: data.categoryWise,
                icon: Icons.category_rounded,
              ),
              const SizedBox(height: 16),
              _FeeGroupCard(
                title: 'Batch wise',
                groups: data.batchWise,
                icon: Icons.groups_rounded,
              ),
            ],
            const SizedBox(height: 16),
            _FeeInvoiceCard(fees: data.fees),
            const SizedBox(height: 16),
            _PaymentHistoryCard(
              payments: data.paymentHistory,
              generatingPaymentId: _generatingReceiptPaymentId,
              onDownload: (payment) => _downloadReceipt(
                context: context,
                data: data,
                payment: payment,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadReceipt({
    required BuildContext context,
    required FeeDetailsModel data,
    required PaymentHistoryModel payment,
  }) async {
    if (_generatingReceiptPaymentId != null) {
      return;
    }

    final receiptNumber = payment.receiptNumber.isEmpty
        ? payment.id.toString()
        : payment.receiptNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
    final receiptLabel = payment.receiptNumber.isEmpty
        ? 'Receipt ${payment.id}'
        : payment.receiptNumber;
    final fileName = 'fee-receipt-$receiptNumber.jpg';
    final notificationId = await LocalNotificationService.showDownloadStarted(
      fileName: fileName,
    );
    var progressDialogShown = false;

    void closeProgressDialog() {
      if (progressDialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogShown = false;
      }
    }

    try {
      if (mounted) {
        setState(() => _generatingReceiptPaymentId = payment.id);
      }
      if (context.mounted) {
        progressDialogShown = true;
        unawaited(_showReceiptGenerationDialog(context));
        await WidgetsBinding.instance.endOfFrame;
      }
      final profileLogoUrl =
          ref
              .read(studentProfileProvider)
              .valueOrNull
              ?.student
              .instituteLogoUrl ??
          ref
              .read(studentBootstrapProvider(null))
              .valueOrNull
              ?.profile
              .student
              .instituteLogoUrl ??
          '';
      final bytes = await _buildDigitalReceiptJpg(
        data: data,
        payment: payment,
        fallbackLogoUrl: profileLogoUrl,
        apiClient: ref.read(apiClientProvider),
      );
      final autoOpenDownloads = await ref
          .read(secureStorageServiceProvider)
          .getAutoOpenDownloadsEnabled();
      final savedPath = await saveBinaryDocument(
        folderName: 'UltraCoachMatrix Receipts',
        fileName: fileName,
        bytes: bytes,
        notificationId: notificationId,
        autoOpen: autoOpenDownloads,
      );
      if (!context.mounted) {
        return;
      }
      closeProgressDialog();
      await showAppMessageDialog(
        context,
        title: 'Receipt downloaded',
        message:
            'Saved $receiptLabel student digital copy locally:\n$savedPath',
        type: AppNotificationType.success,
      );
    } catch (error) {
      await LocalNotificationService.showDownloadFailed(
        fileName: fileName,
        message: error.toString(),
        notificationId: notificationId,
      );
      if (!context.mounted) {
        return;
      }
      closeProgressDialog();
      showAppNotification(
        context,
        title: 'Download failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    } finally {
      closeProgressDialog();
      if (mounted) {
        setState(() => _generatingReceiptPaymentId = null);
      }
    }
  }
}

Future<void> _showReceiptGenerationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF0700A8),
                  ),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Text(
                    'Generating receipt...',
                    style: TextStyle(
                      color: Color(0xFF111640),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FeesHeader extends StatelessWidget {
  const _FeesHeader({required this.data, required this.onRefresh});

  final FeeDetailsModel data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBadge(
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF36C321),
              size: isCompact ? 54 : 62,
            ),
            SizedBox(width: isCompact ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.student.name.isEmpty
                        ? data.student.username
                        : data.student.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF111640),
                      fontSize: isCompact ? 21 : 24,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Admission ${data.student.admissionNumber}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68738E),
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Refresh fees',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        );
      },
    );
  }
}

class _FeeDuePill extends StatelessWidget {
  const _FeeDuePill({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final isClear = amount <= 0;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isClear ? const Color(0xFFDCFCE7) : const Color(0xFFFFF1F2)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isClear ? 'No due amount' : 'Due amount',
            style: TextStyle(
              color: isClear
                  ? const Color(0xFF15803D)
                  : const Color(0xFFBE123C),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeesSummaryGrid extends StatelessWidget {
  const _FeesSummaryGrid({required this.summary, required this.isWide});

  final FeeSummaryModel summary;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final items = [
      _FeeSummaryMetric(
        'Total Fees',
        _formatCurrency(summary.totalFeeAmount),
        '${summary.invoiceCount} invoices',
        Icons.receipt_long_rounded,
        const Color(0xFF21B6E8),
      ),
      _FeeSummaryMetric(
        'Paid',
        _formatCurrency(summary.totalPaidAmount),
        '${summary.activePaymentCount} payments',
        Icons.verified_rounded,
        const Color(0xFF36C321),
      ),
      _FeeSummaryMetric(
        'Due',
        _formatCurrency(summary.totalDueAmount),
        summary.totalDueAmount <= 0 ? 'Clear' : 'Pending',
        Icons.pending_actions_rounded,
        const Color(0xFFFF8B3D),
      ),
      _FeeSummaryMetric(
        'Advance',
        _formatCurrency(summary.overpaidAmount),
        'Credit',
        Icons.savings_rounded,
        const Color(0xFF8B5CF6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 430;
        final crossAxisCount = isWide ? 4 : (isSingleColumn ? 1 : 2);
        final cardHeight = isWide
            ? 148.0
            : isSingleColumn
            ? 132.0
            : 176.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) =>
              _FeeSummaryCard(metric: items[index]),
        );
      },
    );
  }
}

class _FeeSummaryCard extends StatelessWidget {
  const _FeeSummaryCard({required this.metric});

  final _FeeSummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isHorizontal = constraints.maxWidth >= 270;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF76809B),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF111640),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF76809B),
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

          if (!isHorizontal) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(icon: metric.icon, color: metric.color, size: 36),
                const SizedBox(height: 10),
                content,
              ],
            );
          }

          return Row(
            children: [
              _IconBadge(icon: metric.icon, color: metric.color, size: 40),
              const SizedBox(width: 12),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _FeeGroupCard extends StatelessWidget {
  const _FeeGroupCard({
    required this.title,
    required this.groups,
    required this.icon,
  });

  final String title;
  final List<FeeGroupModel> groups;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, color: const Color(0xFF0700A8), size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const _EmptyLine(text: 'No fee breakup available.')
          else
            for (final group in groups) _FeeGroupRow(group: group),
        ],
      ),
    );
  }
}

class _FeeGroupRow extends StatelessWidget {
  const _FeeGroupRow({required this.group});

  final FeeGroupModel group;

  @override
  Widget build(BuildContext context) {
    final progress = group.totalAmount <= 0
        ? 0.0
        : (group.paidAmount / group.totalAmount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name.isEmpty ? 'Other' : group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _formatCurrency(group.dueAmount),
                style: const TextStyle(
                  color: Color(0xFFBE123C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFFE9EEFA),
            color: const Color(0xFF36C321),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatCurrency(group.paidAmount)} paid of ${_formatCurrency(group.totalAmount)}',
            style: const TextStyle(
              color: Color(0xFF76809B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeInvoiceCard extends StatelessWidget {
  const _FeeInvoiceCard({required this.fees});

  final List<FeeItemModel> fees;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Fee details',
            subtitle: 'Invoice status with category and batch',
          ),
          const SizedBox(height: 16),
          if (fees.isEmpty)
            const _EmptyLine(text: 'No fee invoices found.')
          else
            for (final fee in fees.take(8)) _FeeInvoiceRow(fee: fee),
        ],
      ),
    );
  }
}

class _FeeInvoiceRow extends StatelessWidget {
  const _FeeInvoiceRow({required this.fee});

  final FeeItemModel fee;

  @override
  Widget build(BuildContext context) {
    final isPaid = fee.dueAmount <= 0 || fee.status == 'PAID';
    final statusLabel = isPaid
        ? 'Paid'
        : '${_formatCurrency(fee.dueAmount)} due';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;
          final details =
              '${fee.categoryName} - ${fee.batchName ?? 'Other'} - Due ${_formatDate(fee.dueDate)}';
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fee.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF76809B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
          final amount = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(fee.amount),
                style: const TextStyle(
                  color: Color(0xFF111640),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                style: TextStyle(
                  color: isPaid
                      ? const Color(0xFF15803D)
                      : const Color(0xFFBE123C),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
          final icon = _IconBadge(
            icon: isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            color: isPaid ? const Color(0xFF36C321) : const Color(0xFFFF8B3D),
            size: 42,
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [icon, const SizedBox(width: 12), info]),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: amount),
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 12),
              info,
              const SizedBox(width: 10),
              amount,
            ],
          );
        },
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.payments,
    required this.generatingPaymentId,
    required this.onDownload,
  });

  final List<PaymentHistoryModel> payments;
  final int? generatingPaymentId;
  final ValueChanged<PaymentHistoryModel> onDownload;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Payment history',
            subtitle: 'Receipts are available for every payment',
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            const _EmptyLine(text: 'No payment history found.')
          else
            for (final payment in payments.take(10))
              _PaymentHistoryRow(
                payment: payment,
                isGenerating: generatingPaymentId == payment.id,
                isDownloadLocked: generatingPaymentId != null,
                onDownload: onDownload,
              ),
        ],
      ),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  const _PaymentHistoryRow({
    required this.payment,
    required this.isGenerating,
    required this.isDownloadLocked,
    required this.onDownload,
  });

  final PaymentHistoryModel payment;
  final bool isGenerating;
  final bool isDownloadLocked;
  final ValueChanged<PaymentHistoryModel> onDownload;

  @override
  Widget build(BuildContext context) {
    final receiptLabel = payment.receiptNumber.isEmpty
        ? 'Receipt ${payment.id}'
        : payment.receiptNumber;
    final paymentDetail =
        '${payment.invoiceTitle.isEmpty ? 'Invoice' : payment.invoiceTitle} - ${_formatCodeLabel(payment.method)} - ${_formatDate(payment.paidOn)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 430;
          const icon = _IconBadge(
            icon: Icons.receipt_rounded,
            color: Color(0xFF0700A8),
            size: 42,
          );
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiptLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  paymentDetail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF76809B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
          final actions = isGenerating
              ? const _ReceiptGeneratingIndicator()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(payment.amount),
                      style: const TextStyle(
                        color: Color(0xFF111640),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Download student copy JPG',
                      onPressed: isDownloadLocked
                          ? null
                          : () => onDownload(payment),
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ],
                );

          final compactActions = isGenerating
              ? const _ReceiptGeneratingIndicator(width: 220)
              : actions;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [icon, const SizedBox(width: 12), info]),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: compactActions),
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 12),
              info,
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ReceiptGeneratingIndicator extends StatelessWidget {
  const _ReceiptGeneratingIndicator({this.width = 190});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Text(
            'Generating your receipt...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF0700A8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: Color(0xFFE5EAF6),
              color: Color(0xFF0700A8),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeesLoadingView extends StatelessWidget {
  const _FeesLoadingView();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Fees',
            subtitle: 'Loading current fee details',
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 5; i++)
            Container(
              height: i == 0 ? 92 : 68,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4FB),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeesErrorView extends StatelessWidget {
  const _FeesErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBadge(
            icon: Icons.error_outline_rounded,
            color: Color(0xFFE11D48),
            size: 54,
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load fees',
            style: TextStyle(
              color: Color(0xFF111640),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF68738E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF76809B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HomeworkPlannerPage extends ConsumerWidget {
  const _HomeworkPlannerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planner = ref.watch(homeworkPlannerProvider);
    return planner.when(
      loading: () => const _ProfileLoadingView(title: 'Homework'),
      error: (error, _) => _ProfileErrorView(
        title: 'Could not load homework',
        message: error.toString(),
        onRetry: () => refreshHomeworkPlanner(ref),
      ),
      data: (data) => _HomeworkPlannerContent(
        data: data,
        onRefresh: () => refreshHomeworkPlanner(ref),
      ),
    );
  }
}

class _HomeworkPlannerContent extends StatefulWidget {
  const _HomeworkPlannerContent({required this.data, required this.onRefresh});

  final HomeworkPlannerModel data;
  final VoidCallback onRefresh;

  @override
  State<_HomeworkPlannerContent> createState() =>
      _HomeworkPlannerContentState();
}

class _HomeworkPlannerContentState extends State<_HomeworkPlannerContent> {
  int? _selectedSubjectId;
  int? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final filteredItems = _filterHomeworkItems(
      data.homework,
      subjectId: _selectedSubjectId,
      courseId: _selectedCourseId,
    );
    final filteredSubjectWise = _subjectGroupsFromHomework(filteredItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeworkSummaryGrid(data: data, isWide: isWide),
        const SizedBox(height: 18),
        _HomeworkFilterBar(
          data: data,
          selectedSubjectId: _selectedSubjectId,
          selectedCourseId: _selectedCourseId,
          onSubjectChanged: (value) {
            setState(() => _selectedSubjectId = value);
          },
          onCourseChanged: (value) {
            setState(() => _selectedCourseId = value);
          },
          onClear: () {
            setState(() {
              _selectedSubjectId = null;
              _selectedCourseId = null;
            });
          },
        ),
        const SizedBox(height: 18),
        _SubjectWiseHomework(subjectWise: filteredSubjectWise),
      ],
    );
  }
}

class _HomeworkSummaryGrid extends StatelessWidget {
  const _HomeworkSummaryGrid({required this.data, required this.isWide});

  final HomeworkPlannerModel data;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        'Homework',
        data.summary.homeworkCount.toString(),
        'Planner items',
        Icons.edit_note_rounded,
        const Color(0xFFFF8B3D),
      ),
      _Metric(
        'Subjects',
        data.summary.subjectCount.toString(),
        'Subject wise',
        Icons.menu_book_rounded,
        const Color(0xFF21B6E8),
      ),
      _Metric(
        'Courses',
        data.courseCount.toString(),
        'Course wise',
        Icons.local_library_rounded,
        const Color(0xFF8B5CF6),
      ),
      _Metric(
        'Batches',
        data.summary.batchCount.toString(),
        'Batch sections',
        Icons.groups_rounded,
        const Color(0xFF36C321),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWideCards = isWide && constraints.maxWidth >= 900;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useWideCards ? 4 : 1,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: useWideCards ? 2.35 : 3.25,
          ),
          itemBuilder: (context, index) =>
              _HomeworkSummaryCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _HomeworkSummaryCard extends StatelessWidget {
  const _HomeworkSummaryCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IconBadge(icon: metric.icon, color: metric.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metric.value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  metric.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF76809B),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

class _HomeworkFilterBar extends StatelessWidget {
  const _HomeworkFilterBar({
    required this.data,
    required this.selectedSubjectId,
    required this.selectedCourseId,
    required this.onSubjectChanged,
    required this.onCourseChanged,
    required this.onClear,
  });

  final HomeworkPlannerModel data;
  final int? selectedSubjectId;
  final int? selectedCourseId;
  final ValueChanged<int?> onSubjectChanged;
  final ValueChanged<int?> onCourseChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final courses = _homeworkCourseOptions(data.homework);
    final hasActiveFilter =
        selectedSubjectId != null || selectedCourseId != null;
    return _SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _PanelHeading(
                  title: 'Filters',
                  icon: Icons.tune_rounded,
                ),
              ),
              if (hasActiveFilter)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _HomeworkFilterRow(
            label: 'Subject',
            options: [
              const _HomeworkFilterOption(id: null, name: 'All subjects'),
              for (final subject in data.subjectWise)
                _HomeworkFilterOption(id: subject.id, name: subject.name),
            ],
            selectedId: selectedSubjectId,
            onChanged: onSubjectChanged,
          ),
          const SizedBox(height: 10),
          _HomeworkFilterRow(
            label: 'Course',
            options: [
              const _HomeworkFilterOption(id: null, name: 'All courses'),
              ...courses,
            ],
            selectedId: selectedCourseId,
            onChanged: onCourseChanged,
          ),
        ],
      ),
    );
  }
}

class _HomeworkFilterRow extends StatelessWidget {
  const _HomeworkFilterRow({
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final List<_HomeworkFilterOption> options;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF65708A),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                selected: selectedId == option.id,
                label: Text(option.name),
                onSelected: (_) => onChanged(option.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeworkFilterOption {
  const _HomeworkFilterOption({required this.id, required this.name});

  final int? id;
  final String name;
}

class _SubjectWiseHomework extends StatelessWidget {
  const _SubjectWiseHomework({required this.subjectWise});

  final List<HomeworkSubjectGroupModel> subjectWise;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
            title: 'Subject wise homework',
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 14),
          if (subjectWise.isEmpty)
            const _EmptyLine(text: 'No homework assigned yet.')
          else
            for (final subject in subjectWise) ...[
              _HomeworkSubjectSection(subject: subject),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _HomeworkSubjectSection extends StatefulWidget {
  const _HomeworkSubjectSection({required this.subject});

  final HomeworkSubjectGroupModel subject;

  @override
  State<_HomeworkSubjectSection> createState() =>
      _HomeworkSubjectSectionState();
}

class _HomeworkSubjectSectionState extends State<_HomeworkSubjectSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final latestItem = _latestHomeworkItem(subject.items);
    final latestPublished = latestItem == null
        ? ''
        : _formatDate(latestItem.createdAt);
    final previewTitle = latestItem?.title.trim() ?? '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE4F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111640).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF0700A8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111640),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SmallBadge(label: '${subject.homeworkCount}'),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          latestPublished.isEmpty
                              ? 'Published date unavailable'
                              : 'Published $latestPublished',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF65708A),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (previewTitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            previewTitle,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(
                              color: Color(0xFF111640),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF0700A8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < subject.items.length; i++)
                    _HomeworkTile(item: subject.items[i]),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _HomeworkTile extends ConsumerWidget {
  const _HomeworkTile({required this.item});

  final HomeworkItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE5EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.campaign_rounded,
                label:
                    'Published ${item.createdAt.isEmpty ? '-' : _formatDate(item.createdAt)}',
              ),
              if (item.teacherName.isNotEmpty)
                _InfoChip(icon: Icons.person_rounded, label: item.teacherName),
            ],
          ),
          if (item.instructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HomeworkInstructions(html: item.instructions),
          ],
          if (item.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final attachment in item.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HomeworkAttachmentActions(
                      attachment: attachment,
                      instituteName: item.batch.academicYear,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeworkInstructions extends StatelessWidget {
  const _HomeworkInstructions({required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseInstructionBlocks(html);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            _InstructionBlockView(block: blocks[i]),
            if (i != blocks.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _InstructionBlockView extends StatelessWidget {
  const _InstructionBlockView({required this.block});

  final _InstructionBlock block;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(children: block.spans),
      textAlign: block.alignment,
      style: const TextStyle(
        color: Color(0xFF111640),
        fontSize: 13,
        height: 1.42,
        fontWeight: FontWeight.w600,
      ),
    );

    if (block.prefix == null) {
      return SizedBox(width: double.infinity, child: text);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            block.prefix!,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontSize: 13,
              height: 1.42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(child: text),
      ],
    );
  }
}

class _InstructionBlock {
  const _InstructionBlock({
    required this.spans,
    this.prefix,
    this.alignment = TextAlign.start,
  });

  final List<InlineSpan> spans;
  final String? prefix;
  final TextAlign alignment;
}

class _HomeworkAttachmentActions extends ConsumerWidget {
  const _HomeworkAttachmentActions({
    required this.attachment,
    required this.instituteName,
  });

  final HomeworkAttachmentModel attachment;
  final String instituteName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = attachment.fileName.isEmpty
        ? 'Attachment ${attachment.id}'
        : attachment.fileName;
    final canOpen = attachment.fileUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.attach_file_rounded,
            size: 17,
            color: Color(0xFF0700A8),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'View attachment',
            visualDensity: VisualDensity.compact,
            onPressed: canOpen ? () => _openAttachment(context) : null,
            icon: const Icon(Icons.visibility_rounded, size: 18),
            color: const Color(0xFF0700A8),
          ),
          IconButton(
            tooltip: 'Download attachment',
            visualDensity: VisualDensity.compact,
            onPressed: canOpen ? () => _downloadAttachment(context, ref) : null,
            icon: const Icon(Icons.download_rounded, size: 18),
            color: const Color(0xFF15803D),
          ),
        ],
      ),
    );
  }

  void _openAttachment(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          document: _homeworkAttachmentDocument(attachment),
          instituteName: _homeworkAttachmentFolderName(instituteName),
        ),
      ),
    );
  }

  Future<void> _downloadAttachment(BuildContext context, WidgetRef ref) async {
    final fallbackFileName = attachment.fileName.isEmpty
        ? 'attachment-${attachment.id}'
        : attachment.fileName;
    final notificationId = await LocalNotificationService.showDownloadStarted(
      fileName: fallbackFileName,
    );

    try {
      final file = await ref
          .read(studentProfileRepositoryProvider)
          .downloadDocument(attachment.fileUrl);
      final fileName = file.fileName.isEmpty ? fallbackFileName : file.fileName;
      final autoOpenDownloads = await ref
          .read(secureStorageServiceProvider)
          .getAutoOpenDownloadsEnabled();
      final savedPath = await saveBinaryDocument(
        folderName: _homeworkAttachmentFolderName(instituteName),
        fileName: fileName,
        bytes: file.bytes,
        notificationId: notificationId,
        autoOpen: autoOpenDownloads,
      );
      if (!context.mounted) {
        return;
      }
      await showAppMessageDialog(
        context,
        title: 'Attachment downloaded',
        message: 'Saved attachment locally:\n$savedPath',
        type: AppNotificationType.success,
      );
    } catch (error) {
      await LocalNotificationService.showDownloadFailed(
        fileName: fallbackFileName,
        message: error.toString(),
        notificationId: notificationId,
      );
      if (!context.mounted) {
        return;
      }
      showAppNotification(
        context,
        title: 'Download failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    }
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6D3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9A4B00),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0700A8)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label.isEmpty ? '-' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticesPage extends ConsumerWidget {
  const _NoticesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(noticesProvider);
    return notices.when(
      loading: () => const _ProfileLoadingView(title: 'Notices'),
      error: (error, _) => _ProfileErrorView(
        title: 'Could not load notices',
        message: error.toString(),
        onRetry: () => _refreshStudentParentData(ref),
      ),
      data: (data) => _NoticesContent(data: data),
    );
  }
}

class _ResultsPage extends ConsumerWidget {
  const _ResultsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(examsProvider);
    return exams.when(
      loading: () => const _ProfileLoadingView(title: 'Results'),
      error: (error, _) => _ProfileErrorView(
        title: 'Could not load results',
        message: error.toString(),
        onRetry: () => refreshPublishedExams(ref),
      ),
      data: (data) => _ResultsContent(data: data),
    );
  }
}

class _ResultsContent extends ConsumerWidget {
  const _ResultsContent({required this.data});

  final ExamListModel data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedExams = data.exams
        .where((exam) => exam.attempt.isSubmitted)
        .toList();
    final publishedCount = submittedExams
        .where((exam) => exam.attempt.canViewResult)
        .length;
    final pendingCount = submittedExams.length - publishedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SoftCard(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBadge(
                icon: Icons.workspace_premium_rounded,
                color: Color(0xFF8B5CF6),
                size: 62,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Results',
                      style: TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$publishedCount published, $pendingCount waiting for teacher publish',
                      style: const TextStyle(
                        color: Color(0xFF65708A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => refreshPublishedExams(ref),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeading(
                title: 'Submitted exams',
                icon: Icons.fact_check_rounded,
              ),
              const SizedBox(height: 14),
              if (submittedExams.isEmpty)
                const _EmptyLine(text: 'No submitted exams found.')
              else
                for (final exam in submittedExams)
                  _ResultExamCard(
                    exam: exam,
                    onViewResult: () => _openResultReview(
                      context: context,
                      ref: ref,
                      exam: exam,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openResultReview({
    required BuildContext context,
    required WidgetRef ref,
    required ExamModel exam,
  }) async {
    if (!exam.attempt.canViewResult || exam.attempt.id == null) {
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
      showAppNotification(
        context,
        title: 'Unable to load result',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    }
  }
}

class _ResultExamCard extends StatelessWidget {
  const _ResultExamCard({required this.exam, required this.onViewResult});

  final ExamModel exam;
  final VoidCallback onViewResult;

  @override
  Widget build(BuildContext context) {
    final canView = exam.attempt.canViewResult;
    final statusColor = canView
        ? const Color(0xFF16A34A)
        : const Color(0xFFF59E0B);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE4F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                icon: canView
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                color: statusColor,
                size: 46,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${exam.subject.name.isEmpty ? 'General' : exam.subject.name} - ${_formatDate(exam.examDate)}',
                      style: const TextStyle(
                        color: Color(0xFF65708A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.groups_rounded, label: exam.batch.name),
              _InfoChip(
                icon: Icons.assignment_turned_in_rounded,
                label: 'Submitted ${_formatDate(exam.attempt.submittedAt)}',
              ),
              _InfoChip(
                icon: canView
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                label: canView
                    ? 'Result published'
                    : 'Result not published yet',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canView ? onViewResult : null,
              icon: Icon(
                canView
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_clock_rounded,
              ),
              label: Text(canView ? 'View Result' : 'Result Pending'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticesContent extends ConsumerWidget {
  const _NoticesContent({required this.data});

  final NoticeBoardModel data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoticeSummaryGrid(summary: data.summary, isWide: isWide),
        const SizedBox(height: 16),
        _NoticeFilters(data: data),
        const SizedBox(height: 16),
        _SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeading(
                title: 'Notice records',
                icon: Icons.notifications_active_rounded,
              ),
              const SizedBox(height: 14),
              if (data.notices.isEmpty)
                const _EmptyLine(text: 'No notices found.')
              else
                for (final notice in data.notices)
                  _NoticeCard(
                    notice: notice,
                    onMarkRead: () async {
                      await ref
                          .read(noticesRepositoryProvider)
                          .markRead(notice.id);
                      ref
                          .read(apiClientProvider)
                          .clearGetCache(contains: '/api/mobile/bootstrap/');
                      ref.invalidate(studentBootstrapProvider);
                      final refreshedNotices = ref.refresh(
                        noticesProvider.future,
                      );
                      await refreshedNotices;
                    },
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeSummaryGrid extends StatelessWidget {
  const _NoticeSummaryGrid({required this.summary, required this.isWide});

  final NoticeSummaryModel summary;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        'Active',
        summary.totalCount.toString(),
        'Visible now',
        Icons.campaign_rounded,
        const Color(0xFF21B6E8),
      ),
      _Metric(
        'Unread',
        summary.unreadCount.toString(),
        'Need review',
        Icons.mark_email_unread_rounded,
        const Color(0xFFFF5D8F),
      ),
      _Metric(
        'Urgent',
        summary.urgentCount.toString(),
        'High priority',
        Icons.priority_high_rounded,
        const Color(0xFFE11D48),
      ),
      _Metric(
        'Pinned',
        summary.pinnedCount.toString(),
        'Top notices',
        Icons.push_pin_rounded,
        const Color(0xFF8B5CF6),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 390;
        final crossAxisCount = isWide ? 4 : (isSingleColumn ? 1 : 2);
        final aspectRatio = isWide ? 1.8 : (isSingleColumn ? 3.35 : 1.42);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) =>
              _AttendanceMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _NoticeFilters extends ConsumerStatefulWidget {
  const _NoticeFilters({required this.data});

  final NoticeBoardModel data;

  @override
  ConsumerState<_NoticeFilters> createState() => _NoticeFiltersState();
}

class _NoticeFiltersState extends ConsumerState<_NoticeFilters> {
  late final TextEditingController _searchController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.data.filters.search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(NoticesQuery query) {
    ref.read(noticesQueryProvider.notifier).state = query;
  }

  int _activeFilterCount(NoticesQuery query) {
    var count = 0;
    if (query.search.trim().isNotEmpty) count++;
    if (query.category.isNotEmpty) count++;
    if (query.priority.isNotEmpty) count++;
    if (query.unread) count++;
    return count;
  }

  String _choiceLabel(List<NoticeChoiceModel> choices, String value) {
    for (final choice in choices) {
      if (choice.value == value) {
        return choice.label;
      }
    }
    return '';
  }

  String _activeFilterLabel(NoticesQuery query) {
    final labels = <String>[];
    if (query.search.trim().isNotEmpty) {
      labels.add('Search');
    }
    if (query.category.isNotEmpty) {
      labels.add(_choiceLabel(widget.data.categoryChoices, query.category));
    }
    if (query.priority.isNotEmpty) {
      labels.add(_choiceLabel(widget.data.priorityChoices, query.priority));
    }
    if (query.unread) {
      labels.add('Unread');
    }
    final cleanLabels = labels.where((label) => label.isNotEmpty).toList();
    return cleanLabels.isEmpty ? 'All notices' : cleanLabels.join(' • ');
  }

  void _clearFilters() {
    _searchController.clear();
    _update(const NoticesQuery());
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(noticesQueryProvider);
    final activeCount = _activeFilterCount(query);
    return _SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF0700A8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(
                                color: Color(0xFF111640),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (activeCount > 0) ...[
                              const SizedBox(width: 8),
                              _StatusPill(
                                label: activeCount.toString(),
                                color: const Color(0xFFFF5D8F),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _activeFilterLabel(query),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF65708A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeCount > 0)
                    IconButton(
                      tooltip: 'Clear filters',
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton(
                    tooltip: _expanded ? 'Collapse filters' : 'Expand filters',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _update(query.copyWith(search: ''));
                              },
                            ),
                      hintText: 'Search notices',
                    ),
                    onSubmitted: (value) =>
                        _update(query.copyWith(search: value)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NoticeChoiceChip(
                        label: 'All',
                        selected: query.category.isEmpty,
                        onSelected: () => _update(query.copyWith(category: '')),
                      ),
                      for (final choice in widget.data.categoryChoices)
                        _NoticeChoiceChip(
                          label: choice.label,
                          selected: query.category == choice.value,
                          onSelected: () =>
                              _update(query.copyWith(category: choice.value)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NoticeChoiceChip(
                        label: 'Any priority',
                        selected: query.priority.isEmpty,
                        onSelected: () => _update(query.copyWith(priority: '')),
                      ),
                      for (final choice in widget.data.priorityChoices)
                        _NoticeChoiceChip(
                          label: choice.label,
                          selected: query.priority == choice.value,
                          onSelected: () =>
                              _update(query.copyWith(priority: choice.value)),
                        ),
                      _NoticeChoiceChip(
                        label: 'Unread only',
                        selected: query.unread,
                        onSelected: () =>
                            _update(query.copyWith(unread: !query.unread)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}

class _NoticeChoiceChip extends StatelessWidget {
  const _NoticeChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({required this.notice, required this.onMarkRead});

  final NoticeItemModel notice;
  final Future<void> Function() onMarkRead;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _isUpdating = false;

  Future<void> _markRead() async {
    if (widget.notice.isRead || _isUpdating) {
      return;
    }
    setState(() => _isUpdating = true);
    try {
      await widget.onMarkRead();
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _openNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => _NoticeDetailDialog(notice: widget.notice),
    );
    unawaited(_markRead());
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _noticePriorityColor(widget.notice.priority);
    final messageHtml = widget.notice.htmlMessage.isNotEmpty
        ? widget.notice.htmlMessage
        : widget.notice.message;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openNotice,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.notice.isRead
                ? const Color(0xFFF8FAFF)
                : const Color(0xFFFFF5F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.notice.isRead
                  ? const Color(0xFFDDE4F7)
                  : const Color(0xFFFFD5E2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBadge(
                    icon: widget.notice.pinOnTop
                        ? Icons.push_pin_rounded
                        : Icons.campaign_rounded,
                    color: priorityColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.notice.title,
                          style: const TextStyle(
                            color: Color(0xFF111640),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusPill(
                              label: widget.notice.categoryLabel,
                              color: const Color(0xFF21B6E8),
                            ),
                            _StatusPill(
                              label: widget.notice.priorityLabel,
                              color: priorityColor,
                            ),
                            if (!widget.notice.isRead)
                              const _StatusPill(
                                label: 'Unread',
                                color: Color(0xFFFF5D8F),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (messageHtml.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _NoticeMessageView(html: messageHtml, preview: true),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_month_rounded,
                    label: _formatDate(widget.notice.createdAt),
                  ),
                  if (widget.notice.createdBy.isNotEmpty)
                    _InfoChip(
                      icon: Icons.person_rounded,
                      label: widget.notice.createdBy,
                    ),
                  if (_isUpdating)
                    const _InfoChip(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Updating',
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

class _NoticeDetailDialog extends StatelessWidget {
  const _NoticeDetailDialog({required this.notice});

  final NoticeItemModel notice;

  @override
  Widget build(BuildContext context) {
    final priorityColor = _noticePriorityColor(notice.priority);
    final messageHtml = notice.htmlMessage.isNotEmpty
        ? notice.htmlMessage
        : notice.message;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBadge(
                    icon: notice.pinOnTop
                        ? Icons.push_pin_rounded
                        : Icons.campaign_rounded,
                    color: priorityColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice.title,
                          style: const TextStyle(
                            color: Color(0xFF111640),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatusPill(
                              label: notice.categoryLabel,
                              color: const Color(0xFF21B6E8),
                            ),
                            _StatusPill(
                              label: notice.priorityLabel,
                              color: priorityColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_month_rounded,
                    label: _formatDate(notice.createdAt),
                  ),
                  if (notice.createdBy.isNotEmpty)
                    _InfoChip(
                      icon: Icons.person_rounded,
                      label: notice.createdBy,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDE4F7)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _NoticeMessageView(html: messageHtml),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NoticeBlockType { paragraph, orderedItem, unorderedItem }

class _NoticeBlock {
  const _NoticeBlock(this.type, this.html, {this.index});

  final _NoticeBlockType type;
  final String html;
  final int? index;
}

class _NoticeMessageView extends StatelessWidget {
  const _NoticeMessageView({required this.html, this.preview = false});

  final String html;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: const Color(0xFF65708A),
      fontSize: preview ? 13 : 15,
      fontWeight: FontWeight.w600,
      height: 1.42,
    );
    final blocks = _noticeBlocks(html);
    final visibleBlocks = preview ? blocks.take(5).toList() : blocks;

    if (visibleBlocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visibleBlocks.length; i++) ...[
          _NoticeMessageBlock(block: visibleBlocks[i], style: baseStyle),
          if (i != visibleBlocks.length - 1) SizedBox(height: preview ? 5 : 8),
        ],
        if (preview && blocks.length > visibleBlocks.length) ...[
          const SizedBox(height: 4),
          Text(
            'Tap to view full notice',
            style: baseStyle.copyWith(
              color: const Color(0xFF0700A8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoticeMessageBlock extends StatelessWidget {
  const _NoticeMessageBlock({required this.block, required this.style});

  final _NoticeBlock block;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (block.type == _NoticeBlockType.paragraph) {
      return RichText(
        text: TextSpan(children: _noticeInlineSpans(block.html, style)),
      );
    }
    final marker = block.type == _NoticeBlockType.orderedItem
        ? '${block.index ?? 1}.'
        : '\u2022';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Text(
            marker,
            textAlign: TextAlign.right,
            style: style.copyWith(color: const Color(0xFF111640)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(children: _noticeInlineSpans(block.html, style)),
          ),
        ),
      ],
    );
  }
}

List<_NoticeBlock> _noticeBlocks(String html) {
  final normalized = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ');
  final blocks = <_NoticeBlock>[];
  final blockPattern = RegExp(
    r'<(p|ol|ul)[^>]*>([\s\S]*?)</\1>',
    caseSensitive: false,
  );
  var cursor = 0;
  for (final match in blockPattern.allMatches(normalized)) {
    _addLooseNoticeText(blocks, normalized.substring(cursor, match.start));
    final tag = match.group(1)?.toLowerCase() ?? '';
    final content = match.group(2) ?? '';
    if (tag == 'ol' || tag == 'ul') {
      final itemPattern = RegExp(
        r'<li[^>]*>([\s\S]*?)</li>',
        caseSensitive: false,
      );
      var index = 1;
      for (final item in itemPattern.allMatches(content)) {
        blocks.add(
          _NoticeBlock(
            tag == 'ol'
                ? _NoticeBlockType.orderedItem
                : _NoticeBlockType.unorderedItem,
            item.group(1) ?? '',
            index: index,
          ),
        );
        index++;
      }
    } else {
      _addLooseNoticeText(blocks, content);
    }
    cursor = match.end;
  }
  _addLooseNoticeText(blocks, normalized.substring(cursor));
  return blocks
      .where((block) => _stripNoticeTags(block.html).trim().isNotEmpty)
      .toList();
}

void _addLooseNoticeText(List<_NoticeBlock> blocks, String html) {
  final withLineBreaks = html
      .replaceAll(RegExp(r'</div>|</h[1-6]>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'<div[^>]*>|<h[1-6][^>]*>', caseSensitive: false),
        '',
      );
  for (final part in withLineBreaks.split(RegExp(r'\n+'))) {
    if (_stripNoticeTags(part).trim().isNotEmpty) {
      blocks.add(_NoticeBlock(_NoticeBlockType.paragraph, part.trim()));
    }
  }
}

List<TextSpan> _noticeInlineSpans(String html, TextStyle baseStyle) {
  final spans = <TextSpan>[];
  final tagPattern = RegExp(r'<[^>]+>');
  var cursor = 0;
  var isBold = false;
  var isItalic = false;
  var isUnderline = false;
  Color? color;

  TextStyle currentStyle() => baseStyle.copyWith(
    fontWeight: isBold ? FontWeight.w900 : baseStyle.fontWeight,
    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
    decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    color: color ?? baseStyle.color,
  );

  void addText(String value) {
    final decoded = _decodeNoticeHtmlEntities(value);
    if (decoded.isNotEmpty) {
      spans.add(TextSpan(text: decoded, style: currentStyle()));
    }
  }

  for (final match in tagPattern.allMatches(html)) {
    addText(html.substring(cursor, match.start));
    final tag = match.group(0) ?? '';
    final lower = tag.toLowerCase();
    if (lower.startsWith('</')) {
      if (lower.startsWith('</strong') || lower.startsWith('</b')) {
        isBold = false;
      } else if (lower.startsWith('</em') || lower.startsWith('</i')) {
        isItalic = false;
      } else if (lower.startsWith('</u')) {
        isUnderline = false;
      } else if (lower.startsWith('</span')) {
        color = null;
      }
    } else {
      if (lower.startsWith('<strong') || lower.startsWith('<b')) {
        isBold = true;
      } else if (lower.startsWith('<em') || lower.startsWith('<i')) {
        isItalic = true;
      } else if (lower.startsWith('<u')) {
        isUnderline = true;
      } else if (lower.startsWith('<span')) {
        color = _noticeColorFromStyle(tag) ?? color;
      }
    }
    cursor = match.end;
  }
  addText(html.substring(cursor));
  return spans;
}

Color? _noticeColorFromStyle(String tag) {
  final styleMatch = RegExp(
    r'color\s*:\s*([^;"'
    '>]+)',
    caseSensitive: false,
  ).firstMatch(tag);
  if (styleMatch == null) {
    return null;
  }
  final raw = styleMatch.group(1)?.trim().toLowerCase() ?? '';
  if (raw.startsWith('#')) {
    final hex = raw.substring(1);
    final value = int.tryParse(
      hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex,
      radix: 16,
    );
    if (value != null) {
      return Color(0xFF000000 | value);
    }
  }
  final rgb = RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)').firstMatch(raw);
  if (rgb != null) {
    return Color.fromARGB(
      255,
      int.parse(rgb.group(1)!),
      int.parse(rgb.group(2)!),
      int.parse(rgb.group(3)!),
    );
  }
  return const {
    'red': Color(0xFFE11D48),
    'blue': Color(0xFF1D4ED8),
    'green': Color(0xFF16A34A),
    'purple': Color(0xFF7C3AED),
    'orange': Color(0xFFFF8A00),
    'black': Color(0xFF111640),
  }[raw];
}

String _stripNoticeTags(String value) {
  return value.replaceAll(RegExp(r'<[^>]+>'), '');
}

String _decodeNoticeHtmlEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final codePoint = int.tryParse(match.group(1) ?? '');
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      });
}

class _StudentProfilePage extends ConsumerWidget {
  const _StudentProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    final selectedSessionId = ref.watch(selectedAcademicSessionIdProvider);
    return profile.when(
      loading: () => const _ProfileLoadingView(title: 'Profile'),
      error: (error, _) => _ProfileErrorView(
        title: 'Could not load profile',
        message: error.toString(),
        onRetry: () => _refreshStudentParentData(ref),
      ),
      data: (data) => _StudentProfileContent(
        data: data,
        session: _selectedAcademicSession(data, selectedSessionId),
      ),
    );
  }
}

class _StudentProfileContent extends StatelessWidget {
  const _StudentProfileContent({required this.data, required this.session});

  final StudentProfileModel data;
  final AcademicSessionModel? session;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final enrollments = session == null
        ? data.enrollments
        : data.enrollments
              .where(
                (enrollment) => enrollment.academicSessionId == session!.id,
              )
              .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SoftCard(
              padding: const EdgeInsets.all(22),
              child: isWide
                  ? Row(
                      children: [
                        _StudentPhoto(student: student, size: 118),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _StudentProfileHeader(
                            data: data,
                            session: session,
                            enrollments: enrollments,
                            enrollmentCount: enrollments.length,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StudentPhoto(student: student, size: 108),
                        const SizedBox(height: 16),
                        _StudentProfileHeader(
                          data: data,
                          session: session,
                          enrollments: enrollments,
                          enrollmentCount: enrollments.length,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _InfoPanel(
              title: 'Student details',
              icon: Icons.badge_rounded,
              rows: [
                _InfoPair(
                  'Admission number',
                  session?.admissionNumber ?? student.admissionNumber,
                ),
                _InfoPair('PEN No', student.penNo),
                _InfoPair('Appar ID', student.apparId),
                _InfoPair('GR Number', student.grNumber),
                _InfoPair('UDISE Number', student.udiseNumber),
                _InfoPair('Cast', student.cast),
                _InfoPair('Username', student.username),
                _InfoPair('Email', student.email),
                _InfoPair('Phone', student.phone),
                _InfoPair('Date of birth', _formatDate(student.dateOfBirth)),
                _InfoPair(
                  'Joined on',
                  _formatDate(session?.joinedOn ?? student.joinedOn),
                ),
                _InfoPair('Address', student.address),
                _InfoPair('Institute', student.instituteName),
              ],
            ),
            const SizedBox(height: 16),
            _InfoPanel(
              title: 'Academic profile',
              icon: Icons.school_rounded,
              rows: [
                _InfoPair('Academic year', session?.academicYear ?? ''),
                _InfoPair('Session admission', session?.admissionNumber ?? ''),
                _InfoPair(
                  'Session status',
                  _formatCodeLabel(session?.status ?? ''),
                ),
                _InfoPair(
                  'Current school',
                  session?.currentSchoolName.isNotEmpty == true
                      ? session!.currentSchoolName
                      : student.currentSchoolName,
                ),
                _InfoPair(
                  'Current school address',
                  session?.currentSchoolAddress.isNotEmpty == true
                      ? session!.currentSchoolAddress
                      : student.currentSchoolAddress,
                ),
                _InfoPair(
                  'Previous school',
                  session?.previousSchoolName.isNotEmpty == true
                      ? session!.previousSchoolName
                      : student.previousSchoolName,
                ),
                _InfoPair(
                  'Previous class',
                  session?.previousClass.isNotEmpty == true
                      ? session!.previousClass
                      : student.previousClass,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _GuardianPanel(guardians: data.guardians)),
                  const SizedBox(width: 16),
                  Expanded(child: _EnrollmentPanel(enrollments: enrollments)),
                ],
              )
            else ...[
              _GuardianPanel(guardians: data.guardians),
              const SizedBox(height: 16),
              _EnrollmentPanel(enrollments: enrollments),
            ],
            const SizedBox(height: 16),
            _DocumentPreviewPanel(
              documents: data.documents,
              instituteName: data.student.instituteName,
            ),
          ],
        );
      },
    );
  }
}

class _StudentProfileHeader extends StatelessWidget {
  const _StudentProfileHeader({
    required this.data,
    required this.session,
    required this.enrollments,
    required this.enrollmentCount,
  });

  final StudentProfileModel data;
  final AcademicSessionModel? session;
  final List<StudentEnrollmentModel> enrollments;
  final int enrollmentCount;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          student.name.isEmpty ? student.username : student.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111640),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            session?.admissionNumber ?? student.admissionNumber,
            if (session?.academicYear.isNotEmpty == true) session!.academicYear,
            student.instituteName,
          ].where((part) => part.isNotEmpty).join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF68738E),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _ProfileEnrollmentSummary(
          student: student,
          session: session,
          enrollments: enrollments,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: student.isActive ? 'Active student' : 'Inactive student',
              color: student.isActive
                  ? const Color(0xFF15803D)
                  : const Color(0xFFBE123C),
            ),
            _StatusChip(
              label: '$enrollmentCount enrollment(s)',
              color: const Color(0xFF0700A8),
            ),
            _StatusChip(
              label: '${data.documents.length} documents',
              color: const Color(0xFF9333EA),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileEnrollmentSummary extends StatelessWidget {
  const _ProfileEnrollmentSummary({
    required this.student,
    required this.session,
    required this.enrollments,
  });

  final StudentInfoModel student;
  final AcademicSessionModel? session;
  final List<StudentEnrollmentModel> enrollments;

  @override
  Widget build(BuildContext context) {
    final primaryEnrollment = enrollments.isEmpty ? null : enrollments.first;
    final academicYear = session?.academicYear.trim().isNotEmpty == true
        ? session!.academicYear.trim()
        : primaryEnrollment?.academicYear.trim() ?? '';
    final batchName = primaryEnrollment?.batchName.trim() ?? '';
    final courseText =
        primaryEnrollment == null || primaryEnrollment.courses.isEmpty
        ? ''
        : primaryEnrollment.courses.join(', ');
    final status = primaryEnrollment == null
        ? ''
        : _formatCodeLabel(primaryEnrollment.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _EnrollmentSummaryItem(
            icon: Icons.school_rounded,
            label: 'Academic year',
            value: academicYear.isEmpty
                ? 'Academic year not assigned'
                : academicYear,
          ),
          _EnrollmentSummaryItem(
            icon: Icons.groups_rounded,
            label: 'Batch',
            value: batchName.isEmpty ? 'Batch not assigned' : batchName,
          ),
          if (courseText.isNotEmpty)
            _EnrollmentSummaryItem(
              icon: Icons.menu_book_rounded,
              label: 'Course',
              value: courseText,
            ),
          if (status.isNotEmpty)
            _EnrollmentSummaryItem(
              icon: Icons.verified_rounded,
              label: 'Enrollment',
              value: status,
            ),
        ],
      ),
    );
  }
}

class _EnrollmentSummaryItem extends StatelessWidget {
  const _EnrollmentSummaryItem({
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
      constraints: const BoxConstraints(minWidth: 126, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0700A8),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF0700A8), size: 17),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF68738E),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontSize: 12,
                    height: 1.15,
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

class _StudentPhoto extends StatelessWidget {
  const _StudentPhoto({required this.student, required this.size});

  final StudentInfoModel student;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = (student.name.isEmpty ? student.username : student.name)
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.substring(0, 1))
        .take(2)
        .join()
        .toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFEFF6FF),
        child: student.profileImageUrl.isEmpty
            ? Center(
                child: Text(
                  initials.isEmpty ? 'S' : initials,
                  style: TextStyle(
                    color: const Color(0xFF0700A8),
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.network(
                student.profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: const Color(0xFF0700A8),
                    size: size * 0.45,
                  ),
                ),
              ),
      ),
    );
  }
}

class _InfoPair {
  const _InfoPair(this.label, this.value);

  final String label;
  final String value;
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_InfoPair> rows;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(title: title, icon: icon),
          const SizedBox(height: 14),
          for (final row in rows) _InfoLine(label: row.label, value: row.value),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBadge(icon: icon, color: const Color(0xFF0700A8), size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF68738E),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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

class _GuardianPanel extends StatelessWidget {
  const _GuardianPanel({required this.guardians});

  final List<GuardianModel> guardians;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
            title: 'Guardian details',
            icon: Icons.family_restroom_rounded,
          ),
          const SizedBox(height: 14),
          if (guardians.isEmpty)
            const _EmptyLine(text: 'No guardian details available.')
          else
            for (final guardian in guardians)
              _InfoLine(
                label: guardian.isPrimary
                    ? '${guardian.relation.isEmpty ? 'Guardian' : guardian.relation} - Primary'
                    : guardian.relation.isEmpty
                    ? 'Guardian'
                    : guardian.relation,
                value: [
                  guardian.name,
                  guardian.phone,
                  guardian.email,
                ].where((part) => part.isNotEmpty).join(' - '),
              ),
        ],
      ),
    );
  }
}

class _EnrollmentPanel extends StatelessWidget {
  const _EnrollmentPanel({required this.enrollments});

  final List<StudentEnrollmentModel> enrollments;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(title: 'Enrollments', icon: Icons.groups_rounded),
          const SizedBox(height: 14),
          if (enrollments.isEmpty)
            const _EmptyLine(text: 'No enrollment details available.')
          else
            for (final enrollment in enrollments)
              _InfoLine(
                label:
                    '${enrollment.batchName} - ${_formatCodeLabel(enrollment.status)}',
                value:
                    '${enrollment.academicYear} - ${enrollment.courses.isEmpty ? 'No courses' : enrollment.courses.join(', ')} - ${_formatCurrency(enrollment.totalCourseFee)}',
              ),
        ],
      ),
    );
  }
}

class _DocumentPreviewPanel extends StatelessWidget {
  const _DocumentPreviewPanel({
    required this.documents,
    required this.instituteName,
  });

  final List<StudentDocumentModel> documents;
  final String instituteName;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
            title: 'Documents',
            icon: Icons.folder_copy_rounded,
          ),
          const SizedBox(height: 14),
          if (documents.isEmpty)
            const _EmptyLine(text: 'No documents uploaded yet.')
          else
            for (final document in documents.take(4))
              _DocumentTile(document: document, instituteName: instituteName),
        ],
      ),
    );
  }
}

class _StudentDocumentsPage extends ConsumerWidget {
  const _StudentDocumentsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    return profile.when(
      loading: () => const _ProfileLoadingView(title: 'Documents'),
      error: (error, _) => _ProfileErrorView(
        title: 'Could not load documents',
        message: error.toString(),
        onRetry: () => _refreshStudentParentData(ref),
      ),
      data: (data) => _DocumentsContent(
        documents: data.documents,
        instituteName: data.student.instituteName,
      ),
    );
  }
}

class _DocumentsContent extends StatelessWidget {
  const _DocumentsContent({
    required this.documents,
    required this.instituteName,
  });

  final List<StudentDocumentModel> documents;
  final String instituteName;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
            title: 'Student documents',
            icon: Icons.folder_copy_rounded,
          ),
          const SizedBox(height: 14),
          if (documents.isEmpty)
            const _EmptyLine(text: 'No student documents uploaded yet.')
          else
            for (final document in documents)
              _DocumentTile(document: document, instituteName: instituteName),
        ],
      ),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.document, required this.instituteName});

  final StudentDocumentModel document;
  final String instituteName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPreview = canPreviewDocumentUrl(document.fileUrl);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const _IconBadge(
            icon: Icons.description_rounded,
            color: Color(0xFF9333EA),
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title.isEmpty
                      ? 'Document ${document.id}'
                      : document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111640),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${document.documentTypeDisplay.isEmpty ? _formatCodeLabel(document.documentType) : document.documentTypeDisplay} - ${_formatDate(document.uploadedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF76809B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (document.note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    document.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68738E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: document.fileUrl.isEmpty
                ? 'File unavailable'
                : canPreview
                ? 'Open document'
                : 'Download document',
            onPressed: document.fileUrl.isEmpty
                ? null
                : () => canPreview
                      ? Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentViewerScreen(
                              document: document,
                              instituteName: instituteName,
                            ),
                          ),
                        )
                      : _downloadUnsupportedDocument(context, ref),
            icon: Icon(
              canPreview ? Icons.visibility_rounded : Icons.download_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUnsupportedDocument(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final fallbackFileName = document.title.isEmpty
        ? 'document-${document.id}'
        : document.title;
    final notificationId = await LocalNotificationService.showDownloadStarted(
      fileName: fallbackFileName,
    );

    try {
      final file = await ref
          .read(studentProfileRepositoryProvider)
          .downloadDocument(document.fileUrl);
      final fileName = file.fileName.isEmpty ? fallbackFileName : file.fileName;
      final autoOpenDownloads = await ref
          .read(secureStorageServiceProvider)
          .getAutoOpenDownloadsEnabled();
      final savedPath = await saveBinaryDocument(
        folderName: _documentDownloadFolderName(instituteName),
        fileName: fileName,
        bytes: file.bytes,
        notificationId: notificationId,
        autoOpen: autoOpenDownloads,
      );
      if (!context.mounted) {
        return;
      }
      await showAppMessageDialog(
        context,
        title: 'Document downloaded',
        message: 'Saved document locally:\n$savedPath',
        type: AppNotificationType.success,
      );
    } catch (error) {
      await LocalNotificationService.showDownloadFailed(
        fileName: fallbackFileName,
        message: error.toString(),
        notificationId: notificationId,
      );
      if (!context.mounted) {
        return;
      }
      showAppNotification(
        context,
        title: 'Download failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    }
  }
}

String _documentDownloadFolderName(String instituteName) {
  final safeInstitute = instituteName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), '_');
  return '${safeInstitute.isEmpty ? 'Institute' : safeInstitute}_Document';
}

StudentDocumentModel _homeworkAttachmentDocument(
  HomeworkAttachmentModel attachment,
) {
  final fileName = attachment.fileName.trim();
  return StudentDocumentModel(
    id: attachment.id,
    title: fileName.isEmpty ? 'Homework attachment ${attachment.id}' : fileName,
    documentType: 'homework',
    documentTypeDisplay: 'Homework attachment',
    fileUrl: attachment.fileUrl,
    uploadedAt: attachment.uploadedAt,
    note: '',
  );
}

String _homeworkAttachmentFolderName(String value) {
  final safeName = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), '_');
  return '${safeName.isEmpty ? 'Homework' : safeName}_Homework';
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title, subtitle: 'Loading student information'),
          const SizedBox(height: 18),
          for (var i = 0; i < 4; i++)
            Container(
              height: i == 0 ? 110 : 66,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4FB),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBadge(
            icon: Icons.error_outline_rounded,
            color: Color(0xFFE11D48),
            size: 54,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF68738E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ModulePreview extends StatelessWidget {
  const _ModulePreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: EdgeInsets.only(bottom: i == 2 ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 10,
                          width: 170 - (i * 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDE5F7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 8,
                          width: 110 + (i * 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EEFA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountPage extends ConsumerWidget {
  const _AccountPage({required this.user, required this.onLogout});

  final UserModel user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    final instituteName = profile.asData?.value.student.instituteName ?? '';
    return _SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(user: user, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(user),
                      style: const TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email.isEmpty ? user.username : user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF68738E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ProfileRow(label: 'Username', value: user.username),
          _ProfileRow(label: 'Role', value: user.role),
          _ProfileRow(
            label: 'Institute',
            value: instituteName.isEmpty
                ? 'Institute ${user.instituteId}'
                : instituteName,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _showChangePasswordDialog(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF29C7F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Update password'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onLogout,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0700A8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }
}

class _SettingsPage extends ConsumerStatefulWidget {
  const _SettingsPage({
    required this.user,
    required this.onLogout,
    required this.onEnablePush,
    required this.onDisablePush,
  });

  final UserModel user;
  final VoidCallback onLogout;
  final Future<bool> Function() onEnablePush;
  final Future<void> Function() onDisablePush;

  @override
  ConsumerState<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<_SettingsPage> {
  var _downloadFormat = 'PDF';
  var _backgroundSync = true;
  var _pushNotifications = true;
  var _isUpdatingPushNotifications = false;
  var _biometricLock = false;
  var _autoOpenDownloads = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadPushPreference);
    Future<void>.microtask(_loadDownloadPreference);
  }

  Future<void> _loadPushPreference() async {
    final enabled = await ref
        .read(secureStorageServiceProvider)
        .getPushNotificationsEnabled();
    if (mounted) {
      setState(() => _pushNotifications = enabled);
    }
  }

  Future<void> _loadDownloadPreference() async {
    final enabled = await ref
        .read(secureStorageServiceProvider)
        .getAutoOpenDownloadsEnabled();
    if (mounted) {
      setState(() => _autoOpenDownloads = enabled);
    }
  }

  Future<void> _setAutoOpenDownloads(bool enabled) async {
    setState(() => _autoOpenDownloads = enabled);
    await ref
        .read(secureStorageServiceProvider)
        .saveAutoOpenDownloadsEnabled(enabled);
  }

  Future<void> _setPushNotifications(bool enabled) async {
    if (_isUpdatingPushNotifications) {
      return;
    }
    setState(() {
      _pushNotifications = enabled;
      _isUpdatingPushNotifications = true;
    });
    try {
      await ref
          .read(secureStorageServiceProvider)
          .savePushNotificationsEnabled(enabled);
      if (enabled) {
        final registered = await widget.onEnablePush();
        if (!registered) {
          await ref
              .read(secureStorageServiceProvider)
              .savePushNotificationsEnabled(false);
          if (mounted) {
            setState(() => _pushNotifications = false);
          }
          if (mounted) {
            showAppNotification(
              context,
              title: 'Push not enabled',
              message:
                  'Notification permission or Firebase setup is not available on this device.',
              type: AppNotificationType.warning,
            );
          }
          return;
        }
        if (mounted) {
          showAppNotification(
            context,
            title: 'Push notifications on',
            message: 'This device will receive school alerts.',
            type: AppNotificationType.success,
          );
        }
      } else {
        await widget.onDisablePush();
        if (mounted) {
          showAppNotification(
            context,
            title: 'Push notifications off',
            message: 'This device was removed from school alerts.',
            type: AppNotificationType.info,
          );
        }
      }
    } catch (error) {
      await ref
          .read(secureStorageServiceProvider)
          .savePushNotificationsEnabled(!enabled);
      if (mounted) {
        setState(() => _pushNotifications = !enabled);
        showAppNotification(
          context,
          title: 'Push setting failed',
          message: error.toString(),
          type: AppNotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPushNotifications = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SoftCard(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              _IconBadge(
                icon: Icons.tune_rounded,
                color: const Color(0xFF2563EB),
                size: 58,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App settings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF111640),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Important app controls for theme, sync, cache, downloads and security.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF68738E),
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Refresh app data',
                onPressed: () => _refreshStudentParentData(ref),
                icon: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final left = Column(
              children: [
                _SettingsSection(
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFF2563EB),
                  title: 'App settings',
                  subtitle: 'Only the key preferences for this device.',
                  children: [
                    _SettingsSwitchRow(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Background refresh',
                      subtitle: 'Keep cached student data updating quietly.',
                      value: _backgroundSync,
                      onChanged: (value) =>
                          setState(() => _backgroundSync = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CacheSyncSettingsPanel(
                  apiClient: ref.watch(apiClientProvider),
                  onRefresh: () => setState(() {}),
                  onClear: () {
                    ref.read(apiClientProvider).clearGetCache();
                    _refreshStudentParentData(ref);
                    setState(() {});
                    showAppNotification(
                      context,
                      title: 'Cache cleared',
                      message: 'Student app data will refresh now.',
                      type: AppNotificationType.success,
                    );
                  },
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xFF7C3AED),
                  title: 'Notifications',
                  subtitle: 'Allow or stop school alerts on this device.',
                  children: [
                    _SettingsSwitchRow(
                      icon: Icons.notifications_rounded,
                      title: 'Push notifications',
                      subtitle: 'Allow school alerts on this device.',
                      value: _pushNotifications,
                      onChanged: _isUpdatingPushNotifications
                          ? null
                          : _setPushNotifications,
                    ),
                  ],
                ),
              ],
            );

            final right = Column(
              children: [
                _SettingsSection(
                  icon: Icons.download_rounded,
                  color: const Color(0xFF0891B2),
                  title: 'Downloads',
                  subtitle: 'File behavior on this Android device.',
                  children: [
                    _SettingsChoiceRow(
                      icon: Icons.description_rounded,
                      title: 'Default download format',
                      value: _downloadFormat,
                      options: const ['PDF', 'Excel', 'HTML'],
                      onChanged: (value) =>
                          setState(() => _downloadFormat = value),
                    ),
                    _SettingsSwitchRow(
                      icon: Icons.open_in_new_rounded,
                      title: 'Auto-open downloads',
                      subtitle: 'Open files after download completes.',
                      value: _autoOpenDownloads,
                      onChanged: _setAutoOpenDownloads,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.security_rounded,
                  color: const Color(0xFFE11D48),
                  title: 'Privacy & Security',
                  subtitle: 'Protect account access and sensitive data.',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.lock_reset_rounded,
                      title: 'Update password',
                      subtitle: 'Change your login password.',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _ChangePasswordDialog(),
                      ),
                    ),
                    _SettingsSwitchRow(
                      icon: Icons.fingerprint_rounded,
                      title: 'App lock',
                      subtitle: 'Require device lock before opening.',
                      value: _biometricLock,
                      onChanged: (value) =>
                          setState(() => _biometricLock = value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.info_rounded,
                  color: const Color(0xFFEA580C),
                  title: 'App info',
                  subtitle: 'Current server and installed version.',
                  children: [
                    _SettingsInfoRow(
                      icon: Icons.cloud_queue_rounded,
                      title: 'API server',
                      value: AppConfig.defaultBaseUrl,
                    ),
                    _SettingsInfoRow(
                      icon: Icons.info_rounded,
                      title: 'App version',
                      value: '1.0.1',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.account_circle_rounded,
                  color: const Color(0xFF64748B),
                  title: 'Account',
                  subtitle: 'Login security and sign out.',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign out from this device.',
                      danger: true,
                      onTap: widget.onLogout,
                    ),
                  ],
                ),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, color: color, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: _SectionTitle(title: title, subtitle: subtitle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const _SettingsDivider(),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 18, color: Color(0xFFE8ECF5));
  }
}

class _CacheSyncSettingsPanel extends StatelessWidget {
  const _CacheSyncSettingsPanel({
    required this.apiClient,
    required this.onRefresh,
    required this.onClear,
  });

  final ApiClient apiClient;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: apiClient.backgroundRefreshes,
      builder: (context, _, child) {
        final status = apiClient.cacheSyncStatus;
        return _SettingsSection(
          icon: Icons.storage_rounded,
          color: status.isSyncing
              ? const Color(0xFFD97706)
              : const Color(0xFF0F766E),
          title: 'Cache & Sync',
          subtitle: 'Manage cached student data and background refresh.',
          children: [
            Row(
              children: [
                Expanded(
                  child: _SettingsInfoRow(
                    icon: Icons.cloud_done_rounded,
                    title: 'Status',
                    value: status.isSyncing ? 'Syncing' : 'Idle',
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SyncStatChip(label: 'Cached', value: status.cachedResponses),
                _SyncStatChip(label: 'Fresh', value: status.freshResponses),
                _SyncStatChip(label: 'Stale', value: status.staleResponses),
                _SyncStatChip(
                  label: 'In flight',
                  value: status.inFlightRefreshes + status.backgroundRefreshes,
                ),
              ],
            ),
            Text(
              status.detail,
              style: const TextStyle(
                color: Color(0xFF68738E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            _SettingsInfoRow(
              icon: Icons.refresh_rounded,
              title: 'Last refresh',
              value: _formatSettingsDateTime(status.lastRefreshAt),
            ),
            _SettingsInfoRow(
              icon: Icons.delete_sweep_rounded,
              title: 'Last cache clear',
              value: _formatSettingsDateTime(status.lastCacheClearAt),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh status'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Clear cache'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SyncStatChip extends StatelessWidget {
  const _SyncStatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: const Color(0xFF0700A8),
        child: Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

String _formatSettingsDateTime(DateTime? value) {
  if (value == null) {
    return 'Not yet';
  }
  final local = value.toLocal();
  final hour = local.hour > 12
      ? local.hour - 12
      : local.hour == 0
      ? 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day-$month-${local.year} $hour:$minute $period';
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SettingsRowIcon(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: _SettingsRowText(title: title, subtitle: subtitle),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SettingsChoiceRow extends StatelessWidget {
  const _SettingsChoiceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SettingsRowIcon(icon: icon),
            const SizedBox(width: 12),
            Expanded(child: _SettingsRowText(title: title)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: value == option,
                onSelected: (_) => onChanged(option),
                selectedColor: const Color(0xFFE0E7FF),
                labelStyle: TextStyle(
                  color: value == option
                      ? const Color(0xFF0700A8)
                      : const Color(0xFF68738E),
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SettingsRowIcon(icon: icon),
        const SizedBox(width: 12),
        Expanded(child: _SettingsRowText(title: title)),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF111640),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE11D48) : const Color(0xFF0700A8);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            _SettingsRowIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: _SettingsRowText(title: title, subtitle: subtitle),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _SettingsRowIcon extends StatelessWidget {
  const _SettingsRowIcon({
    required this.icon,
    this.color = const Color(0xFF0700A8),
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SettingsRowText extends StatelessWidget {
  const _SettingsRowText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111640),
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF76809B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PasswordField(
                controller: _currentController,
                label: 'Current password',
                obscure: _obscure,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _newController,
                label: 'New password',
                obscure: _obscure,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required';
                  }
                  if (value.length < 8) {
                    return 'Use at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmController,
                label: 'Confirm password',
                obscure: _obscure,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm password is required';
                  }
                  if (value != _newController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  label: Text(_obscure ? 'Show passwords' : 'Hide passwords'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
            confirmPassword: _confirmController.text,
          );
      if (!mounted) {
        return;
      }
      showAppNotification(
        context,
        title: 'Password updated',
        message: 'Your password was updated successfully.',
        type: AppNotificationType.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppNotification(
        context,
        title: 'Password update failed',
        message: error.toString(),
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
            return null;
          },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF68738E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF111640),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int selectedIndex;
  final List<int> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final activePosition = destinations.contains(selectedIndex)
        ? destinations.indexOf(selectedIndex)
        : 0;
    const items = [
      _Destination('Home', Icons.dashboard_rounded),
      _Destination('Attend', Icons.fact_check_rounded),
      _Destination('Fees', Icons.account_balance_wallet_rounded),
      _Destination('Work', Icons.assignment_rounded),
      _Destination('Exams', Icons.quiz_rounded),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 88,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0700A8),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3D101A70),
              blurRadius: 28,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _MobileNavItem(
                  item: items[i],
                  isSelected: activePosition == i,
                  onTap: () => onSelect(destinations[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingNoticeShortcut extends ConsumerWidget {
  const _FloatingNoticeShortcut({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount =
        ref.watch(noticesProvider).asData?.value.summary.unreadCount ?? 0;
    final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';

    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Open notices, $unreadCount unread'
          : 'Open notices',
      child: Tooltip(
        message: unreadCount > 0
            ? '$unreadCount unread notice${unreadCount == 1 ? '' : 's'}'
            : 'Open notices',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF29C7F6)
                            : const Color(0xFF0700A8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40101A70),
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -3,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _Destination item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: isSelected ? 62 : 54,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF29C7F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: Colors.white, size: isSelected ? 25 : 22),
            if (isSelected) ...[
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A1B60),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SearchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: Color(0xFF8792AD)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Search student services',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF8792AD),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF0700A8)),
        ),
      ),
    );
  }
}

class _SessionSelector extends ConsumerWidget {
  const _SessionSelector({required this.isOnDark});

  final bool isOnDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    return profile.when(
      loading: () => _SessionSelectorShell(
        isOnDark: isOnDark,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => _SessionSelectorShell(
        isOnDark: isOnDark,
        child: const Text(
          'Session',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      data: (data) {
        final sessions = data.academicSessions;
        if (sessions.isEmpty) {
          return _SessionSelectorShell(
            isOnDark: isOnDark,
            child: const Text(
              'No session',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          );
        }

        final selectedId = ref.watch(selectedAcademicSessionIdProvider);
        final activeId = data.activeSession?.id ?? sessions.first.id;
        final value = sessions.any((session) => session.id == selectedId)
            ? selectedId
            : activeId;

        return _SessionSelectorShell(
          isOnDark: isOnDark,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isOnDark ? Colors.white : const Color(0xFF0700A8),
              ),
              style: TextStyle(
                color: isOnDark ? Colors.white : const Color(0xFF111640),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              selectedItemBuilder: (context) => [
                for (final session in sessions)
                  Text(
                    session.academicYear.isEmpty
                        ? session.admissionNumber
                        : session.academicYear,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
              items: [
                for (final session in sessions)
                  DropdownMenuItem<int>(
                    value: session.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.academicYear.isEmpty
                              ? 'Session ${session.id}'
                              : session.academicYear,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111640),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (session.admissionNumber.isNotEmpty)
                          Text(
                            session.admissionNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF68738E),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                ref.read(selectedAcademicSessionIdProvider.notifier).state =
                    value;
                _refreshStudentParentData(ref);
              },
            ),
          ),
        );
      },
    );
  }
}

class _SessionSelectorShell extends StatelessWidget {
  const _SessionSelectorShell({required this.isOnDark, required this.child});

  final bool isOnDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final selectorWidth = screenWidth >= 980
        ? 138.0
        : (screenWidth * 0.25).clamp(84.0, 100.0).toDouble();
    return Container(
      width: selectorWidth,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: isOnDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnDark
              ? Colors.white.withValues(alpha: 0.16)
              : const Color(0xFFE0E7FF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            color: isOnDark ? Colors.white : const Color(0xFF0700A8),
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.onMenuOpened,
    required this.onMenuClosed,
    this.isOnDark = false,
  });

  final UserModel user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onMenuOpened;
  final VoidCallback onMenuClosed;
  final bool isOnDark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      offset: const Offset(0, 12),
      elevation: 18,
      constraints: const BoxConstraints(minWidth: 292, maxWidth: 330),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      onOpened: onMenuOpened,
      onCanceled: onMenuClosed,
      onSelected: (value) {
        onMenuClosed();
        if (value.startsWith('nav:')) {
          final index = int.tryParse(value.substring(4));
          if (index != null) {
            onSelect(index);
          }
          return;
        }
        if (value == 'account') {
          onSelect(_StudentParentDashboardScreenState._accountIndex);
          return;
        }
        if (value == 'settings') {
          onSelect(_StudentParentDashboardScreenState._settingsIndex);
          return;
        }
        if (value == 'logout') {
          onLogout();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'nav:9',
          padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: _AccountMenuHeader(),
        ),
        const PopupMenuDivider(height: 4),
        _menuSectionLabel('Main navigation'),
        for (final item
            in isOnDark ? _mobilePrimaryMenuItems : _primaryMenuItems)
          _accountMenuItem(
            value: 'nav:${item.index}',
            icon: item.icon,
            label: item.label,
            isSelected: selectedIndex == item.index,
          ),
        const PopupMenuDivider(height: 8),
        _menuSectionLabel('Academic tools'),
        for (final item
            in isOnDark ? _mobileAcademicMenuItems : _academicMenuItems)
          _accountMenuItem(
            value: 'nav:${item.index}',
            icon: item.icon,
            label: item.label,
            isSelected: selectedIndex == item.index,
          ),
        const PopupMenuDivider(height: 8),
        _accountMenuItem(
          value: 'settings',
          icon: Icons.settings_rounded,
          label: 'Settings',
          isSelected:
              selectedIndex ==
              _StudentParentDashboardScreenState._settingsIndex,
        ),
        _accountMenuItem(
          value: 'account',
          icon: Icons.manage_accounts_rounded,
          label: 'Account settings',
          isSelected:
              selectedIndex == _StudentParentDashboardScreenState._accountIndex,
        ),
        _accountMenuItem(
          value: 'logout',
          icon: Icons.logout_rounded,
          label: 'Logout',
          color: const Color(0xFFE11D48),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isOnDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(17),
        ),
        child: _AccountMenuButtonAvatar(user: user),
      ),
    );
  }

  static const _primaryMenuItems = [
    _MenuDestination(0, 'Dashboard', Icons.dashboard_rounded),
    _MenuDestination(1, 'Attendance', Icons.fact_check_rounded),
    _MenuDestination(2, 'Fees', Icons.account_balance_wallet_rounded),
    _MenuDestination(3, 'Homework', Icons.assignment_rounded),
    _MenuDestination(8, 'Notices', Icons.campaign_rounded),
    _MenuDestination(9, 'Profile', Icons.badge_rounded),
  ];

  static const _academicMenuItems = [
    _MenuDestination(4, 'Exams', Icons.quiz_rounded),
    _MenuDestination(5, 'Results', Icons.workspace_premium_rounded),
    _MenuDestination(7, 'Timetable', Icons.calendar_month_rounded),
    _MenuDestination(11, 'Notifications', Icons.notifications_rounded),
    _MenuDestination(12, 'Documents', Icons.folder_copy_rounded),
  ];

  static const _mobilePrimaryMenuItems = [
    _MenuDestination(0, 'Dashboard', Icons.dashboard_rounded),
    _MenuDestination(1, 'Attendance', Icons.fact_check_rounded),
    _MenuDestination(2, 'Fees', Icons.account_balance_wallet_rounded),
    _MenuDestination(3, 'Homework', Icons.assignment_rounded),
    _MenuDestination(8, 'Notices', Icons.campaign_rounded),
  ];

  static const _mobileAcademicMenuItems = [
    _MenuDestination(4, 'Exams', Icons.quiz_rounded),
    _MenuDestination(5, 'Results', Icons.workspace_premium_rounded),
    _MenuDestination(7, 'Timetable', Icons.calendar_month_rounded),
    _MenuDestination(12, 'Documents', Icons.folder_copy_rounded),
  ];

  PopupMenuItem<String> _menuSectionLabel(String label) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF76809B),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  PopupMenuItem<String> _accountMenuItem({
    required String value,
    required IconData icon,
    required String label,
    bool isSelected = false,
    Color? color,
  }) {
    final itemColor = color ?? const Color(0xFF111640);
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0700A8) : itemColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0700A8) : itemColor,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0700A8),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountMenuWithDeveloperButton extends StatelessWidget {
  const _AccountMenuWithDeveloperButton({
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.onDeveloperTap,
    required this.onMenuOpened,
    required this.onMenuClosed,
  });

  final UserModel user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onDeveloperTap;
  final VoidCallback onMenuOpened;
  final VoidCallback onMenuClosed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 79,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          _AccountMenu(
            user: user,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
            onLogout: onLogout,
            onMenuOpened: onMenuOpened,
            onMenuClosed: onMenuClosed,
          ),
          Positioned(
            right: 6,
            top: 51,
            child: _DeveloperDetailsIconButton(onTap: onDeveloperTap),
          ),
        ],
      ),
    );
  }
}

class _DeveloperDetailsIconButton extends StatelessWidget {
  const _DeveloperDetailsIconButton({
    required this.onTap,
    this.isOnDark = false,
  });

  final VoidCallback onTap;
  final bool isOnDark;

  @override
  Widget build(BuildContext context) {
    final foreground = isOnDark ? Colors.white : const Color(0xFF0700A8);
    return Semantics(
      button: true,
      label: 'Developer details',
      hint: 'Open developer details',
      child: Tooltip(
        message: 'Developer details',
        child: Material(
          color: isOnDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                Icons.question_mark_rounded,
                color: foreground,
                size: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountMenuHeader extends ConsumerWidget {
  const _AccountMenuHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    final student = profile.valueOrNull?.student;
    final session = profile.valueOrNull?.activeSession;
    final name = student?.name.trim().isNotEmpty == true
        ? student!.name
        : student?.username ?? 'Student';
    final admissionNumber = session?.admissionNumber.isNotEmpty == true
        ? session!.admissionNumber
        : student?.admissionNumber ?? student?.username ?? '';

    return Container(
      height: 106,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F7FF), Color(0xFFE8ECFF)],
        ),
        border: Border.all(color: Color(0xFFE0E7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140700A8),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -48,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 52,
                height: 120,
                color: const Color(0xFF0700A8).withValues(alpha: 0.08),
              ),
            ),
          ),
          const Positioned(
            right: 4,
            top: 2,
            child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFA8B0FF)),
          ),
          Row(
            children: [
              _StudentMenuAvatar(
                student: student,
                size: 44,
                accessToken:
                    ref.watch(_brandAccessTokenProvider).valueOrNull ?? '',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF111640),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        admissionNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF63708F),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message: 'View profile',
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x180700A8),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF0700A8),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentMenuAvatar extends StatelessWidget {
  const _StudentMenuAvatar({
    required this.student,
    required this.size,
    required this.accessToken,
  });

  final StudentInfoModel? student;
  final double size;
  final String accessToken;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteImageUrl(student?.profileImageUrl ?? '');
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFFFC857),
        child: imageUrl.isEmpty
            ? Center(
                child: Icon(
                  Icons.person_rounded,
                  color: const Color(0xFF111640),
                  size: size * 0.56,
                ),
              )
            : Image.network(
                imageUrl,
                headers: accessToken.isEmpty
                    ? null
                    : {'Authorization': 'Bearer $accessToken'},
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.person_rounded,
                    color: const Color(0xFF111640),
                    size: size * 0.56,
                  ),
                ),
              ),
      ),
    );
  }
}

class _AccountMenuButtonAvatar extends ConsumerWidget {
  const _AccountMenuButtonAvatar({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student =
        ref.watch(studentProfileProvider).valueOrNull?.student ??
        ref.watch(studentBootstrapProvider(null)).valueOrNull?.profile.student;
    return _StudentMenuAvatar(
      student: student,
      size: 40,
      accessToken: ref.watch(_brandAccessTokenProvider).valueOrNull ?? '',
    );
  }
}

class _MenuDestination {
  const _MenuDestination(this.index, this.label, this.icon);

  final int index;
  final String label;
  final IconData icon;
}

class _BrandLockup extends ConsumerWidget {
  const _BrandLockup({
    required this.size,
    required this.isOnDark,
    required this.showSubtitle,
    required this.onTap,
  });

  final double size;
  final bool isOnDark;
  final bool showSubtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student =
        ref.watch(studentProfileProvider).valueOrNull?.student ??
        ref.watch(studentBootstrapProvider(null)).valueOrNull?.profile.student;
    final instituteName = student?.instituteName.trim() ?? '';
    final instituteLogoUrl = _absoluteImageUrl(
      student?.instituteLogoUrl.trim() ?? '',
    );
    final title = instituteName.isEmpty ? 'UCM' : instituteName;
    const titleColor = Color(0xFFFFC857);
    final subtitleColor = isOnDark
        ? const Color(0xFFB8C3FF)
        : const Color(0xFF69718A);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Row(
        children: [
          _LogoMark(
            size: size,
            logoUrl: instituteLogoUrl,
            title: title,
            accessToken: ref.watch(_brandAccessTokenProvider).valueOrNull ?? '',
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: showSubtitle ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: showSubtitle ? 19 : 14,
                    height: showSubtitle ? null : 1.24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Parent portal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({
    required this.size,
    required this.logoUrl,
    required this.title,
    required this.accessToken,
  });

  final double size;
  final String logoUrl;
  final String title;
  final String accessToken;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: logoUrl.isEmpty
          ? _InstituteInitialsMark(title: title)
          : Image.network(
              logoUrl,
              headers: accessToken.isEmpty
                  ? null
                  : {'Authorization': 'Bearer $accessToken'},
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _InstituteInitialsMark(title: title),
            ),
    );
  }
}

class _InstituteInitialsMark extends StatelessWidget {
  const _InstituteInitialsMark({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final initials = _textInitials(title);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          initials.isEmpty ? 'UCM' : initials,
          maxLines: 1,
          style: const TextStyle(
            color: Color(0xFF0700A8),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.size});

  final UserModel user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFC857),
      child: Text(
        _initials(user),
        style: TextStyle(
          color: const Color(0xFF111640),
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 48});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111640),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF76809B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeatureCatalog {
  static const items = [
    _Feature(
      title: 'Attendance',
      badge: 'Open',
      summary:
          'Monitor daily attendance, late marks, monthly percentage, and leave patterns.',
      icon: Icons.fact_check_rounded,
      color: Color(0xFF21B6E8),
      chips: ['Daily log', 'Leave count', 'Late marks'],
    ),
    _Feature(
      title: 'Fees',
      badge: 'Open',
      summary:
          'Review fee status, upcoming dues, paid invoices, and downloadable receipts.',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF36C321),
      chips: ['Invoices', 'Receipts', 'Payment history'],
    ),
    _Feature(
      title: 'Homework',
      badge: 'Open',
      summary:
          'Track homework, assignments, submission deadlines, and teacher feedback.',
      icon: Icons.assignment_rounded,
      color: Color(0xFFFF8B3D),
      chips: ['Pending work', 'Submissions', 'Feedback'],
    ),
    _Feature(
      title: 'Exams',
      badge: 'Open',
      summary:
          'Follow exam schedules, seating plans, syllabus notes, and preparation updates.',
      icon: Icons.quiz_rounded,
      color: Color(0xFFEF4444),
      chips: ['Schedule', 'Syllabus', 'Exam alerts'],
    ),
    _Feature(
      title: 'Results',
      badge: 'Open',
      summary:
          'See exam schedules, marks, grades, rank insights, and progress trends.',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFF8B5CF6),
      chips: ['Gradebook', 'Progress', 'Exam rank'],
    ),
    _Feature(
      title: 'Reports',
      badge: 'Open',
      summary:
          'Review academic reports, attendance trends, fee summaries, and progress snapshots.',
      icon: Icons.analytics_rounded,
      color: Color(0xFF0EA5E9),
      chips: ['Progress', 'Attendance', 'Fee summary'],
    ),
    _Feature(
      title: 'Timetable',
      badge: 'Open',
      summary:
          'View today classes, weekly timetable, rooms, and teacher assignments.',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFF14B8A6),
      chips: ['Today', 'Weekly', 'Periods'],
    ),
    _Feature(
      title: 'Notices',
      badge: 'Open',
      summary:
          'Stay updated with institute announcements, circulars, and event notices.',
      icon: Icons.campaign_rounded,
      color: Color(0xFFFF5D8F),
      chips: ['Circulars', 'Events', 'Announcements'],
    ),
    _Feature(
      title: 'Profile',
      badge: 'Student info',
      summary:
          'Keep student details, class information, guardian details, and records organized.',
      icon: Icons.badge_rounded,
      color: Color(0xFF4F46E5),
      chips: ['Class', 'Guardian', 'Records'],
    ),
    _Feature(
      title: 'Teachers',
      badge: 'Open',
      summary:
          'Message teachers, follow conversation history, and manage meeting requests.',
      icon: Icons.forum_rounded,
      color: Color(0xFF0F766E),
      chips: ['Messages', 'Meetings', 'Feedback'],
    ),
    _Feature(
      title: 'Notifications',
      badge: 'Open',
      summary:
          'Review alerts for attendance, fees, homework, notices, results, and messages.',
      icon: Icons.notifications_rounded,
      color: Color(0xFFE11D48),
      chips: ['Alerts', 'Reminders', 'Updates'],
    ),
    _Feature(
      title: 'Documents',
      badge: 'Open',
      summary:
          'Access certificates, documents, fee receipts, and shared files.',
      icon: Icons.folder_copy_rounded,
      color: Color(0xFF9333EA),
      chips: ['Receipts', 'Files', 'Certificates'],
    ),
  ];
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _Feature {
  const _Feature({
    required this.title,
    required this.badge,
    required this.summary,
    required this.icon,
    required this.color,
    required this.chips,
  });

  final String title;
  final String badge;
  final String summary;
  final IconData icon;
  final Color color;
  final List<String> chips;
}

class _Metric {
  const _Metric(this.label, this.value, this.caption, this.icon, this.color);

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _FeeSummaryMetric {
  const _FeeSummaryMetric(
    this.label,
    this.value,
    this.caption,
    this.icon,
    this.color,
  );

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _Activity {
  const _Activity(this.title, this.subtitle, this.color);

  final String title;
  final String subtitle;
  final Color color;
}

Color _attendanceRateColor(double rate) {
  if (rate >= 90) {
    return const Color(0xFF36C321);
  }
  if (rate >= 75) {
    return const Color(0xFFFF8B3D);
  }
  return const Color(0xFFE11D48);
}

Color _attendanceStatusColor(String status) {
  switch (status) {
    case 'PRESENT':
      return const Color(0xFF36C321);
    case 'LATE':
      return const Color(0xFFFF8B3D);
    case 'ABSENT':
      return const Color(0xFFE11D48);
    default:
      return const Color(0xFF21B6E8);
  }
}

IconData _attendanceStatusIcon(String status) {
  switch (status) {
    case 'PRESENT':
      return Icons.check_circle_rounded;
    case 'LATE':
      return Icons.schedule_rounded;
    case 'ABSENT':
      return Icons.cancel_rounded;
    default:
      return Icons.fact_check_rounded;
  }
}

Color _noticePriorityColor(String priority) {
  switch (priority) {
    case 'URGENT':
      return const Color(0xFFE11D48);
    case 'IMPORTANT':
      return const Color(0xFFFF8B3D);
    default:
      return const Color(0xFF21B6E8);
  }
}

String _displayName(UserModel user) {
  return user.name.trim().isNotEmpty ? user.name.trim() : user.username;
}

String _initials(UserModel user) {
  final source = _displayName(user);
  final initials = _textInitials(source);
  return initials.isEmpty ? 'U' : initials;
}

String _textInitials(String source) {
  final parts = source
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.first.isEmpty) {
    return '';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _absoluteImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    return trimmed;
  }
  final base = Uri.parse(AppConfig.baseUrl);
  final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return base.resolve(path).toString();
}

String _todayLabel() {
  final now = DateTime.now();
  return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
}

Future<ui.Image?> _decodeReceiptImageBytes(List<int> bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(Uint8List.fromList(bytes), completer.complete);
  return completer.future;
}

Future<ui.Image?> _loadReceiptImage(
  String imageUrl, {
  ApiClient? apiClient,
}) async {
  final absoluteUrl = _absoluteImageUrl(imageUrl);
  if (absoluteUrl.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(absoluteUrl);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  if (apiClient != null) {
    try {
      final response = await apiClient.dio.get<List<int>>(
        absoluteUrl,
        options: Options(
          responseType: ResponseType.bytes,
          extra: {'requiresAuth': true},
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final bytes = response.data;
      if (bytes != null && bytes.isNotEmpty) {
        return await _decodeReceiptImageBytes(bytes);
      }
    } catch (_) {
      // Fall back to unauthenticated image loading for public media URLs.
    }
  }
  try {
    final data = await NetworkAssetBundle(
      uri,
    ).load(uri.toString()).timeout(const Duration(seconds: 5));
    return await _decodeReceiptImageBytes(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

ui.Rect _containImageRect(ui.Image image, ui.Rect bounds) {
  final sourceWidth = image.width.toDouble();
  final sourceHeight = image.height.toDouble();
  final scale = sourceWidth / sourceHeight > bounds.width / bounds.height
      ? bounds.width / sourceWidth
      : bounds.height / sourceHeight;
  final fittedWidth = sourceWidth * scale;
  final fittedHeight = sourceHeight * scale;
  return ui.Rect.fromLTWH(
    bounds.left + (bounds.width - fittedWidth) / 2,
    bounds.top + (bounds.height - fittedHeight) / 2,
    fittedWidth,
    fittedHeight,
  );
}

Uint8List _encodeReceiptJpg(Map<String, Object> payload) {
  final rawImage = img.Image.fromBytes(
    width: payload['width']! as int,
    height: payload['height']! as int,
    bytes: (payload['bytes']! as Uint8List).buffer,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(
    img.encodeJpg(rawImage, quality: payload['quality']! as int),
  );
}

Future<Uint8List> _buildDigitalReceiptJpg({
  required FeeDetailsModel data,
  required PaymentHistoryModel payment,
  String fallbackLogoUrl = '',
  ApiClient? apiClient,
}) async {
  const width = 1080;
  const height = 1680;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  void drawRoundRect(
    ui.Rect rect,
    Color color, {
    double radius = 32,
    Color? borderColor,
    double borderWidth = 2,
  }) {
    final rrect = ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius));
    canvas.drawRRect(rrect, ui.Paint()..color = color);
    if (borderColor != null) {
      canvas.drawRRect(
        rrect,
        ui.Paint()
          ..color = borderColor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
  }

  void drawText(
    String text,
    double x,
    double y,
    double maxWidth, {
    double size = 34,
    FontWeight weight = FontWeight.w700,
    Color color = const Color(0xFF111640),
    ui.TextAlign align = ui.TextAlign.left,
    int maxLines = 1,
    double height = 1.12,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              maxLines: maxLines,
              ellipsis: '...',
              fontSize: size,
              fontWeight: weight,
              fontFamily: 'Roboto',
              height: height,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
              fontFamily: 'Roboto',
              height: height,
            ),
          )
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    canvas.drawParagraph(paragraph, ui.Offset(x, y));
  }

  double drawInfoRow(
    double y,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    drawText(
      label.toUpperCase(),
      104,
      y,
      330,
      size: 24,
      weight: FontWeight.w900,
      color: const Color(0xFF6B7280),
    );
    drawText(
      value.isEmpty ? '-' : value,
      430,
      y - (emphasize ? 6 : 0),
      546,
      size: emphasize ? 38 : 30,
      weight: emphasize ? FontWeight.w900 : FontWeight.w800,
      color: emphasize ? const Color(0xFF0700A8) : const Color(0xFF111640),
      align: ui.TextAlign.right,
      maxLines: 2,
    );
    canvas.drawLine(
      ui.Offset(104, y + 52),
      ui.Offset(976, y + 52),
      ui.Paint()
        ..color = const Color(0xFFE5EAF6)
        ..strokeWidth = 2,
    );
    return y + 82;
  }

  final studentName = data.student.name.isEmpty
      ? data.student.username
      : data.student.name;
  final admission = data.student.admissionNumber.isEmpty
      ? data.student.id.toString()
      : data.student.admissionNumber;
  final receiptNumber = payment.receiptNumber.isEmpty
      ? 'Receipt ${payment.id}'
      : payment.receiptNumber;
  final invoiceTitle = payment.invoiceTitle.isEmpty
      ? 'Fee payment'
      : payment.invoiceTitle;
  final status = payment.status.isEmpty
      ? 'Paid'
      : _formatCodeLabel(payment.status);
  final instituteName = data.student.instituteName.trim().isEmpty
      ? 'School'
      : data.student.instituteName.trim();
  final logoUrl = data.student.instituteLogoUrl.trim().isNotEmpty
      ? data.student.instituteLogoUrl
      : fallbackLogoUrl;
  final instituteLogo = await _loadReceiptImage(logoUrl, apiClient: apiClient);

  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFFF3F6FF),
  );
  drawRoundRect(
    const ui.Rect.fromLTWH(48, 48, 984, 1584),
    Colors.white,
    radius: 44,
    borderColor: const Color(0xFFDDE4F5),
  );
  drawRoundRect(
    const ui.Rect.fromLTWH(48, 48, 984, 290),
    const Color(0xFF0700A8),
    radius: 44,
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(48, 246, 984, 92),
    ui.Paint()..color = const Color(0xFF0700A8),
  );

  drawRoundRect(
    const ui.Rect.fromLTWH(104, 100, 112, 112),
    Colors.white,
    radius: 30,
    borderColor: const Color(0xFFDDE4F5),
  );
  if (instituteLogo != null) {
    final source = ui.Rect.fromLTWH(
      0,
      0,
      instituteLogo.width.toDouble(),
      instituteLogo.height.toDouble(),
    );
    canvas.drawImageRect(
      instituteLogo,
      source,
      _containImageRect(
        instituteLogo,
        const ui.Rect.fromLTWH(120, 116, 80, 80),
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    instituteLogo.dispose();
  } else {
    drawText(
      'UC',
      125,
      126,
      70,
      size: 44,
      weight: FontWeight.w900,
      color: const Color(0xFF0700A8),
      align: ui.TextAlign.center,
    );
  }
  drawText(
    'Fee Receipt',
    244,
    102,
    520,
    size: 56,
    weight: FontWeight.w900,
    color: Colors.white,
  );
  drawText(
    'Digital Student Copy',
    244,
    172,
    520,
    size: 32,
    weight: FontWeight.w800,
    color: const Color(0xFFDDE4FF),
  );
  drawRoundRect(
    const ui.Rect.fromLTWH(790, 118, 184, 70),
    Colors.white,
    radius: 999,
  );
  drawText(
    status.toUpperCase(),
    812,
    136,
    140,
    size: 28,
    weight: FontWeight.w900,
    color: const Color(0xFF15803D),
    align: ui.TextAlign.center,
  );

  drawRoundRect(
    const ui.Rect.fromLTWH(104, 258, 872, 220),
    const Color(0xFFFFFFFF),
    radius: 34,
    borderColor: const Color(0xFFE5EAF6),
  );
  drawText(
    'Amount Paid',
    144,
    304,
    380,
    size: 28,
    weight: FontWeight.w800,
    color: const Color(0xFF65708A),
  );
  drawText(
    _formatCurrency(payment.amount),
    144,
    350,
    520,
    size: 64,
    weight: FontWeight.w900,
    color: const Color(0xFF111640),
  );
  drawText(
    'Receipt No.',
    654,
    304,
    282,
    size: 26,
    weight: FontWeight.w800,
    color: const Color(0xFF65708A),
    align: ui.TextAlign.right,
  );
  drawText(
    receiptNumber,
    566,
    350,
    370,
    size: 34,
    weight: FontWeight.w900,
    color: const Color(0xFF0700A8),
    align: ui.TextAlign.right,
    maxLines: 2,
  );

  var y = 548.0;
  drawText('Student Details', 104, y, 872, size: 36, weight: FontWeight.w900);
  y += 70;
  y = drawInfoRow(y, 'Student', studentName, emphasize: true);
  y = drawInfoRow(y, 'Admission No.', admission);
  y = drawInfoRow(y, 'Invoice', invoiceTitle);
  y = drawInfoRow(y, 'Paid On', _formatDate(payment.paidOn));
  y = drawInfoRow(y, 'Payment Mode', _formatCodeLabel(payment.method));
  y = drawInfoRow(y, 'Generated On', _todayLabel());

  drawText(
    instituteName,
    104,
    1464,
    872,
    size: 34,
    weight: FontWeight.w900,
    color: const Color(0xFF111640),
    align: ui.TextAlign.center,
    maxLines: 2,
  );
  canvas.drawLine(
    const ui.Offset(284, 1546),
    const ui.Offset(796, 1546),
    ui.Paint()
      ..color = const Color(0xFFDDE4F5)
      ..strokeWidth = 3,
  );
  drawText(
    'Computer generated receipt',
    104,
    1584,
    872,
    size: 28,
    weight: FontWeight.w800,
    color: const Color(0xFF65708A),
    align: ui.TextAlign.center,
  );

  final picture = recorder.endRecording();
  final renderedImage = await picture.toImage(width, height);
  final byteData = await renderedImage.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  renderedImage.dispose();
  if (byteData == null) {
    throw StateError('Unable to create receipt image.');
  }
  final rawBytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
  return compute(_encodeReceiptJpg, {
    'width': width,
    'height': height,
    'bytes': rawBytes,
    'quality': 92,
  });
}

String _formatCurrency(double value) {
  final rounded = value.round();
  if ((value - rounded).abs() < 0.01) {
    return 'Rs. ${_groupDigits(rounded.toString())}';
  }
  final parts = value.toStringAsFixed(2).split('.');
  return 'Rs. ${_groupDigits(parts.first)}.${parts.last}';
}

String _formatPercent(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

String _groupDigits(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final fromEnd = value.length - i;
    buffer.write(value[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value.isEmpty ? '-' : value;
  }
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

DateTime? _parseDateParam(String value) {
  return DateTime.tryParse(value);
}

String _formatDateParam(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

int _attendanceLimitForRange(String dateFrom, String dateTo) {
  final start = _parseDateParam(dateFrom);
  final end = _parseDateParam(dateTo);
  if (start == null || end == null) {
    return 180;
  }
  final days = end.difference(start).inDays.abs() + 1;
  return (days * 4).clamp(180, 500).toInt();
}

String _homeworkSubjectCourseLabel(HomeworkItemModel item) {
  final subject = item.subject.name.trim().isEmpty
      ? 'General'
      : item.subject.name.trim();
  final course = item.course.name.trim();
  if (course.isEmpty || course == subject) {
    return subject;
  }
  return '$subject - $course';
}

List<HomeworkItemModel> _filterHomeworkItems(
  List<HomeworkItemModel> items, {
  required int? subjectId,
  required int? courseId,
}) {
  return items.where((item) {
    if (subjectId != null && item.subject.id != subjectId) {
      return false;
    }
    if (courseId != null && item.course.id != courseId) {
      return false;
    }
    return true;
  }).toList();
}

List<HomeworkSubjectGroupModel> _subjectGroupsFromHomework(
  List<HomeworkItemModel> items,
) {
  final grouped = <String, List<HomeworkItemModel>>{};
  for (final item in items) {
    final key = '${item.subject.id}:${item.subject.name}';
    grouped.putIfAbsent(key, () => <HomeworkItemModel>[]).add(item);
  }
  return grouped.values.map((groupItems) {
    final subject = groupItems.first.subject;
    return HomeworkSubjectGroupModel(
      id: subject.id,
      name: subject.name.isEmpty ? 'General' : subject.name,
      homeworkCount: groupItems.length,
      items: groupItems,
    );
  }).toList();
}

HomeworkItemModel? _latestHomeworkItem(List<HomeworkItemModel> items) {
  if (items.isEmpty) {
    return null;
  }
  final sorted = [...items];
  sorted.sort((a, b) {
    final aDate = DateTime.tryParse(a.createdAt);
    final bDate = DateTime.tryParse(b.createdAt);
    if (aDate != null && bDate != null) {
      return bDate.compareTo(aDate);
    }
    if (aDate != null) {
      return -1;
    }
    if (bDate != null) {
      return 1;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted.first;
}

List<_HomeworkFilterOption> _homeworkCourseOptions(
  List<HomeworkItemModel> items,
) {
  final optionsById = <int, _HomeworkFilterOption>{};
  for (final item in items) {
    if (item.course.id == 0 || item.course.name.trim().isEmpty) {
      continue;
    }
    optionsById.putIfAbsent(
      item.course.id,
      () => _HomeworkFilterOption(
        id: item.course.id,
        name: item.course.name.trim(),
      ),
    );
  }
  final options = optionsById.values.toList();
  options.sort((a, b) => a.name.compareTo(b.name));
  return options;
}

String _formatCodeLabel(String value) {
  if (value.isEmpty) {
    return '-';
  }
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

List<_InstructionBlock> _parseInstructionBlocks(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');
  final blocks = <_InstructionBlock>[];
  final currentSpans = <TextSpan>[];
  var currentPrefix = null as String?;
  var currentAlignment = TextAlign.start;
  var boldDepth = 0;
  var italicDepth = 0;
  var underlineDepth = 0;
  var orderedDepth = 0;
  var unorderedDepth = 0;
  final orderedCounters = <int>[];
  final colorStack = <Color?>[];

  void flushBlock() {
    final spans = _trimInstructionSpans(currentSpans);
    if (spans.isNotEmpty) {
      blocks.add(
        _InstructionBlock(
          spans: spans,
          prefix: currentPrefix,
          alignment: currentAlignment,
        ),
      );
    }
    currentSpans.clear();
    currentPrefix = null;
    currentAlignment = TextAlign.start;
  }

  void addText(String rawText) {
    final decoded = _decodeHtmlText(rawText).replaceAll('\u00a0', ' ');
    final lines = decoded.split(RegExp(r'\r?\n'));
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      if (lineIndex > 0) {
        flushBlock();
      }
      var text = lines[lineIndex].replaceAll(RegExp(r'[ \t]+'), ' ');
      if (text.trim().isEmpty) {
        if (currentSpans.isNotEmpty &&
            !(currentSpans.last.text ?? '').endsWith(' ')) {
          currentSpans.add(const TextSpan(text: ' '));
        }
        continue;
      }

      if (currentSpans.isEmpty && currentPrefix == null) {
        final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.+)$').firstMatch(text);
        final bullet = RegExp(r'^\s*[-•]\s+(.+)$').firstMatch(text);
        if (numbered != null) {
          currentPrefix = '${numbered.group(1)}.';
          text = numbered.group(2) ?? '';
        } else if (bullet != null) {
          currentPrefix = '•';
          text = bullet.group(1) ?? '';
        }
      }

      currentSpans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            color: colorStack.isEmpty ? null : colorStack.last,
            fontWeight: boldDepth > 0 ? FontWeight.w900 : FontWeight.w600,
            fontStyle: italicDepth > 0 ? FontStyle.italic : FontStyle.normal,
            decoration: underlineDepth > 0
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      );
    }
  }

  final tokenPattern = RegExp(r'<[^>]+>|[^<]+', caseSensitive: false);
  for (final match in tokenPattern.allMatches(cleaned)) {
    final token = match.group(0) ?? '';
    if (!token.startsWith('<')) {
      addText(token);
      continue;
    }

    final tag = token.toLowerCase();
    final name = _htmlTagName(tag);
    final closing = tag.startsWith('</');
    final selfClosing = tag.endsWith('/>') || name == 'br' || name == 'hr';

    if (name == 'br') {
      flushBlock();
      continue;
    }

    if (!closing && (name == 'p' || name == 'div')) {
      flushBlock();
      currentAlignment = _htmlTextAlign(tag);
      final color = _htmlColor(tag);
      if (color != null) {
        colorStack.add(color);
      }
      continue;
    }
    if (closing && (name == 'p' || name == 'div')) {
      flushBlock();
      if (colorStack.isNotEmpty) {
        colorStack.removeLast();
      }
      continue;
    }

    if (!closing && name == 'ol') {
      orderedDepth += 1;
      orderedCounters.add(0);
      continue;
    }
    if (closing && name == 'ol') {
      flushBlock();
      orderedDepth = (orderedDepth - 1).clamp(0, 999);
      if (orderedCounters.isNotEmpty) {
        orderedCounters.removeLast();
      }
      continue;
    }
    if (!closing && name == 'ul') {
      unorderedDepth += 1;
      continue;
    }
    if (closing && name == 'ul') {
      flushBlock();
      unorderedDepth = (unorderedDepth - 1).clamp(0, 999);
      continue;
    }

    if (!closing && name == 'li') {
      flushBlock();
      if (orderedDepth > 0) {
        final next = orderedCounters.isEmpty ? 1 : orderedCounters.last + 1;
        if (orderedCounters.isEmpty) {
          orderedCounters.add(next);
        } else {
          orderedCounters[orderedCounters.length - 1] = next;
        }
        currentPrefix = '$next.';
      } else if (unorderedDepth > 0) {
        currentPrefix = '•';
      }
      currentAlignment = TextAlign.start;
      continue;
    }
    if (closing && name == 'li') {
      flushBlock();
      continue;
    }

    if (!closing && (name == 'strong' || name == 'b')) {
      boldDepth += 1;
      continue;
    }
    if (closing && (name == 'strong' || name == 'b')) {
      boldDepth = (boldDepth - 1).clamp(0, 999);
      continue;
    }
    if (!closing && (name == 'em' || name == 'i')) {
      italicDepth += 1;
      continue;
    }
    if (closing && (name == 'em' || name == 'i')) {
      italicDepth = (italicDepth - 1).clamp(0, 999);
      continue;
    }
    if (!closing && name == 'u') {
      underlineDepth += 1;
      continue;
    }
    if (closing && name == 'u') {
      underlineDepth = (underlineDepth - 1).clamp(0, 999);
      continue;
    }

    if (!closing && (name == 'span' || name == 'font')) {
      final color = _htmlColor(tag);
      if (color != null) {
        colorStack.add(color);
      }
      if (selfClosing && color != null && colorStack.isNotEmpty) {
        colorStack.removeLast();
      }
      continue;
    }
    if (closing &&
        (name == 'span' || name == 'font') &&
        colorStack.isNotEmpty) {
      colorStack.removeLast();
    }
  }

  flushBlock();
  return blocks;
}

String _htmlTagName(String tag) {
  final match = RegExp(
    r'^</?\s*([a-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(tag);
  return match?.group(1)?.toLowerCase() ?? '';
}

TextAlign _htmlTextAlign(String tag) {
  final match = RegExp(
    r'text-align\s*:\s*(left|right|center|justify)',
    caseSensitive: false,
  ).firstMatch(tag);
  return switch (match?.group(1)?.toLowerCase()) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

Color? _htmlColor(String tag) {
  final colorMatch = RegExp(
    r'(?:color\s*:\s*|color\s*=\s*["'
    ']?)(#[0-9a-f]{3,8}|[a-z]+)',
    caseSensitive: false,
  ).firstMatch(tag);
  final raw = colorMatch?.group(1)?.toLowerCase();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  if (raw.startsWith('#')) {
    var hex = raw.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((part) => '$part$part').join();
    }
    if (hex.length == 6) {
      hex = 'ff$hex';
    }
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }
  return switch (raw) {
    'black' => const Color(0xFF111640),
    'blue' => const Color(0xFF2563EB),
    'red' => const Color(0xFFDC2626),
    'green' => const Color(0xFF16A34A),
    'orange' => const Color(0xFFEA580C),
    'purple' => const Color(0xFF7C3AED),
    'gray' || 'grey' => const Color(0xFF65708A),
    'white' => Colors.white,
    _ => null,
  };
}

List<TextSpan> _trimInstructionSpans(List<TextSpan> spans) {
  final trimmed = <TextSpan>[];
  for (final span in spans) {
    final text = span.text ?? '';
    if (text.isEmpty) {
      continue;
    }
    trimmed.add(TextSpan(text: text, style: span.style));
  }
  if (trimmed.isEmpty) {
    return const [];
  }

  final first = trimmed.first;
  trimmed[0] = TextSpan(
    text: (first.text ?? '').trimLeft(),
    style: first.style,
  );
  final lastIndex = trimmed.length - 1;
  final last = trimmed[lastIndex];
  trimmed[lastIndex] = TextSpan(
    text: (last.text ?? '').trimRight(),
    style: last.style,
  );

  return trimmed.where((span) => (span.text ?? '').isNotEmpty).toList();
}

String _decodeHtmlText(String value) {
  return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (
    match,
  ) {
    final entity = match.group(1) ?? '';
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      final code = int.tryParse(entity.substring(2), radix: 16);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    if (entity.startsWith('#')) {
      final code = int.tryParse(entity.substring(1));
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    return switch (entity.toLowerCase()) {
      'nbsp' => ' ',
      'amp' => '&',
      'lt' => '<',
      'gt' => '>',
      'quot' => '"',
      'apos' => "'",
      _ => match.group(0)!,
    };
  });
}

Future<void> _refreshStudentParentData(WidgetRef ref) async {
  final apiClient = ref.read(apiClientProvider);
  for (final path in const [
    '/api/mobile/bootstrap/',
    '/api/mobile/profile/',
    '/api/mobile/attendance/',
    '/api/mobile/fees/',
    '/api/mobile/homework/',
    '/api/mobile/exams/',
    '/api/mobile/notices/',
  ]) {
    apiClient.clearGetCache(contains: path);
  }
  ref.invalidate(studentBootstrapProvider);
  ref.invalidate(effectiveAcademicSessionIdProvider);
  try {
    await Future.wait<dynamic>([
      ref.refresh(studentProfileProvider.future),
      ref.refresh(attendanceProvider.future),
      ref.refresh(feeDetailsProvider.future),
      ref.refresh(homeworkPlannerProvider.future),
      ref.refresh(examsProvider.future),
      ref.refresh(noticesProvider.future),
    ]);
  } catch (_) {
    // The individual provider error states render the failure on their pages.
  }
}

AcademicSessionModel? _selectedAcademicSession(
  StudentProfileModel profile,
  int? selectedId,
) {
  if (selectedId != null) {
    if (profile.activeSession?.id == selectedId) {
      return profile.activeSession;
    }
    for (final session in profile.academicSessions) {
      if (session.id == selectedId) {
        return session;
      }
    }
  }
  return profile.activeSession ??
      (profile.academicSessions.isNotEmpty
          ? profile.academicSessions.first
          : null);
}

enum _PushRefreshTarget {
  fees('/api/mobile/fees/'),
  attendance('/api/mobile/attendance/'),
  homework('/api/mobile/homework/'),
  notices('/api/mobile/notices/'),
  exams('/api/mobile/exams/'),
  profile('/api/mobile/profile/');

  const _PushRefreshTarget(this.cachePath);

  final String cachePath;
}

_PushRefreshTarget? _pushRefreshTarget(Map<String, dynamic> data) {
  final rawType =
      data['type'] ?? data['event_type'] ?? data['notification_type'] ?? '';
  final type = rawType.toString().trim().toUpperCase().replaceAll(
    RegExp(r'[\s-]+'),
    '_',
  );

  if (const {
    'FEE_PAID',
    'FEE_PAYMENT',
    'PAYMENT',
    'PAYMENT_RECEIVED',
    'PAYMENT_UPDATED',
  }.contains(type)) {
    return _PushRefreshTarget.fees;
  }
  if (const {
    'ATTENDANCE',
    'ATTENDANCE_MARKED',
    'ATTENDANCE_UPDATED',
  }.contains(type)) {
    return _PushRefreshTarget.attendance;
  }
  if (const {
    'HOMEWORK',
    'HOMEWORK_ASSIGNED',
    'HOMEWORK_UPDATED',
  }.contains(type)) {
    return _PushRefreshTarget.homework;
  }
  if (const {'NOTICE', 'NOTICE_PUBLISHED', 'NOTICE_UPDATED'}.contains(type)) {
    return _PushRefreshTarget.notices;
  }
  if (const {
    'EXAM',
    'EXAM_PUBLISHED',
    'EXAM_UPDATED',
    'RESULT',
    'RESULT_DECLARED',
    'RESULT_UPDATED',
  }.contains(type)) {
    return _PushRefreshTarget.exams;
  }
  if (const {
    'STUDENT',
    'STUDENT_UPDATED',
    'STUDENT_PROFILE_UPDATED',
    'PROFILE_UPDATED',
    'ENROLLMENT_UPDATED',
    'ACADEMIC_SESSION_UPDATED',
  }.contains(type)) {
    return _PushRefreshTarget.profile;
  }
  return null;
}
