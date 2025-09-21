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
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(76), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(76),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withAlpha(76),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: widget.textController,
                  focusNode: widget.focusNode,
                  decoration: InputDecoration(
                    hintText: 'Find in note...',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    suffixIcon:
                        widget.textController.text.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                widget.textController.clear();
                                widget.onFind('');
                              },
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(6),
                                minimumSize: const Size(28, 28),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            )
                            : null,
                  ),
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                  onChanged: widget.onFind,
                  onSubmitted: (_) => widget.onNext(),
                ),
              ),
            ),
          ),
          if (widget.hasMatches) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: buttonHeight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(76),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.currentIndex + 1}/${widget.totalMatches}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: buttonHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withAlpha(76),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: widget.onPrevious,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(28, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: widget.onNext,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(28, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            height: buttonHeight,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withAlpha(76),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: widget.onClose,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(28, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
