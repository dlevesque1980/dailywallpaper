import 'dart:async';

import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'html_text.dart';

class ImageInfoBottomSheet extends StatelessWidget {
  const ImageInfoBottomSheet({super.key, required this.image});

  final ImageItem image;

  @override
  Widget build(BuildContext context) {
    final title = image.title?.trim();
    final credit = image.credit?.trim();
    final sourceUri = Uri.tryParse(image.sourceUrl ?? '');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HtmlText(
                data: title?.isNotEmpty == true ? title! : image.displayTitle,
                style: Theme.of(context).textTheme.titleLarge!,
                linkStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                onLinkTap: (url) {
                  unawaited(_openLink(context, url));
                },
              ),
              const SizedBox(height: 12),
              Text('Source: ${image.source}'),
              if (credit?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                HtmlText(
                  data: credit!,
                  style: Theme.of(context).textTheme.bodyMedium!,
                  linkStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  onLinkTap: (url) {
                    unawaited(_openLink(context, url));
                  },
                ),
              ],
              if (sourceUri != null &&
                  (sourceUri.scheme == 'https' || sourceUri.scheme == 'http'))
                TextButton.icon(
                  onPressed: () => _openLink(context, sourceUri.toString()),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open source'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      _showLinkError(context, 'This link is invalid or unsupported.');
      return;
    }

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        _showLinkError(context, 'Could not open source URL.');
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        _showLinkError(context, 'Could not open source URL: $error');
      }
    }
  }

  void _showLinkError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
