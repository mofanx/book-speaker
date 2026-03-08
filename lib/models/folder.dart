import 'dart:convert';

class Folder {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final int sortOrder;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (parentId != null) 'parentId': parentId,
        'createdAt': createdAt.toIso8601String(),
        'sortOrder': sortOrder,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parentId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        sortOrder: (json['sortOrder'] as int?) ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());

  factory Folder.fromJsonString(String jsonStr) =>
      Folder.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
