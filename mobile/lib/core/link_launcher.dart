import 'dart:io' show Platform;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outbound links: store pages (M-02), the server-hosted privacy/terms pages
/// (M-08, M-26), and mailto for support (M-31).
///
/// Every method returns a bool rather than throwing, because in each case the
/// screen has a real fallback to show (design-spec §15) and an exception would
/// only have to be converted into that same bool at the call site.
class LinkLauncher {
  const LinkLauncher._();

  /// Opens the correct store listing for the running platform.
  static Future<bool> openStore({
    required String appStoreUrl,
    required String playStoreUrl,
  }) {
    final String url = !kIsWeb && Platform.isIOS ? appStoreUrl : playStoreUrl;
    return open(url);
  }

  static Future<bool> open(String url) async {
    if (url.trim().isEmpty) return false;
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // No handler installed for the scheme, or the platform refused the intent.
      return false;
    }
  }

  /// mailto with a prefilled subject, used by the M-31 direct-email fallback.
  static Future<bool> email({
    required String address,
    String? subject,
    String? body,
  }) async {
    if (address.trim().isEmpty) return false;
    final Uri uri = Uri(
      scheme: 'mailto',
      path: address.trim(),
      queryParameters: <String, String>{
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );
    try {
      return await launchUrl(uri);
    } on Object {
      return false;
    }
  }

  /// M-27: when notifications are blocked at the OS level the app cannot ask
  /// again, so the only remaining action is to send the user to Settings.
  static Future<bool> openNotificationSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
      return true;
    } on Object {
      try {
        await AppSettings.openAppSettings();
        return true;
      } on Object {
        return false;
      }
    }
  }
}
