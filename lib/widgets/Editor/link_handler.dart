import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that detects and makes URLs clickable in text content
class LinkHandler extends StatelessWidget {
  final String text;
  final TextStyle textStyle;
  final Function(String)? onLinkTap;
  final bool enableLinkDetection;

  const LinkHandler({
    super.key,
    required this.text,
    required this.textStyle,
    this.onLinkTap,
    this.enableLinkDetection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableLinkDetection || text.isEmpty) {
      return Text(text, style: textStyle);
    }

    final spans = _buildTextSpansWithLinks(context);
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  List<TextSpan> _buildTextSpansWithLinks(BuildContext context) {
    final List<TextSpan> spans = [];
    final links = LinkDetector.detectLinks(text);
    
    if (links.isEmpty) {
      spans.add(TextSpan(text: text, style: textStyle));
      return spans;
    }

    int lastIndex = 0;
    
    for (final link in links) {
      // Add text before the link
      if (link.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, link.start),
          style: textStyle,
        ));
      }
      
      // Add the clickable link
      spans.add(TextSpan(
        text: link.text,
        style: textStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decorationColor: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _handleLinkTap(link.url),
      ));
      
      lastIndex = link.end;
    }
    
    // Add remaining text after the last link
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: textStyle,
      ));
    }
    
    return spans;
  }

  void _handleLinkTap(String url) {
    if (onLinkTap != null) {
      onLinkTap!(url);
    } else {
      LinkLauncher.launchURL(url);
    }
  }
}

/// A utility class for detecting URLs in text
class LinkDetector {
  // Comprehensive URL regex that includes www. links
  static final RegExp _extendedUrlRegex = RegExp(
    r'(?:https?://|www\.)[^\s<>"{}|\\^`[\]]+',
    caseSensitive: false,
  );
  
  // Regex for markdown links [Name](url)
  static final RegExp _markdownLinkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

  /// Detects all URLs in the given text and returns their positions
  static List<LinkMatch> detectLinks(String text) {
    final List<LinkMatch> links = [];
    
    // 1. Detect Markdown links first (they take precedence)
    final markdownMatches = _markdownLinkRegex.allMatches(text);
    for (final match in markdownMatches) {
      links.add(LinkMatch(
        url: match.group(2)!,
        originalText: match.group(0)!,
        displayText: match.group(1)!,
        start: match.start,
        end: match.end,
      ));
    }

    // 2. Detect raw URLs
    final urlMatches = _extendedUrlRegex.allMatches(text);
    
    for (final match in urlMatches) {
      // Check if this URL overlaps with any already detected markdown link
      bool overlaps = false;
      for (final link in links) {
        if (match.start < link.end && match.end > link.start) {
          overlaps = true;
          break;
        }
      }
      
      if (!overlaps) {
        String url = match.group(0)!;
        
        // Add protocol if missing for www. links
        if (url.startsWith('www.')) {
          url = 'https://$url';
        }
        
        links.add(LinkMatch(
          url: url,
          originalText: match.group(0)!,
          start: match.start,
          end: match.end,
        ));
      }
    }
    
    // Sort by start position
    links.sort((a, b) => a.start.compareTo(b.start));
    
    return links;
  }

  /// Checks if a string contains any URLs
  static bool hasLinks(String text) {
    return _extendedUrlRegex.hasMatch(text);
  }

  /// Validates if a string is a valid URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}

/// Represents a detected link in text
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

/// Utility class for launching URLs
class LinkLauncher {
  /// Launches a URL in the default browser
  static Future<void> launchURL(String url) async {
    try {
      
      // Ensure the URL has a proper protocol
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.startsWith('www.')) {
          formattedUrl = 'https://$url';
        } else {
          formattedUrl = 'https://$url';
        }
      }
      
      final uri = Uri.parse(formattedUrl);      
      // Try different launch modes for better compatibility
      bool launched = false;
      
      // First try external application mode
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('External launch failed: $e');
      }
      
      // If external failed, try platform default
      if (!launched) {
        try {
          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }
      
      // If still failed, try system mode  
      if (!launched) {
        try {
          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(uri);
          }
        } catch (e) {
          print('System launch failed: $e');
        }
      }
      
      if (!launched) {
        print('All launch attempts failed for: $formattedUrl');
      }
      
    } catch (e) {
      print('Error launching URL: $e');
      print('Original URL: $url');
    }
  }

  /// Opens a URL in the system's simple browser (if available)
  static Future<void> launchURLInApp(String url) async {
    try {
      final uri = Uri.parse(url);
      
      if (!await canLaunchUrl(uri)) {
        throw 'Could not launch $url';
      }
      
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
    } catch (e) {
      print('Error launching URL in app: $e');
      // Fallback to external browser
      await launchURL(url);
    }
  }

  /// Copies a URL to the clipboard
  static Future<void> copyURLToClipboard(String url) async {
    try {
      // This is a placeholder for future implementation
    } catch (e) {
      print('Error copying URL to clipboard: $e');
    }
  }
}

/// A widget that provides a context menu for links
class LinkContextMenu extends StatelessWidget {
  final String url;
  final Widget child;
  final VoidCallback? onOpenInBrowser;
  final VoidCallback? onOpenInApp;
  final VoidCallback? onCopyLink;

  const LinkContextMenu({
    super.key,
    required this.url,
    required this.child,
    this.onOpenInBrowser,
    this.onOpenInApp,
    this.onCopyLink,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: child,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          onTap: onOpenInBrowser ?? () => LinkLauncher.launchURL(url),
          child: const Row(
            children: [
              Icon(Icons.open_in_browser),
              SizedBox(width: 8),
              Text('Open in browser'),
            ],
          ),
        ),
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
          PopupMenuItem(
            onTap: onOpenInApp ?? () => LinkLauncher.launchURLInApp(url),
            child: const Row(
              children: [
                Icon(Icons.web),
                SizedBox(width: 8),
                Text('Open in app'),
              ],
            ),
          ),
        PopupMenuItem(
          onTap: onCopyLink ?? () => LinkLauncher.copyURLToClipboard(url),
          child: const Row(
            children: [
              Icon(Icons.copy),
              SizedBox(width: 8),
              Text('Copy link'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A text field that automatically detects and makes links clickable
class LinkAwareTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final String? hintText;
  final bool readOnly;
  final int? maxLines;
  final bool expands;
  final Function(String)? onChanged;
  final Function(String)? onLinkTap;
  final bool enableLinkDetection;
  final bool showLinkOverlay;
  final ScrollController? scrollController;

  const LinkAwareTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.style,
    this.hintText,
    this.readOnly = false,
    this.maxLines,
    this.expands = false,
    this.onChanged,
    this.onLinkTap,
    this.enableLinkDetection = true,
    this.showLinkOverlay = false,
    this.scrollController,
  });

  @override
  State<LinkAwareTextField> createState() => _LinkAwareTextFieldState();
}

class _LinkAwareTextFieldState extends State<LinkAwareTextField> {
  @override
  Widget build(BuildContext context) {
    if (widget.readOnly && widget.enableLinkDetection) {
      // In read-only mode, show clickable links
      return SingleChildScrollView(
        controller: widget.scrollController,
        child: LinkHandler(
          text: widget.controller.text,
          textStyle: widget.style ?? Theme.of(context).textTheme.bodyMedium!,
          onLinkTap: widget.onLinkTap,
          enableLinkDetection: widget.enableLinkDetection,
        ),
      );
    }

    // In edit mode, show regular TextField with optional link overlay
    if (widget.showLinkOverlay && widget.enableLinkDetection) {
      return Stack(
        children: [
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: widget.style,
            maxLines: widget.maxLines,
            expands: widget.expands,
            readOnly: widget.readOnly,
            scrollController: widget.scrollController,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hintText,
            ),
            onChanged: widget.onChanged,
          ),
          // Overlay to show clickable links while editing
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4.0),
                child: _buildLinkOverlay(),
              ),
            ),
          ),
        ],
      );
    }

    // Standard TextField
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: widget.style,
      maxLines: widget.maxLines,
      expands: widget.expands,
      readOnly: widget.readOnly,
      scrollController: widget.scrollController,
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: widget.hintText,
      ),
      onChanged: widget.onChanged,
    );
  }

  Widget _buildLinkOverlay() {
    final text = widget.controller.text;
    final links = LinkDetector.detectLinks(text);
    
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    return RichText(
      text: TextSpan(
        children: _buildOverlaySpans(text, links),
      ),
    );
  }

  List<TextSpan> _buildOverlaySpans(String text, List<LinkMatch> links) {
    final List<TextSpan> spans = [];
    int lastIndex = 0;
    
    for (final link in links) {
      // Add transparent text before the link
      if (link.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, link.start),
          style: (widget.style ?? Theme.of(context).textTheme.bodyMedium!)
              .copyWith(color: Colors.transparent),
        ));
      }
      
      spans.add(TextSpan(
        text: link.originalText,
        style: (widget.style ?? Theme.of(context).textTheme.bodyMedium!)
            .copyWith(
          color: Colors.transparent,
          decoration: TextDecoration.none,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (widget.onLinkTap != null) {
              widget.onLinkTap!(link.url);
            } else {
              LinkLauncher.launchURL(link.url);
            }
          },
      ));
      
      lastIndex = link.end;
    }
    
    // Add remaining transparent text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: (widget.style ?? Theme.of(context).textTheme.bodyMedium!)
            .copyWith(color: Colors.transparent),
      ));
    }
    
    return spans;
  }
}
