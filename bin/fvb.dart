import 'dart:io';

import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:stack_trace/stack_trace.dart';

void main(List<String> arguments) {
  Chain.capture(() {
    bumpVersion(arguments);
  }, onError: (error, chain) {
    stderr.writeln('Fatal error: $error');
    stderr.writeln(chain.terse);
    exit(ExitCode.software.code);
  });
}
