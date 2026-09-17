import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/utils/chat_text_direction.dart';
import 'package:hermes_android/core/widgets/markdown_code_block.dart';

void main() {
  final cases = <String, TextDirection>{
    'سلام دنیا': TextDirection.rtl,
    'مرحبا بالعالم': TextDirection.rtl,
    'Hello world': TextDirection.ltr,
    'سلام Flutter and many English words': TextDirection.rtl,
    'Hello فارسی فارسی فارسی': TextDirection.ltr,
    '  😀 (123) **سلام**': TextDirection.rtl,
    '۱۲۳، ٤٥٦؟ Hello': TextDirection.ltr,
    '\u064E\u200Cسلام': TextDirection.rtl,
    '\u200FHello': TextDirection.rtl,
    '\u200Eسلام': TextDirection.ltr,
    '\u061CHello': TextDirection.rtl,
    '\n\nسلام\nHello': TextDirection.rtl,
    '\nHello\nسلام': TextDirection.ltr,
    '': TextDirection.ltr,
    '123 ۱۲۳ 😀 ...': TextDirection.ltr,
  };

  for (final entry in cases.entries) {
    test('first strong direction: ${entry.key}', () {
      expect(chatTextDirection(entry.key), entry.value);
    });
  }

  for (final isUser in [true, false]) {
    for (final text in ['سلام English', 'Hello فارسی']) {
      testWidgets('message direction ($isUser): $text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(content: text, isUser: isUser),
            ),
          ),
        );
        final markdown = find.byType(MarkdownBody);
        expect(
          Directionality.of(tester.element(markdown)),
          text.startsWith('سلام') ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          tester.widget<MarkdownBody>(markdown).styleSheet!.textAlign,
          WrapAlignment.start,
        );
        final prose = tester.widget<RichText>(
          find.descendant(
            of: markdown,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is RichText && widget.text.toPlainText() == text,
            ),
          ),
        );
        expect(
          prose.textDirection,
          text.startsWith('سلام') ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(prose.textAlign, TextAlign.start);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('prose around a code fence keeps its own direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            content: 'سلام\n\n```dart\nprint("سلام");\n```\n\nHello',
            isUser: false,
          ),
        ),
      ),
    );
    final prose = find.byType(MarkdownBody);
    expect(prose, findsNWidgets(2));
    expect(Directionality.of(tester.element(prose.at(0))), TextDirection.rtl);
    expect(Directionality.of(tester.element(prose.at(1))), TextDirection.ltr);
    expect(find.byType(MarkdownCodeBlock), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).textDirection,
      TextDirection.ltr,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('code stays LTR in RTL context with and without wrapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: MarkdownCodeBlock(code: 'print("سلام");\n'),
          ),
        ),
      ),
    );
    void expectLtrCode() {
      final code = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(code.textDirection, TextDirection.ltr);
      expect(code.textAlign, TextAlign.start);
    }

    expectLtrCode();
    await tester.tap(find.byTooltip('Wrap lines'));
    await tester.pump();
    expectLtrCode();
    expect(tester.takeException(), isNull);
  });
}
