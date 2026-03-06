import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'new_note_page.dart';
import 'note_detail_page.dart';
import '../widgets/note_list_item.dart';

class NotesListPage extends ConsumerWidget {
  const NotesListPage({super.key});

  void _openDetail(BuildContext context, Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailPage(note: note)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobb Notater'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logget ut')),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: notesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Feil: $e')),
          data: (notes) {
            if (notes.isEmpty) {
              return const Center(child: Text('Ingen notater enda'));
            }

            final bottom = MediaQuery.of(context).padding.bottom;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                padding: EdgeInsets.only(top: 8, bottom: 8 + bottom),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return NoteListItem(
                    note: note,
                    onTap: () => _openDetail(context, note),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewNotePage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}