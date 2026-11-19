import 'package:logger/logger.dart';

class XLoggerHelper {
  static final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  static void debug(String message) => _logger.d(message);

  static void info(String message) => _logger.i(message);

  static void warning(String message) => _logger.w(message);

  /// Never pass health data or tokens into log messages.
  static void error(String message, [dynamic error]) =>
      _logger.e(message, error: error, stackTrace: StackTrace.current);
}
