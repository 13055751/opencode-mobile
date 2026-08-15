import 'dart:convert';

class Session {
  final String id;
  final String? title;
  final String? agent;
  final String? directory;
  final String? summary;
  final Map<String, dynamic>? time;
  final int? cost;
  final bool? archived;

  Session({
    required this.id,
    this.title,
    this.agent,
    this.directory,
    this.summary,
    this.time,
    this.cost,
    this.archived,
  });

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String? ?? '',
        title: j['title'] as String?,
        agent: j['agent'] as String?,
        directory: j['directory'] as String?,
        summary: j['summary'] as String?,
        time: j['time'] as Map<String, dynamic>?,
        cost: j['cost'] as int?,
        archived: j['archived'] as bool?,
      );

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (summary != null && summary!.isNotEmpty) return summary!;
    return 'New session';
  }

  int get createdAtMillis {
    final t = time;
    if (t == null) return 0;
    final created = t['created'];
    if (created is num) return created.toInt();
    if (created is String) {
      final p = DateTime.tryParse(created);
      if (p != null) return p.millisecondsSinceEpoch;
    }
    return 0;
  }
}

enum PartKind { text, reasoning, tool, file, stepStart, stepFinish, agent, subtask, snapshot, patch, compaction, retry, unknown }

class Part {
  final PartKind kind;
  final String? text;
  final String? callID;
  final String? toolName;
  final ToolState? toolState;
  final String? stateText;
  final Map<String, dynamic> raw;

  Part({
    required this.kind,
    this.text,
    this.callID,
    this.toolName,
    this.toolState,
    this.stateText,
    required this.raw,
  });

  factory Part.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String?;
    final kind = switch (type) {
      'text' => PartKind.text,
      'reasoning' => PartKind.reasoning,
      'tool' => PartKind.tool,
      'file' => PartKind.file,
      'step-start' => PartKind.stepStart,
      'step-finish' => PartKind.stepFinish,
      'agent' => PartKind.agent,
      'subtask' => PartKind.subtask,
      'snapshot' => PartKind.snapshot,
      'patch' => PartKind.patch,
      'compaction' => PartKind.compaction,
      'retry' => PartKind.retry,
      _ => PartKind.unknown,
    };
    ToolState? ts;
    if (j['state'] is Map<String, dynamic>) {
      ts = ToolState.fromJson(j['state'] as Map<String, dynamic>);
    }
    final stateText = ts?.status ?? (j['state'] as Map<String, dynamic>?)?['status'];
    return Part(
      kind: kind,
      text: j['text'] as String?,
      callID: j['callID'] as String?,
      toolName: j['tool'] as String?,
      toolState: ts,
      stateText: stateText,
      raw: j,
    );
  }
}

class ToolState {
  final String status;
  final Map<String, dynamic>? input;
  final String? output;
  final String? error;
  final String? title;

  ToolState({
    required this.status,
    this.input,
    this.output,
    this.error,
    this.title,
  });

  factory ToolState.fromJson(Map<String, dynamic> j) => ToolState(
        status: j['status'] as String? ?? 'unknown',
        input: j['input'] is Map<String, dynamic> ? j['input'] as Map<String, dynamic>? : null,
        output: j['output'] as String?,
        error: j['error'] as String?,
        title: j['title'] as String?,
      );

  bool get isCompleted => status == 'completed';
  bool get isError => status == 'error';
}

class ChatMessage {
  final String id;
  final String role;
  final String sessionID;
  final String? agent;
  final String? modelID;
  final Map<String, dynamic>? error;
  final List<Part> parts;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.sessionID,
    this.agent,
    this.modelID,
    this.error,
    this.parts = const [],
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final rawParts = j['parts'] as List<dynamic>? ?? [];
    return ChatMessage(
      id: j['id'] as String? ?? '',
      role: j['role'] as String? ?? 'user',
      sessionID: j['sessionID'] as String? ?? '',
      agent: j['agent'] as String?,
      modelID: j['modelID'] as String?,
      error: j['error'] as Map<String, dynamic>?,
      parts: rawParts.map((e) => Part.fromJson(e as Map<String, dynamic>)).toList(),
      createdAt: _parseTime(j['time']),
    );
  }

  static DateTime? _parseTime(dynamic t) {
    if (t is Map<String, dynamic>) {
      final c = t['created'];
      if (c is String) return DateTime.tryParse(c);
    }
    if (t is String) return DateTime.tryParse(t);
    return null;
  }

  bool get isAssistant => role == 'assistant';

  String get visibleText {
    final buf = StringBuffer();
    for (final p in parts) {
      if (p.kind == PartKind.text && p.text != null && !(p.raw['synthetic'] == true)) {
        buf.writeln(p.text);
      }
    }
    return buf.toString();
  }
}

class FileEntry {
  final String name;
  final String path;
  final String absolute;
  final String type;
  final bool ignored;
  FileEntry({
    required this.name,
    required this.path,
    required this.absolute,
    required this.type,
    this.ignored = false,
  });
  factory FileEntry.fromJson(Map<String, dynamic> j) => FileEntry(
        name: j['name'] as String? ?? '',
        path: j['path'] as String? ?? '',
        absolute: j['absolute'] as String? ?? '',
        type: j['type'] as String? ?? 'file',
        ignored: j['ignored'] == true,
      );
  bool get isDir => type == 'directory';
}

class QuestionOption {
  final String label;
  final String? description;
  QuestionOption({required this.label, this.description});
  factory QuestionOption.fromJson(Map<String, dynamic> j) => QuestionOption(
        label: j['label'] as String? ?? '',
        description: j['description'] as String?,
      );
}

class QuestionInfo {
  final String question;
  final String? header;
  final bool multiple;
  final bool custom;
  final List<QuestionOption> options;
  QuestionInfo({
    required this.question,
    this.header,
    this.multiple = false,
    this.custom = true,
    this.options = const [],
  });
  factory QuestionInfo.fromJson(Map<String, dynamic> j) => QuestionInfo(
        question: j['question'] as String? ?? '',
        header: j['header'] as String?,
        multiple: j['multiple'] == true,
        custom: j['custom'] != false,
        options: (j['options'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(QuestionOption.fromJson)
            .toList(),
      );
}

class PermissionRequest {
  final String id;
  final String? sessionID;
  final String? permission;
  final String? action;
  final List<String> patterns;
  final List<String> resources;
  final Map<String, dynamic>? metadata;
  final bool? save;

  PermissionRequest({
    required this.id,
    this.sessionID,
    this.permission,
    this.action,
    this.patterns = const [],
    this.resources = const [],
    this.metadata,
    this.save,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> j) => PermissionRequest(
        id: j['id'] as String? ?? '',
        sessionID: j['sessionID'] as String?,
        permission: j['permission'] as String?,
        action: j['action'] as String?,
        patterns: (j['patterns'] as List<dynamic>? ?? []).whereType<String>().toList(),
        resources: (j['resources'] as List<dynamic>? ?? []).whereType<String>().toList(),
        metadata: j['metadata'] as Map<String, dynamic>?,
        save: j['save'] as bool?,
      );

  String get display {
    final m = metadata;
    if (m != null && m['prompt'] is String) return m['prompt'] as String;
    final t = action != null && action!.isNotEmpty ? action! : permission ?? '';
    if (resources.isNotEmpty) return '$t: ${resources.join(', ')}';
    if (patterns.isNotEmpty) return '$t: ${patterns.join(', ')}';
    return t;
  }
}

class SessionStatus {
  final String type;
  final int? attempt;
  final String? message;
  SessionStatus({required this.type, this.attempt, this.message});
  factory SessionStatus.fromJson(Map<String, dynamic> j) => SessionStatus(
        type: j['type'] as String? ?? 'idle',
        attempt: j['attempt'] as int?,
        message: j['message'] as String?,
      );
  bool get isBusy => type == 'busy';
}

class Todo {
  final String id;
  final String content;
  final String status;
  final String? actor;
  Todo({required this.id, required this.content, required this.status, this.actor});
  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String? ?? '',
        content: j['content'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        actor: j['actor'] as String?,
      );
}

String prettyJson(Map<String, dynamic>? m) {
  if (m == null) return '';
  return const JsonEncoder.withIndent('  ').convert(m);
}
