import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// CP: A text widget that detects URLs and makes them tappable.
/// URLs are styled as links and open in the browser on tap.
/// Non-URL text has no recognizer, so parent GestureDetector taps pass through.
class LinkableText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const LinkableText({super.key, required this.text, this.style});

  @override
  State<LinkableText> createState() => _LinkableTextState();
}

class _LinkableTextState extends State<LinkableText> {
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s)]+|www\.[^\s)]+',
    caseSensitive: false,
  );

  // CP: Matches trailing punctuation that's almost never part of a real URL
  static final RegExp _trailingPunctuation = RegExp(r'[.,!?;:\]>]+$');

  List<TapGestureRecognizer> _recognizers = [];
  late List<_TextSegment> _segments;

  @override
  void initState() {
    super.initState();
    _buildSegments();
  }

  @override
  void didUpdateWidget(LinkableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _buildSegments();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
  }

  void _buildSegments() {
    _disposeRecognizers();

    final newRecognizers = <TapGestureRecognizer>[];
    final segments = <_TextSegment>[];
    final text = widget.text;
    int cursor = 0;

    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > cursor) {
        segments.add(_TextSegment(text.substring(cursor, match.start), isUrl: false));
      }

      final rawUrl = match.group(0)!;
      final cleanUrl = rawUrl.replaceAll(_trailingPunctuation, '');
      final trailingChars = rawUrl.substring(cleanUrl.length);

      final recognizer = TapGestureRecognizer()..onTap = () => _launchUrl(cleanUrl);
      newRecognizers.add(recognizer);

      segments.add(_TextSegment(cleanUrl, isUrl: true, recognizer: recognizer));
      if (trailingChars.isNotEmpty) {
        segments.add(_TextSegment(trailingChars, isUrl: false));
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      segments.add(_TextSegment(text.substring(cursor), isUrl: false));
    }

    _recognizers = newRecognizers;
    _segments = segments;
  }

  Future<void> _launchUrl(String rawUrl) async {
    final urlString = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final linkColor = Theme.of(context).colorScheme.primary;

    return RichText(
      text: TextSpan(
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: [
          for (final segment in _segments)
            if (segment.isUrl)
              TextSpan(
                text: segment.text,
                style: TextStyle(
                  color: linkColor,
                  decoration: TextDecoration.underline,
                  decorationColor: linkColor,
                ),
                recognizer: segment.recognizer,
              )
            else
              TextSpan(text: segment.text),
        ],
      ),
    );
  }
}

class _TextSegment {
  final String text;
  final bool isUrl;
  final TapGestureRecognizer? recognizer;

  const _TextSegment(this.text, {required this.isUrl, this.recognizer});
}
