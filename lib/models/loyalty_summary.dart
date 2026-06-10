class LoyaltySummary {
  final String carwashId;
  final String carwashName;
  final int punches;
  final int redemptions;
  final int lastTs;

  const LoyaltySummary({
    required this.carwashId,
    required this.carwashName,
    required this.punches,
    required this.redemptions,
    required this.lastTs,
  });

  int get punchesTowardReward => punches % 5;

  int get punchSlotsFilled => punchesTowardReward;

  int get punchSlotsRemaining => 5 - punchSlotsFilled;

  int get unlockedRewards => punches ~/ 5;

  int get availableRewards {
    final value = unlockedRewards - redemptions;
    return value < 0 ? 0 : value;
  }

  double get progressPercent => (punchesTowardReward / 5).clamp(0.0, 1.0);
}
