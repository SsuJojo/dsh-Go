import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';
import 'package:test/test.dart';

// Issue #859: the incremental fold re-runs `_ToolBuilder.build` after every
// appended event. These tests pin the contract that makes the cache sound and
// observable: an unchanged tool keeps its previous ChatItem instance, while
// every input the rendered output depends on flips the identity.
Map<String, Object?> ev(int n, String type, Map<String, Object?> data) => {
  'type': 'event',
  'event': {'seq': n, 'time': 1000 + n, 'type': type, 'data': data},
};
Map<String, Object?> call(int n, String id) =>
    ev(n, 'tool/call', {'turn': n ~/ 10, 'step': 1, 'callId': id, 'name': 'name-$id', 'arguments': '{"n":$n}'});
Map<String, Object?> result(int n, String id, {bool error = false}) => ev(n, 'tool/result', {
  'turn': 1,
  'step': 1,
  'message': {
    'id': 'r$n',
    'role': 'tool',
    'toolCallId': id,
    'isError': error,
    'content': [
      {'type': 'text', 'text': 'r$n'},
    ],
  },
  'meta': {'n': n},
});
Map<String, Object?> end(int n) => ev(n, 'turn/end', {'turn': n ~/ 10, 'reason': {'kind': 'completed'}});
Map<String, Object?> user(int n) => ev(n, 'user/message', {
  'id': 'u$n',
  'role': 'user',
  'source': {'kind': 'user', 'rpcId': 'req$n'},
  'content': [
    {'type': 'text', 'text': 'hello$n'},
  ],
});
Map<String, Object?> snapshot(List<Map<String, Object?>> frames, {int cursor = 100}) => {
  'type': 'snapshot',
  'header': {'id': 's', 'version': 4, 'createdAt': 1000},
  'cursor': cursor,
  'records': frames,
  'hasMore': true,
  'projections': {'asOfSeq': cursor, 'values': {}},
  'assistantStream': {'revision': 0},
};

ToolChatItem toolOf(ChatTranscript t, String callId) =>
    t.items.whereType<ToolChatItem>().singleWhere((item) => item.callId == callId);

void main() {
  ChatTranscript seeded(List<Map<String, Object?>> frames, {int cursor = 100}) => ChatTranscript()
    ..apply(parseFollowFrame('s', jsonDecode(jsonEncode(snapshot(frames, cursor: cursor)))));

  test('an unchanged tool keeps its instance across unrelated durable events', () {
    final t = seeded([ev(0, 'turn/start', {'turn': 1}), call(1, 'c1')]);
    final before = toolOf(t, 'c1');
    expect(before.status, ToolStatus.running);

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(user(2)))));
    final rebuilt = toolOf(t, 'c1');
    expect(identical(rebuilt, before), isTrue, reason: 'unrelated event must not re-create the item');

    // A landing result changes content and identity.
    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(result(3, 'c1')))));
    final done = toolOf(t, 'c1');
    expect(identical(done, before), isFalse);
    expect(done.status, ToolStatus.succeeded);
    expect(done.resultParts, hasLength(1));

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(user(4)))));
    expect(identical(toolOf(t, 'c1'), done), isTrue, reason: 'post-result rebuild must reuse the instance');
  });

  test('a replaced result meta invalidates the cache even with a stable result', () {
    final t = seeded([ev(0, 'turn/start', {'turn': 1}), call(1, 'c1'), result(2, 'c1')]);
    final before = toolOf(t, 'c1');
    expect(before.meta, {'n': 2});

    // ToolResultEvent.meta is a view over data; the fold keeps the same event
    // instance, so only the meta identity check can notice this.
    final replacement = {'replacement': true};
    t.events.whereType<ToolResultEvent>().single.data['meta'] = replacement;
    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(user(3)))));

    final after = toolOf(t, 'c1');
    expect(identical(after, before), isFalse);
    expect(identical(after.meta, replacement), isTrue);
  });

  test('approval asked and decided each flip the identity exactly once', () {
    final t = seeded([ev(0, 'turn/start', {'turn': 1}), call(1, 'c1')]);
    final running = toolOf(t, 'c1');

    t.apply(
      parseFollowFrame(
        's',
        jsonDecode(jsonEncode(ev(2, 'approval/asked', {'id': 'a1', 'toolName': 'name-c1', 'callId': 'c1'}))),
      ),
    );
    final asked = toolOf(t, 'c1');
    expect(identical(asked, running), isFalse);
    expect(asked.status, ToolStatus.awaitingApproval);
    expect(asked.pendingApproval, isNull);

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(user(3)))));
    expect(identical(toolOf(t, 'c1'), asked), isTrue);

    t.apply(
      parseFollowFrame(
        's',
        jsonDecode(jsonEncode(ev(4, 'approval/decided', {'id': 'a1', 'outcome': 'allowed-once'}))),
      ),
    );
    final decided = toolOf(t, 'c1');
    expect(identical(decided, asked), isFalse);
    expect(decided.approvalOutcome, ApprovalOutcome.allowedOnce);
    expect(decided.status, ToolStatus.running);

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(user(5)))));
    expect(identical(toolOf(t, 'c1'), decided), isTrue);
  });

  test('turn end cancels unresolved tools once and then stays stable', () {
    final t = seeded([ev(0, 'turn/start', {'turn': 1}), call(1, 'c1')]);
    final running = toolOf(t, 'c1');

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(end(2)))));
    final cancelled = toolOf(t, 'c1');
    expect(identical(cancelled, running), isFalse);
    expect(cancelled.status, ToolStatus.cancelled);

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(user(3)))));
    expect(identical(toolOf(t, 'c1'), cancelled), isTrue);

    t.apply(parseFollowFrame('s', jsonDecode(jsonEncode(end(4)))));
    expect(identical(toolOf(t, 'c1'), cancelled), isTrue, reason: 'a second end event changes nothing');
  });

  test('draft streaming keeps durable tool identities intact', () {
    final t = seeded([ev(0, 'turn/start', {'turn': 1}), call(1, 'c1'), result(2, 'c1')]);
    final done = toolOf(t, 'c1');

    // Assistant drafts are not log events; every chunk re-runs the fold build
    // while the durable log stays untouched.
    t.apply(AssistantStreamStarted('att', 0, turn: 1, step: 1, startedAfterSeq: 2));
    for (var i = 0; i < 5; i++) {
      t.apply(AssistantChunkEvent('att', 1, index: i, time: DateTime(2026), chunk: TextDeltaChunk(i, 'x$i')));
      final streaming = t.items.whereType<AssistantChatItem>().toList();
      expect(streaming, hasLength(1));
      expect(streaming.single.streaming, isTrue);
      expect(identical(toolOf(t, 'c1'), done), isTrue, reason: 'chunk $i must not touch the durable tool item');
    }

    t.apply(const AssistantStreamEnded('att', 5, index: 5, committed: false, committedSeq: null));
    expect(identical(toolOf(t, 'c1'), done), isTrue);
  });
}
