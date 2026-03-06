import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPermissionService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<bool> requestCamera() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestGallery() async {
    if (!Platform.isAndroid) return false;

    final android = await _deviceInfo.androidInfo;
    final sdk = android.version.sdkInt;

    // Android 13+ (API 33+): READ_MEDIA_IMAGES (via Permission.photos i permission_handler)
    if (sdk >= 33) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }

    // Android 12 og lavere: READ_EXTERNAL_STORAGE (via Permission.storage)
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<bool> isGalleryPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;

    final android = await _deviceInfo.androidInfo;
    final sdk = android.version.sdkInt;

    final status = sdk >= 33
        ? await Permission.photos.status
        : await Permission.storage.status;

    return status.isPermanentlyDenied;
  }

  static Future<bool> isCameraPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  static Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}