import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkMatch {
  final String url;
  final String originalText;
  final String? displayText;
  final int start;
  final int end;

  const LinkMatch({
    required this.url,
    required this.originalText,
    this.displayText,
    required this.start,
    required this.end,
  });

  String get text => displayText ?? originalText;

  @override
  String toString() {
    return 'LinkMatch(url: $url, text: $text, start: $start, end: $end)';
  }
}

class LinkDetector {
  static final RegExp _extendedUrlRegex = RegExp(
    r'(?:https?://|www\.)[^\s<>"{}|\\^`[\]]+',
    caseSensitive: false,
  );

  static final RegExp _markdownLinkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

  static List<LinkMatch> detectLinks(String text) {
    final List<LinkMatch> links = [];

    final markdownMatches = _markdownLinkRegex.allMatches(text);
    for (final match in markdownMatches) {
      links.add(
        LinkMatch(
          url: match.group(2)!,
          originalText: match.group(0)!,
          displayText: match.group(1)!,
          start: match.start,
          end: match.end,
        ),
      );
    }

    final urlMatches = _extendedUrlRegex.allMatches(text);

    for (final match in urlMatches) {
      bool overlaps = false;
      for (final link in links) {
        if (match.start < link.end && match.end > link.start) {
          overlaps = true;
          break;
        }
      }

      if (!overlaps) {
        String url = match.group(0)!;

        if (url.startsWith('www.')) {
          url = 'https://$url';
        }

        links.add(
          LinkMatch(
            url: url,
            originalText: match.group(0)!,
            start: match.start,
            end: match.end,
          ),
        );
      }
    }

    links.sort((a, b) => a.start.compareTo(b.start));

    return links;
  }

  static bool hasLinks(String text) {
    return _extendedUrlRegex.hasMatch(text);
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

class LinkLauncher {
  static Future<void> launchURL(String url) async {
    try {
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final uri = Uri.parse(formattedUrl);

      bool launched = await launchUrl(uri);

      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        debugPrint('All launch attempts failed for: $formattedUrl');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      debugPrint('Original URL: $url');
    }
  }

  static Future<void> launchURLInApp(String url) async {
    try {
      final uri = Uri.parse(url);

      if (!await canLaunchUrl(uri)) {
        throw 'Could not launch $url';
      }

      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } catch (e) {
      debugPrint('Error launching URL in app: $e');
      await launchURL(url);
    }
  }
}
