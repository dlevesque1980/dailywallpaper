import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

class TextWithHyperLink extends StatelessWidget {
  final String text;
  final Color color;
  final Color hyperlinkColor;
  TextWithHyperLink({this.text, this.color, this.hyperlinkColor});

  List<TextSpan> extractUrl(String text) {
    List<TextSpan> textParts = List<TextSpan>();
    final linkStyle = TextStyle(fontSize: 15.0, color: hyperlinkColor, decoration: TextDecoration.underline, fontWeight: FontWeight.bold, package: "dailywallpaper");
    final style = TextStyle(fontSize: 15.0, color: color, package: "dailywallpaper");
    int begin, end;
    do {
      begin = text.indexOf(" <a");
      end = text.indexOf("</a>");
      if (begin != -1 && end != -1) {
        var onlyText = text.substring(0, begin);
        TextSpan part = TextSpan(text: "$onlyText ", style: style);
        textParts.add(part);
        var urlText = text.substring(begin, end + 4);
        var urlRegex = new RegExp(r"<a[\s]+([^>]+)>((?:.(?!\<\/a\>))*.)</a>");
        var url = urlRegex.firstMatch(urlText);
        TextSpan link = TextSpan(
          text: url?.group(2),
          style: linkStyle,
          recognizer: new TapGestureRecognizer()
            ..onTap = () {
              launch(
                url.group(1).replaceAll("href=\"", "").replaceAll("\"", ""),
                option: new CustomTabsOption(
                    toolbarColor: Colors.white,
                    enableDefaultShare: true,
                    enableUrlBarHiding: true,
                    showPageTitle: true,
                    animation: new CustomTabsAnimation.slideIn()),
              ).catchError((e) {
                debugPrint(e.toString());
              });
            },
        );
        textParts.add(link);
        text = text.substring(end + 4, text.length);
      }
    } while (begin != -1 && end != -1);

    if (text.isNotEmpty) {
      TextSpan lastPart = TextSpan(text: text, style: style);
      textParts.add(lastPart);
    }

    return textParts;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: extractUrl(text)));
  }
}
