import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushRegisterService {
  PushRegisterService(this._client);

  final SupabaseClient _client;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<bool> ensurePermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> registerDeviceToken() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await _client.from('device_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,platform');
  }

  void startTokenRefreshListener() {
    _tokenRefreshSub ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          final user = _client.auth.currentUser;
          if (user == null) return;

          if (newToken.isEmpty) return;

          await _client.from('device_tokens').upsert({
            'user_id': user.id,
            'token': newToken,
            'platform': 'android',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,platform');
        });
  }

  Future<void> stopTokenRefreshListener() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}