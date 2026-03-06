import 'dart:convert';

class Sentence {
  final String id;
  final String text;
  final String? speaker;

  Sentence({String? id, required this.text, this.speaker})
      : id = id ?? _generateId();

  static int _counter = 0;
  static String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (speaker != null) 'speaker': speaker,
      };

  factory Sentence.fromJson(Map<String, dynamic> json) => Sentence(
        id: json['id'] as String?,
        text: json['text'] as String,
        speaker: json['speaker'] as String?,
      );
}

class Lesson {
  final String id;
  final String title;
  final List<Sentence> sentences;
  final DateTime createdAt;
  final String? folderId;

  Lesson({
    required this.id,
    required this.title,
    required this.sentences,
    required this.createdAt,
    this.folderId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sentences': sentences.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        if (folderId != null) 'folderId': folderId,
      };

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        title: json['title'] as String,
        sentences: (json['sentences'] as List)
            .map((s) => Sentence.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        folderId: json['folderId'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Lesson.fromJsonString(String jsonStr) =>
      Lesson.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  /// Parse raw dialogue text into a list of Sentences.
  ///
  /// Supports formats like:
  ///   A: Hello! What's your name?
  ///   B: My name is Mike.
  /// Or plain text with one sentence per line.
  static List<Sentence> parseText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final sentences = <Sentence>[];
    final speakerRegex = RegExp(r'^([A-Za-z\s]+):\s*(.+)$');

    for (final line in lines) {
      final match = speakerRegex.firstMatch(line);
      if (match != null) {
        final speaker = match.group(1)!.trim();
        final text = match.group(2)!.trim();
        final subs = _splitBySentence(text);
        for (final sub in subs) {
          sentences.add(Sentence(text: sub, speaker: speaker));
        }
      } else {
        final subs = _splitBySentence(line);
        for (final sub in subs) {
          sentences.add(Sentence(text: sub));
        }
      }
    }

    return sentences;
  }

  /// Split a text block into sentences by terminal punctuation (.!?)
  static List<String> _splitBySentence(String text) {
    final parts = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? [text] : parts;
  }
}
