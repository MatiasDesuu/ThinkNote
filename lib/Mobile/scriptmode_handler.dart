import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Settings/editor_settings_panel.dart' show EditorSettingsCache;

class ScriptBlock {
  final int number;
  final String content;

  ScriptBlock({required this.number, required this.content});
}

class ScriptModeHandler {
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

  static String calculateEstimatedTime(String content) {
    final blocks = parseScript(content);
    final totalWords = blocks.fold(
      0,
      (sum, block) =>
          sum +
          block.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );

    final wordsPerSecond = EditorSettingsCache.instance.wordsPerSecond;
    final totalSeconds = (totalWords / wordsPerSecond).ceil();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  static Widget buildScriptPreview({
    required BuildContext context,
    required String content,
    required ValueNotifier<int> currentBlockIndex,
    required VoidCallback onBlockChanged,
  }) {
    final blocks = parseScript(content);
    final totalBlocks = blocks.length;

    if (totalBlocks == 0) {
      return Center(
        child: Text(
          "Empty script or incorrect format",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    currentBlockIndex.value = currentBlockIndex.value.clamp(0, totalBlocks - 1);
    final currentBlock = blocks[currentBlockIndex.value];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.localPosition.dx < screenWidth / 3) {
          _navigateBlock(-1, currentBlockIndex, totalBlocks, onBlockChanged);
        } else if (details.localPosition.dx > screenWidth * 2 / 3) {
          _navigateBlock(1, currentBlockIndex, totalBlocks, onBlockChanged);
        }
      },
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      currentBlock.content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _ProgressIndicator(
              current: currentBlockIndex.value + 1,
              total: totalBlocks,
            ),
          ),
        ],
      ),
    );
  }

  static void _navigateBlock(
    int direction,
    ValueNotifier<int> currentIndex,
    int totalBlocks,
    VoidCallback callback,
  ) {
    if (totalBlocks == 0) return;

    final newIndex = (currentIndex.value + direction).clamp(0, totalBlocks - 1);

    if (newIndex != currentIndex.value) {
      currentIndex.value = newIndex;
      HapticFeedback.selectionClick();
      callback();
    }
  }

  static Widget buildRegularPreview({
    required BuildContext context,
    required String content,
  }) {
    final blocks = parseScript(content);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
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
          child: Text(
            block.content,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.4),
          ),
        );
      },
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$current/$total',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        shadows: [
          Shadow(
            color: Theme.of(context).colorScheme.shadow,
            blurRadius: 5,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    );
  }
}
