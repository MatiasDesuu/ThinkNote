import 'package:flutter/material.dart';

/// Manager class that handles all search-related functionality in the editor
class SearchManager {
  TextEditingController noteController;
  ScrollController scrollController;
  TextStyle textStyle;

  // Search state
  int _currentFindIndex = -1;
  List<int> _findMatches = [];

  SearchManager({
    required this.noteController,
    required this.scrollController,
    required this.textStyle,
  });

  /// Update the text style when it changes
  void updateTextStyle(TextStyle newStyle) {
    textStyle = newStyle;
  }

  /// Update controllers when the note changes
  void updateControllers({
    required TextEditingController newNoteController,
    required ScrollController newScrollController,
  }) {
    noteController = newNoteController;
    scrollController = newScrollController;
    // Reset search state when note changes
    _currentFindIndex = -1;
    _findMatches = [];
  }

  /// Reset search state without changing controllers
  void reset() {
    _currentFindIndex = -1;
    _findMatches = [];
  }

  // Getters
  int get currentFindIndex => _currentFindIndex;
  List<int> get findMatches => _findMatches;
  bool get hasMatches => _findMatches.isNotEmpty;

  /// Performs a search and updates the matches list
  void performFind(String query, VoidCallback onUpdate) {
    if (query.isEmpty) {
      _currentFindIndex = -1;
      _findMatches = [];
      onUpdate();
      return;
    }

    final text = noteController.text;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    List<int> matches = [];
    int index = 0;

    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      matches.add(index);
      index += 1;
    }

    _findMatches = matches;
    _currentFindIndex = matches.isNotEmpty ? 0 : -1;

    onUpdate();

    if (matches.isNotEmpty) {
      selectCurrentMatch();
    }
  }

  /// Selects and scrolls to the current match
  void selectCurrentMatch() {
    if (_currentFindIndex >= 0 && _currentFindIndex < _findMatches.length) {
      // Check if ScrollController is attached
      if (!scrollController.hasClients) {
        // If not attached, schedule for next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            selectCurrentMatch();
          }
        });
        return;
      }

      // Calculate the position of the current match
      final matchPosition = _findMatches[_currentFindIndex];
      final text = noteController.text;

      // Calculate scroll position more accurately
      final textBeforeMatch = text.substring(0, matchPosition);
      final lines = textBeforeMatch.split('\n');
      final lineNumber = lines.length - 1;

      // Estimate position based on line number and average line height
      final lineHeight = textStyle.fontSize! * textStyle.height!;
      final estimatedPosition = lineNumber * lineHeight;

      // Get current scroll position and viewport height
      final viewportHeight = scrollController.position.viewportDimension;

      // Calculate target position to center the match in the viewport
      final targetPosition = (estimatedPosition - viewportHeight / 2).clamp(
        0.0,
        scrollController.position.maxScrollExtent,
      );

      // Animate scroll to the target position
      scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Moves to the next match
  void nextMatch(VoidCallback onUpdate) {
    if (_findMatches.isEmpty) return;

    _currentFindIndex = (_currentFindIndex + 1) % _findMatches.length;

    onUpdate();
    selectCurrentMatch();
  }

  /// Moves to the previous match
  void previousMatch(VoidCallback onUpdate) {
    if (_findMatches.isEmpty) return;

    _currentFindIndex =
        _currentFindIndex <= 0
            ? _findMatches.length - 1
            : _currentFindIndex - 1;

    onUpdate();
    selectCurrentMatch();
  }

  /// Clears all search state
  void clear(VoidCallback onUpdate) {
    _currentFindIndex = -1;
    _findMatches = [];
    onUpdate();
  }

  /// Builds the highlight overlay widget
  Widget buildHighlightOverlay(String query, ColorScheme colorScheme) {
    final text = noteController.text;

    if (query.isEmpty || _findMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    List<TextSpan> spans = [];
    int lastIndex = 0;

    // Find all matches and build text spans
    int index = 0;
    int matchIndex = 0;
    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      // Add text before match
      if (index > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, index),
            style: textStyle.copyWith(color: Colors.transparent),
          ),
        );
      }

      // Add highlighted match - only current match gets bold
      final isCurrentMatch = matchIndex == _currentFindIndex;

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: textStyle.copyWith(
            backgroundColor:
                isCurrentMatch
                    ? colorScheme.primary.withAlpha(120)
                    : colorScheme.primary.withAlpha(50),
            fontWeight: isCurrentMatch ? FontWeight.w600 : FontWeight.normal,
            color: Colors.transparent,
          ),
        ),
      );

      lastIndex = index + query.length;
      index = lastIndex;
      matchIndex++;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: textStyle.copyWith(color: Colors.transparent),
        ),
      );
    }

    // If no spans were created, use original text
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: textStyle.copyWith(color: Colors.transparent),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(
        top: 4.0, // Match TextField's default padding
        bottom: 4.0,
        left: 0.0,
        right: 0.0,
      ),
      alignment: Alignment.topLeft,
      child: RichText(
        text: TextSpan(children: spans),
        textAlign: TextAlign.start,
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }
}

/// Widget that provides highlighted text field with search functionality
class HighlightedTextField extends StatelessWidget {
  final TextEditingController controller;
  final UndoHistoryController? undoController;
  final FocusNode focusNode;
  final TextStyle textStyle;
  final String hintText;
  final SearchManager? searchManager;
  final String? searchQuery;
  final VoidCallback onChanged;
  final ScrollController scrollController;

  const HighlightedTextField({
    super.key,
    required this.controller,
    this.undoController,
    required this.focusNode,
    required this.textStyle,
    required this.hintText,
    required this.onChanged,
    required this.scrollController,
    this.searchManager,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    // If no search query or no matches, show normal TextField
    if (searchQuery == null ||
        searchQuery!.isEmpty ||
        searchManager == null ||
        !searchManager!.hasMatches) {
      return TextField(
        controller: controller,
        undoController: undoController,
        focusNode: focusNode,
        style: textStyle,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: textStyle.fontSize,
            height: textStyle.height,
          ),
        ),
        onChanged: (_) => onChanged(),
      );
    }

    // For search mode, use a Stack with ScrollView containing both TextField and overlay
    return SingleChildScrollView(
      controller: scrollController,
      child: Stack(
        children: [
          // Main TextField for editing
          TextField(
            controller: controller,
            undoController: undoController,
            focusNode: focusNode,
            style: textStyle,
            maxLines: null,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: textStyle.fontSize,
                height: textStyle.height,
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
          // Overlay for highlighting (non-interactive)
          Positioned.fill(
            child: IgnorePointer(
              child: searchManager!.buildHighlightOverlay(
                searchQuery!,
                Theme.of(context).colorScheme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
