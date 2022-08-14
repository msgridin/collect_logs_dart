import 'dart:core';

class Params {
  final String server;
  final String database;
  final int startLogRecord;
  final int endLogRecord;
  final String logPath;

  Params({required this.server, required this.database, required this.startLogRecord, required this.endLogRecord, required this.logPath});
}

class Log {
  final String status;
  final DateTime date;
  final String database;
  final String user;
  final String event;
  final String comment;
  final String metadata;
  final String data;
  final String comp;
  final String app;
  final String server;
  final int id;
  final bool error;

  Log({
    required this.id,
    required this.date,
    required this.user,
    required this.comp,
    required this.app,
    required this.event,
    required this.comment,
    required this.metadata,
    required this.data,
    required this.error,
    required this.database,
    required this.server,
    required this.status,
  });

  Map toJson() => {
    'status': status,
    'date': date.toIso8601String(),
    'database': database,
    'user': user,
    'event': event,
    'comment': comment,
    'metadata': metadata,
    'data': data,
    'comp': comp,
    'app': app,
    'server': server,
    'id': id,
    'error': error,
  };
}
