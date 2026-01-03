import 'package:flutter/material.dart';

class FindBar extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final Function(String) onFind;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final int currentIndex;
  final int totalMatches;
  final bool hasMatches;

  const FindBar({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.onClose,
    required this.onFind,
    required this.onNext,
    required this.onPrevious,
    required this.currentIndex,
    required this.totalMatches,
    required this.hasMatches,
  });

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const buttonHeight = 36.0; // Height for all elements

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
                    color: colorScheme.outline.withAlpha(50),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: TextField(
                controller: widget.textController,
                focusNode: widget.focusNode,
                decoration: InputDecoration(
                  hintText: 'Find in note...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(76),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  suffixIcon:
                      widget.textController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 14),
                            onPressed: () {
                              widget.textController.clear();
                              widget.onFind('');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            color: colorScheme.onSurfaceVariant,
                          )
                          : null,
                ),
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                onChanged: widget.onFind,
                onSubmitted: (_) => widget.onNext(),
              ),
            ),
          ),
          SizedBox(width: 6),
          if (widget.hasMatches) ...[
            SizedBox(
              height: buttonHeight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(40),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.currentIndex + 1} of ${widget.totalMatches}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
              onPressed: widget.onPrevious,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              color: colorScheme.onSurfaceVariant,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
              onPressed: widget.onNext,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: widget.onClose,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
