// lib/features/documents/document_pdf.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import 'document_repository.dart';

/// Downloads a document's letterhead PDF and opens it in the device's PDF
/// viewer. Shared by the list (tap the Doc No, like the web) and the detail
/// screen's PDF button; reports progress / failure via a snackbar.
Future<void> downloadDocumentPdf(
  BuildContext context,
  WidgetRef ref, {
  required int locationId,
  required String docType,
  required String docKey,
  required String label,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String m, {bool hold = false}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(m),
      duration: hold ? const Duration(minutes: 1) : const Duration(seconds: 4),
    ));

  say('Preparing PDF…', hold: true);
  try {
    final bytes = await ref.read(documentRepositoryProvider).pdfBytes(
          locationId: locationId,
          docType: docType,
          key: docKey,
        );
    final dir = await getTemporaryDirectory();
    final safe = '${label}_$docKey'.replaceAll(RegExp(r'[^\w\-]'), '_');
    final file = File('${dir.path}/$safe.pdf');
    await file.writeAsBytes(bytes, flush: true);
    messenger.hideCurrentSnackBar();
    final res = await OpenFilex.open(file.path);
    if (res.type != ResultType.done) {
      say('Could not open PDF: ${res.message}');
    }
  } on ApiException catch (e) {
    say(e.message);
  } catch (e) {
    say('PDF download failed: $e');
  }
}
