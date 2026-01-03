import 'package:flutter/material.dart';

/// Manager class that handles all search-related functionality in the editor
class SearchManager {
  SearchTextEditingController? noteController;
  ScrollController scrollController;
  TextStyle textStyle;

  // Search state
  int _currentFindIndex = -1;
  List<int> _findMatches = [];

  SearchManager({
    this.noteController,
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
    if (newNoteController is SearchTextEditingController) {
      noteController = newNoteController;
    }
    scrollController = newScrollController;
    // Reset search state when note changes
    _currentFindIndex = -1;
    _findMatches = [];
    noteController?.updateSearchData('', [], -1);
  }

  /// Reset search state without changing controllers
  void reset() {
    _currentFindIndex = -1;
    _findMatches = [];
    noteController?.updateSearchData('', [], -1);
  }

  // Getters
  int get currentFindIndex => _currentFindIndex;
  List<int> get findMatches => _findMatches;
  bool get hasMatches => _findMatches.isNotEmpty;

  /// Performs a search and updates the matches list
  void performFind(String query, VoidCallback onUpdate) {
    if (noteController == null) return;

    if (query.isEmpty) {
      _currentFindIndex = -1;
      _findMatches = [];
      noteController?.updateSearchData('', [], -1);
      onUpdate();
      return;
    }

    final text = noteController!.text;
    List<int> matches = [];

    try {
      // Use RegExp for case-insensitive search without copying the whole text
      final regex = RegExp(RegExp.escape(query), caseSensitive: false);
      for (final match in regex.allMatches(text)) {
        matches.add(match.start);
      }
    } catch (e) {
      // Fallback to simple indexOf if regex fails
      final lowerText = text.toLowerCase();
      final lowerQuery = query.toLowerCase();
      int index = 0;
      while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
        matches.add(index);
        index += 1;
      }
    }

    _findMatches = matches;
    _currentFindIndex = matches.isNotEmpty ? 0 : -1;

    noteController?.updateSearchData(query, _findMatches, _currentFindIndex);
    onUpdate();

    if (matches.isNotEmpty) {
      selectCurrentMatch();
    }
  }

  /// Selects and scrolls to the current match
  void selectCurrentMatch() {
    if (noteController == null) return;
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
      final text = noteController!.text;

      // Calculate scroll position
      final textBeforeMatch = text.substring(0, matchPosition);
      final lines = textBeforeMatch.split('\n');
      final lineNumber = lines.length - 1;

      // Estimate position based on line number and average line height
      final lineHeight = textStyle.fontSize! * (textStyle.height ?? 1.2);
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

    noteController?.updateSearchData(
      noteController?.searchQuery ?? '',
      _findMatches,
      _currentFindIndex,
    );
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

    noteController?.updateSearchData(
      noteController?.searchQuery ?? '',
      _findMatches,
      _currentFindIndex,
    );
    onUpdate();
    selectCurrentMatch();
  }

  /// Clears all search state
  void clear(VoidCallback onUpdate) {
    _currentFindIndex = -1;
    _findMatches = [];
    noteController?.updateSearchData('', [], -1);
    onUpdate();
  }
}

/// Custom TextEditingController that handles search highlighting
class SearchTextEditingController extends TextEditingController {
  String _searchQuery = '';
  int _currentMatchIndex = -1;
  List<int> _matches = [];
  Color? highlightColor;
  Color? currentMatchColor;

  SearchTextEditingController({super.text});

  String get searchQuery => _searchQuery;

  void updateSearchData(String query, List<int> matches, int currentIndex) {
    if (_searchQuery == query &&
        _currentMatchIndex == currentIndex &&
        _matches.length == matches.length) {
      return;
    }
    _searchQuery = query;
    _matches = matches;
    _currentMatchIndex = currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_searchQuery.isEmpty || _matches.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final List<InlineSpan> children = [];
    final String text = this.text;
    int lastIndex = 0;

    final Color hColor =
        highlightColor ?? Theme.of(context).colorScheme.primary.withAlpha(40);
    final Color cColor =
        currentMatchColor ?? Theme.of(context).colorScheme.primary.withAlpha(140);

    for (int i = 0; i < _matches.length; i++) {
      final int start = _matches[i];
      final int end = start + _searchQuery.length;

      // Safety check for range
      if (start < lastIndex || end > text.length) continue;

      if (start > lastIndex) {
        children.add(TextSpan(text: text.substring(lastIndex, start)));
      }

      final bool isCurrent = i == _currentMatchIndex;
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: style?.copyWith(backgroundColor: isCurrent ? cColor : hColor),
        ),
      );

      lastIndex = end;
    }

    if (lastIndex < text.length) {
      children.add(TextSpan(text: text.substring(lastIndex)));
    }

    return TextSpan(style: style, children: children);
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
    // Now we always use a normal TextField because highlighting is handled by the controller
    return TextField(
      controller: controller,
      undoController: undoController,
      focusNode: focusNode,
      style: textStyle,
      maxLines: null,
      expands: true,
      scrollController: scrollController,
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
}

