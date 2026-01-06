import 'package:equb/models/onboarding_state.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';

class GroupGuidanceStep extends StatefulWidget {
  const GroupGuidanceStep({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  final OnboardingData initialData;
  final Function(OnboardingData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  @override
  State<GroupGuidanceStep> createState() => _GroupGuidanceStepState();
}

class _GroupGuidanceStepState extends State<GroupGuidanceStep> {
  String _selectedGroupType = '';

  final List<Map<String, dynamic>> _groupTypes = [
    {
      'id': 'family',
      'name': 'Family & Friends',
      'icon': Icons.family_restroom,
      'description': 'Save with close family and friends',
      'memberRange': '5-15 members',
      'color': Colors.blue,
    },
    {
      'id': 'community',
      'name': 'Community Group',
      'icon': Icons.groups,
      'description': 'Join your local community savings group',
      'memberRange': '10-50 members',
      'color': Colors.green,
    },
    {
      'id': 'workplace',
      'name': 'Workplace Colleagues',
      'icon': Icons.business,
      'description': 'Save with coworkers and colleagues',
      'memberRange': '8-25 members',
      'color': Colors.orange,
    },
    {
      'id': 'investment',
      'name': 'Investment Club',
      'icon': Icons.trending_up,
      'description': 'Focus on investment and higher returns',
      'memberRange': '15-30 members',
      'color': Colors.purple,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group illustration
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_2,
                size: 60,
                color: scheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Find your savings group',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Choose the type of group that best fits your savings goals',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Group type selection
          ..._groupTypes.map((groupType) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildGroupTypeOption(groupType),
          )),

          const SizedBox(height: 24),

          // Selected group info
          if (_selectedGroupType.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens next?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNextStep(
                    'Browse Groups',
                    'Find existing groups that match your preferences',
                  ),
                  _buildNextStep(
                    'Create New Group',
                    'Start your own group if you can\'t find one',
                  ),
                  _buildNextStep(
                    'Invite Members',
                    'Add friends and family to your savings circle',
                  ),
                  _buildNextStep(
                    'Start Saving',
                    'Begin making regular contributions',
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedGroupType.isNotEmpty ? _completeGuidance : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tips section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Savings Tips',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTip(
                  'Start small with people you trust',
                  'Begin with a small, trusted group to build confidence',
                ),
                const SizedBox(height: 8),
                _buildTip(
                  'Set clear rules from the beginning',
                  'Define contribution amounts, schedules, and payout rules upfront',
                ),
                const SizedBox(height: 8),
                _buildTip(
                  'Regular contributions build discipline',
                  'Consistent saving helps build good financial habits',
                ),
                const SizedBox(height: 8),
                _buildTip(
                  'Track your progress',
                  'Monitor your savings growth and group performance',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Support text
          Center(
            child: Text(
              'Need help? Our support team is here to assist you.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTypeOption(Map<String, dynamic> groupType) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedGroupType == groupType['id'];

    return InkWell(
      onTap: () => setState(() => _selectedGroupType = groupType['id']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? groupType['color'].withOpacity(0.1)
              : scheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? groupType['color'].withOpacity(0.3)
                : scheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: groupType['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                groupType['icon'],
                color: groupType['color'],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        groupType['name'],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: groupType['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          groupType['memberRange'],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: groupType['color'],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    groupType['description'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: groupType['color'],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward,
              size: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle,
          size: 16,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _completeGuidance() {
    final updatedData = widget.initialData.copyWith(
      preferredGroupType: _selectedGroupType,
    );
    widget.onDataChanged(updatedData);
    widget.onNext();
  }
}

