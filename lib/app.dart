import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/subscription_expired_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/student_parent/presentation/screens/student_parent_dashboard_screen.dart';

class UltraCoachMatrixApp extends StatelessWidget {
  const UltraCoachMatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultra Coach Matrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD8DEE9)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  late final Future<void> _restoreFuture;

  @override
  void initState() {
    super.initState();
    _restoreFuture = Future<void>(
      () => ref.read(authProvider.notifier).restoreSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return FutureBuilder<void>(
      future: _restoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            authState.isLoading) {
          return const _AppLoadingScreen();
        }
        final user = authState.user;
        if (user?.role == 'STUDENT_PARENT') {
          final apiClient = ref.watch(apiClientProvider);
          return ValueListenableBuilder(
            valueListenable: apiClient.subscriptionAccess,
            builder: (context, access, _) {
              if (access.isBlocked) {
                return SubscriptionExpiredScreen(message: access.message);
              }
              return StudentParentDashboardScreen(user: user!);
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}
