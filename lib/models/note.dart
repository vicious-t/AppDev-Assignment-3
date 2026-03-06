import 'package:flutter/cupertino.dart';

class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime updatedAt;
  final String? userEmail;
  final String? imageUrl;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.userEmail,
    this.imageUrl,

  });

  factory Note.fromMap(Map<String, dynamic> map) {
    final updatedRaw = map['updated_at'];
    final updatedStr = updatedRaw?.toString();
    final email = (map['profiles'] is Map)
        ? map['profiles']['email']?.toString() : null;

    return Note(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      updatedAt: (updatedStr == null || updatedStr.isEmpty)
          ? DateTime.now().toUtc()
          : DateTime.parse(updatedStr),
      userEmail: email,
      imageUrl: map['image_url']?.toString(),
    );
  }
}