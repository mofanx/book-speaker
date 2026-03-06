import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubRepo = 'mofanx/book-speaker';
  static const String _apiUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['tag_name'] as String;
        final releaseNotes = data['body'] as String?;
        final downloadUrl = data['html_url'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = 'v${packageInfo.version}';

        if (_isNewerVersion(currentVersion, latestVersion)) {
          return UpdateInfo(
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            releaseNotes: releaseNotes ?? '',
            downloadUrl: downloadUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final c = current.replaceAll('v', '').split('+')[0].split('.');
      final l = latest.replaceAll('v', '').split('+')[0].split('.');

      for (int i = 0; i < 3; i++) {
        final cVal = int.parse(c[i]);
        final lVal = int.parse(l[i]);
        if (lVal > cVal) return true;
        if (lVal < cVal) return false;
      }
    } catch (e) {
      debugPrint('Version parse error: $e');
    }
    return false;
  }

  Future<void> launchDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String downloadUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

final updateService = UpdateService();
