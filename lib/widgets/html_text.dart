import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class HtmlText extends StatefulWidget {
  const HtmlText({
    super.key,
    required this.data,
    required this.style,
    required this.linkStyle,
    required this.onLinkTap,
  });

  final String data;
  final TextStyle style;
  final TextStyle linkStyle;
  final ValueChanged<String> onLinkTap;

  @override
  State<HtmlText> createState() => _HtmlTextState();
}

class _HtmlTextState extends State<HtmlText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void didUpdateWidget(covariant HtmlText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _disposeRecognizers();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final document = html_parser.parseFragment(widget.data);
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: document.nodes
            .expand((node) => _buildNode(node, widget.style))
            .toList(growable: false),
      ),
    );
  }

  List<InlineSpan> _buildNode(dom.Node node, TextStyle inheritedStyle) {
    if (node is dom.Text) {
      return [TextSpan(text: node.text)];
    }
    if (node is! dom.Element ||
        node.localName == 'script' ||
        node.localName == 'style') {
      return const [];
    }

    final tag = node.localName;
    var style = inheritedStyle;
    if (tag == 'b' || tag == 'strong') {
      style = style.copyWith(fontWeight: FontWeight.bold);
    } else if (tag == 'i' || tag == 'em') {
      style = style.copyWith(fontStyle: FontStyle.italic);
    } else if (tag == 'u') {
      style = style.copyWith(decoration: TextDecoration.underline);
    }

    TapGestureRecognizer? recognizer;
    if (tag == 'a') {
      style = style.merge(widget.linkStyle);
      final href = node.attributes['href'];
      if (href != null && href.isNotEmpty) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onLinkTap(href);
        _recognizers.add(recognizer);
      }
    }

    final children = node.nodes
        .expand((child) => _buildNode(child, style))
        .toList(growable: false);
    if (tag == 'br') return const [TextSpan(text: '\n')];
    if (tag == 'p' || tag == 'div') {
      return [
        const TextSpan(text: '\n'),
        TextSpan(children: children),
        const TextSpan(text: '\n'),
      ];
    }
    return [TextSpan(children: children, recognizer: recognizer)];
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}
