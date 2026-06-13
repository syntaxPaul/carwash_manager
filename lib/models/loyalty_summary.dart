import '../data/settings.dart';

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

  int get washesPerReward => AppSettings.instance.loyaltyWashesPerReward;

  int get punchesTowardReward => punches % washesPerReward;

  int get punchSlotsFilled => punchesTowardReward;

  int get punchSlotsRemaining => washesPerReward - punchSlotsFilled;

  int get unlockedRewards => punches ~/ washesPerReward;

  int get availableRewards {
    final value = unlockedRewards - redemptions;
    return value < 0 ? 0 : value;
  }

  double get progressPercent =>
      (punchesTowardReward / washesPerReward).clamp(0.0, 1.0);
}
