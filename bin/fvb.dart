import 'dart:io';

import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = bumpVersion(arguments);
  } catch (error, stackTrace) {
    stderr.writeln('Fatal error: $error');
    if (arguments.contains('-v') || arguments.contains('--verbose')) {
      stderr.writeln(Trace.from(stackTrace).terse);
    }
    exitCode = ExitCode.software.code;
  }
}
