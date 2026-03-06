import 'dart:convert';

class Folder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (parentId != null) 'parentId': parentId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Folder.fromJsonString(String jsonStr) =>
      Folder.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
