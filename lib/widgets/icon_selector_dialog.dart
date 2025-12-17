import 'package:flutter/material.dart';
import '../database/models/notebook_icons.dart';
import 'custom_dialog.dart';

class IconSelectorDialog extends StatefulWidget {
  final int? currentIconId;
  final String? notebookName;

  const IconSelectorDialog({super.key, this.currentIconId, this.notebookName});

  @override
  State<IconSelectorDialog> createState() => _IconSelectorDialogState();
}

class _IconSelectorDialogState extends State<IconSelectorDialog> {
  int? _selectedIconId;

  @override
  void initState() {
    super.initState();
    _selectedIconId = widget.currentIconId;
  }

  @override
  Widget build(BuildContext context) {
    final allIcons = NotebookIconsRepository.icons;

    return CustomDialog(
      title:
          widget.notebookName != null
              ? 'Select Icon for "${widget.notebookName}"'
              : 'Select Notebook Icon',
      icon: Icons.folder_rounded,
      width: 700,
      height: 600,
      bottomBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Cancel',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(0, 44),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, _selectedIconId),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Select',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
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
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.withAlpha(76),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      isSelected
                          ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                          : null,
                ),
                child: Icon(
                  icon.icon,
                  size: 28,
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
