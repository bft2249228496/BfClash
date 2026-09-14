import 'package:emoji_regex/emoji_regex.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:material_ui/material_ui.dart';

import '../state.dart';

class TooltipText extends StatelessWidget {
  final Widget text;

  const TooltipText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final rawText = text;
    if (rawText is! Text) {
      return rawText;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isOverflow = globalState.measure.computeTextIsOverflow(
          rawText,
          maxWidth: maxWidth,
        );
        if (isOverflow) {
          return Tooltip(
            triggerMode: TooltipTriggerMode.longPress,
            preferBelow: false,
            message: rawText.data,
            child: rawText,
          );
        }
        return rawText;
      },
    );
  }
}

class TooltipLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const TooltipLabel(this.text, {super.key, this.style, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return TooltipText(
      text: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
    );
  }
}

class TooltipTextV2 extends StatefulWidget {
  final Text text;

  const TooltipTextV2({super.key, required this.text});

  @override
  State<TooltipTextV2> createState() => _TooltipTextV2State();
}

class _TooltipTextV2State extends State<TooltipTextV2> {
  bool _isOverflow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  void _checkOverflow() {
    if (!mounted) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final isOverflow = globalState.measure.computeTextIsOverflow(
      widget.text,
      maxWidth: renderBox.size.width,
    );
    setState(() => _isOverflow = isOverflow);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: false,
      message: _isOverflow ? widget.text.data : '',
      child: widget.text,
    );
  }
}

class EmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const EmojiText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.style,
  });

  List<TextSpan> _buildTextSpans(String emojis) {
    final List<TextSpan> spans = [];
    final matches = emojiRegex().allMatches(text);

    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style?.copyWith(fontFamily: FontFamily.twEmoji.value),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: _buildTextSpans(text)),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style:
            style?.copyWith(color: Colors.white) ??
            const TextStyle(color: Colors.white),
      ),
    );
  }
}
