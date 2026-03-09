import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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

  // Search
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';


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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Folder> get _filteredFolders {
    if (_searchQuery.isEmpty) return _folders;
    final q = _searchQuery.toLowerCase();
    return _folders.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  List<Lesson> get _filteredLessons {
    if (_searchQuery.isEmpty) return _lessons;
    final q = _searchQuery.toLowerCase();
    return _lessons.where((l) => l.title.toLowerCase().contains(q)).toList();
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
        sortOrder: lesson.sortOrder,
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
        sortOrder: folder.sortOrder,
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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  void _selectAllItems() {
    setState(() {
      if (_selectedFolderIds.length == _folders.length &&
          _selectedLessonIds.length == _lessons.length) {
        _selectedFolderIds.clear();
        _selectedLessonIds.clear();
      } else {
        _selectedFolderIds.addAll(_folders.map((f) => f.id));
        _selectedLessonIds.addAll(_lessons.map((l) => l.id));
      }
    });
  }

  void _invertSelectionItems() {
    setState(() {
      final allFIds = _folders.map((f) => f.id).toSet();
      final allLIds = _lessons.map((l) => l.id).toSet();
      final newF = allFIds.difference(_selectedFolderIds);
      final newL = allLIds.difference(_selectedLessonIds);
      _selectedFolderIds
        ..clear()
        ..addAll(newF);
      _selectedLessonIds
        ..clear()
        ..addAll(newL);
    });
  }

  void _exportSelectedItems() {
    final buf = StringBuffer();
    for (final f in _folders.where((f) => _selectedFolderIds.contains(f.id))) {
      buf.writeln('[${f.name}]');
    }
    for (final l in _lessons.where((l) => _selectedLessonIds.contains(l.id))) {
      buf.writeln('${l.title}\n${_formatLessonText(l)}\n');
    }
    final text = buf.toString().trim();
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('exported_to_clipboard'))),
      );
    }
  }

  Future<void> _onReorderFolders(int oldIndex, int newIndex) async {
    // Batch drag: if the dragged folder is selected, move all selected folders
    if (_selectedFolderIds.contains(_folders[oldIndex].id) && _selectedFolderIds.length > 1) {
      final selectedIndices = <int>[];
      for (int i = 0; i < _folders.length; i++) {
        if (_selectedFolderIds.contains(_folders[i].id)) selectedIndices.add(i);
      }
      final items = selectedIndices.map((i) => _folders[i]).toList();
      for (int i = selectedIndices.length - 1; i >= 0; i--) {
        _folders.removeAt(selectedIndices[i]);
      }
      int insertAt = newIndex;
      for (final idx in selectedIndices) {
        if (idx < newIndex) insertAt--;
      }
      insertAt = insertAt.clamp(0, _folders.length);
      _folders.insertAll(insertAt, items);
    } else {
      if (newIndex > oldIndex) newIndex--;
      final item = _folders.removeAt(oldIndex);
      _folders.insert(newIndex, item);
    }
    setState(() {});
    await _saveFolderOrder();
  }

  Future<void> _onReorderLessons(int oldIndex, int newIndex) async {
    // Batch drag
    if (_selectedLessonIds.contains(_lessons[oldIndex].id) && _selectedLessonIds.length > 1) {
      final selectedIndices = <int>[];
      for (int i = 0; i < _lessons.length; i++) {
        if (_selectedLessonIds.contains(_lessons[i].id)) selectedIndices.add(i);
      }
      final items = selectedIndices.map((i) => _lessons[i]).toList();
      for (int i = selectedIndices.length - 1; i >= 0; i--) {
        _lessons.removeAt(selectedIndices[i]);
      }
      int insertAt = newIndex;
      for (final idx in selectedIndices) {
        if (idx < newIndex) insertAt--;
      }
      insertAt = insertAt.clamp(0, _lessons.length);
      _lessons.insertAll(insertAt, items);
    } else {
      if (newIndex > oldIndex) newIndex--;
      final item = _lessons.removeAt(oldIndex);
      _lessons.insert(newIndex, item);
    }
    setState(() {});
    await _saveLessonOrder();
  }

  Future<void> _saveFolderOrder() async {
    for (int i = 0; i < _folders.length; i++) {
      final f = _folders[i];
      if (f.sortOrder != i) {
        final updated = Folder(
          id: f.id, name: f.name, parentId: f.parentId,
          createdAt: f.createdAt, sortOrder: i,
        );
        _folders[i] = updated;
        await storageService.saveFolder(updated);
      }
    }
  }

  Future<void> _saveLessonOrder() async {
    for (int i = 0; i < _lessons.length; i++) {
      final l = _lessons[i];
      if (l.sortOrder != i) {
        final updated = Lesson(
          id: l.id, title: l.title, sentences: l.sentences,
          createdAt: l.createdAt, folderId: l.folderId, sortOrder: i,
        );
        _lessons[i] = updated;
        await storageService.saveLesson(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _folders.isNotEmpty || _lessons.isNotEmpty;
    final folders = _filteredFolders;
    final lessons = _filteredLessons;

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
          if (hasContent) ...[
            IconButton(
              icon: Icon(_isSearching ? Icons.search_off : Icons.search),
              tooltip: t('search'),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              tooltip: _isSelectionMode ? t('cancel') : t('select'),
              onPressed: _toggleSelectionMode,
            ),
          ],
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
              : Column(
                  children: [
                    if (_isSearching) _buildSearchBar(),
                    Expanded(
                      child: _isSelectionMode
                          ? _buildSelectionList()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: folders.length + lessons.length,
                              itemBuilder: (context, index) {
                                if (index < folders.length) {
                                  final folder = folders[index];
                                  return _buildFolderCard(folder, false);
                                } else {
                                  final lesson = lessons[index - folders.length];
                                  return _buildLessonCard(lesson, false, index - folders.length);
                                }
                              },
                            ),
                    ),
                  ],
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

  Widget _buildSearchBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: t('search_home_hint'),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _toggleSearch,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildSelectionList() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_folders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t('folders_section'),
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: cs.primary,
                  )),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _folders.length,
              onReorder: _onReorderFolders,
              proxyDecorator: (child, _, __) => Material(
                elevation: 4, borderRadius: BorderRadius.circular(12), child: child,
              ),
              itemBuilder: (_, i) {
                final f = _folders[i];
                final selected = _selectedFolderIds.contains(f.id);
                return Card(
                  key: ValueKey('folder_${f.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text('${i + 1}', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.45))),
                        ),
                        GestureDetector(
                          onTap: () => _toggleFolderSelection(f.id),
                          child: Icon(
                            selected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: selected ? cs.primary : Colors.grey,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Icon(Icons.folder, color: Colors.orange.shade300, size: 28),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          if (_lessons.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t('contents_section'),
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: cs.primary,
                  )),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lessons.length,
              onReorder: _onReorderLessons,
              proxyDecorator: (child, _, __) => Material(
                elevation: 4, borderRadius: BorderRadius.circular(12), child: child,
              ),
              itemBuilder: (_, i) {
                final l = _lessons[i];
                final selected = _selectedLessonIds.contains(l.id);
                return Card(
                  key: ValueKey('lesson_${l.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text('${i + 1}', textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.45))),
                        ),
                        GestureDetector(
                          onTap: () => _toggleLessonSelection(l.id),
                          child: Icon(
                            selected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: selected ? cs.primary : Colors.grey,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(t('sentences_detected').replaceAll('%d', '${l.sentences.length}')),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
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
                  PopupMenuItem(value: 'export', child: Text(t('export'))),
                  PopupMenuItem(value: 'delete', child: Text(t('delete'), style: const TextStyle(color: Colors.red))),
                ],
                onSelected: (v) {
                  if (v == 'rename') _renameFolder(folder);
                  if (v == 'export') _exportFolder(folder);
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
                  PopupMenuItem(value: 'export', child: Text(t('export'))),
                  PopupMenuItem(value: 'delete', child: Text(t('delete'), style: const TextStyle(color: Colors.red))),
                ],
                onSelected: (v) {
                  if (v == 'rename') _renameLesson(lesson);
                  if (v == 'export') _exportLesson(lesson);
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
    final allCount = _folders.length + _lessons.length;
    final allSelected = count == allCount && allCount > 0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return BottomAppBar(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: bottomPadding > 0 ? bottomPadding : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: count + select all + invert
          Row(
            children: [
              const SizedBox(width: 8),
              Text('$count ${t('selected')}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: _selectAllItems,
                child: Text(allSelected ? t('deselect') : t('select_all')),
              ),
              TextButton(
                onPressed: _invertSelectionItems,
                child: Text(t('invert_selection')),
              ),
            ],
          ),
          // Row 2: scrollable actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (count == 1)
                  _actionChip(Icons.edit, t('rename'), () {
                    if (_selectedFolderIds.length == 1) {
                      final f = _folders.firstWhere((f) => f.id == _selectedFolderIds.first);
                      _renameFolder(f);
                    } else if (_selectedLessonIds.length == 1) {
                      final l = _lessons.firstWhere((l) => l.id == _selectedLessonIds.first);
                      _renameLesson(l);
                    }
                  }),
                _actionChip(Icons.create_new_folder, t('add_folder'), _createFolder),
                _actionChip(Icons.note_add, t('add_content'), () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImportScreen(folderId: widget.folder?.id),
                    ),
                  );
                  if (result == true) _loadData();
                }),
                if (count > 0) ...[
                  _actionChip(Icons.drive_file_move, t('move'), _moveSelected),
                  _actionChip(Icons.copy, t('copy'), _copySelected),
                  _actionChip(Icons.ios_share, t('export'), _exportSelectedItems),
                  _actionChip(Icons.delete, t('delete'), _deleteSelected, isDestructive: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onPressed, {bool isDestructive = false}) {
    final color = isDestructive ? Colors.red : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color)),
        onPressed: onPressed,
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
          sortOrder: lesson.sortOrder,
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
          sortOrder: folder.sortOrder,
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
          sortOrder: lesson.sortOrder,
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

  // ---- Export ----

  String _formatLessonText(Lesson lesson) {
    final buf = StringBuffer();
    for (final s in lesson.sentences) {
      if (s.speaker != null) {
        buf.writeln('${s.speaker}: ${s.text}');
      } else {
        buf.writeln(s.text);
      }
    }
    return buf.toString().trim();
  }

  void _exportLesson(Lesson lesson) {
    final text = '${lesson.title}\n\n${_formatLessonText(lesson)}';
    _showExportSheet(title: lesson.title, text: text);
  }

  Future<void> _exportFolder(Folder folder) async {
    final allLessons = await storageService.getAllLessons();
    final folderLessons = allLessons.where((l) => l.folderId == folder.id).toList();

    final buf = StringBuffer();
    buf.writeln(folder.name);
    for (final lesson in folderLessons) {
      buf.writeln();
      buf.writeln('--- ${lesson.title} ---');
      buf.writeln(_formatLessonText(lesson));
    }
    _showExportSheet(title: folder.name, text: buf.toString().trim());
  }

  void _showExportSheet({required String title, required String text}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(t('export_to_clipboard')),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t('exported_to_clipboard'))),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(t('export_to_file')),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(text, subject: title);
              },
            ),
          ],
        ),
      ),
    );
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
