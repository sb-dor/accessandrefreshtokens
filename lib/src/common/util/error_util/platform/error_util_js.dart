// ignore_for_file: avoid_positional_boolean_parameters

// the only service that works both for js and vm
// use this one for web if you have Sentry service

//  * Sentry.captureException(exception, stackTrace: stackTrace, hint: hint);
Future<void> $captureException(Object exception, StackTrace stackTrace, String? hint, bool fatal) =>
    Future<void>.value(null);

// the only service that works both for js and vm
// use this one for web if you have Sentry service

// /*
//  * Sentry.captureMessage(
//  *   message,
//  *   level: warning ? SentryLevel.warning : SentryLevel.info,
//  *   hint: hint,
//  *   params: <String>[
//  *     ...?params,
//  *     if (stackTrace != null) 'StackTrace: $stackTrace',
//  *   ],
//  * );
//  * (warning || stackTrace != null)
//  *   ? FirebaseCrashlytics.instance.recordError(message, stackTrace ?? StackTrace.current);
//  *   : FirebaseCrashlytics.instance.log('$message${hint != null ? '\r\n$hint' : ''}');
//  * */
Future<void> $captureMessage(String message, StackTrace? stackTrace, String? hint, bool warning) =>
    Future<void>.value(null);
