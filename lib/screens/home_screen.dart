import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../models/folder.dart';
import '../l10n/app_localizations.dart';
import '../services/service_locator.dart';
import 'import_screen.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Folder? folder;

  const HomeScreen({super.key, this.folder});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Folder> _folders = [];
  List<Lesson> _lessons = [];
  bool _isLoading = true;

  // Selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedFolderIds = {};
  final Set<String> _selectedLessonIds = {};

  Future<void> _loadData() async {
    final allFolders = await storageService.getAllFolders();
    final allLessons = await storageService.getAllLessons();

    final currentFolderId = widget.folder?.id;

    setState(() {
      _folders = allFolders.where((f) => f.parentId == currentFolderId).toList();
      _lessons = allLessons.where((l) => l.folderId == currentFolderId).toList();
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedFolderIds.clear();
        _selectedLessonIds.clear();
      }
    });
  }

  void _toggleFolderSelection(String id) {
    setState(() {
      if (_selectedFolderIds.contains(id)) {
        _selectedFolderIds.remove(id);
      } else {
        _selectedFolderIds.add(id);
      }
    });
  }

  void _toggleLessonSelection(String id) {
    setState(() {
      if (_selectedLessonIds.contains(id)) {
        _selectedLessonIds.remove(id);
      } else {
        _selectedLessonIds.add(id);
      }
    });
  }

  Future<void> _renameLesson(Lesson lesson) async {
    final ctrl = TextEditingController(text: lesson.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('rename')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t('rename_hint'),
            labelText: t('name'),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t('save')),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != lesson.title) {
      await storageService.saveLesson(Lesson(
        id: lesson.id,
        title: newName,
        sentences: lesson.sentences,
        createdAt: lesson.createdAt,
        folderId: lesson.folderId,
      ));
      _loadData();
    }
  }

  Future<void> _renameFolder(Folder folder) async {
    final ctrl = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('rename')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t('rename_hint'),
            labelText: t('name'),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t('save')),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      await storageService.saveFolder(Folder(
        id: folder.id,
        name: newName,
        parentId: folder.parentId,
        createdAt: folder.createdAt,
      ));
      _loadData();
    }
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_content')),
        content: Text(t('delete_content_confirm').replaceAll('%s', lesson.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await storageService.deleteLesson(lesson.id);
      _loadData();
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete')),
        content: Text(t('delete_folder_confirm').replaceAll('%s', folder.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await storageService.deleteFolder(folder.id);
      _loadData();
    }
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('new_folder')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t('folder_name_hint'),
            labelText: t('folder_name'),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t('create')),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final folder = Folder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        parentId: widget.folder?.id,
        createdAt: DateTime.now(),
      );
      await storageService.saveFolder(folder);
      _loadData();
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add),
              title: Text(t('add_content')),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImportScreen(folderId: widget.folder?.id),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: Text(t('add_folder')),
              onTap: () {
                Navigator.pop(ctx);
                _createFolder();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _folders.isNotEmpty || _lessons.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder?.name ?? t('app_name')),
        centerTitle: true,
        leading: widget.folder != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (hasContent)
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              tooltip: _isSelectionMode ? t('cancel') : t('select'),
              onPressed: _toggleSelectionMode,
            ),
          if (!_isSelectionMode && widget.folder == null)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: t('settings'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                setState(() {});
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasContent
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.folder == null ? Icons.menu_book : Icons.folder_open,
                        size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                          widget.folder == null ? t('no_content') : t('folder_empty'),
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text(t('home_empty'),
                          style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _folders.length + _lessons.length,
                  itemBuilder: (context, index) {
                    if (index < _folders.length) {
                      final folder = _folders[index];
                      final isSelected = _selectedFolderIds.contains(folder.id);
                      return _buildFolderCard(folder, isSelected);
                    } else {
                      final lesson = _lessons[index - _folders.length];
                      final isSelected = _selectedLessonIds.contains(lesson.id);
                      return _buildLessonCard(lesson, isSelected, index - _folders.length);
                    }
                  },
                ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddMenu,
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar() : null,
    );
  }

  Widget _buildFolderCard(Folder folder, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.folder,
          color: isSelected ? Colors.blue : Colors.orange.shade300,
          size: 40,
        ),
        title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: _isSelectionMode 
            ? null 
            : PopupMenuButton<String>(
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text(t('rename'))),
                  PopupMenuItem(value: 'delete', child: Text(t('delete'), style: const TextStyle(color: Colors.red))),
                ],
                onSelected: (v) {
                  if (v == 'rename') _renameFolder(folder);
                  if (v == 'delete') _deleteFolder(folder);
                },
              ),
        onTap: () {
          if (_isSelectionMode) {
            _toggleFolderSelection(folder.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen(folder: folder)),
            ).then((_) => _loadData());
          }
        },
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson, bool isSelected, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: _isSelectionMode
            ? Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 32,
              )
            : CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text('${index + 1}',
                    style: TextStyle(color: Colors.blue[800])),
              ),
        title: Text(lesson.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(t('sentences_detected').replaceAll('%d', '${lesson.sentences.length}')),
        trailing: _isSelectionMode
            ? null
            : PopupMenuButton<String>(
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text(t('rename'))),
                  PopupMenuItem(value: 'delete', child: Text(t('delete'), style: const TextStyle(color: Colors.red))),
                ],
                onSelected: (v) {
                  if (v == 'rename') _renameLesson(lesson);
                  if (v == 'delete') _deleteLesson(lesson);
                },
              ),
        onTap: () async {
          if (_isSelectionMode) {
            _toggleLessonSelection(lesson.id);
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReaderScreen(lesson: lesson),
              ),
            );
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
    final count = _selectedFolderIds.length + _selectedLessonIds.length;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text('$count ${t('selected')}'),
          TextButton.icon(
            icon: const Icon(Icons.drive_file_move),
            label: Text(t('move')),
            onPressed: count > 0 ? () => _moveSelected() : null,
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(t('copy')),
            onPressed: count > 0 ? () => _copySelected() : null,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: Text(t('delete'), style: const TextStyle(color: Colors.red)),
            onPressed: count > 0 ? () => _deleteSelected() : null,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete')),
        content: Text(t('delete_selected_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in _selectedLessonIds) {
        await storageService.deleteLesson(id);
      }
      for (final id in _selectedFolderIds) {
        await storageService.deleteFolder(id);
      }
      _toggleSelectionMode();
      _loadData();
    }
  }

  Future<void> _moveSelected() async {
    final targetFolderId = await _showFolderPicker(t('move_to'));
    if (targetFolderId == 'CANCEL') return;

    // A null targetFolderId means "Root".
    final dest = targetFolderId == 'ROOT' ? null : targetFolderId;

    for (final id in _selectedLessonIds) {
      final lesson = await storageService.getLesson(id);
      if (lesson != null) {
        await storageService.saveLesson(Lesson(
          id: lesson.id,
          title: lesson.title,
          sentences: lesson.sentences,
          createdAt: lesson.createdAt,
          folderId: dest,
        ));
      }
    }

    for (final id in _selectedFolderIds) {
      // Prevent moving folder into itself or its own subfolder (simple check: just prevent moving into itself)
      if (id == dest) continue;
      
      final folder = await storageService.getFolder(id);
      if (folder != null) {
        await storageService.saveFolder(Folder(
          id: folder.id,
          name: folder.name,
          parentId: dest,
          createdAt: folder.createdAt,
        ));
      }
    }

    _toggleSelectionMode();
    _loadData();
  }

  Future<void> _copySelected() async {
    final targetFolderId = await _showFolderPicker(t('copy_to'));
    if (targetFolderId == 'CANCEL') return;

    final dest = targetFolderId == 'ROOT' ? null : targetFolderId;

    for (final id in _selectedLessonIds) {
      final lesson = await storageService.getLesson(id);
      if (lesson != null) {
        await storageService.saveLesson(Lesson(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: '${lesson.title} (${t('copy')})',
          sentences: lesson.sentences,
          createdAt: DateTime.now(),
          folderId: dest,
        ));
      }
    }

    // For folders, we only do a shallow copy for now, or just ignore. 
    // Implementing deep copy of folders is complex.
    for (final id in _selectedFolderIds) {
      final folder = await storageService.getFolder(id);
      if (folder != null) {
        await storageService.saveFolder(Folder(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: '${folder.name} (${t('copy')})',
          parentId: dest,
          createdAt: DateTime.now(),
        ));
      }
    }

    _toggleSelectionMode();
    _loadData();
  }

  /// Returns folderId, 'ROOT', or 'CANCEL'
  Future<String?> _showFolderPicker(String title) async {
    final allFolders = await storageService.getAllFolders();
    
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: Text(t('root_directory')),
                  onTap: () => Navigator.pop(ctx, 'ROOT'),
                ),
                const Divider(),
                ...allFolders.map((f) {
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(f.name),
                    onTap: () => Navigator.pop(ctx, f.id),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'CANCEL'),
              child: Text(t('cancel')),
            ),
          ],
        );
      },
    );
  }
}
