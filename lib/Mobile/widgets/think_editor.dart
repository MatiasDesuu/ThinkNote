import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../database/models/think.dart';
import '../../database/database_helper.dart';
import '../animations/animations_handler.dart';
import '../scriptmode_handler.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/Editor/list_continuation_handler.dart';

class ThinkEditor extends StatefulWidget {
  final Think selectedThink;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final bool isEditing;
  final bool isImmersiveMode;
  final Future<void> Function() onSaveThink;
  final VoidCallback onToggleEditing;
  final VoidCallback onTitleChanged;
  final VoidCallback onContentChanged;
  final Function(bool) onToggleImmersiveMode;

  const ThinkEditor({
    super.key,
    required this.selectedThink,
    required this.titleController,
    required this.contentController,
    required this.contentFocusNode,
    required this.isEditing,
    required this.isImmersiveMode,
    required this.onSaveThink,
    required this.onToggleEditing,
    required this.onTitleChanged,
    required this.onContentChanged,
    required this.onToggleImmersiveMode,
  });

  @override
  State<ThinkEditor> createState() => _ThinkEditorState();
}

class _ThinkEditorState extends State<ThinkEditor>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  bool _isScript = false;
  bool _isReadMode = false;
  Timer? _scriptDetectionDebouncer;
  Timer? _autoSaveDebounce;
  late SaveAnimationController _saveController;
  final ValueNotifier<int> _currentBlockIndex = ValueNotifier<int>(0);
  bool _isImmersiveMode = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _saveController = SaveAnimationController(vsync: this);
    widget.contentController.addListener(_onContentChanged);
    widget.titleController.addListener(_onTitleChanged);
    _detectScriptMode();
  }

  void _onTitleChanged() {
    widget.onTitleChanged();

    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _handleSave(isAutoSave: true);
    });
  }

  void _onContentChanged() {
    widget.onContentChanged();

    _scriptDetectionDebouncer?.cancel();
    _scriptDetectionDebouncer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isScript = ScriptModeHandler.isScript(widget.contentController.text);
          if (_isScript) {
            _currentBlockIndex.value = 0;
          }
        });
      }
    });

    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      _handleSave(isAutoSave: true);
    });
  }

  void _detectScriptMode() {
    setState(() {
      _isScript = ScriptModeHandler.isScript(widget.contentController.text);
      if (_isScript) {
        _currentBlockIndex.value = 0;
      }
    });
  }

  void _toggleReadMode() {
    setState(() {
      _isReadMode = !_isReadMode;
      if (!_isReadMode) {
        _isImmersiveMode = false;
      }
    });
  }

  void _toggleImmersiveMode() {
    if (_isReadMode && _isScript) {
      setState(() {
        _isImmersiveMode = !_isImmersiveMode;
      });
      widget.onToggleImmersiveMode(_isImmersiveMode);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleSave({bool isAutoSave = false}) async {
    if (!mounted) return;

    if (isAutoSave && _saveController.isAnimating) {
      await widget.onSaveThink();
      return;
    }

    try {
      _saveController.start();
      final startTime = DateTime.now();

      await widget.onSaveThink();
      DatabaseHelper.notifyDatabaseChanged();

      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      final remainingTime = elapsedTime;

      if (remainingTime > 0 && mounted) {
        await Future.delayed(Duration(milliseconds: remainingTime));
      }

      if (mounted) {
        await _saveController.complete();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _saveController.reset();
        setState(() {});
        if (!isAutoSave) {
          CustomSnackbar.show(
            context: context,
            message: 'Error saving think',
            type: CustomSnackbarType.error,
            duration: const Duration(milliseconds: 500),
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _handleBackNavigation() async {
    if (!mounted) return;

    try {
      await widget.onSaveThink();
      DatabaseHelper.notifyDatabaseChanged();
    } catch (e) {
      debugPrint('Error saving think: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    widget.contentController.removeListener(_onContentChanged);
    widget.titleController.removeListener(_onTitleChanged);
    _scriptDetectionDebouncer?.cancel();
    _autoSaveDebounce?.cancel();
    _saveController.dispose();
    _scaleController.dispose();
    _currentBlockIndex.dispose();
    widget.contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: !isKeyboardVisible,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (didPop) return;

        if (isKeyboardVisible) {
          FocusScope.of(context).unfocus();
          return;
        }

        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: TextField(
            controller: widget.titleController,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Think title',
              contentPadding: EdgeInsets.zero,
            ),
            enabled: widget.isEditing && !_isReadMode,
            onChanged: (_) => widget.onTitleChanged(),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              FocusScope.of(context).unfocus();
              _handleBackNavigation();
            },
          ),
          actions: [
            if (_isScript)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: DurationEstimator(
                  content: widget.contentController.text,
                  controller: widget.contentController,
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            onLongPress: _toggleImmersiveMode,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                Column(
                  children: [
                    if (!_isImmersiveMode && !isKeyboardVisible)
                      Divider(
                        height: 0,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    Expanded(
                      child:
                          _isReadMode && _isScript
                              ? _isImmersiveMode
                                  ? ValueListenableBuilder<int>(
                                    valueListenable: _currentBlockIndex,
                                    builder: (context, currentIndex, child) {
                                      return ScriptModeHandler.buildScriptPreview(
                                        context: context,
                                        content: widget.contentController.text,
                                        currentBlockIndex: _currentBlockIndex,
                                        onBlockChanged: () {
                                          widget.onContentChanged();
                                        },
                                      );
                                    },
                                  )
                                  : ScriptModeHandler.buildRegularPreview(
                                    context: context,
                                    content: widget.contentController.text,
                                  )
                              : widget.isEditing
                              ? Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 8,
                                  right: 8,
                                ),
                                child: Focus(
                                  onKeyEvent: (node, event) {
                                    // Handle Enter key for list continuation
                                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                                      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                                      
                                      // Try to handle list continuation
                                      if (ListContinuationHandler.handleEnterKey(widget.contentController, isShiftPressed)) {
                                        widget.onContentChanged();
                                        return KeyEventResult.handled;
                                      }
                                      
                                      // If not handled by list continuation, let default behavior proceed
                                    }
                                    
                                    return KeyEventResult.ignored;
                                  },
                                  child: TextField(
                                    controller: widget.contentController,
                                    autofocus: widget.selectedThink.id != null,
                                    focusNode: widget.contentFocusNode,
                                    maxLines: null,
                                    expands: true,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    cursorOpacityAnimates: true,
                                    cursorWidth: 2,
                                    cursorRadius: const Radius.circular(2),
                                    cursorColor:
                                        Theme.of(context).colorScheme.primary,
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1.4,
                                      color:
                                          Theme.of(context).colorScheme.onSurface,
                                    ),
                                    keyboardType: TextInputType.multiline,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Start thinking...',
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (_) => widget.onContentChanged(),
                                    readOnly: _isReadMode,
                                  ),
                                ),
                              )
                              : SingleChildScrollView(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 8,
                                  right: 8,
                                ),
                                child: Text(
                                  widget.contentController.text,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                    ),
                  ],
                ),
                if (!_isImmersiveMode)
                  Positioned(
                    bottom: bottomPadding + (isKeyboardVisible ? 0 : 16),
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          reverseDuration: const Duration(milliseconds: 300),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            final offsetAnimation = Tween<Offset>(
                              begin: const Offset(0.0, 0.5),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                                reverseCurve: Curves.easeInBack,
                              ),
                            );

                            final fadeAnimation = Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Interval(
                                  0.0,
                                  0.5,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                            );

                            final scaleAnimation = Tween<double>(
                              begin: 0.5,
                              end: 1.0,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Interval(
                                  0.3,
                                  1.0,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                            );

                            return SlideTransition(
                              position: offsetAnimation,
                              child: ScaleTransition(
                                scale: scaleAnimation,
                                child: FadeTransition(
                                  opacity: fadeAnimation,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child:
                              widget.isEditing && !_isReadMode
                                  ? FloatingActionButton(
                                    key: const ValueKey('save'),
                                    heroTag: 'saveButton',
                                    onPressed: () => _handleSave(),
                                    elevation: 4,
                                    child: const Icon(Icons.save_rounded),
                                  )
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        FloatingActionButton(
                          heroTag: 'editButton',
                          onPressed: _toggleReadMode,
                          elevation: 4,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child:
                                _isReadMode
                                    ? const Icon(
                                      Icons.edit_rounded,
                                      key: ValueKey('edit'),
                                    )
                                    : const Icon(
                                      Icons.visibility_rounded,
                                      key: ValueKey('eye'),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DurationEstimator extends StatefulWidget {
  final String content;
  final TextEditingController controller;

  const DurationEstimator({
    super.key,
    required this.content,
    required this.controller,
  });

  @override
  State<DurationEstimator> createState() => _DurationEstimatorState();
}

class _DurationEstimatorState extends State<DurationEstimator> {
  Timer? _debounceTimer;
  String _duration = "00:00";

  @override
  void initState() {
    super.initState();
    _calculateDuration();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _calculateDuration();

    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      _calculateDuration,
    );
  }

  void _calculateDuration() {
    final newDuration = ScriptModeHandler.calculateEstimatedTime(
      widget.controller.text,
    );

    if (mounted && newDuration != _duration) {
      setState(() => _duration = newDuration);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            _duration,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
