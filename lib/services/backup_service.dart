import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class BackupService {
  static const int _backupVersion = 4;
  static const List<String> _boxesToBackup = [
    'lessons',
    'folders',
    'settings',
    'providers',
    'translations',
  ];

  // String-typed boxes (stored as Box<String> in Hive)
  static const _stringBoxes = {'lessons', 'folders', 'providers', 'translations'};

  BoxBase _getOpenBox(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      if (_stringBoxes.contains(boxName)) {
        try {
          return Hive.box<String>(boxName);
        } catch (_) {
          return Hive.box(boxName);
        }
      }
      return Hive.box(boxName);
    }
    throw Exception('Box "$boxName" is not open');
  }

  Future<String?> exportData() async {
    try {
      final Map<String, dynamic> backupData = {
        '_meta': {
          'version': _backupVersion,
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.6.0',
        },
      };

      for (final boxName in _boxesToBackup) {
        final box = _getOpenBox(boxName);
        final Map<String, dynamic> boxData = {};
        for (final key in box.keys) {
          boxData[key.toString()] = (box as Box).get(key);
        }
        backupData[boxName] = boxData;
      }

      final jsonStr = jsonEncode(backupData);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'book_speaker_backup_$timestamp.json';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Book Speaker Backup',
      );

      if (result.status == ShareResultStatus.success) {
        return 'success';
      }
      return null;
    } catch (e) {
      debugPrint('Export error: $e');
      return e.toString();
    }
  }

  Future<String?> importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final Map<String, dynamic> backupData = jsonDecode(jsonStr);

        // Log backup metadata if present
        if (backupData.containsKey('_meta')) {
          debugPrint('Importing backup: ${backupData['_meta']}');
        }

        for (final boxName in _boxesToBackup) {
          if (backupData.containsKey(boxName)) {
            final box = _getOpenBox(boxName) as Box;
            await box.clear();
            
            final Map<String, dynamic> boxData =
                Map<String, dynamic>.from(backupData[boxName] as Map);
            for (final entry in boxData.entries) {
              // For string boxes, ensure value is stored as String
              if (_stringBoxes.contains(boxName)) {
                await box.put(entry.key, entry.value?.toString() ?? '');
              } else {
                await box.put(entry.key, entry.value);
              }
            }
          }
        }
        return 'success';
      }
      return null; // Cancelled
    } catch (e) {
      debugPrint('Import error: $e');
      return e.toString();
    }
  }
}

final backupService = BackupService();
