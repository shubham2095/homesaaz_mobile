// lib/widgets/hs_dialog.dart
//
// Mirrors the web app's SweetAlert2 confirmation dialog (used by
// user/list.blade.php and uploadgateentrybill/list.blade.php's delete
// flows): a white rounded card, a warning icon, bold title, muted body
// text, and a Cancel / destructive-confirm button pair
// (`cancelButtonColor:#6c757d`, `confirmButtonColor:#dc3545`).
import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Shows the confirmation dialog and resolves `true` only if the
/// destructive action button was tapped.
Future<bool> showHsConfirmDialog(
  BuildContext context, {
  required String title,
  String text = 'This action cannot be undone.',
  String confirmLabel = 'Yes, Delete',
  String cancelLabel = 'Cancel',
  Color confirmColor = Hs.red,
  IconData icon = Icons.warning_amber_rounded,
  Color iconColor = Hs.amber,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Hs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Hs.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Hs.muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C757D),
                      side: const BorderSide(color: Color(0xFF6C757D)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
