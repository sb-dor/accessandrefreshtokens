import 'dart:async';

import 'package:l/l.dart';
import 'package:platform_info/platform_info.dart';
import 'package:accessandrefreshtoken/src/common/util/error_util/error_util.dart';

/// Catch all application errors and logs.
void appZone(Future<void> Function() fn) => l.capture<void>(
  () => runZonedGuarded<void>(() => fn(), ErrorUtil.logError),
  LogOptions(
    messageFormatting: _messageFormatting,
    handlePrint: true,
    outputInRelease: false, //? do not set true, we do not have to see
    printColors: !platform.iOS, //? Remove when iOS will supports ANSI colors in console.
  ),
);

/// Formats the log message.
Object _messageFormatting(LogMessage log) => '${_timeFormat(log.timestamp)} | ${log.message}';

/// Formats the time.
String _timeFormat(DateTime time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
