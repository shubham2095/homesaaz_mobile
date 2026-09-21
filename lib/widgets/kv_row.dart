// lib/widgets/kv_row.dart
import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// A label / value row for detail screens — styled like the web `.card-row`.
class KvRow extends StatelessWidget {
  const KvRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final Object? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || '$value'.trim().isEmpty) ? '—' : '$value';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Hs.muted,
                letterSpacing: .3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Hs.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
