import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../utils/chat_text_direction.dart';

/// Keep the Markdown parser in charge of syntax and URLs. Only parsed inline
/// text is decorated for display; the caller retains the original for copying.
class ChatMarkdownBody extends StatelessWidget {
  const ChatMarkdownBody({
    super.key,
    required this.data,
    required this.styleSheet,
    this.onTapLink,
  });

  final String data;
  final MarkdownStyleSheet styleSheet;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final styles = MarkdownStyleSheet.fromTheme(
      Theme.of(context),
    ).merge(styleSheet);
    final prose = _ProseBuilder(styles, onTapLink);
    return MarkdownBody(
      data: data,
      selectable: false,
      fitContent: false,
      softLineBreak: true,
      styleSheet: styles,
      onTapLink: onTapLink,
      builders: {
        for (final tag in ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li'])
          tag: prose,
        'code': _InlineCodeBuilder(),
      },
    );
  }
}

class _InlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Text(
      element.textContent,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      style: parentStyle?.merge(preferredStyle) ?? preferredStyle,
    );
  }
}

class _ProseBuilder extends MarkdownElementBuilder {
  _ProseBuilder(this.styles, this.onTapLink);
  final MarkdownStyleSheet styles;
  final MarkdownTapLinkCallback? onTapLink;

  // Keep flutter_markdown's inline stack balanced even though we replace the
  // completed block. Returning null here leaves an empty inline stack frame.
  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) =>
      Text(text.text, style: preferredStyle);

  bool _inlineOnly(md.Node node) {
    if (node is! md.Element) return true;
    // Let the stock renderer retain layout for nested blocks and images.
    if (!['a', 'em', 'strong', 'del', 'code', 'br'].contains(node.tag)) {
      return false;
    }
    return node.children?.every(_inlineOnly) ?? true;
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (!(element.children?.every(_inlineOnly) ?? false)) return null;
    return _ProseLines(
      element: element,
      styles: styles,
      style: parentStyle?.merge(preferredStyle) ?? preferredStyle,
      onTapLink: onTapLink,
    );
  }
}

class _ProseLines extends StatefulWidget {
  const _ProseLines({
    required this.element,
    required this.styles,
    required this.style,
    required this.onTapLink,
  });

  final md.Element element;
  final MarkdownStyleSheet styles;
  final TextStyle? style;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  State<_ProseLines> createState() => _ProseLinesState();
}

class _ProseLinesState extends State<_ProseLines> {
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final lines = <List<InlineSpan>>[[]];
    void text(String value, TextStyle? style, GestureRecognizer? recognizer) {
      final parts = value.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) lines.add([]);
        lines.last.add(
          TextSpan(text: parts[i], style: style, recognizer: recognizer),
        );
      }
    }

    void visit(md.Node node, TextStyle? style, GestureRecognizer? recognizer) {
      if (node is md.Text) {
        text(node.text, style, recognizer);
      } else if (node is md.Element) {
        if (node.tag == 'br') {
          lines.add([]);
          return;
        }
        final childStyle = style?.merge(widget.styles.styles[node.tag]) ??
            widget.styles.styles[node.tag];
        if (node.tag == 'code') {
          // WidgetSpan is atomic, with unmodified code and an LTR base.
          lines.last.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Text(
                node.textContent,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style: childStyle,
              ),
            ),
          );
          return;
        }
        if (node.tag == 'a') {
          final link = TapGestureRecognizer()
            ..onTap = () => widget.onTapLink?.call(
              node.textContent,
              node.attributes['href'],
              node.attributes['title'] ?? '',
            );
          _recognizers.add(link);
          recognizer = link;
        }
        for (final child in node.children ?? <md.Node>[]) {
          visit(child, childStyle, recognizer);
        }
      }
    }

    for (final node in widget.element.children ?? <md.Node>[]) {
      visit(node, widget.style, null);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: lines.map((spans) {
        // U+FFFC stands for a code widget; code never enters prose bidi.
        final plain = TextSpan(children: spans).toPlainText();
        final marks = chatBidiInsertions(plain);
        var offset = 0;
        final display = <InlineSpan>[];
        for (final span in spans) {
          if (span is TextSpan) {
            final original = span.text ?? '';
            final value = StringBuffer();
            for (var i = 0; i < original.length; i++, offset++) {
              value.write(marks[offset] ?? '');
              value.write(original[i]);
            }
            display.add(
              TextSpan(
                text: value.toString(),
                style: span.style,
                recognizer: span.recognizer,
              ),
            );
          } else {
            if (marks.containsKey(offset)) {
              display.add(TextSpan(text: marks[offset]));
            }
            display.add(span);
            offset++;
          }
        }
        if (marks.containsKey(offset)) display.add(TextSpan(text: marks[offset]));
        return Text.rich(
          display.length == 1 && display.single is TextSpan
              ? display.single as TextSpan
              : TextSpan(children: display),
          textDirection: chatTextDirection(plain),
          textAlign: TextAlign.start,
          textScaler: widget.styles.textScaler,
        );
      }).toList(),
    );
  }
}
