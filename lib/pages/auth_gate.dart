import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/push_register_service.dart';
import '../utils/supabase_error.dart';
import 'login_page.dart';
import 'notes_list_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _pushInitialized = false;

  Future<void> _initPushOnce() async {
    if (_pushInitialized) return;

    try {
      final svc = PushRegisterService(Supabase.instance.client);

      final ok = await svc.ensurePermission();
      if (!ok) {
        debugPrint('Notifications permission denied.');
        return;
      }

      await svc.registerDeviceToken();
      svc.startTokenRefreshListener();

      _pushInitialized = true;
      debugPrint('Push init OK');
    } catch (e) {
      debugPrint('Push init failed: ${supabaseErrorMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          _pushInitialized = false;
          return const LoginPage();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initPushOnce();
        });

        return const NotesListPage();
      },
    );
  }
}