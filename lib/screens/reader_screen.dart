import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../services/tts_service.dart';

enum PlayMode { single, continuous, loop }

class ReaderScreen extends StatefulWidget {
  final Lesson lesson;

  const ReaderScreen({super.key, required this.lesson});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final TtsService _tts = TtsService();
  int _currentIndex = -1;
  bool _isPlaying = false;
  PlayMode _playMode = PlayMode.single;
  double _speechRate = 0.4;

  @override
  void initState() {
    super.initState();
    _tts.onComplete = () => _onSpeechComplete();
    _tts.onStart = () {
      if (mounted) setState(() => _isPlaying = true);
    };
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  void _onSpeechComplete() {
    if (!mounted) return;

    switch (_playMode) {
      case PlayMode.single:
        setState(() => _isPlaying = false);
        break;
      case PlayMode.continuous:
        if (_currentIndex < widget.lesson.sentences.length - 1) {
          _speakAt(_currentIndex + 1);
        } else {
          setState(() => _isPlaying = false);
        }
        break;
      case PlayMode.loop:
        if (_currentIndex < widget.lesson.sentences.length - 1) {
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
    await _tts.speak(widget.lesson.sentences[index].text);
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
      final startIndex = _currentIndex < 0 ? 0 : _currentIndex;
      _speakAt(startIndex);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _speakAt(_currentIndex - 1);
    }
  }

  void _next() {
    if (_currentIndex < widget.lesson.sentences.length - 1) {
      _speakAt(_currentIndex + 1);
    }
  }

  Future<void> _changeRate(double rate) async {
    setState(() => _speechRate = rate);
    await _tts.setRate(rate);
  }

  String _rateLabel(double rate) {
    return '${(rate * 2).toStringAsFixed(1)}x';
  }

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

  @override
  Widget build(BuildContext context) {
    final sentences = widget.lesson.sentences;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          PopupMenuButton<PlayMode>(
            icon: Icon(_playModeIcon()),
            tooltip: 'Play mode',
            onSelected: (mode) => setState(() => _playMode = mode),
            itemBuilder: (_) => [
              _buildModeItem(PlayMode.single, Icons.looks_one, 'Single'),
              _buildModeItem(
                  PlayMode.continuous, Icons.playlist_play, 'Continuous'),
              _buildModeItem(PlayMode.loop, Icons.repeat, 'Loop All'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Sentence List ----
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: sentences.length,
              itemBuilder: (context, index) {
                final sentence = sentences[index];
                final isActive = index == _currentIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() => _playMode = PlayMode.single);
                    _speakAt(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.blue.shade50
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isActive ? Colors.blue : Colors.grey.shade200,
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        // Play indicator
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isActive && _isPlaying
                              ? const Icon(Icons.volume_up,
                                  color: Colors.blue,
                                  size: 24,
                                  key: ValueKey('playing'))
                              : Icon(Icons.play_circle_outline,
                                  color: Colors.grey[400],
                                  size: 24,
                                  key: const ValueKey('idle')),
                        ),
                        const SizedBox(width: 12),
                        // Sentence text
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
                                    color: Colors.blue[700],
                                  ),
                                ),
                              Text(
                                sentence.text,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.5,
                                  color: isActive
                                      ? Colors.blue[900]
                                      : Colors.black87,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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
            ),
          ),

          // ---- Bottom Control Bar ----
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                  // Speed slider
                  Row(
                    children: [
                      const Icon(Icons.speed, size: 20),
                      const SizedBox(width: 8),
                      Text(_rateLabel(_speechRate),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
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
                  // Playback controls
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
                        icon: Icon(
                            _isPlaying ? Icons.stop : Icons.play_arrow),
                        label:
                            Text(_isPlaying ? 'Stop' : 'Play All'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        iconSize: 36,
                        onPressed:
                            _currentIndex < sentences.length - 1
                                ? _next
                                : null,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<PlayMode> _buildModeItem(
      PlayMode mode, IconData icon, String label) {
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon,
              color: _playMode == mode ? Colors.blue : Colors.grey),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                fontWeight: _playMode == mode
                    ? FontWeight.bold
                    : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
