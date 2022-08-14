import 'package:collect_logs/collect_logs.dart' as collect_logs;
import 'package:collect_logs/common.dart';

Future<void> main(List<String> arguments) async {
  logClear();
  collect_logs.doCollectLogs();
}

