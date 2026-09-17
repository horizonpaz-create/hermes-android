import 'package:flutter/widgets.dart';

// Unicode letters exclude digits, punctuation, emoji and combining marks, which
// must not make a Persian draft LTR just because they precede its first letter.
final _letter = RegExp(r'\p{Letter}', unicode: true);
final _rtlLetter = RegExp(
  r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF\u{1E900}-\u{1E95F}]',
  unicode: true,
);

/// Resolve chat prose and drafts by their first strong character, not by the
/// proportion of RTL words. Empty or neutral-only drafts default to LTR.
TextDirection chatTextDirection(String text) {
  for (final rune in text.runes) {
    // Explicit strong direction marks (not embeddings/isolates or ZWNJ).
    if (rune == 0x200F || rune == 0x061C) return TextDirection.rtl;
    if (rune == 0x200E) return TextDirection.ltr;
    final character = String.fromCharCode(rune);
    if (!_letter.hasMatch(character)) continue;
    return _rtlLetter.hasMatch(character)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
  return TextDirection.ltr;
}
