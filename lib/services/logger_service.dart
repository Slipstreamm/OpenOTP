import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late Logger _logger;

  // Singleton pattern
  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal() {
    Level logLevel;

    if (kDebugMode) {
      logLevel = Level.debug;
    } else if (kProfileMode) {
      logLevel = Level.info;
    } else if (kReleaseMode) {
      logLevel = Level.warning;
    } else {
      logLevel = Level.off;
    }

    _logger = Logger(printer: SimplePrinter(colors: false, printTime: true), level: logLevel);
  }

  void v(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}
