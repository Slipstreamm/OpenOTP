import 'dart:io';
import 'dart:typed_data';
import 'package:zxing2/qrcode.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'logger_service.dart';
import '../utils/base32_utils.dart';
import '../models/otp_entry.dart';

class QrScannerService {
  final LoggerService _logger = LoggerService();

  // Check if the current platform supports camera QR scanning
  bool isCameraQrScanningSupported() {
    _logger.d('Checking if platform supports camera QR scanning');
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  // Check if the current platform supports file-based QR scanning
  bool isFileQrScanningSupported() {
    _logger.d('Checking if platform supports file-based QR scanning');
    // All platforms that support file picking should support this
    return true;
  }

  // Get platform-specific message for unsupported camera platforms
  String getUnsupportedCameraMessage() {
    _logger.d('Getting unsupported camera message');
    if (Platform.isWindows) {
      return 'Camera QR scanning is not supported on Windows. Please use the image file option instead.';
    } else if (Platform.isLinux) {
      return 'Camera QR scanning is not supported on Linux. Please use the image file option instead.';
    } else {
      return 'Camera QR scanning is not supported on this platform. Please use the image file option instead.';
    }
  }

  // Pick an image file and decode QR code from it - platform aware method
  Future<String?> pickAndDecodeQrFromImage() async {
    _logger.d('Picking image file for QR decoding');
    try {
      // Use image_picker for mobile platforms and file_picker for desktop
      if (Platform.isAndroid || Platform.isIOS) {
        return await _pickAndDecodeQrFromImageMobile();
      } else {
        return await _pickAndDecodeQrFromImageDesktop();
      }
    } catch (e, stackTrace) {
      _logger.e('Error picking or decoding QR from image', e, stackTrace);
      return null;
    }
  }

  // Pick an image using image_picker (for mobile platforms)
  Future<String?> _pickAndDecodeQrFromImageMobile() async {
    _logger.d('Picking image file for QR decoding using image_picker (mobile)');
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        String filePath = image.path;
        _logger.i('Image file picked (mobile): $filePath');
        return await decodeQrFromImagePath(filePath);
      } else {
        _logger.d('No image picked on mobile');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error picking or decoding QR from image on mobile', e, stackTrace);
      return null;
    }
  }

  // Pick an image using file_picker (for desktop platforms)
  Future<String?> _pickAndDecodeQrFromImageDesktop() async {
    _logger.d('Picking image file for QR decoding using file_picker (desktop)');
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']);

      if (result != null && result.files.single.path != null) {
        String? filePath = result.files.single.path;
        _logger.i('Image file picked (desktop): $filePath');
        return await decodeQrFromImagePath(filePath!);
      } else {
        _logger.d('No image file picked or path is null on desktop');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error picking or decoding QR from image on desktop', e, stackTrace);
      return null;
    }
  }

  // Decode QR code from image path
  Future<String?> decodeQrFromImagePath(String imagePath) async {
    _logger.d('Decoding QR from image path: $imagePath');
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        _logger.w('File does not exist: $imagePath');
        return null;
      }

      // Read the image file bytes
      final bytes = await file.readAsBytes();

      // Decode the image using the image package
      final image = img.decodeImage(bytes);
      if (image == null) {
        _logger.w('Could not decode image: $imagePath');
        return null;
      }

      // Convert to luminance source for ZXing
      final pixels = Int32List(image.width * image.height);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          // Get RGB values from the pixel and convert to int
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          // Combine into RGB value (ignoring alpha)
          pixels[y * image.width + x] = (r << 16) | (g << 8) | b;
        }
      }

      final luminanceSource = RGBLuminanceSource(image.width, image.height, pixels);

      // Create a binary bitmap for the QR reader
      final binaryBitmap = BinaryBitmap(HybridBinarizer(luminanceSource));

      // Set up the QR code reader
      final reader = QRCodeReader();

      try {
        // Attempt to decode the QR code
        final result = reader.decode(binaryBitmap);
        if (result.text.isNotEmpty) {
          _logger.i('Successfully decoded QR code from image');
          return result.text;
        }
      } catch (e) {
        _logger.w('No QR code found in the image: ${e.toString()}');
      }

      _logger.w('No QR code found in the image');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error decoding QR from image', e, stackTrace);
      return null;
    }
  }

  // Parse otpauth URI format
  // Format: otpauth://totp/ISSUER:ACCOUNT?secret=SECRET&issuer=ISSUER&algorithm=ALGORITHM&digits=DIGITS&period=PERIOD
  // Format: otpauth://hotp/ISSUER:ACCOUNT?secret=SECRET&issuer=ISSUER&algorithm=ALGORITHM&digits=DIGITS&counter=COUNTER
  Map<String, dynamic> parseOtpAuthUri(String uri) {
    _logger.d('Parsing OTP auth URI: $uri');
    try {
      // Check if the URI is in the correct format and determine OTP type
      OtpType otpType;
      String typePrefix;

      if (uri.startsWith('otpauth://totp/')) {
        otpType = OtpType.totp;
        typePrefix = 'otpauth://totp/';
      } else if (uri.startsWith('otpauth://hotp/')) {
        otpType = OtpType.hotp;
        typePrefix = 'otpauth://hotp/';
      } else {
        _logger.w('Invalid OTP auth URI format: $uri');
        throw FormatException('Invalid OTP auth URI format');
      }

      // Extract the label (which may contain issuer and account name)
      final labelPart = uri.substring(typePrefix.length, uri.indexOf('?'));
      String issuer = '';
      String name = labelPart;

      // If the label contains a colon, it has both issuer and account name
      if (labelPart.contains(':')) {
        final labelParts = labelPart.split(':');
        issuer = labelParts[0];
        name = labelParts[1];
      }

      // Parse the query parameters
      final queryParams = Uri.parse(uri).queryParameters;

      // Extract the secret (required)
      final secret = queryParams['secret'];
      if (secret == null || secret.isEmpty) {
        _logger.w('Missing secret in OTP auth URI: $uri');
        throw FormatException('Missing secret in OTP auth URI');
      }

      // Validate that the secret contains valid base32 characters
      if (!Base32Utils.isValidBase32(secret)) {
        _logger.w('Invalid base32 characters in secret: $secret');
        throw FormatException('Invalid base32 characters in secret key');
      }

      // Validate that the secret can be decoded
      if (!Base32Utils.canDecode(secret)) {
        _logger.w('Secret cannot be decoded as base32: $secret');
        throw FormatException('Secret key cannot be decoded as base32');
      }

      // If issuer is in query params, it overrides the one in the label
      if (queryParams.containsKey('issuer') && queryParams['issuer']!.isNotEmpty) {
        issuer = queryParams['issuer']!;
      }

      // Extract optional parameters with defaults
      final algorithm = queryParams['algorithm'] ?? 'SHA1';
      final digits = int.tryParse(queryParams['digits'] ?? '6') ?? 6;

      // Create result map with common fields
      final result = {'name': name, 'secret': secret, 'issuer': issuer, 'algorithm': algorithm, 'digits': digits, 'type': otpType.index};

      // Add type-specific parameters
      if (otpType == OtpType.totp) {
        final period = int.tryParse(queryParams['period'] ?? '30') ?? 30;
        result['period'] = period;
      } else {
        // HOTP
        final counter = int.tryParse(queryParams['counter'] ?? '0') ?? 0;
        result['counter'] = counter;
        // Add period anyway for UI consistency (not used for HOTP generation)
        result['period'] = 30;
      }

      _logger.i('Successfully parsed OTP auth URI of type ${otpType.name}');
      return result;
    } catch (e, stackTrace) {
      _logger.e('Error parsing OTP auth URI', e, stackTrace);
      rethrow;
    }
  }
}
