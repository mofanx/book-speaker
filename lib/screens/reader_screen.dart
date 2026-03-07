import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../l10n/app_localizations.dart';
import '../services/tts_service.dart';
import '../services/service_locator.dart';
import '../services/llm_service.dart';

enum PlayMode { single, continuous, loop }

class ReaderScreen extends StatefulWidget {
  final Lesson lesson;

  const ReaderScreen({super.key, required this.lesson});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final TtsService _tts;
  late List<Sentence> _sentences;
  int _currentIndex = -1;
  bool _isPlaying = false;
  PlayMode _playMode = PlayMode.single;
  double _speechRate = 0.4;

  // Edit mode
  bool _isEditMode = false;
  final Set<int> _selectedIndices = {};

  // Translation — keyed by sentence text for stable caching
  final Map<String, String> _translationCache = {};
  bool _showTranslations = false;
  bool _isTranslating = false;

  // Scroll
  final _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _sentences = List.from(widget.lesson.sentences);
    _syncKeys();
    _tts = TtsService.instance(settingsService);
    _speechRate = settingsService.speechRate;
    _tts.onComplete = () => _onSpeechComplete();
    _tts.onStart = () {
      if (mounted) setState(() => _isPlaying = true);
    };
    _initTts();
  }

  Future<void> _initTts() async {
    // If there is an existing error, re-initialize to attempt recovery
    if (_tts.error != null) {
      await _tts.init();
    } else if (!_tts.isInitialized) {
      await _tts.init();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Don't dispose singleton TtsService; just detach callbacks
    _tts.onComplete = null;
    _tts.onStart = null;
    super.dispose();
  }

  void _syncKeys() {
    while (_itemKeys.length < _sentences.length) {
      _itemKeys.add(GlobalKey());
    }
    while (_itemKeys.length > _sentences.length) {
      _itemKeys.removeLast();
    }
  }

  void _scrollToIndex(int index) {
    if (index < 0 || index >= _itemKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _itemKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      } else if (_scrollController.hasClients) {
        final estimate = index * 96.0;
        _scrollController.animateTo(
          estimate.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ---- TTS Playback ----

  void _onSpeechComplete() {
    if (!mounted) return;
    switch (_playMode) {
      case PlayMode.single:
        setState(() => _isPlaying = false);
        break;
      case PlayMode.continuous:
        if (_currentIndex < _sentences.length - 1) {
          _speakAt(_currentIndex + 1);
        } else {
          setState(() => _isPlaying = false);
        }
        break;
      case PlayMode.loop:
        if (_currentIndex < _sentences.length - 1) {
          _speakAt(_currentIndex + 1);
        } else {
          _speakAt(0);
        }
        break;
    }
  }

  Future<void> _speakAt(int index) async {
    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });
    _scrollToIndex(index);
    
    // Quick recovery attempt if TTS is in error state before speaking
    if (_tts.error != null) {
      await _initTts();
    }
    
    await _tts.speak(_sentences[index].text);
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() => _isPlaying = false);
  }

  Future<void> _playAll() async {
    if (_isPlaying) {
      await _stop();
    } else {
      setState(() => _playMode = PlayMode.continuous);
      _speakAt(_currentIndex < 0 ? 0 : _currentIndex);
    }
  }

  void _previous() {
    if (_currentIndex > 0) _speakAt(_currentIndex - 1);
  }

  void _next() {
    if (_currentIndex < _sentences.length - 1) _speakAt(_currentIndex + 1);
  }

  Future<void> _changeRate(double rate) async {
    setState(() => _speechRate = rate);
    await _tts.setRate(rate);
  }

  String _rateLabel(double rate) => '${(rate * 2).toStringAsFixed(1)}x';

  IconData _playModeIcon() {
    switch (_playMode) {
      case PlayMode.single:
        return Icons.looks_one;
      case PlayMode.continuous:
        return Icons.playlist_play;
      case PlayMode.loop:
        return Icons.repeat;
    }
  }

  // ---- Edit Mode ----

  void _toggleEditMode() {
    if (_isPlaying) _stop();
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _sentences.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(_sentences.length, (i) => i));
      }
    });
  }

  Future<void> _mergeSelected() async {
    if (_selectedIndices.length < 2) return;
    final sorted = _selectedIndices.toList()..sort();
    final merged = sorted.map((i) => _sentences[i].text).join(' ');
    final speaker = _sentences[sorted.first].speaker;
    // Remove from end to start
    for (int i = sorted.length - 1; i >= 1; i--) {
      _sentences.removeAt(sorted[i]);
    }
    _sentences[sorted.first] = Sentence(
      text: merged,
      speaker: speaker,
    );
    _selectedIndices.clear();
    _currentIndex = -1;
    _syncKeys();
    await _saveChanges();
    setState(() {});
  }

  Future<void> _splitSentence(int index) async {
    final sentence = _sentences[index];
    final parts = sentence.text
        .split(RegExp(r'(?<=[.!?。！？])[\s]*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('no_sentences'))),
        );
      }
      return;
    }
    _sentences.removeAt(index);
    for (int i = parts.length - 1; i >= 0; i--) {
      _sentences.insert(index, Sentence(text: parts[i], speaker: sentence.speaker));
    }
    _syncKeys();
    await _saveChanges();
    setState(() {});
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_sentences_title')),
        content: Text(t('delete_sentences_confirm').replaceAll('%d', '${_selectedIndices.length}')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text(t('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final sorted = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final idx in sorted) {
        _sentences.removeAt(idx);
      }
      _selectedIndices.clear();
      _currentIndex = -1;
      _syncKeys();
      await _saveChanges();
      setState(() {});
    }
  }

  Future<void> _deleteSingle(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_sentence_title')),
        content: Text(t('delete_sentence_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text(t('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      _sentences.removeAt(index);
      if (_currentIndex >= _sentences.length) _currentIndex = -1;
      _syncKeys();
      await _saveChanges();
      setState(() {});
    }
  }

  Future<void> _editSentence(int index) async {
    final sentence = _sentences[index];
    final textCtrl = TextEditingController(text: sentence.text);
    final speakerCtrl = TextEditingController(text: sentence.speaker ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('edit_sentence')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: speakerCtrl,
              decoration: InputDecoration(
                labelText: t('speaker_optional'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('text'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('save'))),
        ],
      ),
    );

    if (result == true) {
      final text = textCtrl.text.trim();
      if (text.isNotEmpty) {
        _sentences[index] = Sentence(
          id: sentence.id,
          text: text,
          speaker:
              speakerCtrl.text.trim().isEmpty ? null : speakerCtrl.text.trim(),
        );
        await _saveChanges();
        setState(() {});
      }
    }
    textCtrl.dispose();
    speakerCtrl.dispose();
  }

  Future<void> _addSentence() async {
    final textCtrl = TextEditingController();
    final speakerCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('add_sentence')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: speakerCtrl,
              decoration: InputDecoration(
                labelText: t('speaker_optional'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                labelText: t('text'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('add'))),
        ],
      ),
    );

    if (result == true) {
      final text = textCtrl.text.trim();
      if (text.isNotEmpty) {
        _sentences.add(Sentence(
          text: text,
          speaker:
              speakerCtrl.text.trim().isEmpty ? null : speakerCtrl.text.trim(),
        ));
        _syncKeys();
        await _saveChanges();
        setState(() {});
      }
    }
    textCtrl.dispose();
    speakerCtrl.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _sentences.removeAt(oldIndex);
      _sentences.insert(newIndex, item);
    });
    _syncKeys();
    _saveChanges();
  }

  Future<void> _saveChanges() async {
    final updated = Lesson(
      id: widget.lesson.id,
      title: widget.lesson.title,
      sentences: _sentences,
      createdAt: widget.lesson.createdAt,
      folderId: widget.lesson.folderId,
    );
    await storageService.saveLesson(updated);
  }

  // ---- Translation ----

  bool get _hasCache => _translationCache.isNotEmpty;

  Future<void> _translateSingle(int index) async {
    final text = _sentences[index].text;
    // Return cached result
    if (_translationCache.containsKey(text)) {
      setState(() => _showTranslations = true);
      return;
    }
    setState(() => _isTranslating = true);
    try {
      final result = await llmService.translateText(
        text,
        settingsService.translationTargetLang,
      );
      if (mounted) {
        setState(() {
          _translationCache[text] = result.trim();
          _showTranslations = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('translation_failed')}: $e')),
        );
      }
    }
  }

  Future<void> _translateAll() async {
    // Find sentences not yet cached
    final uncached = <int, String>{};
    for (int i = 0; i < _sentences.length; i++) {
      if (!_translationCache.containsKey(_sentences[i].text)) {
        uncached[i] = _sentences[i].text;
      }
    }
    // If all cached, just show
    if (uncached.isEmpty) {
      setState(() => _showTranslations = true);
      return;
    }
    setState(() => _isTranslating = true);
    try {
      final textsToTranslate = uncached.values.toList();
      final result = await llmService.translateText(
        textsToTranslate.join('\n'),
        settingsService.translationTargetLang,
      );
      final lines = result.trim().split('\n');
      if (mounted) {
        setState(() {
          int li = 0;
          for (final text in textsToTranslate) {
            if (li < lines.length) {
              _translationCache[text] = lines[li].trim();
            }
            li++;
          }
          _showTranslations = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('translation_failed')}: $e')),
        );
      }
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
              child: _isEditMode ? _buildEditList() : _buildPlayList()),
          if (!_isEditMode) _buildControlBar(),
        ],
      ),
      floatingActionButton: _isEditMode
          ? FloatingActionButton(
              onPressed: _addSentence, child: const Icon(Icons.add))
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasTranslationConfig = settingsService.translationProviderId.isNotEmpty &&
        settingsService.translationModel.isNotEmpty;
    return AppBar(
      title: Text(widget.lesson.title),
      actions: [
        if (_isEditMode) ...[
          TextButton(
            onPressed: _selectAll,
            child: Text(_selectedIndices.length == _sentences.length
                ? t('deselect')
                : t('select_all')),
          ),
          if (_selectedIndices.length >= 2)
            IconButton(
              icon: const Icon(Icons.merge_type),
              tooltip: t('merge_sentences'),
              onPressed: _mergeSelected,
            ),
          if (_selectedIndices.length == 1)
            IconButton(
              icon: const Icon(Icons.content_cut),
              tooltip: t('split_sentence'),
              onPressed: () => _splitSentence(_selectedIndices.first),
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: t('delete_selected'),
            onPressed: _selectedIndices.isNotEmpty ? _deleteSelected : null,
          ),
        ] else ...[
          if (hasTranslationConfig)
            _isTranslating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.translate),
                    tooltip: t('translate'),
                    onSelected: (v) {
                      if (v == 'all') _translateAll();
                      if (v == 'single' && _currentIndex >= 0) _translateSingle(_currentIndex);
                      if (v == 'hide') setState(() => _showTranslations = false);
                      if (v == 'show') setState(() => _showTranslations = true);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'all', child: Text(t('translate_all'))),
                      if (_currentIndex >= 0)
                        PopupMenuItem(value: 'single', child: Text(t('translate'))),
                      if (_showTranslations)
                        PopupMenuItem(value: 'hide', child: Text(t('hide_translation'))),
                      if (!_showTranslations && _hasCache)
                        PopupMenuItem(value: 'show', child: Text(t('show_translation'))),
                    ],
                  ),
          PopupMenuButton<PlayMode>(
            icon: Icon(_playModeIcon()),
            tooltip: t('play_mode'),
            onSelected: (mode) => setState(() => _playMode = mode),
            itemBuilder: (_) => [
              _buildModeItem(PlayMode.single, Icons.looks_one, t('single_mode')),
              _buildModeItem(
                  PlayMode.continuous, Icons.playlist_play, t('continuous_mode')),
              _buildModeItem(PlayMode.loop, Icons.repeat, t('loop_mode')),
            ],
          ),
        ],
        IconButton(
          icon: Icon(_isEditMode ? Icons.check : Icons.edit_note),
          tooltip: _isEditMode ? t('done') : t('edit'),
          onPressed: _toggleEditMode,
        ),
      ],
    );
  }

  // ---- Play Mode List ----

  Widget _buildPlayList() {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _sentences.length,
      itemBuilder: (context, index) {
        final sentence = _sentences[index];
        final isActive = index == _currentIndex;

        return GestureDetector(
          key: _itemKeys[index],
          onTap: () {
            setState(() => _playMode = PlayMode.single);
            _speakAt(index);
          },
          onLongPress: _toggleEditMode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? cs.primary : cs.outlineVariant,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isActive && _isPlaying
                      ? Icon(Icons.volume_up,
                          color: cs.primary,
                          size: 24,
                          key: const ValueKey('playing'))
                      : Icon(Icons.play_circle_outline,
                          color: cs.onSurface.withValues(alpha: 0.35),
                          size: 24,
                          key: const ValueKey('idle')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sentence.speaker != null)
                        Text(
                          sentence.speaker!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                      Text(
                        sentence.text,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          color: isActive
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (_showTranslations && _translationCache.containsKey(sentence.text))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _translationCache[sentence.text]!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Edit Mode List ----

  Widget _buildEditList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _sentences.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final sentence = _sentences[index];
        final isSelected = _selectedIndices.contains(index);

        return Card(
          key: ValueKey(sentence.id),
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editSentence(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(index),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sentence.speaker != null)
                          Text(sentence.speaker!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold)),
                        Text(sentence.text,
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editSentence(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    onPressed: () => _deleteSingle(index),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Bottom Control Bar ----

  Widget _buildControlBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 8),
                Text(_rateLabel(_speechRate),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                Expanded(
                  child: Slider(
                    value: _speechRate,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: _rateLabel(_speechRate),
                    onChanged: _changeRate,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  onPressed: _currentIndex > 0 ? _previous : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _playAll,
                  icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(_isPlaying ? t('stop') : t('play_all')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 36,
                  onPressed: _currentIndex < _sentences.length - 1
                      ? _next
                      : null,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<PlayMode> _buildModeItem(
      PlayMode mode, IconData icon, String label) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, color: _playMode == mode ? Colors.blue : Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                fontWeight:
                    _playMode == mode ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
