import 'package:flutter/widgets.dart';

final _letter = RegExp(r'\p{Letter}', unicode: true);
final _rtlLetter = RegExp(
  r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF\u{1E900}-\u{1E95F}]',
  unicode: true,
);

/// Persian gateway policy: any RTL letter wins, even after English text.
/// Digits, punctuation, emoji and combining marks do not set direction.
/// Call per rendered line for messages; drafts use the whole editing value.
TextDirection chatTextDirection(String text) {
  for (final rune in text.runes) {
    if (rune == 0x200F || rune == 0x061C) return TextDirection.rtl;
    final character = String.fromCharCode(rune);
    if (_letter.hasMatch(character) && _rtlLetter.hasMatch(character)) {
      return TextDirection.rtl;
    }
  }
  return TextDirection.ltr;
}

const chatRlm = '\u200F';
const chatLri = '\u2066';
const chatPdi = '\u2069';

final _latinRun = RegExp(
  r'''[A-Za-z0-9][A-Za-z0-9@#$%&*_+=<>/\\.,:;!?()\[\]{}'"~^-]*(?:[ \t][A-Za-z0-9@#$%&*_+=<>/\\.,:;!?()\[\]{}'"~^-]+)*''',
);

/// Display-only insertion offsets for a single, already-parsed prose line.
/// Never apply this to raw Markdown, hrefs, code, or the stored/copied message.
/// Offsets let the renderer preserve styles and recognizers across Latin runs.
Map<int, String> chatBidiInsertions(String line) {
  if (chatTextDirection(line) != TextDirection.rtl) return {};
  final marks = <int, String>{};
  if (!line.startsWith(chatRlm)) marks[0] = chatRlm;
  var depth = 0;
  var cursor = 0;
  for (final match in _latinRun.allMatches(line)) {
    for (var i = cursor; i < match.start; i++) {
      final unit = line.codeUnitAt(i);
      if (unit >= 0x2066 && unit <= 0x2068) depth++;
      if (unit == 0x2069 && depth > 0) depth--;
    }
    if (depth == 0) {
      marks.update(
        match.start,
        (value) => value + chatLri,
        ifAbsent: () => chatLri,
      );
      marks[match.end] = chatPdi;
    }
    cursor = match.end;
  }
  return marks;
}

/// Plain rendered-text counterpart, useful outside Markdown and in tests.
String chatDisplayText(String text) => text.split('\n').map((line) {
  final marks = chatBidiInsertions(line);
  final result = StringBuffer();
  for (var i = 0; i <= line.length; i++) {
    result.write(marks[i] ?? '');
    if (i < line.length) result.write(line[i]);
  }
  return result.toString();
}).join('\n');
