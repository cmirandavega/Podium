import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../models/league.dart';
import '../../services/chat_service.dart';
import '../../services/league_service.dart';
import '../../theme.dart';

/// Use Case 7: real-time league chat. Long-press a message to report it,
/// delete it, or (for moderators) mute its sender.
class LeagueChatScreen extends StatefulWidget {
  const LeagueChatScreen({super.key, required this.league, required this.user});

  final League league;
  final AppUser user;

  @override
  State<LeagueChatScreen> createState() => _LeagueChatScreenState();
}

class _LeagueChatScreenState extends State<LeagueChatScreen> {
  final _chat = ChatService();
  final _input = TextEditingController();
  late final Stream<List<ChatMessage>> _messages = _chat.watchMessages(widget.league.id);
  late final Stream<List<LeagueMember>> _members = LeagueService().watchMembers(widget.league.id);
  bool _sending = false;

  bool get _isModerator =>
      widget.league.isCommissioner(widget.user.uid) || widget.user.isAdmin;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send(LeagueMember me) async {
    final error = ChatService.validateBody(_input.text);
    if (error != null) {
      _toast(error);
      return;
    }
    setState(() => _sending = true);
    try {
      await _chat.send(league: widget.league, me: me, body: _input.text);
      _input.clear();
    } catch (error) {
      // Keep the typed text so the user can retry.
      if (mounted) _toast('Message not sent: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _actions(ChatMessage message, Map<String, LeagueMember> members) async {
    final mine = message.senderId == widget.user.uid;
    final sender = members[message.senderId];
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            if (mine || _isModerator)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            if (_isModerator && !mine && sender != null)
              ListTile(
                leading: Icon(sender.isMuted ? Icons.volume_up : Icons.volume_off),
                title: Text(sender.isMuted ? 'Unmute @${sender.username}' : 'Mute @${sender.username}'),
                onTap: () => Navigator.pop(context, 'mute'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      switch (choice) {
        case 'report':
          await _chat.reportMessage(message: message, leagueName: widget.league.name);
          _toast('Report sent to the admins.');
        case 'delete':
          await _chat.deleteMessage(leagueId: widget.league.id, messageId: message.id);
          _toast('Message deleted.');
        case 'mute':
          await _chat.setMuted(
            leagueId: widget.league.id,
            userId: message.senderId,
            muted: !sender!.isMuted,
          );
          _toast(sender.isMuted ? '@${sender.username} can chat again.' : '@${sender.username} is muted.');
      }
    } catch (error) {
      _toast('$error');
    }
  }

  String _time(DateTime? t) {
    if (t == null) return 'sending...';
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay = now.year == t.year && now.month == t.month && now.day == t.day;
    final day = sameDay ? '' : '${t.month}/${t.day} ';
    return '$day$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _bubble(ChatMessage m, Map<String, LeagueMember> members) {
    final mine = m.senderId == widget.user.uid;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: m.isDeleted ? null : () => _actions(m, members),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? PodiumColors.gold.withValues(alpha: 0.2) : PodiumColors.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: mine ? PodiumColors.gold : PodiumColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mine ? 'You' : '@${m.senderName}'} · ${_time(m.createdAt)}',
                style: const TextStyle(fontSize: 12, color: PodiumColors.muted),
              ),
              const SizedBox(height: 4),
              m.isDeleted
                  ? const Text('Message deleted',
                      style: TextStyle(fontStyle: FontStyle.italic, color: PodiumColors.muted))
                  : Text(m.body),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.league.name} Chat')),
      body: StreamBuilder<List<LeagueMember>>(
        stream: _members,
        builder: (context, memberSnap) {
          final members = {for (final m in memberSnap.data ?? const <LeagueMember>[]) m.userId: m};
          final me = members[widget.user.uid];
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messages,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Unable to load chat.'));
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('No messages yet. Say hi to your league.',
                            style: TextStyle(color: PodiumColors.muted)),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (context, i) => _bubble(messages[i], members),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: me == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      )
                    : me.isMuted
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'A moderator muted you in this league, so you can read but not send messages.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: PodiumColors.muted),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _input,
                                    minLines: 1,
                                    maxLines: 4,
                                    maxLength: ChatMessage.maxLength,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sending ? null : _send(me),
                                    decoration: const InputDecoration(
                                      hintText: 'Message your league',
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Send',
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send, color: PodiumColors.gold),
                                  onPressed: _sending ? null : () => _send(me),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
