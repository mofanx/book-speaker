import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/lesson.dart';
import '../services/ocr_service.dart';
import '../services/service_locator.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  late final OcrService _ocr;
  bool _isProcessing = false;
  bool _isOptimizing = false;
  int _sentenceCount = 0;

  @override
  void initState() {
    super.initState();
    _ocr = OcrService(settingsService, llmService);
    _textController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _textController.removeListener(_updatePreview);
    _titleController.dispose();
    _textController.dispose();
    _ocr.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final text = _textController.text.trim();
    final count = text.isEmpty ? 0 : Lesson.parseText(text).length;
    if (count != _sentenceCount) {
      setState(() => _sentenceCount = count);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isProcessing = true);
    try {
      final text = await _ocr.recognizeText(File(image.path));
      _textController.text = text;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _optimizeText() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    setState(() => _isOptimizing = true);
    try {
      final optimized = await llmService.optimizeText(rawText);
      _textController.text = optimized;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text optimized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Optimization failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOptimizing = false);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final rawText = _textController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or import some text')),
      );
      return;
    }

    final sentences = Lesson.parseText(rawText);
    if (sentences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sentences found in text')),
      );
      return;
    }

    final lesson = Lesson(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      sentences: sentences,
      createdAt: DateTime.now(),
    );

    await storageService.saveLesson(lesson);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showOptimize = settingsService.enableTextOptimization;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Lesson'),
        actions: [
          TextButton.icon(
            onPressed: (_isProcessing || _isOptimizing) ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                hintText: 'e.g. Unit 3 - At the Zoo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('From Gallery'),
                  ),
                ),
              ],
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Recognizing text...')),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Or paste dialogue text below:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (showOptimize)
                  TextButton.icon(
                    onPressed: (_isOptimizing ||
                            _textController.text.trim().isEmpty)
                        ? null
                        : _optimizeText,
                    icon: _isOptimizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(_isOptimizing ? 'Optimizing...' : 'AI Optimize'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 15,
              decoration: const InputDecoration(
                hintText:
                    'A: Hello! What\'s your name?\nB: My name is Mike.\nA: Nice to meet you!',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_sentenceCount > 0)
              Text(
                '$_sentenceCount sentences detected',
                style: TextStyle(color: Colors.green[700]),
              ),
          ],
        ),
      ),
    );
  }
}
