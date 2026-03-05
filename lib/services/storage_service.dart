import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/lesson.dart';

class StorageService {
  static const String _boxName = 'lessons';
  Box<String>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  Future<void> saveLesson(Lesson lesson) async {
    await init();
    await _box!.put(lesson.id, jsonEncode(lesson.toJson()));
  }

  Future<void> deleteLesson(String id) async {
    await init();
    await _box!.delete(id);
  }

  Future<List<Lesson>> getAllLessons() async {
    await init();
    final lessons = <Lesson>[];
    for (final key in _box!.keys) {
      final json = _box!.get(key);
      if (json != null) {
        try {
          lessons.add(
              Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>));
        } catch (_) {
          // Skip corrupted entries
        }
      }
    }
    lessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return lessons;
  }

  Future<Lesson?> getLesson(String id) async {
    await init();
    final json = _box!.get(id);
    if (json == null) return null;
    return Lesson.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
