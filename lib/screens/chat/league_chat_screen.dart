import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../models/league.dart';
import '../../services/chat_service.dart';
import '../../services/league_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';

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

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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

  /// Turns "Bad state: ..." and similar wrappers into the plain message.
  String _clean(Object error) {
    final text = '$error';
    final colon = text.indexOf(': ');
    return colon > 0 && colon < 30 ? text.substring(colon + 2) : text;
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
      if (mounted) _toast('Message not sent: ${_clean(error)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _actions(ChatMessage message, Map<String, LeagueMember> members) async {
    final mine = message.senderId == widget.user.uid;
    final sender = members[message.senderId];
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: PodiumColors.field,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                message.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: PodiumColors.muted, fontSize: 13),
              ),
            ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: PodiumColors.dangerText),
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
                leading: Icon(sender.isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
                title: Text(sender.isMuted ? 'Unmute @${sender.username}' : 'Mute @${sender.username}'),
                onTap: () => Navigator.pop(context, 'mute'),
              ),
            const SizedBox(height: 8),
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
      _toast(_clean(error));
    }
  }

  String _time(DateTime? t) {
    if (t == null) return 'Sending...';
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    if (_sameDay(t, now)) return 'Today';
    if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${_weekdays[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}';
  }

  /// [messages] is newest first. A message starts a new group (name and avatar
  /// shown) when the older message before it is from someone else, on another
  /// day, or more than 10 minutes earlier.
  bool _startsGroup(List<ChatMessage> messages, int i) {
    if (i == messages.length - 1) return true;
    final m = messages[i];
    final older = messages[i + 1];
    if (older.senderId != m.senderId) return true;
    final a = m.createdAt;
    final b = older.createdAt;
    if (a == null || b == null) return false;
    return !_sameDay(a, b) || a.difference(b).inMinutes > 10;
  }

  bool _startsDay(List<ChatMessage> messages, int i) {
    final t = messages[i].createdAt;
    if (t == null) return false;
    if (i == messages.length - 1) return true;
    final older = messages[i + 1].createdAt;
    return older == null || !_sameDay(t, older);
  }

  Widget _dayChip(DateTime t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(indent: 20, endIndent: 12)),
          Text(_dayLabel(t).toUpperCase(), style: PodiumText.overline.copyWith(fontSize: 11)),
          const Expanded(child: Divider(indent: 12, endIndent: 20)),
        ],
      ),
    );
  }

  Widget _message(List<ChatMessage> messages, int i, Map<String, LeagueMember> members) {
    final m = messages[i];
    final mine = m.senderId == widget.user.uid;
    final first = _startsGroup(messages, i);
    final name = members[m.senderId]?.username ?? m.senderName;
    final isCommissioner = widget.league.isCommissioner(m.senderId);

    final bubble = GestureDetector(
      onLongPress: m.isDeleted ? null : () => _actions(m, members),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        decoration: BoxDecoration(
          color: m.isDeleted
              ? Colors.transparent
              : mine
                  ? PodiumColors.line
                  : PodiumColors.field,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(!mine && first ? 4 : 18),
            topRight: Radius.circular(mine && first ? 4 : 18),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
          border: mine && !m.isDeleted ? null : Border.all(color: PodiumColors.line),
        ),
        child: m.isDeleted
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, size: 14, color: PodiumColors.muted),
                  SizedBox(width: 6),
                  Text(
                    'Message deleted',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: PodiumColors.muted),
                  ),
                ],
              )
            : Text(m.body, style: const TextStyle(fontSize: 14, height: 1.4)),
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine) ...[
            Text(
              '@$name',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PodiumColors.silver),
            ),
            if (isCommissioner) ...[
              const SizedBox(width: 6),
              Text('COMMISH', style: PodiumText.overline.copyWith(fontSize: 10, color: PodiumColors.gold)),
            ],
            const SizedBox(width: 8),
          ],
          Text(_time(m.createdAt), style: PodiumText.caption.copyWith(fontSize: 11)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_startsDay(messages, i)) _dayChip(m.createdAt!),
        Padding(
          padding: EdgeInsets.fromLTRB(16, first ? 10 : 3, 16, 0),
          child: Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) ...[
                first
                    ? InitialsAvatar(
                        name: name,
                        size: 34,
                        ring: isCommissioner ? PodiumColors.gold : PodiumColors.line,
                      )
                    : const SizedBox(width: 34),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (first) header,
                    bubble,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _composer(LeagueMember? me) {
    Widget body;
    if (me == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    } else if (me.isMuted) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.volume_off_outlined, size: 18, color: PodiumColors.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'A moderator muted you in this league. You can read but not send messages.',
                style: TextStyle(color: PodiumColors.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    } else {
      body = Row(
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
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: PodiumColors.gold,
              foregroundColor: PodiumColors.navy,
              disabledBackgroundColor: PodiumColors.line,
              disabledForegroundColor: PodiumColors.muted,
              fixedSize: const Size(50, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PodiumRadii.control),
              ),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: PodiumColors.navy),
                  )
                : const Icon(Icons.arrow_upward_rounded),
            onPressed: _sending ? null : () => _send(me),
          ),
        ],
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: PodiumColors.deep,
        border: Border(top: BorderSide(color: PodiumColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberCount = widget.league.memberIds.length;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const TintedIcon(
              icon: Icons.forum_outlined,
              color: PodiumColors.navy,
              background: PodiumColors.gold,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.league.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    'League chat · $memberCount ${memberCount == 1 ? 'member' : 'members'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: PodiumColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: EmptyCard(
                            icon: Icons.cloud_off_outlined,
                            title: 'Unable to load chat',
                            message: 'Check your connection and open the chat again.',
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: EmptyCard(
                            icon: Icons.forum_outlined,
                            title: 'No messages yet',
                            message: 'Say hi to your league. Long-press any message later to report or delete it.',
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      itemCount: messages.length,
                      itemBuilder: (context, i) => _message(messages, i, members),
                    );
                  },
                ),
              ),
              _composer(me),
            ],
          );
        },
      ),
    );
  }
}
