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

        const SizedBox(height: 16),

        // Template Variables Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Template Variables',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Use these variables in your templates to auto-fill information',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dates & Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Current Date',
                  syntax: '{{date}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'ISO Date',
                  syntax: '{{dateiso}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Long Date',
                  syntax: '{{datelong}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Current Time',
                  syntax: '{{time}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Time (12h)',
                  syntax: '{{time12}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Day of Month',
                  syntax: '{{day}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Month Number',
                  syntax: '{{month}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Full Month Name',
                  syntax: '{{monthname}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Short Month Name',
                  syntax: '{{monthnameshort}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Year',
                  syntax: '{{year}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Weekday',
                  syntax: '{{weekday}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Short Weekday',
                  syntax: '{{weekdayshort}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Week of Year',
                  syntax: '{{week}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Day of Year',
                  syntax: '{{dayofyear}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Week Start',
                  syntax: '{{weekstart}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Week End',
                  syntax: '{{weekend}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Tomorrow',
                  syntax: '{{tomorrow}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Yesterday',
                  syntax: '{{yesterday}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Created Timestamp',
                  syntax: '{{created}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Hour (24h)',
                  syntax: '{{hour}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Minute',
                  syntax: '{{minute}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'AM/PM',
                  syntax: '{{ampm}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Unix Timestamp',
                  syntax: '{{timestamp}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Timezone',
                  syntax: '{{timezone}}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contextual',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Notebook Name',
                  syntax: '{{notebook}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Greeting',
                  syntax: '{{greeting}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Platform',
                  syntax: '{{platform}}',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Sequential Number (titles only)',
                  syntax: '{{number}}',
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
