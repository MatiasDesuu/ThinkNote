import 'package:flutter/material.dart';
import 'widgets/Editor/unified_text_handler.dart';
import 'database/models/note.dart';

class ScriptModeHandlerDesktop {
  static bool isScript(String content) {
    final lines = content.split('\n');
    return lines.isNotEmpty && lines.first.trim() == "#script";
  }

  static List<ScriptBlock> parseScript(String content) {
    final List<ScriptBlock> blocks = [];
    final lines = content.split('\n');
    int currentBlockNumber = 0;
    String currentContent = "";

    for (String line in lines.skip(1)) {
      final trimmedLine = line.trim();
      final headerMatch = RegExp(r'^#\d+$').firstMatch(trimmedLine);

      if (headerMatch != null) {
        if (currentBlockNumber > 0) {
          blocks.add(
            ScriptBlock(
              number: currentBlockNumber,
              content: currentContent.trim(),
            ),
          );
        }
        currentBlockNumber++;
        currentContent = "";
      } else {
        currentContent += "$line\n";
      }
    }

    if (currentBlockNumber > 0) {
      blocks.add(
        ScriptBlock(number: currentBlockNumber, content: currentContent.trim()),
      );
    }

    return blocks;
  }

  static Widget buildScriptPreview(
    BuildContext context,
    String content, {
    TextStyle? textStyle,
    Function(Note, bool)? onNoteLinkTap,
  }) {
    final blocks = parseScript(content);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: blocks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final block = blocks[index];
        return Container(
          decoration: BoxDecoration(
            color:
                index.isEven
                    ? colorScheme.surfaceContainerLow
                    : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: _buildEnhancedScriptText(
            context,
            block.content,
            textStyle ?? Theme.of(context).textTheme.bodyLarge!,
            onNoteLinkTap: onNoteLinkTap,
          ),
        );
      },
    );
  }

  static Widget _buildEnhancedScriptText(
    BuildContext context, 
    String text, 
    TextStyle textStyle, {
    Function(Note, bool)? onNoteLinkTap,
  }) {
    // Use the new UnifiedTextHandler that handles ALL formatting types
    return UnifiedTextHandler(
      text: text,
      textStyle: textStyle,
      enableNoteLinkDetection: true,
      enableLinkDetection: true,
      enableListDetection: true,
      enableFormatDetection: true,
      onNoteLinkTap: onNoteLinkTap,
    );
  }
}

class ScriptBlock {
  final int number;
  final String content;

  ScriptBlock({required this.number, required this.content});
}

class DurationEstimatorDesktop extends StatelessWidget {
  final String content;

  const DurationEstimatorDesktop({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final blocks = ScriptModeHandlerDesktop.parseScript(content);

    // Same counting logic as in Android
    final totalWords = blocks.fold(
      0,
      (sum, block) =>
          sum +
          block.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );

    final totalSeconds = (totalWords * 0.20).ceil(); // Same calculation
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    final duration =
        "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            duration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
