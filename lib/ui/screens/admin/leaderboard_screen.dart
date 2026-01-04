import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _leaderboardEntries;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top performers', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Recognition for admins and members who keep their groups running smoothly. Points combine contribution timeliness and payout success rates.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _badgeColor(
                        entry.rank,
                      ).withAlpha((0.15 * 255).round()),
                      child: Text(
                        '#${entry.rank}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _badgeColor(entry.rank),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.groupName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.points} pts',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.onTimeRate}% on-time',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => _showComingSoon(context, 'Leaderboard exports'),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export leaderboard'),
            ),
          ),
        ],
      ),
    );
  }

  Color _badgeColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.secondary;
      case 2:
        return AppColors.textSecondary;
      case 3:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

class _LeaderboardEntry {
  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.groupName,
    required this.points,
    required this.onTimeRate,
  });

  final int rank;
  final String name;
  final String groupName;
  final int points;
  final int onTimeRate;
}

const _leaderboardEntries = <_LeaderboardEntry>[
  _LeaderboardEntry(
    rank: 1,
    name: 'Sara Bekele',
    groupName: 'Downtown Circle',
    points: 2140,
    onTimeRate: 98,
  ),
  _LeaderboardEntry(
    rank: 2,
    name: 'Kidus Hailu',
    groupName: 'Market Makers',
    points: 1975,
    onTimeRate: 95,
  ),
  _LeaderboardEntry(
    rank: 3,
    name: 'Seble Fekadu',
    groupName: 'Sunrise Equb',
    points: 1860,
    onTimeRate: 93,
  ),
  _LeaderboardEntry(
    rank: 4,
    name: 'Jonas Getahun',
    groupName: 'Tech Savers',
    points: 1730,
    onTimeRate: 91,
  ),
  _LeaderboardEntry(
    rank: 5,
    name: 'Meron Getachew',
    groupName: 'Addis Ambition',
    points: 1645,
    onTimeRate: 89,
  ),
  _LeaderboardEntry(
    rank: 6,
    name: 'Abel Tadesse',
    groupName: 'Growth Guild',
    points: 1580,
    onTimeRate: 87,
  ),
  _LeaderboardEntry(
    rank: 7,
    name: 'Hanna Guta',
    groupName: 'Unity Circle',
    points: 1510,
    onTimeRate: 86,
  ),
  _LeaderboardEntry(
    rank: 8,
    name: 'Surafel Girma',
    groupName: 'Green Fund',
    points: 1445,
    onTimeRate: 84,
  ),
  _LeaderboardEntry(
    rank: 9,
    name: 'Bilen Aklilu',
    groupName: 'Millennium Crew',
    points: 1380,
    onTimeRate: 82,
  ),
  _LeaderboardEntry(
    rank: 10,
    name: 'Mikiyas Demissie',
    groupName: 'Ethio Innovators',
    points: 1325,
    onTimeRate: 80,
  ),
];

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
}
