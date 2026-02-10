import 'package:flutter/material.dart';
import '../../database/models/notebook_icons.dart';

class IconSelectorScreen extends StatefulWidget {
  final int? currentIconId;
  final Function(int) onIconSelected;

  const IconSelectorScreen({
    super.key,
    this.currentIconId,
    required this.onIconSelected,
  });

  @override
  State<IconSelectorScreen> createState() => _IconSelectorScreenState();
}

class _IconSelectorScreenState extends State<IconSelectorScreen> {
  int? _selectedIconId;

  @override
  void initState() {
    super.initState();
    _selectedIconId = widget.currentIconId;
  }

  @override
  Widget build(BuildContext context) {
    final allIcons = NotebookIconsRepository.icons;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 40.0,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () {
            if (_selectedIconId != null) {
              widget.onIconSelected(_selectedIconId!);
            }
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Select Icon',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _selectedIconId != null
                    ? () {
                      widget.onIconSelected(_selectedIconId!);
                      Navigator.pop(context);
                    }
                    : null,
            icon: Icon(Icons.save_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedIconId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      NotebookIconsRepository.getIconById(
                            _selectedIconId!,
                          )?.icon ??
                          Icons.folder_rounded,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: allIcons.length,
                itemBuilder: (context, index) {
                  final icon = allIcons[index];
                  final isSelected = _selectedIconId == icon.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIconId = icon.id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon.icon,
                        size: 32,
                        color:
                            isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
