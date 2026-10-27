import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../constants/theme.dart';
import '../../../core/di.dart';
import '../../auth/services/supabase_service.dart';
import '../../profile/screens/profile_detail_screen.dart';
import '../../profile/services/profile_service.dart';
import '../../profile/widgets/safety_action_sheet.dart';
import '../services/chat_service.dart';
import '../services/outbox_service.dart';
import '../../family/services/family_service.dart';

class ChatConversationScreen extends StatefulWidget {
  final String? conversationId;
  final String profileId;
  final String name;
  final String? photoUrl;
  final String? subcaste;
  final bool isVerified;
  final bool isOnline;

  const ChatConversationScreen({
    super.key,
    this.conversationId,
    required this.profileId,
    required this.name,
    this.photoUrl,
    this.subcaste,
    this.isVerified = true,
    this.isOnline = true,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = getIt<ChatService>();
  final OutboxService _outbox = OutboxService.instance;

  String? _activeConvId;
  bool _isLoadingConv = true;
  bool _isSending = false;
  bool _isOnline = true;
  bool _isUploadingFile = false;

  // Local pending messages shown in UI while offline
  List<Map<String, dynamic>> _pendingMessages = [];
  CandidateContextModel? _myGuardianContext;
  RealtimeChannel? _candidateVetoChannel;

  String? get _effectiveMyId {
    final candId = _myGuardianContext?.candidateId;
    if (candId != null && candId.isNotEmpty) return candId;
    return _chatService.currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _initConversation();
    _checkConnectivity();
    _loadGuardianContext();
    _outbox.queueNotifier.addListener(_onOutboxChanged);
    Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = connected);
    });
  }

  Future<void> _loadGuardianContext() async {
    try {
      final ctx = await FamilyService.instance.getGuardianActiveCandidate();
      if (mounted && ctx != null) {
        setState(() => _myGuardianContext = ctx);
        _subscribeCandidateVeto(ctx.candidateId);
      }
    } catch (_) {}
  }

  void _subscribeCandidateVeto(String candidateId) {
    if (candidateId.isEmpty || _candidateVetoChannel != null) return;
    try {
      _candidateVetoChannel = SupabaseService.client
          .channel('public:candidate_veto:$candidateId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: candidateId,
            ),
            callback: (_) async {
              final updated = await FamilyService.instance.getGuardianActiveCandidate();
              if (mounted && updated != null) {
                setState(() => _myGuardianContext = updated);
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = results.any((r) => r != ConnectivityResult.none));
    }
  }

  void _onOutboxChanged() {
    if (!mounted) return;
    final pending = _outbox.pendingMessages
        .where((m) => m.conversationId == (_activeConvId ?? ''))
        .map((m) => {
              'content': m.content,
              'sender_id': _effectiveMyId,
              'is_pending': true,
              'is_retrying': m.isRetrying,
              'created_at': m.createdAt.toIso8601String(),
              'local_id': m.localId,
            })
        .toList();
    setState(() => _pendingMessages = pending);
  }

  Future<void> _initConversation() async {
    await _chatService.initE2EE();

    if (widget.conversationId != null) {
      _activeConvId = widget.conversationId;
    } else {
      _activeConvId = await _chatService.getOrCreateConversation(widget.profileId);
    }

    if (mounted) {
      setState(() {
        _isLoadingConv = false;
      });
      if (_activeConvId != null) {
        _chatService.markDelivered(_activeConvId!);
        _chatService.markAsRead(_activeConvId!);
      }
    }
  }

  @override
  void dispose() {
    if (_candidateVetoChannel != null) {
      SupabaseService.client.removeChannel(_candidateVetoChannel!);
    }
    _outbox.queueNotifier.removeListener(_onOutboxChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_myGuardianContext != null && !_myGuardianContext!.allowGuardianProxyChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_myGuardianContext!.candidateName} has paused parent proxy messaging.',
          ),
          backgroundColor: const Color(0xFF92400E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty || _activeConvId == null || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    if (!_isOnline) {
      // ── OFFLINE: queue to outbox with 🕒 pending state ──────────────────
      _outbox.enqueue(
        conversationId: _activeConvId!,
        receiverId: widget.profileId,
        content: text,
      );
      if (mounted) setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Message queued — will send when online', style: GoogleFonts.inter(fontSize: 13)),
          ]),
          backgroundColor: const Color(0xFF92400E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ── ONLINE: send immediately ─────────────────────────────────────────
    final success = await _chatService.sendMessage(
      conversationId: _activeConvId!,
      receiverId: widget.profileId,
      content: text,
      senderRole: _myGuardianContext?.guardianRole,
      onBehalfOf: _myGuardianContext?.candidateId,
    );

    if (mounted) setState(() => _isSending = false);

    if (success) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } else if (mounted && _myGuardianContext != null) {
      await _loadGuardianContext();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _myGuardianContext!.allowGuardianProxyChat
                  ? 'Unable to send proxy message. Please try again.'
                  : '${_myGuardianContext!.candidateName} has paused parent proxy messaging.',
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// File/image picker + upload to Supabase Storage, then send link as message
  Future<void> _pickAndSendFile() async {
    if (_activeConvId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text('Share File or Photo', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_rounded, color: Color(0xFFD97706)),
                title: Text('Gallery Photo / Video', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null && mounted) await _uploadAndSend(File(picked.path), 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text('Camera Photo', style: GoogleFonts.inter(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null && mounted) await _uploadAndSend(File(picked.path), 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                title: Text('Horoscope / Jatakam PDF', style: GoogleFonts.inter(fontSize: 14)),
                subtitle: Text('Share your Kundali securely', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (result != null && result.files.single.path != null && mounted) {
                    await _uploadAndSend(File(result.files.single.path!), 'pdf');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndSend(File file, String type) async {
    if (!mounted) return;
    setState(() => _isUploadingFile = true);

    try {
      final myId = _chatService.currentUserId ?? 'unknown';
      final ext = file.path.split('.').last;
      final fileName = '${_activeConvId!}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'chat_attachments/$myId/$fileName';

      await SupabaseService.client.storage
          .from('chat-files')
          .upload(storagePath, file,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      String fileUrl;
      try {
        fileUrl = await SupabaseService.client.storage
            .from('chat-files')
            .createSignedUrl(storagePath, 60 * 60 * 24 * 7);
      } catch (_) {
        fileUrl = SupabaseService.client.storage
            .from('chat-files')
            .getPublicUrl(storagePath);
      }

      final emoji = type == 'pdf' ? '📄' : '🖼️';
      final label = type == 'pdf' ? 'Kundali PDF' : 'Photo';
      final messageText = '$emoji $label shared: $fileUrl';

      await _chatService.sendMessage(
        conversationId: _activeConvId!,
        receiverId: widget.profileId,
        content: messageText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label sent securely 🔒'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint('[Chat Upload Error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: ${e.toString().substring(0, 60)}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _effectiveMyId;
    final isDeleted = msg['is_deleted'] == true;
    final messageId = msg['id'] as String;
    final text = msg['content'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isDeleted)
                  ListTile(
                    leading: const Icon(Icons.copy_rounded, color: Color(0xFF2B2118)),
                    title: Text('Copy Message', style: GoogleFonts.inter(fontSize: 14)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied to clipboard')),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
                  title: Text('Delete for Me', style: GoogleFonts.inter(fontSize: 14)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _chatService.deleteMessage(messageId: messageId, deleteForEveryone: false);
                  },
                ),
                if (isMe && !isDeleted)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: Text('Delete for Everyone', style: GoogleFonts.inter(fontSize: 14, color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _chatService.deleteMessage(messageId: messageId, deleteForEveryone: true);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Chat History?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: Text(
          'This will clear all messages on your device. Messages will remain visible to ${widget.name.split(" ").first}.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && _activeConvId != null) {
      await _chatService.clearConversationHistory(_activeConvId!);
    }
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = timestamp is DateTime ? timestamp : DateTime.parse(timestamp.toString()).toLocal();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMyId = _effectiveMyId;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Offline Banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: const Color(0xFF92400E),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text('Offline — messages queued until reconnected',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
              ]),
            ),

          // E2EE Trust & Security Badge
          _buildSecurityBanner(),
          
          // Transparency Notice (If Proxy Active)
          _buildTransparencyBanner(),

          // Messages Stream
          Expanded(
            child: _isLoadingConv
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _activeConvId == null
                    ? _buildErrorPlaceholder()
                    : StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _chatService.getMessagesStream(_activeConvId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }

                          final messages = snapshot.data ?? [];
                          final allMessages = [...messages, ..._pendingMessages];

                          if (allMessages.isEmpty) return _buildEmptyChatPlaceholder();

                          if (_activeConvId != null) {
                            _chatService.markDelivered(_activeConvId!);
                            _chatService.markAsRead(_activeConvId!);
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            itemCount: allMessages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    children: [
                                      const Expanded(child: Divider(color: Color(0xFFE5DCD3))),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFEBE5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Today, Auspicious Muhurtham',
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5A4A42)),
                                        ),
                                      ),
                                      const Expanded(child: Divider(color: Color(0xFFE5DCD3))),
                                    ],
                                  ),
                                );
                              }

                              final msg = allMessages[index - 1];
                              final isPending = msg['is_pending'] == true;
                              final isMe = msg['sender_id'] == effectiveMyId;
                              final time = _formatMessageTime(msg['created_at']);
                              final isRead = msg['is_read'] == true;
                              final isDelivered = msg['is_delivered'] == true;
                              final isDeleted = msg['is_deleted'] == true;
                              final proxySenderRole = msg['proxy_sender_role'] as String?;

                              if (isPending) {
                                return _buildMessageBubble(
                                  text: msg['content'] ?? '',
                                  isMe: true,
                                  time: time,
                                  isRead: false,
                                  isDelivered: false,
                                  isDeleted: false,
                                  isPending: true,
                                  proxySenderRole: proxySenderRole ?? _myGuardianContext?.guardianRole,
                                );
                              }

                              return GestureDetector(
                                onLongPress: () => _showMessageOptions(msg),
                                child: _buildMessageBubble(
                                  text: msg['content'] ?? '',
                                  isMe: isMe,
                                  time: time,
                                  isRead: isRead,
                                  isDelivered: isDelivered,
                                  isDeleted: isDeleted,
                                  proxySenderRole: proxySenderRole,
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),

          // Bottom Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF6E1732),
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEDE4DC),
                backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                    ? NetworkImage(widget.photoUrl!)
                    : null,
                child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                    ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                    : null,
              ),
              if (widget.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: Color(0xFFD97706), size: 14),
                    ],
                  ],
                ),
                Text(
                  widget.subcaste ?? (widget.isOnline ? 'Online now' : 'Offline'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_rounded, color: Color(0xFFC99A4B)),
          onPressed: () {},
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFC99A4B)),
          onSelected: (val) async {
            if (val == 'profile') {
              final profile = await ProfileService().getProfileById(widget.profileId);
              if (mounted && profile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileDetailScreen(profile: profile),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile details are currently unavailable.'),
                  ),
                );
              }
            } else if (val == 'clear') {
              _confirmClearChat();
            } else if (val == 'safety') {
              SafetyActionSheet.show(
                context,
                profileId: widget.profileId,
                fullName: widget.name,
                onBlocked: () => Navigator.pop(context),
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF2B2118)),
                  SizedBox(width: 8),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.cleaning_services_rounded, size: 18, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Clear Chat'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'safety',
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: Color(0xFFC62828)),
                  SizedBox(width: 8),
                  Text('Block / Report', style: TextStyle(color: Color(0xFFC62828))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      color: const Color(0xFFFFFBEB),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'End-to-End Encrypted. Messages are private between parties.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparencyBanner() {
    if (_myGuardianContext == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE68A).withValues(alpha: 0.4),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF92400E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2B2118), height: 1.4),
                children: [
                  TextSpan(
                    text: 'GUARDIAN PROXY MODE: ',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF6E1732)),
                  ),
                  TextSpan(
                    text: 'Viewing alliance thread for ${_myGuardianContext!.candidateName} as ${_myGuardianContext!.guardianRole}. Messages sent by you carry a "🏷️ Sent by ${_myGuardianContext!.guardianRole}" badge.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Mutual Interest Accepted!',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B2118),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Start the auspicious conversation by saying Namaskaram to ${widget.name.split(" ").first}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF8C7B6E),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Text(
        'Unable to initialize secure chat channel.',
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF8C7B6E)),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String time,
    required bool isRead,
    required bool isDelivered,
    required bool isDeleted,
    bool isPending = false,
    String? proxySenderRole,
  }) {
    final hasRoleBadge = proxySenderRole != null &&
        proxySenderRole.isNotEmpty &&
        proxySenderRole.toLowerCase() != 'candidate';

    final senderName = hasRoleBadge
        ? '🏷️ Sent by $proxySenderRole'
        : (isMe ? 'You' : widget.name);
    final headerColor = isMe ? const Color(0xFFE6C786) : const Color(0xFF6E1732);

    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDeleted
                ? (isMe ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.shade200)
                : (isMe ? AppColors.primary : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: isMe ? null : Border.all(color: const Color(0xFFE5DCD3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasRoleBadge) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFFC99A4B).withValues(alpha: 0.22)
                        : const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFC99A4B).withValues(alpha: 0.55),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    senderName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                    ),
                  ),
                ),
              ] else if (!isMe) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: headerColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                  color: isMe ? Colors.white : const Color(0xFF2B2118),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : const Color(0xFF9E8E81),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isMe && !isDeleted) ...[
                      const SizedBox(width: 4),
                      isPending
                          ? const Icon(Icons.schedule_rounded, size: 13, color: Colors.white54)
                          : _buildTickIcon(isRead: isRead, isDelivered: isDelivered),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // TAIL
        Positioned(
          top: 14,
          right: isMe ? -4 : null,
          left: isMe ? null : -4,
          child: Transform.rotate(
            angle: 45 * 3.1415927 / 180,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                border: isMe ? null : const Border(
                  left: BorderSide(color: Color(0xFFE5DCD3), width: 1),
                  bottom: BorderSide(color: Color(0xFFE5DCD3), width: 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: bubble,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFEDE4DC),
              backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                  ? NetworkImage(widget.photoUrl!)
                  : null,
              child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                  ? const Icon(Icons.person, color: AppColors.primary, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            bubble,
          ],
        ),
      ),
    );
  }

  Widget _buildTickIcon({required bool isRead, required bool isDelivered}) {
    if (isRead) {
      return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFFFDE68A));
    } else if (isDelivered) {
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
    } else {
      return const Icon(Icons.done_rounded, size: 14, color: Colors.white60);
    }
  }

  Widget _buildInputBar() {
    final isVetoedGuardian =
        _myGuardianContext != null && !_myGuardianContext!.allowGuardianProxyChat;

    if (isVetoedGuardian) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF9),
          border: Border(top: BorderSide(color: Color(0xFFE5DCD3), width: 0.8)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EFE6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD6C8B4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_person_rounded, color: Color(0xFF6E1732), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'View-Only Mode — ${_myGuardianContext!.candidateName} has paused parent proxy messaging.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5A4A42),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F6F0),
      ),
      child: Row(
        children: [
          // ── File/Image Attachment Button (Paperclip) ───────────────────────────────
          GestureDetector(
            onTap: _isUploadingFile ? null : _pickAndSendFile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _isUploadingFile
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.attach_file_rounded, color: Color(0xFF5A4A42), size: 26),
            ),
          ),
          const SizedBox(width: 4),

          // ── Message Input (Grey Pill) ─────────────────────────────────────────────
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBE5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF2B2118)),
                decoration: InputDecoration(
                  hintText: _isOnline ? 'Type a message as ${_myGuardianContext?.guardianRole ?? "Candidate"}...' : '🕒 Offline — message will queue...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF8C7B6E)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── Mic Button (Gold) ───────────────────────────────────────────────
          GestureDetector(
            onTap: () {
               // Future: implement voice notes
            },
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFC99A4B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_none_rounded,
                color: Colors.white, size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Send Button (Burgundy) ───────────────────────────────────────────────
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF6E1732),
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Center(child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white, size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
