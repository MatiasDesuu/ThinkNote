// help_formats_panel.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';

class HelpFormatsPanel extends StatelessWidget {
  const HelpFormatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        const Text(
          'Text Formatting Guide',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Text Formatting Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_bold_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Text Formatting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Format your text using Markdown syntax',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFormatItem(
                  context: context,
                  label: 'Bold text',
                  syntax: '**text** or __text__',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Italic text',
                  syntax: '*text* or _text_',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Strikethrough',
                  syntax: '~~text~~',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Inline code',
                  syntax: '`text`',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Headings Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.title_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Headings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create headings using # symbols',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFormatItem(
                  context: context,
                  label: 'Heading 1',
                  syntax: '# Main Title',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Heading 2',
                  syntax: '## Section Title',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Heading 3',
                  syntax: '### Subsection',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Heading 4',
                  syntax: '#### Small Heading',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Heading 5',
                  syntax: '##### Tiny Heading',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Lists Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Lists',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create different types of lists',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Numbered list',
                  syntax: '1. item',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Bullet list',
                  syntax: '- item or • item',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Asterisk list',
                  syntax: '* item',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Checkbox (unchecked)',
                  syntax: '- [ ] task',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Checkbox (checked)',
                  syntax: '- [x] task',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Links Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Links',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create clickable links and references',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFormatItem(
                  context: context,
                  label: 'Web links',
                  syntax: 'http://example.com',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Note links',
                  syntax: '[[Note Title]]',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatItem({
    required BuildContext context,
    required String label,
    required String syntax,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: colorScheme.outline.withAlpha(51),
                    width: 1,
                  ),
                ),
                child: Text(
                  syntax,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
