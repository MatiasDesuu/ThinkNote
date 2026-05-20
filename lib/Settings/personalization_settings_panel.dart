import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_dialog.dart';
import '../theme_handler.dart' as theme_handler;
import '../custom_font_manager.dart';

const List<Color> materialYouColors = [
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF5E35B1),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF039BE5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFFDD835),
  Color(0xFFFFB300),
  Color(0xFFFB8C00),
  Color(0xFFD84315),
  Color(0xFF795548),
  Color(0xFF757575),
  Color(0xFF546E7A),

  Color(0xFFFFABAB),
  Color(0xFFF48FB1),
  Color(0xFFCE93D8),
  Color(0xFFB39DDB),
  Color(0xFF9FA8DA),
  Color(0xFF90CAF9),
  Color(0xFF81D4FA),
  Color(0xFF80DEEA),
  Color(0xFF80CBC4),
  Color(0xFFA5D6A7),
  Color(0xFFC5E1A5),
  Color(0xFFFFF59D),
  Color(0xFFFFE082),
  Color(0xFFFFCC80),
  Color(0xFFFFAB91),
  Color(0xFFBCAAA4),
  Color(0xFFBDBDBD),
  Color(0xFF90A4AE),
];

List<String> get appTextFonts => [
  ...CustomFontManager.customFonts,
  'Roboto',
  'Inter',
  'Montserrat',
  'Poppins',
  'Ubuntu',
  'Open Sans',
  'Merriweather',
  'Lora',
  'Playfair Display',
  'Fira Code',
  'JetBrains Mono',
  'Source Code Pro',
  'IBM Plex Mono',
  'Roboto Mono',
  'Dancing Script',
  'Menlo',
  'Monaco',
  'SF Mono',
  'SF Pro Display',
  'SF Pro Text',
  'Helvetica Neue',
  'Helvetica',
  'Avenir',
  'Avenir Next',
  'Palatino',
  'Optima',
  'American Typewriter',
  'Baskerville',
  'Gill Sans',
  'Copperplate',
  'Futura',
  'Noteworthy',
  'Didot',
  'Courier New',
];

TextStyle appFontStyle(
  String fontFamily, {
  double? fontSize,
  Color? color,
  FontWeight? fontWeight,
}) {
  const googleFonts = {
    'Roboto',
    'Inter',
    'Montserrat',
    'Poppins',
    'Ubuntu',
    'Open Sans',
    'Merriweather',
    'Lora',
    'Playfair Display',
    'Fira Code',
    'JetBrains Mono',
    'Source Code Pro',
    'IBM Plex Mono',
    'Roboto Mono',
    'Dancing Script',
  };

  if (googleFonts.contains(fontFamily)) {
    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    }
  }

  return TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
  );
}

class PersonalizationSettingsPanel extends StatefulWidget {
  final VoidCallback? onThemeUpdated;

  const PersonalizationSettingsPanel({super.key, this.onThemeUpdated});

  @override
  PersonalizationSettingsPanelState createState() =>
      PersonalizationSettingsPanelState();
}

class PersonalizationSettingsPanelState
    extends State<PersonalizationSettingsPanel> {
  Color _currentColor = const Color(0xFFC6A0F6);
  bool _isDarkTheme = true;
  bool _isColorMode = true;
  bool _isMonochromeEnabled = false;
  bool _isCatppuccinEnabled = false;
  bool _isEInkEnabled = false;
  bool _isAmoledEnabled = false;
  String _catppuccinFlavor = 'mocha';
  String _catppuccinAccent = 'mauve';
  bool _isLoading = true;
  String _appFontFamily = 'Roboto';

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final color = await theme_handler.ThemeManager.getThemeColor();
    final brightness = await theme_handler.ThemeManager.getThemeBrightness();
    final colorMode = await theme_handler.ThemeManager.getColorModeEnabled();
    final monochromeEnabled =
        await theme_handler.ThemeManager.getMonochromeEnabled();
    final catppuccinEnabled =
        await theme_handler.ThemeManager.getCatppuccinEnabled();
    final catppuccinFlavor =
      await theme_handler.ThemeManager.getCatppuccinFlavor();
    final appFontFamily = await theme_handler.ThemeManager.getAppFontFamily();
    final catppuccinAccent =
        await theme_handler.ThemeManager.getCatppuccinAccent();
    final einkEnabled = await theme_handler.ThemeManager.getEInkEnabled();
    final amoledEnabled = await theme_handler.ThemeManager.getAmoledEnabled();

    setState(() {
      _currentColor = color;
      _isDarkTheme = brightness == Brightness.dark;
      _isColorMode = colorMode;
      _isMonochromeEnabled = monochromeEnabled;
      _isCatppuccinEnabled = catppuccinEnabled;
      _isEInkEnabled = einkEnabled;
      _isAmoledEnabled = amoledEnabled;
      _appFontFamily = appFontFamily;
      _catppuccinFlavor = catppuccinFlavor;
      _catppuccinAccent = catppuccinAccent;
      _isLoading = false;
    });
  }

  void _updateColor(Color color) {
    setState(() => _currentColor = color);
    _saveSettings();
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkTheme = !value;
      if (value) {
        _isAmoledEnabled = false;
      }
    });
    _saveSettings();
  }

  void _toggleAmoled(bool value) {
    setState(() {
      _isAmoledEnabled = value;
    });
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  void _toggleColorMode(bool value) {
    setState(() {
      _isColorMode = value;

      if (value) {
        _isMonochromeEnabled = false;
        _isCatppuccinEnabled = false;
        _isEInkEnabled = false;
      }
    });
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  void _toggleMonochrome(bool value) {
    setState(() {
      _isMonochromeEnabled = value;

      if (value) {
        _isColorMode = false;
        _isCatppuccinEnabled = false;
        _isEInkEnabled = false;
      }
    });
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  void _toggleCatppuccin(bool value) {
    setState(() {
      _isCatppuccinEnabled = value;

      if (value) {
        _isColorMode = false;
        _isMonochromeEnabled = false;
        _isEInkEnabled = false;
      }
    });
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  void _toggleEInk(bool value) {
    setState(() {
      _isEInkEnabled = value;

      if (value) {
        _isColorMode = false;
        _isMonochromeEnabled = false;
        _isCatppuccinEnabled = false;
        _isAmoledEnabled = false;
      }
    });
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  void _updateCatppuccinFlavor(String flavor) {
    setState(() => _catppuccinFlavor = flavor);
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  void _updateCatppuccinAccent(String accent) {
    setState(() => _catppuccinAccent = accent);
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  Future<void> _saveSettings() async {
    await theme_handler.ThemeManager.saveTheme(
      _currentColor,
      _isDarkTheme ? Brightness.dark : Brightness.light,
      colorModeEnabled: _isColorMode,
      monochromeEnabled: _isMonochromeEnabled,
      catppuccinEnabled: _isCatppuccinEnabled,
      catppuccinFlavor: _catppuccinFlavor,
      catppuccinAccent: _catppuccinAccent,
      einkEnabled: _isEInkEnabled,
      appFontFamily: _appFontFamily,
      amoledEnabled: _isAmoledEnabled,
    );
    widget.onThemeUpdated?.call();
    await _loadCurrentSettings();
  }

  void _updateAppFontFamily(String fontFamily) {
    setState(() => _appFontFamily = fontFamily);
    _saveSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onThemeUpdated?.call();
    });
  }

  Future<void> _openCustomColorPicker() async {
    Color tempColor = _currentColor;
    final hexController = TextEditingController();

    void updateHex() {
      hexController.text =
          tempColor.toARGB32().toRadixString(16).substring(2).toUpperCase();
    }

    updateHex();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return CustomDialog(
            title: 'Custom color',
            icon: Icons.color_lens_rounded,
            width: 520,
            height: 440,
            bottomBar: Container(
              height: 56,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _updateColor(tempColor);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size(0, 44),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HueRingPicker(
                        pickerColor: tempColor,
                        onColorChanged: (color) {
                          setState(() {
                            tempColor = color;
                            updateHex();
                          });
                        },
                        enableAlpha: false,
                        displayThumbColor: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hexController,
                        decoration: const InputDecoration(
                          labelText: 'HEX',
                          prefixText: '#',
                        ),
                        onSubmitted: (value) {
                          try {
                            final color = Color(int.parse('FF$value', radix: 16));
                            setState(() {
                              tempColor = color;
                              updateHex();
                            });
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } finally {
      hexController.dispose();
    }
  }

  Future<void> _openAppFontSelector() async {
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return CustomDialog(
                title: 'App Text Font',
                icon: Icons.text_fields_rounded,
                width: 500,
                height: 400,
                headerActions: [
                  TextButton.icon(
                    onPressed: () async {
                      final newFont = await CustomFontManager.pickAndLoadFont();
                      if (newFont != null) {
                        setDialogState(() {});
                      }
                    },
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload Font'),
                  ),
                ],
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: appTextFonts.length,
                  itemBuilder: (context, index) {
                    final font = appTextFonts[index];
                    final isSelected = font == _appFontFamily;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withAlpha(127),
                          width: 0.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          mouseCursor: SystemMouseCursors.click,
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _updateAppFontFamily(font);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color:
                                      isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    font,
                                    style: appFontStyle(
                                      font,
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.normal,
      fontSize: 15,
    );

    return ListView(
      children: [
        const Text(
          'Theme Customization',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        if (!_isEInkEnabled) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.coffee_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Catppuccin Theme',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use Catppuccin color palette for a cohesive and beautiful theme experience',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enable Catppuccin Theme', style: textStyle),
                            const SizedBox(height: 4),
                            Text(
                              'When enabled, disables other theme options and uses Catppuccin colors',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isCatppuccinEnabled,
                        onChanged: _toggleCatppuccin,
                      ),
                    ],
                  ),

                  if (_isCatppuccinEnabled) ...[
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Text(
                          'Flavor',
                          style: textStyle?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: _buildFlavorSelector(),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Text(
                          'Accent Color',
                          style: textStyle?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: _buildAccentSelector(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],

        if (!_isCatppuccinEnabled && !_isEInkEnabled) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Accent Color',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the color you want to use as accent in the application',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        'Strong Colors',
                        style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: _buildColorGrid(0, 17),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        'Soft Colors',
                        style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: _buildColorGrid(18, 35),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Text(
                        'Custom Color',
                        style: textStyle?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '#${_currentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openCustomColorPicker,
                          icon: const Icon(Icons.colorize_rounded),
                          label: const Text(
                            'Pick',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            minimumSize: const Size(0, 50),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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

          const SizedBox(height: 16),
        ],

        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'App Text Font',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Change the default font used across the app UI without affecting the editor',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _appFontFamily,
                          style: appFontStyle(
                            _appFontFamily,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _openAppFontSelector,
                        icon: const Icon(Icons.text_fields_rounded),
                        label: const Text(
                          'Pick',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size(0, 50),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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

        const SizedBox(height: 16),

        if (!_isCatppuccinEnabled) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Theme Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure theme appearance and behavior',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: Text('Light theme', style: textStyle)),
                      Switch(
                        value: !_isDarkTheme,
                        onChanged: (value) => _toggleTheme(value),
                      ),
                    ],
                  ),

                  if (_isDarkTheme && !_isEInkEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AMOLED Mode', style: textStyle),
                              const SizedBox(height: 4),
                              Text(
                                'Pitch black backgrounds for dark theme',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAmoledEnabled,
                          onChanged: _toggleAmoled,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('E-Ink Mode', style: textStyle),
                            const SizedBox(height: 4),
                            Text(
                              'Pure black and white theme for e-ink displays. No colors, gray tones, or transparencies. When Light theme is on: white background with black elements. When Light theme is off: black background with white elements.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(value: _isEInkEnabled, onChanged: _toggleEInk),
                    ],
                  ),

                  if (!_isEInkEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Color Mode', style: textStyle),
                              const SizedBox(height: 4),
                              Text(
                                'Applies dynamic colors to the entire interface. If disabled, only basic elements are colored.',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isColorMode,
                          onChanged: _toggleColorMode,
                        ),
                      ],
                    ),

                    if (!_isColorMode) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Monochrome Mode', style: textStyle),
                                const SizedBox(height: 4),
                                Text(
                                  'Uses white (dark theme) or black (light theme) accent colors instead of the selected color, keeping backgrounds the same.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isMonochromeEnabled,
                            onChanged: _toggleMonochrome,
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],

        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.preview_rounded, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'See how your theme will look with current settings',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _isEInkEnabled
                    ? _buildEInkPreviewSection()
                    : _isCatppuccinEnabled
                    ? _buildCatppuccinPreviewSection()
                    : Row(
                      children: [
                        Expanded(
                          child: _buildThemeSection(
                            'Light',
                            ColorScheme.fromSeed(
                              seedColor: _currentColor,
                              brightness: Brightness.light,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildThemeSection(
                            'Dark',
                            _isAmoledEnabled
                                ? theme_handler.ThemeManager.applyAmoledSurfaces(
                                    ColorScheme.fromSeed(
                                      seedColor: _currentColor,
                                      brightness: Brightness.dark,
                                    ),
                                  )
                                : ColorScheme.fromSeed(
                                    seedColor: _currentColor,
                                    brightness: Brightness.dark,
                                  ),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlavorSelector() {
    final flavors = ['latte', 'frappe', 'macchiato', 'mocha'];
    final flavorNames = {
      'latte': 'Latte (Light)',
      'frappe': 'Frappé (Medium Light)',
      'macchiato': 'Macchiato (Medium Dark)',
      'mocha': 'Mocha (Dark)',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          flavors.map((flavor) {
            final isSelected = _catppuccinFlavor == flavor;
            return GestureDetector(
              onTap: () => _updateCatppuccinFlavor(flavor),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Text(
                  flavorNames[flavor]!,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildAccentSelector() {
    final colors =
        theme_handler.ThemeManager.catppuccinColors[_catppuccinFlavor]!;
    final accentNames = {
      'rosewater': 'Rosewater',
      'flamingo': 'Flamingo',
      'pink': 'Pink',
      'mauve': 'Mauve',
      'red': 'Red',
      'maroon': 'Maroon',
      'peach': 'Peach',
      'yellow': 'Yellow',
      'green': 'Green',
      'teal': 'Teal',
      'sky': 'Sky',
      'sapphire': 'Sapphire',
      'blue': 'Blue',
      'lavender': 'Lavender',
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          colors.entries.map((entry) {
            final color = entry.value;
            final isSelected = _catppuccinAccent == entry.key;
            return GestureDetector(
              onTap: () => _updateCatppuccinAccent(entry.key),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : color.computeLuminance() > 0.8
                                ? Colors.grey.withAlpha(127)
                                : Colors.transparent,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child:
                        isSelected
                            ? Icon(
                              Icons.check_rounded,
                              color:
                                  color.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                              size: 20,
                            )
                            : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accentNames[entry.key]!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildCatppuccinPreviewSection() {
    final colors =
        theme_handler.ThemeManager.catppuccinColors[_catppuccinFlavor]!;
    final baseColors =
        theme_handler.ThemeManager.catppuccinBaseColors[_catppuccinFlavor]!;
    final accentColor = colors[_catppuccinAccent]!;

    final flavorNames = {
      'latte': 'Latte',
      'frappe': 'Frappé',
      'macchiato': 'Macchiato',
      'mocha': 'Mocha',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColors['base']!,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.coffee_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '${flavorNames[_catppuccinFlavor]} - ${_catppuccinAccent.toUpperCase()}',
                style: TextStyle(
                  color: baseColors['text']!,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCatppuccinColorRow('Accent', accentColor, baseColors),
          _buildCatppuccinColorRow(
            'Background',
            baseColors['base']!,
            baseColors,
          ),
          _buildCatppuccinColorRow(
            'Surface',
            baseColors['surface0']!,
            baseColors,
          ),
          _buildCatppuccinColorRow('Text', baseColors['text']!, baseColors),
        ],
      ),
    );
  }

  Widget _buildCatppuccinColorRow(
    String label,
    Color color,
    Map<String, Color> baseColors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: baseColors['overlay0']!, width: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: baseColors['text']!,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: baseColors['subtext0']!,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorGrid(int startIndex, int endIndex) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      children:
          materialYouColors
              .sublist(startIndex, endIndex + 1)
              .map(
                (color) => GestureDetector(
                  onTap: () => _updateColor(color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            _currentColor.toARGB32() == color.toARGB32()
                                ? Theme.of(context).colorScheme.primary
                                : color.computeLuminance() > 0.8
                                ? Colors.grey.withAlpha(127)
                                : Colors.transparent,
                        width:
                            _currentColor.toARGB32() == color.toARGB32()
                                ? 3
                                : 1,
                      ),
                    ),
                    child:
                        _currentColor.toARGB32() == color.toARGB32()
                            ? Icon(
                              Icons.check_rounded,
                              color:
                                  color.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                              size: 20,
                            )
                            : null,
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildThemeSection(String title, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _buildColorRow('Primary', scheme.primary, scheme),
          _buildColorRow('Secondary', scheme.secondary, scheme),
          _buildColorRow('Background', scheme.surface, scheme),
          _buildColorRow('Error', scheme.error, scheme),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, Color color, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border:
                  color.computeLuminance() > 0.8
                      ? Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 0.5,
                      )
                      : Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 0.5,
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEInkPreviewSection() {
    final backgroundColor =
        !_isDarkTheme ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final foregroundColor =
        !_isDarkTheme ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: foregroundColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEInkColorRow(
                'Background',
                backgroundColor,
                foregroundColor,
              ),
              _buildEInkColorRow(
                'Foreground',
                foregroundColor,
                foregroundColor,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: foregroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sample Button',
                  style: TextStyle(
                    color: backgroundColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEInkColorRow(String label, Color color, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: textColor, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
