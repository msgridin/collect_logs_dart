import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:collect_logs/config.dart';
import 'package:intl/intl.dart';

printError(String error) {
  AnsiPen pen = AnsiPen()..red();
  print(pen('[ERROR]: $error'));
}

printInfo(String info) {
  AnsiPen pen = AnsiPen()..gray();
  print(pen('[INFO]: $info'));
}

printWarning(String warning) {
  AnsiPen pen = AnsiPen()..yellow();
  print(pen('[WARNING]: $warning'));
}

logError(String error) {
  printError(error);

  final now = DateTime.now();
  final file = File(Config.kErrorsFileName);
  file.writeAsStringSync("${DateFormat('dd MMM hh:mm:ss').format(now)} $error\n", mode: FileMode.append);
}