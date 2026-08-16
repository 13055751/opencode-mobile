import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/question_dialog.dart';
import 'bubbles.dart';
import 'composer.dart';

class ChatScreen extends StatefulWidget {
  final OpenCodeApi api;
  final Session session;
  const ChatScreen({super.key, required this.api, required this.session});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Hosts one or more chat sessions as switchable tabs.
class _ChatScreenState extends State<ChatScreen> {
  final List<Session> _sessions = [];
  final List<GlobalKey<_ChatPaneState>> _paneKeys = [];
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _sessions.add(widget.session);
    _paneKeys.add(GlobalKey<_ChatPaneState>());
  }

  _ChatPaneState get _pane => _paneKeys[_current].currentState!;

  void _addSession(Session s) {
    final existing = _sessions.indexWhere((x) => x.id == s.id);
    if (existing != -1) {
      setState(() => _current = existing);
      return;
    }
    setState(() {
      _sessions.add(s);
      _paneKeys.add(GlobalKey<_ChatPaneState>());
      _current = _sessions.length - 1;
    });
  }

  void _removeTab(int i) {
    if (i < 0 || i >= _sessions.length) return;
    setState(() {
      _sessions.removeAt(i);
      _paneKeys.removeAt(i);
      if (_sessions.isEmpty) {
        Navigator.of(context).pop(true);
        return;
      }
      if (_current >= _sessions.length) _current = _sessions.length - 1;
    });
  }

  Future<void> _pickSession() async {
    try {
      final s = await widget.api.listSessions();
      if (!mounted) return;
      final picked = await showModalBottomSheet<Session>(
        context: context,
        backgroundColor: const Color(0xFF1C1E26),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('打开会话',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: s.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF6C5CE7),
                      child: Text(
                        (s[i].displayTitle.isNotEmpty
                                ? s[i].displayTitle[0]
                                : '?')
                            .toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(s[i].displayTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      s[i].agent ?? s[i].id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                    onTap: () => Navigator.pop(sheetCtx, s[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (picked != null) _addSession(picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取会话列表失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = _sessions[_current];
    final curBusy = _pane.busy;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cur.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (cur.agent != null)
              Text(
                cur.agent!,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
          ],
        ),
        actions: [
          if (curBusy)
            IconButton(
              onPressed: () => _pane.abort(),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          IconButton(
            onPressed: _pickSession,
            icon: const Icon(Icons.tab_new_outlined),
            tooltip: '打开会话',
          ),
          IconButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => ChatActionsSheet(
                api: widget.api,
                session: cur,
                onDeleted: () => _removeTab(_current),
              ),
            ),
            icon: const Icon(Icons.more_vert),
          ),
        ],
        bottom: _sessions.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 46,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FilterChip(
                          selected: i == _current,
                          selectedColor: const Color(0xFF6C5CE7),
                          showCheckmark: false,
                          label: Text(
                            _sessions[i].displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onSelected: (_) {
                            _pane.pauseStream();
                            setState(() => _current = i);
                            WidgetsBinding.instance.addPostFrameCallback((_) => _pane.resumeStream());
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _current,
              children: [
                for (var i = 0; i < _sessions.length; i++)
                  _ChatPane(
                    key: _paneKeys[i],
                    api: widget.api,
                    session: _sessions[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPane extends StatefulWidget {
  final OpenCodeApi api;
  final Session session;
  const _ChatPane({super.key, required this.api, required this.session});

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _busy = false;
  bool _nearBottom = true;
  bool _loadingOlder = false;
  String? _nextCursor;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _streamActive = true;

  final List<PermissionRequest> _permQueue = [];
  bool _permShowing = false;
  final List<_QItem> _qQueue = [];
  bool _qShowing = false;

  String? _agentOverride;
  String? _modelProvider;
  String? _modelID;

  bool get busy => _busy;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _scroll.addListener(_trackBottom);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _connectEvents();
    await _loadNewest();
  }

  Future<void> _loadNewest() async {
    setState(() {
      _loading = true;
      _messages.clear();
      _nextCursor = null;
    });
    try {
      final page = await widget.api.listMessagesPage(widget.session.id);
      if (!mounted) return;
      setState(() {
        _messages.addAll(page.messages);
        _nextCursor = page.before;
        _loading = false;
      });
      _jumpBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载消息失败: $e')));
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _nextCursor == null) return;
    setState(() => _loadingOlder = true);
    final cursor = _nextCursor;
    try {
      final page = await widget.api.listMessagesPage(widget.session.id, before: cursor);
      if (!mounted) return;
      final count = page.messages.length;
      setState(() {
        // older messages go to the front (they load above the current view)
        _messages.insertAll(0, page.messages);
        _nextCursor = page.before;
        _loadingOlder = false;
      });
      // keep the visible viewport anchored where it was
      if (count > 0 && _scroll.hasClients) {
        final offset = _scroll.position.pixels;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(offset + count * 8);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadOlder();
    }
  }

  void _trackBottom() {
    final near = _scroll.hasClients && _scroll.position.pixels < 120;
    if (near != _nearBottom) setState(() => _nearBottom = near);
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void pauseStream() {
    _streamActive = false;
  }

  void resumeStream() {
    _streamActive = true;
  }

  Future<void> abort() async {
    try {
      await widget.api.abort(widget.session.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('中断失败: $e')));
    }
  }

  void _connectEvents() {
    _sub?.cancel();
    _sub = widget.api.eventStream().listen((event) async {
      if (!_streamActive) return;
      await _onEvent(event);
    }, onError: (_) {});
  }

  Future<void> _onEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String? ?? '';
    final data = (event['data'] as Map<String, dynamic>?) ?? {};
    final esid = data['sessionID'] as String?;
    if (esid != null && esid != widget.session.id) return;

    switch (type) {
      case 'session.status':
        final status = SessionStatus.fromJson(data['status'] as Map<String, dynamic>? ?? {});
        setState(() {
          _busy = status.isBusy;
        });
        if (status.isBusy && _nearBottom) {
          _jumpBottom();
        }
        break;
      case 'session.idle':
        setState(() {
          _busy = false;
        });
        if (_nearBottom) _jumpBottom();
        break;
      case 'session.error':
        setState(() => _busy = false);
        break;
      case 'message.updated':
        final info = data['info'];
        if (info is Map<String, dynamic>) {
          _upsertMessage(ChatMessage.fromJson(info));
          if (_nearBottom) _jumpBottom();
        }
        break;
      case 'message.part.updated':
        final mid = esid ?? data['messageID'] as String?;
        final part = data['part'];
        if (part is Map<String, dynamic> && mid != null) {
          _updatePart(mid, part);
          if (_nearBottom) _jumpBottom();
        }
        break;
      case 'message.part.delta':
        final mid = data['messageID'] as String?;
        final pid = data['partID'] as String?;
        final field = data['field'] as String?;
        final delta = data['delta'] as String?;
        if (mid != null && pid != null && field == 'text' && delta != null) {
          _appendPartText(mid, pid, delta);
          if (_nearBottom) _jumpBottom();
        }
        break;
      case 'message.removed':
        final mid = data['messageID'] as String?;
        if (mid != null) {
          setState(() => _messages.removeWhere((m) => m.id == mid));
        }
        break;
      case 'permission.v2.asked':
      case 'permission.asked':
        _enqueuePermission(PermissionRequest.fromJson(data));
        break;
      case 'question.v2.asked':
      case 'question.asked':
        final qs = (data['questions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(QuestionInfo.fromJson)
            .toList();
        if (qs.isNotEmpty) {
          final requestID = data['id'] as String? ?? '';
          final sessionID = data['sessionID'] as String? ?? widget.session.id;
          _enqueueQuestion(sessionID, requestID, qs);
        }
        break;
    }
  }

  void _enqueuePermission(PermissionRequest req) {
    if (_permQueue.any((x) => x.id == req.id)) return;
    setState(() => _permQueue.add(req));
    _drainPermissions();
  }

  Future<void> _drainPermissions() async {
    if (_permShowing || _permQueue.isEmpty || !mounted) return;
    _permShowing = true;
    final req = _permQueue.removeAt(0);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PermissionDialog(
          req: req,
          onReply: (reply, remember) async {
            await widget.api.respondPermission(widget.session.id, req.id, reply, remember: remember);
          },
        ),
      );
    } finally {
      _permShowing = false;
      _drainPermissions();
    }
  }

  void _enqueueQuestion(String sessionID, String requestID, List<QuestionInfo> qs) {
    if (_qQueue.any((x) => x.requestID == requestID)) return;
    setState(() => _qQueue.add(_QItem(sessionID: sessionID, requestID: requestID, questions: qs)));
    _drainQuestions();
  }

  Future<void> _drainQuestions() async {
    if (_qShowing || _qQueue.isEmpty || !mounted) return;
    _qShowing = true;
    final item = _qQueue.removeAt(0);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => QuestionDialog(
          questions: item.questions,
          onSubmit: (answers) async {
            await widget.api.answerQuestion(item.sessionID, item.requestID, [answers]);
          },
        ),
      );
    } finally {
      _qShowing = false;
      _drainQuestions();
    }
  }

  Future<void> _pickModeModel() async {
    try {
      final a = await widget.api.listAgents();
      final m = await widget.api.listModels();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1C1E26),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _ModeModelSheet(
          agents: List<Map<String, dynamic>>.from(a.whereType<Map<String, dynamic>>()),
          models: {'all': m.$1},
          agent: _agentOverride,
          provider: _modelProvider,
          modelID: _modelID,
          onDone: (agent, provider, modelId) {
            setState(() {
              _agentOverride = agent;
              _modelProvider = provider;
              _modelID = modelId;
            });
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取模式/模型失败: $e')));
    }
  }

  void _upsertMessage(ChatMessage msg) {
    setState(() {
      final i = _messages.indexWhere((m) => m.id == msg.id);
      if (i == -1) {
        _messages.add(msg);
      } else {
        _messages[i] = msg;
      }
    });
  }

  void _updatePart(String sessionID, Map<String, dynamic> part) {
    final p = Part.fromJson(part);
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.sessionID != sessionID) continue;
        final found = m.parts.indexWhere((x) => x.callID == p.callID && x.raw['id'] == p.raw['id']);
        if (found != -1) {
          final newParts = [...m.parts];
          newParts[found] = p;
          _messages[i] = ChatMessage(
            id: m.id,
            role: m.role,
            sessionID: m.sessionID,
            agent: m.agent,
            modelID: m.modelID,
            parts: newParts,
          );
          return;
        }
      }
    });
  }

  void _appendPartText(String mid, String pid, String delta) {
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.id != mid) continue;
        final found = m.parts.indexWhere((x) => x.raw['id'] == pid);
        if (found != -1) {
          final parts = [...m.parts];
          final old = parts[found];
          final newText = (old.text ?? '') + delta;
          final raw = {...old.raw, 'text': newText};
          parts[found] = Part(kind: PartKind.text, text: newText, raw: raw);
          _messages[i] = ChatMessage(id: m.id, role: m.role, sessionID: m.sessionID, parts: parts);
          return;
        }
        final textRaw = {'id': pid, 'type': 'text', 'text': delta};
        _messages[i] = ChatMessage(
          id: m.id,
          role: m.role,
          sessionID: m.sessionID,
          parts: [...m.parts, Part(kind: PartKind.text, text: delta, raw: textRaw)],
        );
        return;
      }
    });
  }

  Future<void> _send(String text, List<Map<String, dynamic>> parts) async {
    setState(() {
      _busy = true;
      _messages.add(ChatMessage(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        sessionID: widget.session.id,
        parts: [Part(kind: PartKind.text, text: text, raw: {'type': 'text', 'text': text})],
      ));
      _jumpBottom();
    });
    try {
      await widget.api.sendMessage(
        widget.session.id,
        parts.isEmpty ? text : '',
        agent: _agentOverride,
        modelProvider: _modelProvider,
        modelID: _modelID,
        parts: parts,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('开始对话吧', style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) => MessageBubble(message: _messages[i]),
                        ),
                        if (_loadingOlder)
                          const Positioned(
                            top: 4,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
        Composer(
          api: widget.api,
          busy: _busy,
          onSend: _send,
          onAbort: abort,
          onPickModeModel: _pickModeModel,
        ),
      ],
    );
  }
}

class _QItem {
  final String sessionID;
  final String requestID;
  final List<QuestionInfo> questions;
  _QItem({required this.sessionID, required this.requestID, required this.questions});
}

class _ModeModelSheet extends StatefulWidget {
  final List<Map<String, dynamic>> agents;
  final Map<String, dynamic> models;
  final String? agent;
  final String? provider;
  final String? modelID;
  final void Function(String? agent, String? provider, String? modelId) onDone;
  const _ModeModelSheet({
    required this.agents,
    required this.models,
    this.agent,
    this.provider,
    this.modelID,
    required this.onDone,
  });

  @override
  State<_ModeModelSheet> createState() => _ModeModelSheetState();
}

class _ModeModelSheetState extends State<_ModeModelSheet> {
  String? _agent;
  String? _provider;
  String? _modelID;

  @override
  void initState() {
    super.initState();
    _agent = widget.agent;
    _provider = widget.provider;
    _modelID = widget.modelID;
  }

  List<String> _modelChoices() {
    final all = (widget.models['all'] as List<dynamic>? ?? []);
    final out = <String>[];
    for (final prov in all.whereType<Map<String, dynamic>>()) {
      final pid = prov['id'] as String? ?? '';
      final models = prov['models'];
      if (models is Map<String, dynamic>) {
        for (final mid in models.keys) {
          out.add('$pid/${models[mid]}');
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final modelChoices = _modelChoices();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('模式与模型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text('模式（agent）', style: TextStyle(fontSize: 12, color: Colors.white38)),
                ),
                if (widget.agents.isEmpty)
                  const ListTile(
                    dense: true,
                    title: Text('未获取到可用模式', style: TextStyle(fontSize: 13)),
                  )
                else
                  for (final a in widget.agents)
                    RadioListTile<String?>(
                      dense: true,
                      value: a['name'] as String?,
                      groupValue: _agent,
                      activeColor: const Color(0xFF6C5CE7),
                      title: Text((a['name'] as String? ?? ''), style: const TextStyle(fontSize: 14)),
                      subtitle: a['description'] is String && (a['description'] as String).isNotEmpty
                          ? Text(
                              (a['description'] as String).replaceAll('\n', ' '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                            )
                          : null,
                      onChanged: (v) => setState(() => _agent = v),
                    ),
                const Divider(height: 1, color: Colors.white12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text('模型', style: TextStyle(fontSize: 12, color: Colors.white38)),
                ),
                if (modelChoices.isEmpty)
                  const ListTile(
                    dense: true,
                    title: Text('未获取到可用模型', style: TextStyle(fontSize: 13)),
                  )
                else
                  for (final mc in modelChoices)
                    RadioListTile<String>(
                      dense: true,
                      value: mc,
                      groupValue: _provider == null ? null : '$_provider/$_modelID',
                      activeColor: const Color(0xFF6C5CE7),
                      title: Text(mc, style: const TextStyle(fontSize: 13)),
                      onChanged: (v) {
                        if (v == null) return;
                        final sl = v.indexOf('/');
                        setState(() {
                          _provider = v.substring(0, sl);
                          _modelID = v.substring(sl + 1);
                        });
                      },
                    ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              onPressed: () {
                widget.onDone(_agent, _provider, _modelID);
                Navigator.of(context).pop();
              },
              child: const Text('应用'),
            ),
          ),
        ],
      ),
    );
  }
}