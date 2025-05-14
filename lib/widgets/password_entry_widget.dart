import 'package:flutter/material.dart';
import '../services/logger_service.dart';

class PasswordEntryWidget extends StatefulWidget {
  final Future<bool> Function(String) verifyPassword;
  final Future<bool> Function() authenticateWithBiometrics;
  final bool biometricAvailable;
  final bool canCancel;
  final VoidCallback onAuthenticated;
  final VoidCallback? onCancelled;

  const PasswordEntryWidget({
    super.key,
    required this.verifyPassword,
    required this.authenticateWithBiometrics,
    required this.biometricAvailable,
    required this.canCancel,
    required this.onAuthenticated,
    this.onCancelled,
  });

  @override
  State<PasswordEntryWidget> createState() => _PasswordEntryWidgetState();
}

class _PasswordEntryWidgetState extends State<PasswordEntryWidget> {
  final LoggerService _logger = LoggerService();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isAuthenticating = false;
  bool _isObscured = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _logger.d('Password entry widget initialized');

    // Try biometric authentication immediately if available
    if (widget.biometricAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithBiometrics();
      });
    }

    // Set focus to password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) {
      _logger.d('Biometric authentication already in progress, ignoring request');
      return;
    }

    _logger.i('Starting biometric authentication');
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      _logger.d('Calling authenticateWithBiometrics()');
      final authenticated = await widget.authenticateWithBiometrics();
      _logger.i('Biometric authentication result: $authenticated');

      if (authenticated && mounted) {
        _logger.i('Biometric authentication successful, calling onAuthenticated()');
        widget.onAuthenticated();
      } else if (mounted) {
        _logger.w('Biometric authentication failed or was cancelled');
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Biometric authentication failed. Please try again or use your password.';
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error during biometric authentication', e, stackTrace);
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _verifyPassword() async {
    if (_isAuthenticating) return;

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final authenticated = await widget.verifyPassword(password);

      if (authenticated && mounted) {
        widget.onAuthenticated();
      } else if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Incorrect password';
          _passwordController.clear();
        });
      }
    } catch (e) {
      _logger.e('Error during password verification', e);
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Authentication error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication Required'),
        automaticallyImplyLeading: widget.canCancel,
        leading:
            widget.canCancel
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (widget.onCancelled != null) {
                      widget.onCancelled!();
                    }
                  },
                )
                : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),
            const Text('Enter your password to continue', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    ),
                  ],
                ),
              ),
              obscureText: _isObscured,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => _verifyPassword(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isAuthenticating ? null : _verifyPassword,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _isAuthenticating ? const CircularProgressIndicator() : const Text('Unlock', style: TextStyle(fontSize: 16)),
            ),
            if (widget.biometricAvailable) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use Biometrics'),
                onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
