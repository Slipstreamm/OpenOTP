![Logo](https://raw.githubusercontent.com/Slipstreamm/OpenOTP/refs/heads/master/assets/icons/horizontal_transparent.png)

# OpenOTP

A feature-rich, secure OTP (One-Time Password) generator app built with Flutter. OpenOTP allows you to store your OTP keys securely and generate TOTP and HOTP codes with a clean, customizable interface.

## Features

### Core Functionality

- Securely store OTP keys using Flutter Secure Storage
- Support for both TOTP (time-based) and HOTP (counter-based) codes
- Optional AES encryption of OTP keys with a password
- Customize OTP settings (digits, period, algorithm, counter)
- Multiple view options:
  - Grid view
  - List view
  - Focus view (Authy-style)
- Edit mode for rearranging and deleting entries

### QR Code Support

- Scan QR codes from camera (Android, iOS, macOS)
- Import QR codes from image files (all platforms)
- Standard otpauth URI format support

### Customization

- Multiple theme options (Light, Dark, Dark Forest, and more)
- Custom theme editor to create your own themes
- Adjustable page transition animations
- Provider icon support for popular services

### Security

- Biometric authentication (fingerprint, face ID)
- Password/PIN code protection
- Encrypted storage of sensitive data
- Optional second layer of encryption using your password
- Secure password storage in platform's secure storage

### Backup & Sync

- LAN synchronization between devices
  - QR code pairing for easy connection
  - Optional port configuration
  - Selective sync (OTP data only or all settings)
- Export/Import functionality
  - Optional encryption with password protection
  - File-based or direct text import/export

## Getting Started

### Prerequisites

- Flutter SDK (version 3.7.2 or higher)
- Dart SDK (version 3.0.0 or higher)

### Installation

1. Clone the repository
2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:

   ```bash
   flutter run
   ```

## Usage

### Adding OTP Entries

1. Tap the floating action button on the home screen
2. Choose to scan a QR code or manually enter details
3. For manual entry, provide the account name, secret key, and optional settings
4. Save the entry

### Viewing and Managing OTP Codes

- For TOTP entries, codes refresh automatically based on time
- For HOTP entries, tap the dice button to generate a new code
- Tap the code to copy it to clipboard
- Enter edit mode to rearrange or delete entries
- Switch between grid, list, and focus views in settings

### Syncing Between Devices

1. Open LAN Sync on both devices
2. Set one device as server and one as client
3. Connect using IP address or scan the QR code
4. Select what data to sync
5. Confirm the sync operation

### Backup and Restore

- Export your data to an encrypted file
- Import from file or directly paste exported data
- Choose what to import (OTP entries, settings, or both)

### Enhanced Security

1. Set up a password in Settings > Security
2. Enable the "Password Encryption" option to add a second layer of encryption
3. Your OTP data will be encrypted with your password for additional security
4. If you change your password, your data will be automatically re-encrypted
5. If you remove your password, the second layer of encryption will be removed

## Protection

OpenOTP uses multiple layers of security to protect your sensitive data:

- **Secure Storage**: OTP keys are encrypted and stored in the platform's secure storage:
  - Android: AES encryption with Android Keystore
  - iOS: Keychain
  - Windows/macOS/Linux: Appropriate platform-specific secure storage

- **Password Encryption**: Optional second layer of encryption using your app password:
  - Adds an additional encryption layer to your OTP data
  - Automatically re-encrypts data when password is changed
  - Decrypts data if password is removed
  - Password hash/salt stored securely in platform's secure storage

- **Biometric Authentication**: Supports fingerprint, face ID, and other biometric methods on compatible devices

- **Encrypted Exports**: Optional password protection for exported data

## Contributing

Contributions are welcome! Please feel free to submit a pull request, or open an issue.

## License & Copyright

This project is open source and available under the GNU General Public License v3.0. For more details, see the [LICENSE](LICENSE) file.

## Support

If you find this project useful, consider supporting its development through [this link](https://slipstreamm.github.io/donate). Your support is greatly appreciated!
I only accept cryptocurrencies donations at the moment.

## Icon Credits

[Key](https://icons8.com/icon/82753/key) icon by [Icons8](https://icons8.com)
