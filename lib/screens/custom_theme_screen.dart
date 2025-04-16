import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../utils/color_utils.dart';
import '../models/settings_model.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';
import '../widgets/custom_app_bar.dart';

class CustomThemeScreen extends StatefulWidget {
  const CustomThemeScreen({super.key});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  final LoggerService _logger = LoggerService();
  bool _editingLightTheme = true;
  late CustomThemeModel _lightTheme;
  late CustomThemeModel _darkTheme;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing CustomThemeScreen');

    // Initialize with current themes from ThemeService
    final themeService = Provider.of<ThemeService>(context, listen: false);
    _lightTheme = themeService.settings.lightCustomTheme ?? CustomThemeModel.lightDefaults;
    _darkTheme = themeService.settings.darkCustomTheme ?? CustomThemeModel.darkDefaults;
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building CustomThemeScreen widget');

    // Get the current theme being edited
    final currentTheme = _editingLightTheme ? _lightTheme : _darkTheme;

    return Scaffold(
      appBar: CustomAppBar(title: 'Custom Theme Editor'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme mode toggle
            Card(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Theme Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Light Theme'),
                          selected: _editingLightTheme,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _editingLightTheme = true;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Dark Theme'),
                          selected: !_editingLightTheme,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _editingLightTheme = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Theme preview
            Card(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: currentTheme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // App bar preview
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: currentTheme.appBarBackgroundColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: currentTheme.appBarElevation)],
                            ),
                            child: Row(
                              children: [
                                Text('App Bar', style: TextStyle(color: currentTheme.appBarForegroundColor, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Icon(Icons.more_vert, color: currentTheme.appBarForegroundColor, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card preview
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: currentTheme.cardColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: currentTheme.cardElevation)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Card Title', style: TextStyle(color: currentTheme.textPrimaryColor, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Card content with primary text', style: TextStyle(color: currentTheme.textPrimaryColor)),
                                Text('Secondary text in card', style: TextStyle(color: currentTheme.textSecondaryColor, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Button previews
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Elevated button
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: currentTheme.elevatedButtonBackgroundColor, borderRadius: BorderRadius.circular(4)),
                                child: Text('BUTTON', style: TextStyle(color: currentTheme.elevatedButtonForegroundColor, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              // Text button
                              Text('TEXT BUTTON', style: TextStyle(color: currentTheme.textButtonColor, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Dialog preview
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: currentTheme.dialogBackgroundColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dialog Title', style: TextStyle(color: currentTheme.dialogTitleColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('Dialog content text', style: TextStyle(color: currentTheme.dialogContentColor, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // FAB preview
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: currentTheme.fabBackgroundColor,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(Icons.add, color: currentTheme.fabForegroundColor, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Basic Colors Section
            _buildColorSection('Basic Colors', [
              _buildColorPickerItem('Primary Color', currentTheme.primaryColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(primaryColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(primaryColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Background Color', currentTheme.scaffoldBackgroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(scaffoldBackgroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(scaffoldBackgroundColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Surface Color', currentTheme.surfaceColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(surfaceColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(surfaceColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Error Color', currentTheme.errorColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(errorColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(errorColor: color);
                  }
                });
              }),
            ]),

            // App Bar Section
            _buildColorSection('App Bar', [
              _buildColorPickerItem('App Bar Background', currentTheme.appBarBackgroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(appBarBackgroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(appBarBackgroundColor: color);
                  }
                });
              }),
              _buildColorPickerItem('App Bar Text', currentTheme.appBarForegroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(appBarForegroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(appBarForegroundColor: color);
                  }
                });
              }),
            ]),

            // FAB Section
            _buildColorSection('Floating Action Button', [
              _buildColorPickerItem('FAB Background', currentTheme.fabBackgroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(fabBackgroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(fabBackgroundColor: color);
                  }
                });
              }),
              _buildColorPickerItem('FAB Icon', currentTheme.fabForegroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(fabForegroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(fabForegroundColor: color);
                  }
                });
              }),
            ]),

            // Text Section
            _buildColorSection('Text', [
              _buildColorPickerItem('Primary Text', currentTheme.textPrimaryColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(textPrimaryColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(textPrimaryColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Secondary Text', currentTheme.textSecondaryColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(textSecondaryColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(textSecondaryColor: color);
                  }
                });
              }),
            ]),

            // Card Section
            _buildColorSection('Card', [
              _buildColorPickerItem('Card Color', currentTheme.cardColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(cardColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(cardColor: color);
                  }
                });
              }),
            ]),

            // Dialog Section
            _buildColorSection('Dialog', [
              _buildColorPickerItem('Dialog Background', currentTheme.dialogBackgroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(dialogBackgroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(dialogBackgroundColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Dialog Title', currentTheme.dialogTitleColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(dialogTitleColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(dialogTitleColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Dialog Content', currentTheme.dialogContentColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(dialogContentColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(dialogContentColor: color);
                  }
                });
              }),
            ]),

            // Button Section
            _buildColorSection('Buttons', [
              _buildColorPickerItem('Elevated Button Background', currentTheme.elevatedButtonBackgroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(elevatedButtonBackgroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(elevatedButtonBackgroundColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Elevated Button Text', currentTheme.elevatedButtonForegroundColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(elevatedButtonForegroundColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(elevatedButtonForegroundColor: color);
                  }
                });
              }),
              _buildColorPickerItem('Text Button Color', currentTheme.textButtonColor, (color) {
                setState(() {
                  if (_editingLightTheme) {
                    _lightTheme = _lightTheme.copyWith(textButtonColor: color);
                  } else {
                    _darkTheme = _darkTheme.copyWith(textButtonColor: color);
                  }
                });
              }),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _logger.d('Custom theme creation cancelled');
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  _logger.d('Saving custom theme');
                  final themeService = Provider.of<ThemeService>(context, listen: false);

                  // Update both light and dark themes
                  await themeService.updateCustomLightTheme(_lightTheme);
                  await themeService.updateCustomDarkTheme(_darkTheme);

                  // Switch to custom theme
                  await themeService.updateThemeStyleType(ThemeStyleType.custom);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom theme applied')));
                  }
                },
                child: const Text('Save & Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build a section of color pickers
  Widget _buildColorSection(String title, List<Widget> colorPickers) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 16), ...colorPickers],
        ),
      ),
    );
  }

  // Helper method to build a color picker item with hex input and copy button
  Widget _buildColorPickerItem(String label, Color color, Function(Color) onColorChanged) {
    // Create a text editing controller for the hex input
    final hexController = TextEditingController(text: ColorUtils.colorToHex(color, includeHash: true));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              // Color preview box
              GestureDetector(
                onTap: () {
                  _showColorPickerDialog(color, label, (newColor) {
                    // Update the hex input when color changes
                    hexController.text = ColorUtils.colorToHex(newColor, includeHash: true);
                    onColorChanged(newColor);
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),

              // Hex input field
              Expanded(
                child: TextField(
                  controller: hexController,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    hintText: '#RRGGBB',
                  ),
                  onChanged: (value) {
                    // Only update if it's a valid hex color
                    if (ColorUtils.isValidHex(value)) {
                      final newColor = ColorUtils.hexToColor(value);
                      onColorChanged(newColor);
                    }
                  },
                ),
              ),

              // Copy button
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy hex code',
                onPressed: () {
                  final hexCode = ColorUtils.colorToHex(color, includeHash: true);
                  Clipboard.setData(ClipboardData(text: hexCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $hexCode to clipboard'), duration: const Duration(seconds: 1)));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show color picker dialog with hex input
  void _showColorPickerDialog(Color initialColor, String title, Function(Color) onColorChanged) {
    Color pickerColor = initialColor;
    final hexController = TextEditingController(text: ColorUtils.colorToHex(initialColor, includeHash: true));

    // Get the current theme's surface color
    final surfaceColor = Theme.of(context).colorScheme.surface;

    // Function to update hex input when color changes
    void updateHexInput(Color color) {
      hexController.text = ColorUtils.colorToHex(color, includeHash: true);
    }

    // Function to update color picker when hex changes
    void updateColorFromHex(String hex) {
      if (ColorUtils.isValidHex(hex)) {
        pickerColor = ColorUtils.hexToColor(hex);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: surfaceColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9, // Make dialog wider
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text('Select $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Hex input field
                Row(
                  children: [
                    const Text('Hex: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: TextField(
                        controller: hexController,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          hintText: '#RRGGBB',
                        ),
                        onChanged: (value) {
                          updateColorFromHex(value);
                        },
                        onSubmitted: (value) {
                          if (ColorUtils.isValidHex(value)) {
                            final newColor = ColorUtils.hexToColor(value);
                            pickerColor = newColor;
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy hex code',
                      onPressed: () {
                        final hexCode = hexController.text;
                        Clipboard.setData(ClipboardData(text: hexCode));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Copied $hexCode to clipboard'), duration: const Duration(seconds: 1)));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Color picker
                Flexible(
                  child: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: pickerColor,
                      onColorChanged: (color) {
                        pickerColor = color;
                        updateHexInput(color);
                      },
                      pickerAreaHeightPercent: 0.8,
                      enableAlpha: true,
                      displayThumbColor: true,
                      paletteType: PaletteType.hsv,
                      pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        onColorChanged(pickerColor);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
