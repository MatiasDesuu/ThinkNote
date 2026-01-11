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
                _buildFormatItem(
                  context: context,
                  label: 'Copy block',
                  syntax: '[text]',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Horizontal Divider',
                  syntax: '* * *',
                  showDivider: false,
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
                  showDivider: false,
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
                  syntax: '1. text',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Bullet list',
                  syntax: '- text',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Checkbox (unchecked)',
                  syntax: '-[ ] text',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Checkbox (checked)',
                  syntax: '-[x] text',
                  showDivider: false,
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
                  label: 'Web links with custom text',
                  syntax: '[Example](http://example.com)',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Note links',
                  syntax: '[[note:Note Title]]',
                ),
                _buildFormatItem(
                  context: context,
                  label: 'Notebooks links',
                  syntax: '[[notebook:Notebook Title]]',
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Templates Section
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_motion_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Templates help you create notes quickly by reusing predefined content and automatically filling in details like dates and times.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'How to Create Templates',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Create a notebook named "#templates" or "#category" (you can also create sub-notebooks for organized groups like #templates_meetings or #category_work).',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '2. Create a notebook starting with "#template_" (e.g., #template_Project) to use the entire notebook structure as a template.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '3. Add notes to these notebooks - they will be copied when the template is applied.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '4. Use template variables like {{date}} or {{notebook}} in titles and content.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'How to Use Templates',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Open the templates panel by clicking the New Note icon in the sidebar and then clicking the "Templates" button (you can also use Ctrl+Shift+T / Cmd+Shift+T).',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '2. Select a template from the list.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '3. Choose the notebook where you want to create the new note.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '4. Click to apply - a new note will be created with the template content.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.layers_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Stack Templates - Create Multiple Notes at Once',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stack templates let you create several related notes in one click.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'How to Create Stack Templates:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1. Create a note template with "#stack" in the title (like "#stack Meeting Notes").',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '2. In the template content, specify which notes to create using {{note1, note2, note3}}.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '3. Make sure notes with those exact titles exist in the same template notebook.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      Text(
                        '4. When applied, it will create all the specified notes in your target notebook.',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colorScheme.primary,
                    ),
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
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Dates & Time',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
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
                  showDivider: false,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Contextual',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
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
                  showDivider: false,
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
    bool showDivider = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
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
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withAlpha(80),
          ),
      ],
    );
  }
}
