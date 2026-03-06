import 'dart:async';
import 'dart:io';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returnerer en brukervennlig feilmelding for Supabase/Auth/Storage + nettverk.
///
/// Bruk:
///   try { ... } catch (e) { showSnackBar(supabaseErrorMessage(e)); }
String supabaseErrorMessage(Object error) {
  // --------- Auth ---------
  if (error is AuthException) {
    return _authMessage(error);
  }

  // --------- Database (PostgREST) ---------
  if (error is PostgrestException) {
    return _postgrestMessage(error);
  }

  // --------- Storage ---------
  if (error is StorageException) {
    return _storageMessage(error);
  }

  // --------- Network / IO ---------
  if (error is SocketException) {
    return 'Ingen nettverkstilkobling. Sjekk internett og prøv igjen.';
  }
  if (error is TimeoutException) {
    return 'Tidsavbrudd. Prøv igjen.';
  }

  // --------- Your own throw Exception('...') ---------
  if (error is Exception) {
    final msg = error.toString().replaceFirst('Exception: ', '').trim();
    if (msg.isNotEmpty) return msg;
  }

  return 'Noe gikk galt. Prøv igjen.';
}

String _authMessage(AuthException e) {
  final m = e.message.toLowerCase();


  if (m.contains('invalid login credentials')) {
    return 'Feil e-post eller passord.';
  }
  if (m.contains('email not confirmed')) {
    return 'E-posten er ikke bekreftet. Sjekk innboksen og bekreft kontoen.';
  }
  if (m.contains('user already registered') || m.contains('already registered')) {
    return 'Det finnes allerede en konto med denne e-posten.';
  }
  if (m.contains('password') && m.contains('length')) {
    return 'Passordet er for kort.';
  }

  return e.message;
}

String _postgrestMessage(PostgrestException e) {
  final msg = (e.message).toLowerCase();

  if (msg.contains('permission denied') || msg.contains('violates row-level security')) {
    return 'Ingen tilgang.';
  }

  if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
    return 'Dette finnes allerede (duplikat).';
  }

  if (msg.contains('null value') || msg.contains('not-null')) {
    return 'Mangler påkrevde felter.';
  }

  return e.message;
}

String _storageMessage(StorageException e) {
  final msg = e.message.toLowerCase();

  if (msg.contains('unauthorized') || msg.contains('permission')) {
    return 'Ingen tilgang til lagring av bilder.';
  }
  if (msg.contains('not found')) {
    return 'Fant ikke filen.';
  }

  return e.message;
}