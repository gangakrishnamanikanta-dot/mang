import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di.dart';
import '../../auth/services/supabase_service.dart';
import '../../family/services/family_service.dart';
import 'e2ee_crypto_service.dart';

class ChatService {
  final SupabaseClient _client = SupabaseService.client;
  final E2eeCryptoService _crypto = getIt<E2eeCryptoService>();

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Ensures E2EE keys are generated and synced with backend
  Future<void> initE2EE() async {
    await _crypto.initializeKeys();
  }

  /// Fetches all active conversations for the logged in user (or linked Candidate if Guardian)
  Future<List<Map<String, dynamic>>> getConversations() async {
    final myId = currentUserId;
    if (myId == null) return [];

    try {
      final guardianCtx = await FamilyService.instance.getGuardianActiveCandidate();
      final effectiveUserId =
          (guardianCtx != null && guardianCtx.candidateId.isNotEmpty)
              ? guardianCtx.candidateId
              : myId;

      final response = await _client
          .from('conversations')
          .select('''
            id,
            user1_id,
            user2_id,
            last_message,
            last_message_nonce,
            last_message_time,
            last_sender_id,
            user1_unread_count,
            user2_unread_count,
            created_at,
            user1:user1_id (id, full_name, profile_photo_url, sub_caste, is_verified),
            user2:user2_id (id, full_name, profile_photo_url, sub_caste, is_verified)
          ''')
          .or('user1_id.eq.$effectiveUserId,user2_id.eq.$effectiveUserId')
          .order('last_message_time', ascending: false);

      final List<Map<String, dynamic>> results = [];

      for (final row in response) {
        final isUser1 = row['user1_id'] == effectiveUserId;
        final otherUser = isUser1 ? row['user2'] : row['user1'];
        final unreadCount = isUser1
            ? (row['user1_unread_count'] as int? ?? 0)
            : (row['user2_unread_count'] as int? ?? 0);

        if (otherUser != null) {
          final otherId = otherUser['id'] as String;
          String displayLastMessage = row['last_message'] ?? '';
          final nonce = row['last_message_nonce'] as String? ?? '';

          if (displayLastMessage.startsWith('e2ee:')) {
            try {
              displayLastMessage = await _crypto.decryptMessage(
                conversationId: row['id'],
                ciphertext: displayLastMessage,
                nonce: nonce,
              );
            } catch (_) {
              displayLastMessage = '🔒 [Encrypted Message]';
            }
          }

          results.add({
            'conversation_id': row['id'],
            'other_user_id': otherId,
            'name': otherUser['full_name'] ?? 'Member',
            'photo_url': otherUser['profile_photo_url'],
            'subcaste': otherUser['sub_caste'] ?? 'Brahmin',
            'is_verified': otherUser['is_verified'] == true,
            'last_message': displayLastMessage,
            'last_message_time': row['last_message_time'],
            'unread_count': unreadCount,
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('[ChatService] Error fetching conversations: $e');
      return [];
    }
  }

  /// Real-time stream of messages with automatic on-the-fly E2EE decryption, Delivery ACK & Deletion Filtering
  Stream<List<Map<String, dynamic>>> getMessagesStream(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .asyncMap((rawList) async {
          final myId = currentUserId;

          // Auto-trigger delivery ACK in background for any un-delivered incoming messages
          if (myId != null) {
            final hasUndelivered = rawList.any((m) => m['sender_id'] != myId && m['is_delivered'] != true);
            if (hasUndelivered) {
              markDelivered(conversationId);
            }
          }

          final List<Map<String, dynamic>> decryptedList = [];

          for (final raw in rawList) {
            // Check if deleted for current user
            final deletedFor = List<dynamic>.from(raw['deleted_for_users'] ?? []);
            if (myId != null && deletedFor.contains(myId)) {
              continue; // Skip message deleted for me
            }

            final isDeleted = raw['is_deleted'] == true;
            final ciphertext = raw['content'] as String? ?? '';
            final nonce = raw['nonce'] as String? ?? '';

            String plainText = ciphertext;
            if (isDeleted) {
              plainText = '🚫 This message was deleted';
            } else if (ciphertext.startsWith('e2ee:')) {
              try {
                plainText = await _crypto.decryptMessage(
                  conversationId: conversationId,
                  ciphertext: ciphertext,
                  nonce: nonce,
                );
              } catch (_) {
                plainText = '🔒 [Encrypted Message]';
              }
            } else {
              // Safety net: never expose non-encrypted content to UI
              plainText = '🔒 [Encrypted Message]';
            }

            final messageMap = Map<String, dynamic>.from(raw);
            messageMap['content'] = plainText;
            decryptedList.add(messageMap);
          }

          return decryptedList;
        });
  }

  /// Sends a new E2EE encrypted message in a conversation
  Future<bool> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
    String? senderRole,
    String? onBehalfOf,
  }) async {
    final myId = currentUserId;
    if (myId == null || content.trim().isEmpty) return false;

    try {
      // 1. Client-side X25519 + AES-GCM encryption
      final encrypted = await _crypto.encryptMessage(
        conversationId: conversationId,
        plaintext: content.trim(),
      );

      final isProxy = senderRole != null && senderRole.isNotEmpty && senderRole.toLowerCase() != 'candidate';

      if (isProxy) {
        await _client.rpc('send_proxy_message', params: {
          'p_conversation_id': conversationId,
          'p_receiver_id': receiverId,
          'p_content': encrypted['ciphertext'],
          'p_nonce': encrypted['nonce'] ?? '',
          'p_sender_role': senderRole,
          'p_on_behalf_of': onBehalfOf,
        });
      } else {
        await _client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_id': myId,
          'receiver_id': receiverId,
          'content': encrypted['ciphertext'],
          'nonce': encrypted['nonce'],
          'is_delivered': false,
          'is_read': false,
        });
      }

      return true;
    } catch (e) {
      debugPrint('[ChatService] Error sending encrypted message: $e');
      return false;
    }
  }

  /// Deletes a message ("Delete for Everyone" or "Delete for Me")
  Future<bool> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final res = await _client.rpc('delete_message', params: {
        'p_message_id': messageId,
        'p_delete_for_everyone': deleteForEveryone,
      });
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[ChatService] Error deleting message: $e');
      return false;
    }
  }

  /// Clears all past message history for caller in a conversation
  Future<bool> clearConversationHistory(String conversationId) async {
    try {
      final res = await _client.rpc('clear_conversation_history', params: {
        'p_conversation_id': conversationId,
      });
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[ChatService] Error clearing conversation: $e');
      return false;
    }
  }

  /// Gets existing or creates a new conversation with a target user
  Future<String?> getOrCreateConversation(String otherUserId) async {
    try {
      final res = await _client.rpc(
        'get_or_create_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      return res as String?;
    } catch (e) {
      debugPrint('[ChatService] Error getting or creating conversation: $e');
      return null;
    }
  }

  /// Acknowledges delivery receipt for incoming messages
  Future<void> markDelivered(String conversationId) async {
    final myId = currentUserId;
    if (myId == null) return;

    try {
      await _client.rpc('mark_messages_delivered', params: {
        'p_conversation_id': conversationId,
      });
    } catch (e) {
      debugPrint('[ChatService] Error marking messages delivered: $e');
    }
  }

  /// Marks unread messages as read atomically
  Future<void> markAsRead(String conversationId) async {
    final myId = currentUserId;
    if (myId == null) return;

    try {
      await _client.rpc('mark_conversation_read', params: {
        'p_conversation_id': conversationId,
      });
    } catch (e) {
      debugPrint('[ChatService] Error marking messages as read: $e');
    }
  }
}
