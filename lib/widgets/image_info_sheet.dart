import 'package:flutter/material.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageInfoBottomSheet extends StatelessWidget {
  final ImageItem image;

  const ImageInfoBottomSheet({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              image.description,
              style:
                  const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            Html(
              data: image.copyright,
              style: {
                "body": Style(
                  fontSize: FontSize(15.0),
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
                "a": Style(
                  color: Colors.blue,
                  textDecoration: TextDecoration.underline,
                ),
              },
              onLinkTap: (url, attributes, element) async {
                if (url != null) {
                  await _launchUrl(url);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(
          showTitle: true,
        ),
      );
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
