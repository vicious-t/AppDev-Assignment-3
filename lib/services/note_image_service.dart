import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoteImageService {
  NoteImageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int maxBytes = 15 * 1024 * 1024;
  static const allowedExt = {'jpg', 'jpeg', 'png', 'webp'};

  Future<void> validateOrThrow(XFile file) async {
    final f = File(file.path);

    final bytes = await f.length();
    if (bytes > maxBytes) {
      throw Exception('Bildet er for stort. Maks 15 MB.');
    }

    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    if (!allowedExt.contains(ext)) {
      throw Exception('Ugyldig filtype. Bruk JPG, PNG eller WebP.');
    }
  }

  Future<String> uploadAndGetPublicUrl(XFile file) async {
    final uid = _client.auth.currentUser!.id;

    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;

    final path = '$uid/$timestamp.$ext';

    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };

    await _client.storage.from('note-images').upload(
      path,
      File(file.path),
      fileOptions: FileOptions(
        upsert: false,
        contentType: contentType,
      ),
    );

    return _client.storage.from('note-images').getPublicUrl(path);
  }

  Future<void> deleteByPath(String path) async {
    await _client.storage.from('note-images').remove([path]);
  }

  String? tryGetPathFromPublicUrl(String publicUrl) {
    final marker = '/storage/v1/object/public/note-images/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return null;

    final path = publicUrl.substring(idx + marker.length);
    if (path.isEmpty) return null;
    return path;
  }

  Future<void> deleteByPublicUrl(String publicUrl) async {
    final path = tryGetPathFromPublicUrl(publicUrl);
    if (path == null) {
      throw Exception('Klarte ikke å finne filsti fra URL.');
    }
    await deleteByPath(path);
  }
}