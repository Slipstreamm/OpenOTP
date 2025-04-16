import 'package:flutter/material.dart';
import '../services/logger_service.dart';

class PasswordSetupWidget extends StatefulWidget {
  final Future<bool> Function(String) setPassword;
  final VoidCallback? onCancelled;
  final ValueChanged<bool> onComplete;

  const PasswordSetupWidget({super.key, required this.setPassword, this.onCancelled, required this.onComplete});

  @override
  State<PasswordSetupWidget> createState() => _PasswordSetupWidgetState();
}

class _PasswordSetupWidgetState extends State<PasswordSetupWidget> {
  final LoggerService _logger = LoggerService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isProcessing = false;
  bool _isObscured = true;
  bool _isConfirmObscured = true;
  String? _errorMessage;
  bool _isConfirmStep = false;

  @override
  void initState() {
    super.initState();
    _logger.d('Password setup widget initialized');

    // Set focus to password field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateAndProceed() {
    if (_isProcessing) return;

    if (!_isConfirmStep) {
      // First step - validate password
      final password = _passwordController.text;
      if (password.isEmpty) {
        setState(() {
          _errorMessage = 'Password cannot be empty';
        });
        return;
      }

      if (password.length < 6) {
        setState(() {
          _errorMessage = 'Password must be at least 6 characters';
        });
        return;
      }

      // Move to confirmation step
      setState(() {
        _isConfirmStep = true;
        _errorMessage = null;
      });
    } else {
      // Confirm step - check if passwords match
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;

      if (password != confirmPassword) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }

      // Passwords match, proceed with setting the password
      _setPassword(password);
    }
  }

  Future<void> _setPassword(String password) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.setPassword(password);

      if (mounted) {
        if (success) {
          // Close the dialog when password is set successfully
          Navigator.of(context).pop();
          // Then notify the parent about the success
          widget.onComplete(true);
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Failed to set password';
          });
        }
      }
    } catch (e) {
      _logger.e('Error setting password', e);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isConfirmStep ? 'Confirm Password' : 'Set Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isConfirmStep) {
              // Go back to first step
              setState(() {
                _isConfirmStep = false;
                _errorMessage = null;
              });
            } else if (widget.onCancelled != null) {
              widget.onCancelled!();
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            Text(_isConfirmStep ? 'Confirm your password' : 'Create a secure password', style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              _isConfirmStep ? 'Please enter your password again to confirm' : 'Your password can include letters, numbers, and special characters',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!_isConfirmStep)
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
                  suffixIcon: IconButton(
                    icon: Icon(_isObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  ),
                ),
                obscureText: _isObscured,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _validateAndProceed(),
              )
            else
              TextField(
                controller: _confirmPasswordController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isConfirmObscured = !_isConfirmObscured;
                      });
                    },
                  ),
                ),
                obscureText: _isConfirmObscured,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _validateAndProceed(),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isProcessing ? null : _validateAndProceed,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child:
                  _isProcessing ? const CircularProgressIndicator() : Text(_isConfirmStep ? 'Set Password' : 'Continue', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
