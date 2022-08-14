import 'dart:convert';
import 'dart:io';
import 'dart:ffi';

import 'package:collect_logs/common.dart';
import 'package:collect_logs/config.dart';
import 'package:collect_logs/models.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';

const int kMillisecondsFromAdToEpoch = 62135596800000;

Future<void> doCollectLogs() async {
  try {
    final paramsList = await readParamsFile(Config.kParamsFileName);

    for (final params in paramsList) {
      final logs = await readLogs(params);
      await saveLogsToElastic(logs);
    }
  } catch(e) {
    logError(e.toString());
  }
}

Future<List<Params>> readParamsFile(String path) async {
  final paramsList = <Params>[];
  final file = File(path);

  if (!file.existsSync()) throw 'Params file not exists: $path';

  final lines = await file.readAsLines();
  for (final line in lines) {
    final array = line.split('|');

    if (array.length != 6) throw 'Params line not valid: $line';

    final params = Params(
      server: array[1],
      database: array[2],
      startLogRecord: int.parse(array[3]),
      endLogRecord: int.parse(array[4]),
      logPath: array[5],
    );
    paramsList.add(params);
  }

  return paramsList;
}

Future<List<Log>> readLogs(Params params) async {
  final logs = <Log>[];
  final file = File(params.logPath);
  open.overrideFor(OperatingSystem.windows, _openOnWindows);

  if (!file.existsSync()) throw 'Log file not exists: ${params.logPath}';

  final db = sqlite3.open(params.logPath, mode: OpenMode.readOnly);

  final ResultSet resultSet = db.select(_requestText, [params.startLogRecord, params.endLogRecord]);
  printError('${resultSet.length} : ${params.logPath}');
  for (var row in resultSet) {
    final log = Log(
      id: row['id'],
      date: idToDateTime(row['id']),
      user: parseString(row['user']),
      comp: parseString(row['comp']),
      app: parseString(row['app']),
      event: parseString(row['event']),
      comment: parseString(row['comment']),
      metadata: parseString(row['metadata']),
      data: parseString(row['data']),
      error: parseBoolean(row['error']),
      database: params.database,
      server: params.server,
      status: parseBoolean(row['error'])
          ? 'Ошибка'
          : parseString(row['transactionStatus']) == 'Отмена'
              ? 'Отмена'
              : '',
    );
    logs.add(log);
  }

  db.dispose();
  return logs;
}

DynamicLibrary _openOnWindows() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}/sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}

Future<void> saveLogsToElastic(List<Log> logs) async {
  final now = DateTime.now();
  final String table = "utp_logs-${DateFormat('yyyy.MM').format(now)}";
  var auth = 'Basic ${base64Encode(utf8.encode('${Config.kElasticLogin}:${Config.kElasticPassword}'))}';
  var options = BaseOptions(
      connectTimeout: 5000, receiveTimeout: 3000, headers: <String, String>{'authorization': auth, 'Content-Type': 'application/json'});
  final dio = Dio(options);
  for (final log in logs) {
    final url = '${Config.kElasticUrl}/$table/_doc/${log.id}';
    final json = jsonEncode(log);
    final response = await dio.post(url, data: json);
    printError('${response.statusCode} ${log.id}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw 'Elastic response error: ${response.statusCode} ${response.statusMessage} ${response.toString()}';
    }
  }
}

DateTime idToDateTime(int id) => DateTime.fromMillisecondsSinceEpoch(id ~/ 10 - kMillisecondsFromAdToEpoch);

int dateTimeToId(DateTime date) => (date.millisecondsSinceEpoch + kMillisecondsFromAdToEpoch) * 10;

String parseString(String? input) {
  String output = input ?? '';
  output = output.replaceAll("\"", '');

  return output;
}

bool parseBoolean(int value) {
  return value == 1;
}

String get _requestText => r"""
WITH EventNames(code, name) AS
          (
        SELECT '"_$Session$_.Start"', 'Сеанс. Начало'
        union all select '"_$Session$_.Authentication"', 'Сеанс. Аутентификация'
        union all select '"_$Session$_.Finish"', 'Сеанс. Завершение'
        union all select '"_$InfoBase$_.ConfigUpdate"', 'Информационная база. Изменение конфигурации'
        union all select '"_$InfoBase$_.DBConfigUpdate"', 'Информационная база. Изменение конфигурации базы данных'
        union all select '"_$InfoBase$_.EventLogSettingsUpdate"', 'Информационная база. Изменение параметров журнала регистрации'
        union all select '"_$InfoBase$_.InfoBaseAdmParamsUpdate"', 'Информационная база. Изменение параметров информационной базы'
        union all select '"_$InfoBase$_.MasterNodeUpdate"', 'Информационная база. Изменение главного узла'
        union all select '"_$InfoBase$_.RegionalSettingsUpdate"', 'Информационная база. Изменение региональных установок'
        union all select '"_$InfoBase$_.TARInfo"', 'Тестирование и исправление. Сообщение'
        union all select '"_$InfoBase$_.TARMess"', 'Тестирование и исправление. Предупреждение'
        union all select '"_$InfoBase$_.TARImportant"', 'Тестирование и исправление. Ошибка'
        union all select '"_$Data$_.New"', 'Данные. Добавление'
        union all select '"_$Data$_.Update"', 'Данные. Изменение'
        union all select '"_$Data$_.Delete"', 'Данные. Удаление'
        union all select '"_$Data$_.TotalsPeriodUpdate"', 'Данные. Изменение периода рассчитанных итогов'
        union all select '"_$Data$_.Post"', 'Данные. Проведение'
        union all select '"_$Data$_.Unpost"', 'Данные. Отмена проведения'
        union all select '"_$User$_.New"', 'Пользователи. Добавление'
        union all select '"_$User$_.Update"', 'Пользователи. Изменение'
        union all select '"_$User$_.Delete"', 'Пользователи. Удаление'
        union all select '"_$Job$_.Start"', 'Фоновое задание. Запуск'
        union all select '"_$Job$_.Succeed"', 'Фоновое задание. Успешное завершение'
        union all select '"_$Job$_.Fail"', 'Фоновое задание. Ошибка выполнения'
        union all select '"_$Job$_.Cancel"', 'Фоновое задание. Отмена'
        union all select '"_$PerformError$_"', 'Ошибка выполнения'
        union all select '"_$Transaction$_.Begin"', 'Транзакция. Начало'
        union all select '"_$Transaction$_.Commit"', 'Транзакция. Фиксация'
        union all select '"_$Transaction$_.Rollback"', 'Транзакция. Отмена'
    )
    SELECT
      CASE
        WHEN en.name LIKE '%Ошибка%' THEN 1 ELSE 0
      END as error,
      date as id,
      u.name AS user,
      c.name AS comp,
      a.name AS app,
      en.name AS event,
      comment,
      e.transactionID AS transaction_id,
      CASE
        WHEN e.transactionStatus = 1 THEN 'Зафиксирована'
        WHEN e.transactionStatus = 2 THEN 'Отменена'
        ELSE ''
      END as transaction_status,
      m.name as metadata,
      e.dataPresentation as data
    FROM EventLog e
    LEFT JOIN UserCodes u ON e.userCode = u.code
    LEFT JOIN ComputerCodes c ON e.computerCode = c.code
    LEFT JOIN AppCodes a ON e.appCode = a.code
    LEFT JOIN EventCodes ec ON e.eventCode = ec.code
    LEFT JOIN EventNames en ON ec.name = en.code
    LEFT JOIN MetadataCodes m ON e.metadataCodes = m.code
    WHERE (date >= ? AND date <= ?)
    ORDER BY date desc;
""";
