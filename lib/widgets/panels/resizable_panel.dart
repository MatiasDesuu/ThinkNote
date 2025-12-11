import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../draggable_header.dart';

class ResizablePanel extends StatefulWidget {
  final Widget child;
  final double minWidth;
  final double maxWidth;
  final FocusNode appFocusNode;
  final String title;
  final String preferencesKey;
  final Widget? trailing;
  final bool showLeftSeparator;

  const ResizablePanel({
    super.key,
    required this.child,
    this.minWidth = 200,
    this.maxWidth = 400,
    required this.appFocusNode,
    required this.title,
    required this.preferencesKey,
    this.trailing,
    this.showLeftSeparator = false,
  });

  @override
  ResizablePanelState createState() => ResizablePanelState();
}

class ResizablePanelLeft extends StatefulWidget {
  final Widget child;
  final double minWidth;
  final double maxWidth;
  final FocusNode appFocusNode;
  final String title;
  final String preferencesKey;
  final Widget? trailing;

  const ResizablePanelLeft({
    super.key,
    required this.child,
    this.minWidth = 200,
    this.maxWidth = 400,
    required this.appFocusNode,
    required this.title,
    required this.preferencesKey,
    this.trailing,
  });

  @override
  ResizablePanelLeftState createState() => ResizablePanelLeftState();
}

class ResizablePanelState extends State<ResizablePanel>
    with SingleTickerProviderStateMixin {
  double _width = 250;
  bool _isExpanded = true;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  final FocusNode _panelFocusNode = FocusNode();

  bool get isExpanded => _isExpanded;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(begin: 0, end: _width).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _panelFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedExpanded = prefs.getBool('${widget.preferencesKey}_expanded') ?? true;
    setState(() {
      _width = prefs.getDouble('${widget.preferencesKey}_width') ?? 250;
      _isExpanded = savedExpanded;
      _widthAnimation = Tween<double>(begin: 0, end: _width).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.value = 0;
    }
  }

  Future<void> _saveExpandedState(bool isExpanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.preferencesKey}_expanded', isExpanded);
  }

  Future<void> _saveWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${widget.preferencesKey}_width', width);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isExpanded) return;
    setState(() {
      _width = (_width + details.delta.dx).clamp(
        widget.minWidth,
        widget.maxWidth,
      );
      _widthAnimation = Tween<double>(begin: 0, end: _width).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _saveWidth(_width);
  }

  void togglePanel() {
    final navigatorContext = context;
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _saveExpandedState(_isExpanded);

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void collapsePanel() {
    if (!_isExpanded) return; // Already collapsed

    final navigatorContext = context;
    setState(() {
      _isExpanded = false;
    });
    _saveExpandedState(_isExpanded);
    _animationController.reverse();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void expandPanel() {
    if (_isExpanded) return; // Already expanded

    final navigatorContext = context;
    setState(() {
      _isExpanded = true;
    });
    _saveExpandedState(_isExpanded);
    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final separatorWidth = widget.showLeftSeparator ? 1.0 : 0.0;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final animatedWidth = _widthAnimation.value + (separatorWidth * _animationController.value);
            return ClipRect(
              child: SizedBox(
                width: animatedWidth,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: _width + separatorWidth,
                  maxWidth: _width + separatorWidth,
                  child: child,
                ),
              ),
            );
          },
          child: Row(
            children: [
              if (widget.showLeftSeparator)
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              SizedBox(
                width: _width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Column(
                        children: [
                          if (widget.title.isNotEmpty)
                            Stack(
                              children: [
                                Container(
                                  height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Row(
                                children: [
                                  // Iconos específicos para cada panel
                                  if (widget.title == 'Notebooks') ...[
                                    Icon(
                                      Icons.folder_rounded,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                  ] else if (widget.title == 'Notes') ...[
                                    Icon(
                                      Icons.note_rounded,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.trailing != null) widget.trailing!,
                                ],
                              ),
                            ),
                          ),
                          // MoveWindow en el área del título, excluyendo el botón trailing
                          Positioned(
                            top: 0,
                            left: 0,
                            right:
                                widget.trailing != null
                                    ? 100
                                    : 0, // Excluir área del botón
                            height: 48,
                            child: MoveWindow(),
                          ),
                        ],
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: _onDragEnd,
                    child: Container(width: 8, color: Colors.transparent),
                  ),
                ),
              ),
            ],
          ),
        ),
            ],
          ),
        ),
      ],
    );
  }
}

class ResizablePanelLeftState extends State<ResizablePanelLeft>
    with SingleTickerProviderStateMixin {
  double _width = 250;
  bool _isExpanded = true;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  final FocusNode _panelFocusNode = FocusNode();

  bool get isExpanded => _isExpanded;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(begin: 0, end: _width).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _panelFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedExpanded = prefs.getBool('${widget.preferencesKey}_expanded') ?? true;
    setState(() {
      _width = prefs.getDouble('${widget.preferencesKey}_width') ?? 250;
      _isExpanded = savedExpanded;
      _widthAnimation = Tween<double>(begin: 0, end: _width).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.value = 0;
    }
  }

  Future<void> _saveExpandedState(bool isExpanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.preferencesKey}_expanded', isExpanded);
  }

  Future<void> _saveWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${widget.preferencesKey}_width', width);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isExpanded) return;
    setState(() {
      // Para redimensionar desde la izquierda, restamos el delta
      _width = (_width - details.delta.dx).clamp(
        widget.minWidth,
        widget.maxWidth,
      );
      _widthAnimation = Tween<double>(begin: 0, end: _width).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _saveWidth(_width);
  }

  void togglePanel() {
    final navigatorContext = context;
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _saveExpandedState(_isExpanded);

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void collapsePanel() {
    if (!_isExpanded) return; // Already collapsed

    final navigatorContext = context;
    setState(() {
      _isExpanded = false;
    });
    _saveExpandedState(_isExpanded);
    _animationController.reverse();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  void expandPanel() {
    if (_isExpanded) return; // Already expanded

    final navigatorContext = context;
    setState(() {
      _isExpanded = true;
    });
    _saveExpandedState(_isExpanded);
    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!navigatorContext.mounted) return;
      if (widget.appFocusNode.canRequestFocus) {
        FocusScope.of(navigatorContext).requestFocus(widget.appFocusNode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return ClipRect(
              child: SizedBox(
                width: _widthAnimation.value,
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: _width,
                  maxWidth: _width,
                  child: child,
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    if (widget.title.isNotEmpty)
                      DraggableHeader(
                        title: widget.title,
                        trailing: widget.trailing,
                      )
                    else
                      DraggableArea(height: 40),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: _onDragEnd,
                    child: Container(width: 8, color: Colors.transparent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
