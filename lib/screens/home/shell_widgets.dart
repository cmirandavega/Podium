import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';
import '../leagues/create_league_screen.dart';
import '../leagues/join_league_screen.dart';

/// Pieces shared by the bottom-tab screens.

/// Big tab title with an optional line under it and trailing widgets.
class ShellHeader extends StatelessWidget {
  const ShellHeader({
    super.key,
    required this.title,
    this.below,
    this.trailing = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 16, 16, 8),
  });

  final String title;
  final Widget? below;
  final List<Widget> trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                if (below != null) ...[
                  const SizedBox(height: 2),
                  below!,
                ],
              ],
            ),
          ),
          for (final w in trailing) ...[const SizedBox(width: 8), w],
        ],
      ),
    );
  }
}

/// "Sunday Legends ▾": the active league, tap to switch.
class LeagueSwitcher extends StatelessWidget {
  const LeagueSwitcher({
    super.key,
    required this.leagues,
    required this.active,
    required this.onSelect,
  });

  final List<League> leagues;
  final League active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final canSwitch = leagues.length > 1;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canSwitch ? () => showLeaguePicker(context, leagues, active.id, onSelect) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                active.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: PodiumColors.silver, fontWeight: FontWeight.w500),
              ),
            ),
            if (canSwitch) ...[
              const SizedBox(width: 2),
              const Icon(Icons.expand_more_rounded, size: 18, color: PodiumColors.silver),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the user's leagues.
Future<void> showLeaguePicker(
  BuildContext context,
  List<League> leagues,
  String activeId,
  ValueChanged<String> onSelect,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('Switch league', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final l in leagues)
            PodiumCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: PodiumRadii.tile,
              borderColor: l.id == activeId ? PodiumColors.gold : PodiumColors.line,
              onTap: () {
                Navigator.pop(sheetContext);
                onSelect(l.id);
              },
              child: Row(
                children: [
                  TintedIcon(
                    icon: Icons.emoji_events_outlined,
                    size: 36,
                    color: l.id == activeId ? PodiumColors.gold : PodiumColors.silver,
                    background: l.id == activeId ? PodiumColors.goldTint : PodiumColors.silverTint,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(l.sports.join(' · '), style: PodiumText.caption),
                      ],
                    ),
                  ),
                  if (l.id == activeId) const Icon(Icons.check_rounded, color: PodiumColors.gold),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Shown on league tabs when the user isn't in a league yet.
class NoLeagueView extends StatelessWidget {
  const NoLeagueView({super.key, required this.user, required this.title, required this.message});

  final AppUser user;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          ShellHeader(title: title, padding: const EdgeInsets.only(bottom: 16)),
          EmptyCard(icon: Icons.emoji_events_outlined, title: 'Join a league first', message: message),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create a league'),
            onPressed: () => open(CreateLeagueScreen(user: user)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Join with an invite code'),
            onPressed: () => open(JoinLeagueScreen(user: user)),
          ),
        ],
      ),
    );
  }
}

/// Live coin balance for one league, as a [CoinBadge]. Give it a key with
/// the league ID so switching leagues starts a fresh subscription.
class LeagueCoins extends StatefulWidget {
  const LeagueCoins({super.key, required this.leagueId, required this.userId, this.onTap});

  final String leagueId;
  final String userId;
  final VoidCallback? onTap;

  @override
  State<LeagueCoins> createState() => _LeagueCoinsState();
}

class _LeagueCoinsState extends State<LeagueCoins> {
  late final Stream<List<LeagueMember>> _stream = LeagueService().watchMembers(widget.leagueId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeagueMember>>(
      stream: _stream,
      builder: (context, snap) {
        int? coins;
        for (final m in snap.data ?? const <LeagueMember>[]) {
          if (m.userId == widget.userId) coins = m.coins;
        }
        return CoinBadge(coins: coins, onTap: widget.onTap);
      },
    );
  }
}
