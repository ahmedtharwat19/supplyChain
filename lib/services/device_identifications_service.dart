import 'dart:io' show Platform, Process;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentifierService {
  static Future<String> getDeviceId() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('web_device_id');
      if (id == null) {
        id = const Uuid().v4();
        await prefs.setString('web_device_id', id);
      }
      return id;
    }

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // AndroidId
    }

    if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios";
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // يمكن هنا استخدام أوامر النظام لجلب MAC
      // مثال لـ Windows
      try {
        final result = await Process.run("getmac", []);
        return result.stdout.toString().split("\n").first.trim();
      } catch (e) {
        return "unknown_desktop";
      }
    }

    return "unknown_device";
  }
}
