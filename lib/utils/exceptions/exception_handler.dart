import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/translations.dart';
import '../logging/logger.dart';

/// -- Turns backend errors into a message that is safe and useful to show.
class XExceptionHandler {
  XExceptionHandler._();

  /// The message in the app language (database and server messages are translated too).
  static String message(Object error) {
    final text = _message(error);
    // The one database message that contains a name.
    final guardian = RegExp(r'^This member is the only guardian of (.+)\. Make another family member a guardian of .+ first\.$')
        .firstMatch(text);
    if (guardian != null) {
      return 'This member is the only guardian of {name}. Make another family member a guardian of {name} first.'
          .trf({'name': guardian.group(1)});
    }
    return text.tr;
  }

  static String _message(Object error) {
    XLoggerHelper.warning('Handled error: ${error.runtimeType}');
    if (_isOffline(error)) return 'No connection. Check your internet and try again.'.tr; // already translated
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      if (error.code == '23505') return 'This already exists.'.tr;
      if (error.code == '42501') return 'You do not have permission to do this.'.tr;
      if (error.code == 'P0001') return error.message; // raised by our own database functions
      return 'Something went wrong while saving your data. Please try again.'.tr;
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] is String) return details['error'] as String;
      return 'The service is unavailable right now. Please try again.'.tr;
    }
    if (error is TimeoutException) return 'The request took too long. Please try again.'.tr;
    if (error is String) return error;
    return 'Something went wrong. Please try again.'.tr;
  }

  /// The phone could not reach the server (no network, or the server's address could not be looked up).
  /// Supabase wraps these in its own exceptions, so the text is checked as well as the type.
  static bool _isOffline(Object error) {
    if (error is SocketException || error is HandshakeException) return true;
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('Network is unreachable');
  }
}
