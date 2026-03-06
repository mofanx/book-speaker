import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/lesson.dart';
import '../models/folder.dart';

class StorageService {
  static const String _boxName = 'lessons';
  static const String _folderBoxName = 'folders';
  Box<String>? _box;
  Box<String>? _folderBox;

  Future<void> init() async {
    _box ??= await Hive.openBox<String>(_boxName);
    _folderBox ??= await Hive.openBox<String>(_folderBoxName);
  }

  Future<void> saveLesson(Lesson lesson) async {
    await init();
    await _box!.put(lesson.id, jsonEncode(lesson.toJson()));
  }

  Future<void> deleteLesson(String id) async {
    await init();
    await _box!.delete(id);
  }

  // --- Folder Management ---

  Future<void> saveFolder(Folder folder) async {
    await init();
    await _folderBox!.put(folder.id, folder.toJsonString());
  }

  Future<void> deleteFolder(String id, {bool deleteContents = true}) async {
    await init();
    
    if (deleteContents) {
      // Find all lessons in this folder and delete them
      final lessons = await getAllLessons();
      for (final lesson in lessons.where((l) => l.folderId == id)) {
        await deleteLesson(lesson.id);
      }
      // Delete subfolders
      final folders = await getAllFolders();
      for (final subFolder in folders.where((f) => f.parentId == id)) {
        await deleteFolder(subFolder.id, deleteContents: true);
      }
    } else {
      // Move contents to root
      final lessons = await getAllLessons();
      for (final lesson in lessons.where((l) => l.folderId == id)) {
        final updatedLesson = Lesson(
          id: lesson.id,
          title: lesson.title,
          sentences: lesson.sentences,
          createdAt: lesson.createdAt,
          folderId: null, // Move to root
        );
        await saveLesson(updatedLesson);
      }
      final folders = await getAllFolders();
      for (final subFolder in folders.where((f) => f.parentId == id)) {
        final updatedFolder = Folder(
          id: subFolder.id,
          name: subFolder.name,
          parentId: null,
          createdAt: subFolder.createdAt,
        );
        await saveFolder(updatedFolder);
      }
    }
    
    await _folderBox!.delete(id);
  }

  Future<List<Folder>> getAllFolders() async {
    await init();
    final folders = <Folder>[];
    for (final key in _folderBox!.keys) {
      final json = _folderBox!.get(key);
      if (json != null) {
        try {
          folders.add(Folder.fromJsonString(json));
        } catch (_) {}
      }
    }
    folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return folders;
  }

  Future<Folder?> getFolder(String id) async {
    await init();
    final json = _folderBox!.get(id);
    if (json == null) return null;
    return Folder.fromJsonString(json);
  }

  // --- Utility ---

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
