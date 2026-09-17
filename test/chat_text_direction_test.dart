import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/utils/chat_text_direction.dart';
import 'package:hermes_android/core/widgets/chat_markdown_body.dart';
import 'package:hermes_android/core/widgets/markdown_code_block.dart';

Finder paragraph(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == text,
);

void main() {
  final cases = <String, TextDirection>{
    'سلام دنیا': TextDirection.rtl,
    'مرحبا بالعالم': TextDirection.rtl,
    'Hello world': TextDirection.ltr,
    'سلام Flutter and many English words': TextDirection.rtl,
    'Hello فارسی فارسی فارسی': TextDirection.rtl,
    'https://example.com/path?q=hello': TextDirection.ltr,
    '  😀 (123) **سلام**': TextDirection.rtl,
    '۱۲۳، ٤٥٦؟ Hello': TextDirection.ltr,
    '\u064E\u200Cسلام': TextDirection.rtl,
    '\u200FHello': TextDirection.rtl,
    '\u200Eسلام': TextDirection.rtl,
    '\u061CHello': TextDirection.rtl,
    '\n\nسلام\nHello': TextDirection.rtl,
    '\nHello\nسلام': TextDirection.rtl,
    '': TextDirection.ltr,
    '123 ۱۲۳ 😀 ...': TextDirection.ltr,
  };
  for (final entry in cases.entries) {
    test('any RTL letter wins: ${entry.key}', () {
      expect(chatTextDirection(entry.key), entry.value);
    });
  }

  test('display marks are line-local and pure LTR lines are untouched', () {
    expect(
      chatDisplayText('Hello فارسی\nHello world\nhttps://example.com\n\nسلام API'),
      '\u200F\u2066Hello\u2069 فارسی\nHello world\nhttps://example.com\n\n'
      '\u200Fسلام \u2066API\u2069',
    );
  });

  test('Latin phrases and URL punctuation stay together', () {
    expect(chatDisplayText('با Cloudflare Turnstile و https://example.com?q=1 هست'),
        '\u200Fبا \u2066Cloudflare Turnstile\u2069 و '
        '\u2066https://example.com?q=1\u2069 هست');
  });

  test('repeated rendering never nests isolates or duplicates RLM', () {
    for (final source in [
      'Hello فارسی',
      'سلام \u2066Cloudflare Turnstile\u2069 و API',
      '\u200Fسلام API',
      'سلام \u2067Hello \u2066API\u2069\u2069',
    ]) {
      final once = chatDisplayText(source);
      expect(chatDisplayText(once), once);
      expect(once, isNot(contains('\u2066\u2066')));
      expect(once, isNot(contains('\u200F\u200F')));
    }
  });

  for (final isUser in [true, false]) {
    for (final text in ['سلام English', 'Hello فارسی']) {
      testWidgets('message direction ($isUser): $text', (tester) async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: MessageBubble(content: text, isUser: isUser),
        )));
        final prose = tester.renderObject<RenderParagraph>(
          paragraph(chatDisplayText(text)),
        );
        expect(prose.textDirection, TextDirection.rtl);
        expect(prose.textAlign, TextAlign.start);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('each soft/hard line and paragraph resolves independently', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: MessageBubble(
        content: 'Hello فارسی\nEnglish only\nhttps://example.com  \n'
            'API عربی\n\nLast English paragraph',
        isUser: false,
      ),
    )));
    for (final line in [
      'Hello فارسی', 'English only', 'https://example.com',
      'API عربی', 'Last English paragraph',
    ]) {
      final render = tester.renderObject<RenderParagraph>(paragraph(chatDisplayText(line)));
      expect(render.textDirection, chatTextDirection(line));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('styled Latin phrase is isolated across spans, links keep real href', (tester) async {
    String? tappedHref;
    String? tappedLabel;
    const href = 'https://example.com/path?q=1&lang=fa#part';
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ChatMarkdownBody(
        data: 'از **Cloudflare** Turnstile و [API docs]($href) استفاده کن',
        styleSheet: MarkdownStyleSheet(),
        onTapLink: (text, url, title) {
          tappedLabel = text;
          tappedHref = url;
        },
      ),
    )));
    final rich = tester.widget<RichText>(paragraph(
      '\u200Fاز \u2066Cloudflare Turnstile\u2069 و \u2066API docs\u2069 استفاده کن',
    ));
    final spans = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan) spans.add(span);
      return true;
    });
    expect(spans.any((span) => span.style?.fontWeight == FontWeight.bold), isTrue);
    final link = spans.firstWhere((span) => span.recognizer is TapGestureRecognizer);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    expect(tappedHref, href);
    expect(tappedLabel, 'API docs');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference links are resolved before bidi decoration', (tester) async {
    String? tappedHref;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ChatMarkdownBody(
        data: 'Hello فارسی [docs][ref]\n\n[ref]: https://example.com/a?q=1',
        styleSheet: MarkdownStyleSheet(),
        onTapLink: (text, url, title) => tappedHref = url,
      ),
    )));
    final rich = tester.widget<RichText>(paragraph(
      '\u200F\u2066Hello\u2069 فارسی \u2066docs\u2069',
    ));
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
        (span.recognizer! as TapGestureRecognizer).onTap!();
      }
      return true;
    });
    expect(tappedHref, 'https://example.com/a?q=1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline code is an unchanged LTR widget in mixed prose', (tester) async {
    const code = 'print("سلام");';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: MessageBubble(content: 'Hello فارسی `$code` پایان', isUser: false),
    )));
    final codeWidget = tester.widget<Text>(find.text(code));
    expect(codeWidget.data, code);
    expect(codeWidget.textDirection, TextDirection.ltr);
    expect(tester.renderObject<RenderParagraph>(paragraph(code)).textDirection, TextDirection.ltr);
    expect(tester.takeException(), isNull);
  });

  testWidgets('message and fenced code copy retain original source', (tester) async {
    const code = 'print("سلام");\n';
    const source = 'Hello فارسی\n\n```dart\n${code}```\n\nHello';
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: MessageBubble(content: source, isUser: false),
    )));
    expect(tester.renderObject<RenderParagraph>(paragraph(chatDisplayText('Hello فارسی')))
        .textDirection, TextDirection.rtl);
    expect(tester.renderObject<RenderParagraph>(paragraph('Hello')).textDirection,
        TextDirection.ltr);
    expect(find.byType(MarkdownCodeBlock), findsOneWidget);
    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, code);
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pump();
    expect(copied.last, code);
    await tester.longPress(find.byKey(const Key('message-bubble')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy message'));
    await tester.pumpAndSettle();
    expect(copied.last, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('code stays LTR in RTL context with and without wrapping', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: MarkdownCodeBlock(code: 'print("سلام");\n'),
      ),
    )));
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
