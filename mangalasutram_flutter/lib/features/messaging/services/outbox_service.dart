import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/di.dart';
import 'chat_service.dart';

/// A pending message waiting to be sent when connectivity restores
class PendingMessage {
  final String localId;
  final String conversationId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  bool isRetrying;

  PendingMessage({
    required this.localId,
    required this.conversationId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRetrying = false,
  });

  Map<String, dynamic> toMap() => {
    'localId': localId,
    'conversationId': conversationId,
    'receiverId': receiverId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// Manages an in-memory outbox for messages sent while offline.
/// On reconnect, auto-flushes all pending messages in order.
class OutboxService {
  OutboxService._();
  static final OutboxService instance = OutboxService._();

  final List<PendingMessage> _queue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFlushing = false;
  bool _isConnected = true;

  /// Notifies listeners about queue changes (for UI clock icon updates)
  final ValueNotifier<List<PendingMessage>> queueNotifier = ValueNotifier([]);

  void initialize() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final wasConnected = _isConnected;
      _isConnected = results.any((r) => r != ConnectivityResult.none);
      debugPrint('[Outbox] Connectivity: $_isConnected (was: $wasConnected)');
      if (!wasConnected && _isConnected && _queue.isNotEmpty) {
        debugPrint('[Outbox] Reconnected — flushing ${_queue.length} pending messages');
        _flushQueue();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    queueNotifier.dispose();
  }

  bool get isConnected => _isConnected;

  List<PendingMessage> get pendingMessages => List.unmodifiable(_queue);

  bool hasPendingFor(String conversationId) =>
      _queue.any((m) => m.conversationId == conversationId);

  /// Enqueue a message for later sending (when offline)
  PendingMessage enqueue({
    required String conversationId,
    required String receiverId,
    required String content,
  }) {
    final msg = PendingMessage(
      localId: '${DateTime.now().millisecondsSinceEpoch}_${receiverId.substring(0, 6)}',
      conversationId: conversationId,
      receiverId: receiverId,
      content: content,
      createdAt: DateTime.now(),
    );
    _queue.add(msg);
    queueNotifier.value = List.from(_queue);
    debugPrint('[Outbox] Enqueued message "${content.substring(0, content.length.clamp(0, 30))}..." (queue size: ${_queue.length})');
    return msg;
  }

  void removePending(String localId) {
    _queue.removeWhere((m) => m.localId == localId);
    queueNotifier.value = List.from(_queue);
  }

  /// Immediately attempt to flush all pending messages
  Future<void> _flushQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;

    final chatService = getIt<ChatService>();
    final toFlush = List<PendingMessage>.from(_queue);

    for (final msg in toFlush) {
      if (!_isConnected) break; // Stop if disconnected again mid-flush
      msg.isRetrying = true;
      queueNotifier.value = List.from(_queue);

      try {
        final success = await chatService.sendMessage(
          conversationId: msg.conversationId,
          receiverId: msg.receiverId,
          content: msg.content,
        );
        if (success) {
          _queue.remove(msg);
          queueNotifier.value = List.from(_queue);
          debugPrint('[Outbox] Flushed message ${msg.localId}');
        } else {
          msg.isRetrying = false;
        }
      } catch (e) {
        msg.isRetrying = false;
        debugPrint('[Outbox] Failed to flush ${msg.localId}: $e');
      }
    }

    _isFlushing = false;
    queueNotifier.value = List.from(_queue);
  }

  /// Manually trigger a flush attempt (call after re-open app)
  Future<void> manualFlush() => _flushQueue();
}
