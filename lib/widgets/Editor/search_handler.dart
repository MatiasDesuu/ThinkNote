import 'package:flutter/material.dart';

class SearchManager {
  SearchTextEditingController? noteController;
  ScrollController scrollController;
  TextStyle textStyle;

  int _currentFindIndex = -1;
  List<int> _findMatches = [];

  SearchManager({
    this.noteController,
    required this.scrollController,
    required this.textStyle,
  });

  void updateTextStyle(TextStyle newStyle) {
    textStyle = newStyle;
  }

  void updateControllers({
    required TextEditingController newNoteController,
    required ScrollController newScrollController,
  }) {
    if (newNoteController is SearchTextEditingController) {
      noteController = newNoteController;
    }
    scrollController = newScrollController;

    _currentFindIndex = -1;
    _findMatches = [];
    noteController?.updateSearchData('', [], -1);
  }

  void reset() {
    _currentFindIndex = -1;
    _findMatches = [];
    noteController?.updateSearchData('', [], -1);
  }

  int get currentFindIndex => _currentFindIndex;
  List<int> get findMatches => _findMatches;
  bool get hasMatches => _findMatches.isNotEmpty;

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
      final regex = RegExp(RegExp.escape(query), caseSensitive: false);
      for (final match in regex.allMatches(text)) {
        matches.add(match.start);
      }
    } catch (e) {
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

  void selectCurrentMatch() {
    if (noteController == null) return;
    if (_currentFindIndex >= 0 && _currentFindIndex < _findMatches.length) {
      if (!scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            selectCurrentMatch();
          }
        });
        return;
      }

      final matchPosition = _findMatches[_currentFindIndex];
      final text = noteController!.text;

      final textBeforeMatch = text.substring(0, matchPosition);
      final lines = textBeforeMatch.split('\n');
      final lineNumber = lines.length - 1;

      final lineHeight = textStyle.fontSize! * (textStyle.height ?? 1.2);
      final estimatedPosition = lineNumber * lineHeight;

      final viewportHeight = scrollController.position.viewportDimension;

      final targetPosition = (estimatedPosition - viewportHeight / 2).clamp(
        0.0,
        scrollController.position.maxScrollExtent,
      );

      scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

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

  void clear(VoidCallback onUpdate) {
    _currentFindIndex = -1;
    _findMatches = [];
    noteController?.updateSearchData('', [], -1);
    onUpdate();
  }
}

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
        currentMatchColor ??
        Theme.of(context).colorScheme.primary.withAlpha(140);

    for (int i = 0; i < _matches.length; i++) {
      final int start = _matches[i];
      final int end = start + _searchQuery.length;

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
