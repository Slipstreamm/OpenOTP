import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openotp/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';
import '../models/otp_entry.dart';
import '../models/settings_model.dart';
import '../services/otp_service.dart';
import '../services/secure_storage_service.dart';
import '../services/logger_service.dart';
import '../services/qr_scanner_service.dart';
import '../services/icon_service.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../utils/route_generator.dart';

// Enum for the FAB menu options
enum FabOption { scanQr, scanQrFromImage, manualEntry }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  final OtpService _otpService = OtpService();
  final LoggerService _logger = LoggerService();
  final QrScannerService _qrScannerService = QrScannerService();
  final IconService _iconService = IconService();
  final AuthService _authService = AuthService();
  List<OtpEntry> _otpEntries = [];
  Timer? _timer;
  int _secondsRemaining = 30;
  bool _isEditMode = false;

  // Cache for icon widgets to avoid rebuilding them on every timer tick
  final Map<String, Widget> _iconCache = {};

  // Cache for TOTP codes to avoid regenerating them on every timer tick
  final Map<String, String> _totpCache = {};

  // Selected OTP entry for Authy-style view
  String? _selectedOtpId;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing HomeScreen');
    _checkAndCleanupInvalidEntries();
    _startTimer();
  }

  // Check for and remove any invalid OTP entries
  Future<void> _checkAndCleanupInvalidEntries() async {
    _logger.d('Checking for invalid OTP entries');
    try {
      // Run the cleanup
      final removedCount = await _storageService.cleanupInvalidEntries();

      // Show a notification if any entries were removed
      if (removedCount > 0 && mounted) {
        // Delay the snackbar to ensure the UI is built
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $removedCount invalid OTP ${removedCount == 1 ? 'entry' : 'entries'}')));
          }
        });
      }

      // Load the entries after cleanup
      await _loadOtpEntries();
    } catch (e, stackTrace) {
      _logger.e('Error checking for invalid OTP entries', e, stackTrace);
      // Still try to load entries even if cleanup failed
      await _loadOtpEntries();
    }
  }

  // Select the first OTP entry when entries are loaded
  void _selectFirstOtpIfNeeded() {
    if (_otpEntries.isNotEmpty && _selectedOtpId == null) {
      setState(() {
        _selectedOtpId = _otpEntries.first.id;
      });
    }
  }

  @override
  void dispose() {
    _logger.i('Disposing HomeScreen');
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _logger.d('Starting OTP refresh timer');

    // Generate initial TOTP codes for all entries
    _generateAllTotpCodes();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpEntries.isNotEmpty) {
        // Use the OTP service to get the remaining seconds
        final entry = _otpEntries.first;
        final secondsRemaining = _otpService.getRemainingSeconds(entry);

        setState(() {
          _secondsRemaining = secondsRemaining;
        });

        // Refresh codes when timer reaches 0
        if (secondsRemaining == entry.period) {
          _logger.d('Timer reached 0, refreshing OTP codes');
          // Regenerate all TOTP codes
          _generateAllTotpCodes();
          setState(() {}); // Trigger rebuild to update UI
        }
      }
    });
  }

  // Generate TOTP codes for all entries and store in cache
  void _generateAllTotpCodes() {
    _logger.d('Generating TOTP codes for all entries');
    for (final entry in _otpEntries) {
      final code = _otpService.generateTotp(entry);
      _totpCache[entry.id] = code;

      // Log appropriate message based on code generation result
      if (code == 'ERROR') {
        _logger.w('Failed to generate TOTP code for ${entry.name} - invalid secret key');
      } else {
        _logger.d('Generated TOTP code for ${entry.name}: $code');
      }
    }
  }

  Future<void> _loadOtpEntries() async {
    _logger.d('Loading OTP entries');
    try {
      final entries = await _storageService.getOtpEntries();
      setState(() {
        _otpEntries = entries;
        // Clear the caches when entries are reloaded
        _iconCache.clear();
        _totpCache.clear();
      });
      _logger.i('Loaded ${entries.length} OTP entries');

      // Generate new TOTP codes for the loaded entries
      if (entries.isNotEmpty) {
        _generateAllTotpCodes();
        _selectFirstOtpIfNeeded();
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading OTP entries', e, stackTrace);
    }
  }

  Future<void> _addOtpEntry() async {
    _logger.d('Navigating to add OTP entry screen for manual entry');
    try {
      if (!mounted) return;

      final result = await Navigator.pushNamed<bool>(context, RouteGenerator.addOtp, arguments: {'showQrOptions': false});

      if (result == true) {
        _logger.i('New OTP entry added, reloading entries');
        await _loadOtpEntries();
      } else {
        _logger.d('Add OTP entry cancelled or failed');
      }
    } catch (e, stackTrace) {
      _logger.e('Error navigating to add OTP entry screen', e, stackTrace);
    }
  }

  Future<void> _scanQrCode() async {
    _logger.d('Starting QR code scanning');
    try {
      if (!mounted) return;

      if (_qrScannerService.isCameraQrScanningSupported()) {
        // Navigate to the AddOtpScreen with QR scanning enabled
        final result = await Navigator.pushNamed<bool>(context, RouteGenerator.addOtp, arguments: {'initiallyShowQrScanner': true});

        if (result == true) {
          _logger.i('New OTP entry added from QR scan, reloading entries');
          await _loadOtpEntries();
        } else {
          _logger.d('QR scan cancelled or failed');
        }
      } else {
        // Show message for unsupported platforms
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_qrScannerService.getUnsupportedCameraMessage())));

        // Offer to scan from image instead
        _scanQrFromImage();
      }
    } catch (e, stackTrace) {
      _logger.e('Error during QR code scanning', e, stackTrace);
    }
  }

  Future<void> _scanQrFromImage() async {
    _logger.d('Starting QR scan from image');
    try {
      if (!mounted) return;

      final qrCode = await _qrScannerService.pickAndDecodeQrFromImage();

      if (qrCode != null) {
        // Navigate to AddOtpScreen with the scanned QR code
        if (!mounted) return;
        final result = await Navigator.pushNamed<bool>(context, RouteGenerator.addOtp, arguments: {'initialQrCode': qrCode});

        if (result == true) {
          _logger.i('New OTP entry added from image QR scan, reloading entries');
          await _loadOtpEntries();
        } else {
          _logger.d('Image QR scan processing cancelled or failed');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in the selected image')));
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error scanning QR from image', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning QR code: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteOtpEntry(String id) async {
    _logger.d('Attempting to delete OTP entry with ID: $id');
    try {
      // Find the entry to get its name for confirmation
      final entry = _otpEntries.firstWhere((entry) => entry.id == id);
      final entryName = entry.issuer.isNotEmpty ? '${entry.issuer} (${entry.name})' : entry.name;

      // Show confirmation dialog
      final confirmed = await _showDeleteConfirmationDialog(entryName);

      if (confirmed) {
        _logger.i('Deletion confirmed for OTP entry: $entryName');

        // Remove the entry from caches
        _iconCache.remove(id);
        _totpCache.remove(id);

        await _storageService.deleteOtpEntry(id);
        _logger.i('OTP entry deleted, reloading entries');
        await _loadOtpEntries();
      } else {
        _logger.d('Deletion cancelled for OTP entry: $entryName');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting OTP entry with ID: $id', e, stackTrace);
    }
  }

  // Show a confirmation dialog for deletion
  Future<bool> _showDeleteConfirmationDialog(String entryName) async {
    // Get the current settings from ThemeService
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final useSimpleConfirmation = themeService.settings.simpleDeleteConfirmation;

    if (useSimpleConfirmation) {
      // Simple confirmation with checkbox
      return _showSimpleDeleteConfirmationDialog(entryName);
    } else {
      // Advanced confirmation requiring typing the name
      return _showAdvancedDeleteConfirmationDialog(entryName);
    }
  }

  // Show a simple confirmation dialog with just a checkbox
  Future<bool> _showSimpleDeleteConfirmationDialog(String entryName) async {
    bool isConfirmed = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to delete "$entryName"?'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isConfirmed,
                        onChanged: (value) {
                          setState(() {
                            isConfirmed = value ?? false;
                          });
                        },
                      ),
                      const Text('Yes, I want to delete this entry'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red, disabledForegroundColor: Colors.grey),
                  onPressed:
                      isConfirmed
                          ? () {
                            Navigator.of(context).pop(true);
                          }
                          : null,
                  child: const Text('DELETE'),
                ),
              ],
            );
          },
        );
      },
    );

    // Return false if the dialog was dismissed
    return result ?? false;
  }

  // Show an advanced confirmation dialog that requires typing the entry name
  Future<bool> _showAdvancedDeleteConfirmationDialog(String entryName) async {
    final TextEditingController textController = TextEditingController();
    bool isNameMatch = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To confirm deletion, please type "Delete $entryName"'),
                  Text('You can simplify the confirmation in settings > security', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Type "Delete $entryName"'),
                    onChanged: (value) {
                      setState(() {
                        isNameMatch = value == 'Delete $entryName';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red, disabledForegroundColor: Colors.grey),
                  onPressed:
                      isNameMatch
                          ? () {
                            Navigator.of(context).pop(true);
                          }
                          : null,
                  child: const Text('DELETE'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose the controller
    textController.dispose();

    // Return false if the dialog was dismissed
    return result ?? false;
  }

  // Lock the app manually
  Future<void> _lockApp() async {
    _logger.d('Manually locking the app');
    try {
      // Lock the app using the auth service
      await _authService.lockApp();

      // Reload the screen to trigger authentication
      if (mounted) {
        Navigator.pushReplacementNamed(context, RouteGenerator.home);
      }
    } catch (e, stackTrace) {
      _logger.e('Error locking app', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to lock app')));
      }
    }
  }

  // Navigate to settings screen
  void _openSettings() async {
    _logger.d('Navigating to settings screen');
    try {
      await Navigator.pushNamed(context, RouteGenerator.settings);
      _logger.i('Returned from settings screen');
    } catch (e, stackTrace) {
      _logger.e('Error navigating to settings screen', e, stackTrace);
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    _logger.d('Toggling edit mode: ${!_isEditMode}');
    setState(() {
      _isEditMode = !_isEditMode;
      // Clear icon cache when toggling edit mode to ensure proper rebuilding
      if (!_isEditMode) {
        _iconCache.clear();
      }
    });
  }

  // Reorder OTP entries
  void _reorderEntries(int oldIndex, int newIndex) {
    _logger.d('Reordering OTP entry from $oldIndex to $newIndex');
    setState(() {
      if (newIndex > oldIndex) {
        // When moving down, the destination index needs to be adjusted
        newIndex -= 1;
      }
      final item = _otpEntries.removeAt(oldIndex);
      _otpEntries.insert(newIndex, item);
    });
    // Save the new order
    _saveEntryOrder();
  }

  // Save the current order of OTP entries
  Future<void> _saveEntryOrder() async {
    _logger.d('Saving new OTP entry order');
    try {
      await _storageService.saveOtpEntries(_otpEntries);
      _logger.i('Successfully saved new OTP entry order');
    } catch (e, stackTrace) {
      _logger.e('Error saving OTP entry order', e, stackTrace);
    }
  }

  // Navigate to edit screen for an OTP entry
  Future<void> _editOtpEntry(OtpEntry entry) async {
    _logger.d('Navigating to edit OTP entry: ${entry.name}');
    try {
      // Create a screen to edit the entry
      // For now, we'll just navigate to the add screen and let the user re-enter the data
      // In a future enhancement, we could create a proper edit screen that pre-fills the data
      if (!mounted) return;

      final result = await Navigator.pushNamed<bool>(context, RouteGenerator.addOtp, arguments: {'showQrOptions': true});

      if (result == true) {
        _logger.i('OTP entry edited, reloading entries');
        await _loadOtpEntries();
      } else {
        _logger.d('Edit OTP entry cancelled or failed');
      }
    } catch (e, stackTrace) {
      _logger.e('Error navigating to edit OTP entry', e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current view type from settings
    final themeService = Provider.of<ThemeService>(context);
    final homeViewType = themeService.settings.homeViewType;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'OpenOTP',
        actions: [
          // Lock button
          IconButton(icon: const Icon(Icons.lock), onPressed: _lockApp, tooltip: 'Lock App'),
          // View toggle button
          IconButton(icon: _getViewTypeIcon(homeViewType), onPressed: () => _toggleViewType(themeService), tooltip: _getViewTypeTooltip(homeViewType)),
          // Edit button
          IconButton(icon: Icon(_isEditMode ? Icons.done : Icons.edit), onPressed: _toggleEditMode, tooltip: _isEditMode ? 'Done' : 'Edit'),
          // Settings button
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings, tooltip: 'Settings'),
        ],
      ),
      body:
          _otpEntries.isEmpty
              ? const Center(
                child: Text(
                  'No OTP entries yet. Add one to get started!\nYou should check out the settings page before adding entries.',
                  textAlign: TextAlign.center,
                ),
              )
              : _isEditMode
              // ReorderableListView for edit mode
              ? ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _otpEntries.length,
                onReorder: _reorderEntries,
                itemBuilder: (context, index) {
                  final entry = _otpEntries[index];
                  final code = _totpCache[entry.id] ?? _otpService.generateTotp(entry);

                  return Card(
                    color: Theme.of(context).colorScheme.surface,
                    key: Key(entry.id),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Provider icon if available
                                _buildProviderIcon(entry),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.issuer.isNotEmpty ? '${entry.issuer}\n(${entry.name})' : entry.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete button - now outside of the drag area
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => _deleteOtpEntry(entry.id),
                                    child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.delete, color: Colors.red, size: 24)),
                                  ),
                                ),
                                // Visual indicator for drag handle
                                const SizedBox(width: 8),
                                const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0), textAlign: TextAlign.left),
                            const SizedBox(height: 8),
                            Text(
                              'Refreshes in $_secondsRemaining seconds',
                              style: TextStyle(
                                color:
                                    _secondsRemaining < 5
                                        ? Colors
                                            .red // Keep red for warning
                                        : Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                        : const Color(0xFF4F4F4F), // Light mode Text Secondary
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
              // Choose between different view types based on settings
              : homeViewType == HomeViewType.authyStyle
              ? _buildAuthyStyleView()
              : homeViewType == HomeViewType.grid
              ? _buildGridView()
              : ListView.builder(
                itemCount: _otpEntries.length,
                itemBuilder: (context, index) {
                  final entry = _otpEntries[index];
                  // Use cached TOTP code instead of generating on every build
                  final code = _totpCache[entry.id] ?? _otpService.generateTotp(entry);

                  return Card(
                    color: Theme.of(context).colorScheme.surface,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Provider icon if available
                              _buildProviderIcon(entry),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.issuer.isNotEmpty ? '${entry.issuer}\n(${entry.name})' : entry.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      overflow: TextOverflow.visible,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircularProgressIndicator(value: _secondsRemaining / entry.period, strokeWidth: 5),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              code == 'ERROR'
                                  ? Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.red),
                                      const SizedBox(width: 8),
                                      const Text('Invalid Key', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.red),
                                        onPressed: () => _editOtpEntry(entry),
                                        tooltip: 'Edit entry to fix key',
                                      ),
                                    ],
                                  )
                                  : Row(
                                    children: [
                                      Text(
                                        code,
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0),
                                        textAlign: TextAlign.left,
                                      ),
                                      IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyCodeToClipboard(code), tooltip: 'Copy code'),
                                    ],
                                  ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Refreshes in $_secondsRemaining seconds',
                            style: TextStyle(
                              color:
                                  _secondsRemaining < 5
                                      ? Colors
                                          .red // Keep red for warning
                                      : Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                      : const Color(0xFF4F4F4F), // Light mode Text Secondary
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showFabMenu(context);
        },
        tooltip: 'Add OTP Entry',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Build provider icon widget for an OTP entry
  Widget _buildProviderIcon(OtpEntry entry) {
    // Check if we already have this icon in the cache
    if (_iconCache.containsKey(entry.id)) {
      return _iconCache[entry.id]!;
    }

    _logger.d('Building provider icon for ${entry.name} (not cached)');

    // Get icon widget from the icon service (it will handle fallbacks internally)
    final iconWidget = _iconService.getIconWidget(
      entry.issuer,
      entry.name,
      size: 40.0,
      color:
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFFFFF) // White for dark mode
              : null, // Original colors for light mode
    );

    // Create the container with appropriate styling
    final containerWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A) // Slightly lighter than dark background
                : const Color(0xFFEEEEEE), // Light gray for light mode
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: iconWidget, // IconService now always returns a widget
    );

    // Store in cache for future use
    _iconCache[entry.id] = containerWidget;

    return containerWidget;
  }

  // Get the appropriate icon for the current view type
  Icon _getViewTypeIcon(HomeViewType viewType) {
    switch (viewType) {
      case HomeViewType.authyStyle:
        return const Icon(Icons.view_list);
      case HomeViewType.grid:
        return const Icon(Icons.dashboard_customize);
      case HomeViewType.list:
        return const Icon(Icons.view_module);
    }
  }

  // Get the tooltip text for the view toggle button
  String _getViewTypeTooltip(HomeViewType viewType) {
    switch (viewType) {
      case HomeViewType.authyStyle:
        return 'Switch to List View';
      case HomeViewType.grid:
        return 'Switch to Authy Style';
      case HomeViewType.list:
        return 'Switch to Grid View';
    }
  }

  // Toggle between view types
  void _toggleViewType(ThemeService themeService) {
    _logger.d('Toggling view type');
    HomeViewType newViewType;

    switch (themeService.settings.homeViewType) {
      case HomeViewType.authyStyle:
        newViewType = HomeViewType.list;
        break;
      case HomeViewType.grid:
        newViewType = HomeViewType.authyStyle;
        break;
      case HomeViewType.list:
        newViewType = HomeViewType.grid;
        break;
    }

    themeService.updateHomeViewType(newViewType);
  }

  // Build grid view for OTP entries
  Widget _buildGridView() {
    // Calculate the number of columns based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);

    // Use a responsive aspect ratio based on screen size
    // Taller cards (lower aspect ratio) for smaller screens to prevent clipping
    final childAspectRatio = screenWidth > 600 ? 0.95 : 0.8;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, // Responsive number of items per row
        childAspectRatio: childAspectRatio, // Responsive aspect ratio
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _otpEntries.length,
      itemBuilder: (context, index) {
        final entry = _otpEntries[index];
        // Use cached TOTP code instead of generating on every build
        final code = _totpCache[entry.id] ?? _otpService.generateTotp(entry);

        return Card(
          color: Theme.of(context).colorScheme.surface,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Show a dialog with the full details
              _showOtpDetailsDialog(entry, code);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top section with icon and names
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Provider icon
                        _buildProviderIcon(entry),
                        const SizedBox(height: 4),
                        // Provider name
                        Flexible(
                          child: Text(
                            entry.issuer.isNotEmpty ? entry.issuer : entry.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        // Account name if issuer is present
                        if (entry.issuer.isNotEmpty)
                          Flexible(
                            child: Text(
                              entry.name,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                        : const Color(0xFF4F4F4F), // Light mode Text Secondary
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Middle section with OTP code
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Token text
                          Text(
                            'TOTP:',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                      : const Color(0xFF4F4F4F), // Light mode Text Secondary
                            ),
                          ),
                          const SizedBox(height: 2),
                          // OTP code
                          code == 'ERROR'
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error, color: Colors.red, size: 14),
                                  const SizedBox(width: 2),
                                  const Flexible(
                                    child: Text(
                                      'Invalid Key',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                              : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0)),
                              ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom section with timer and copy button
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Expiration timer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                value: _secondsRemaining / entry.period,
                                strokeWidth: 1.5,
                                color: _secondsRemaining < 5 ? Colors.red : null,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Expires: $_secondsRemaining s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      _secondsRemaining < 5
                                          ? Colors.red
                                          : Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                          : const Color(0xFF4F4F4F), // Light mode Text Secondary
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Copy button
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copyCodeToClipboard(code),
                            tooltip: 'Copy code',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Show a dialog with OTP details
  void _showOtpDetailsDialog(OtpEntry entry, String code) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                _buildProviderIcon(entry),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.issuer.isNotEmpty ? entry.issuer : entry.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.issuer.isNotEmpty)
                        Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                    : const Color(0xFF4F4F4F), // Light mode Text Secondary
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'TOTP is:',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                            : const Color(0xFF4F4F4F), // Light mode Text Secondary
                  ),
                ),
                const SizedBox(height: 8),
                code == 'ERROR'
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        const Text('Invalid Secret Key', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    )
                    : Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  'Refreshes in $_secondsRemaining seconds',
                  style: TextStyle(
                    color:
                        _secondsRemaining < 5
                            ? Colors.red
                            : Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                            : const Color(0xFF4F4F4F), // Light mode Text Secondary
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      onPressed:
                          code == 'ERROR'
                              ? null // Disable button for invalid entries
                              : () {
                                _copyCodeToClipboard(code);
                                Navigator.pop(context);
                              },
                    ),
                    if (!_isEditMode)
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteOtpEntry(entry.id);
                        },
                      ),
                  ],
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
    );
  }

  // Copy code to clipboard
  void _copyCodeToClipboard(String code) {
    _logger.d('Copying code to clipboard');
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  // Build Authy-style view with selected TOTP at top and grid below
  Widget _buildAuthyStyleView() {
    // If no entry is selected, select the first one
    if (_selectedOtpId == null && _otpEntries.isNotEmpty) {
      _selectedOtpId = _otpEntries.first.id;
    }

    // Find the selected entry
    final selectedEntry = _otpEntries.firstWhere((entry) => entry.id == _selectedOtpId, orElse: () => _otpEntries.first);

    // Get the code for the selected entry
    final selectedCode = _totpCache[selectedEntry.id] ?? _otpService.generateTotp(selectedEntry);

    return Column(
      children: [
        // Top section with selected TOTP
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Provider icon and name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProviderIcon(selectedEntry),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedEntry.issuer.isNotEmpty ? selectedEntry.issuer : selectedEntry.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (selectedEntry.issuer.isNotEmpty)
                        Text(
                          selectedEntry.name,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                    : const Color(0xFF4F4F4F), // Light mode Text Secondary
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Token text
              Text(
                'TOTP is:',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                          : const Color(0xFF4F4F4F), // Light mode Text Secondary
                ),
              ),
              const SizedBox(height: 8),
              // OTP code
              selectedCode == 'ERROR'
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 24),
                      const SizedBox(width: 8),
                      const Text('Invalid Secret Key', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24)),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.red),
                        onPressed: () => _editOtpEntry(selectedEntry),
                        tooltip: 'Edit entry to fix key',
                      ),
                    ],
                  )
                  : Text(selectedCode, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 30, height: 30, child: CircularProgressIndicator(value: _secondsRemaining / selectedEntry.period, strokeWidth: 3)),
                  const SizedBox(width: 8),
                  Text(
                    'Refreshes in $_secondsRemaining seconds',
                    style: TextStyle(
                      color:
                          _secondsRemaining < 5
                              ? Colors.red
                              : Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                              : const Color(0xFF4F4F4F), // Light mode Text Secondary
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Copy button
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
                onPressed: selectedCode == 'ERROR' ? null : () => _copyCodeToClipboard(selectedCode),
              ),
            ],
          ),
        ),
        // Divider
        const Divider(height: 1),
        // Bottom section with grid of TOTPs
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              // Responsive grid based on screen width
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
              // Use a responsive aspect ratio based on screen size
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 0.95 : 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _otpEntries.length,
            itemBuilder: (context, index) {
              final entry = _otpEntries[index];
              final isSelected = entry.id == _selectedOtpId;

              return Card(
                elevation: isSelected ? 4 : 1,
                color: isSelected ? Theme.of(context).colorScheme.primary.withAlpha(25) : Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedOtpId = entry.id;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Provider icon
                        Expanded(flex: 3, child: Center(child: _buildProviderIcon(entry))),
                        // Provider name and account
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Provider name
                              Flexible(
                                child: Text(
                                  entry.issuer.isNotEmpty ? entry.issuer : entry.name,
                                  style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 11),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              // Account name if issuer is present
                              if (entry.issuer.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    entry.name,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color:
                                          Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                              : const Color(0xFF4F4F4F), // Light mode Text Secondary
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFabMenu(BuildContext context) {
    _logger.d('Showing FAB menu');
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Scan QR Code'),
                onTap: () {
                  Navigator.pop(context);
                  _scanQrCode();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Scan QR from Image'),
                onTap: () {
                  Navigator.pop(context);
                  _scanQrFromImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Manual Entry'),
                onTap: () {
                  Navigator.pop(context);
                  _addOtpEntry();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
