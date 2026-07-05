import 'package:flutter_test/flutter_test.dart';

import 'package:carwash_manager/utils/vat_math.dart';

/// The accounting safety net.
///
/// WashDesk's core promise is "your books are right." These tests pin down
/// the VAT engine so no future change can silently reintroduce drift between
/// Reports and the ledger (the R234.78 vs R234.80 bug). If any of these
/// fail, do not ship — the accountant pack no longer ties to the trial
/// balance.
///
/// Run with: flutter test test/vat_math_test.dart
void main() {
  const rate = 0.15; // South African VAT

  group('VatMath.round2', () {
    test('rounds to 2 decimals', () {
      expect(VatMath.round2(1.006), 1.01);
      expect(VatMath.round2(1.004), 1.00);
      expect(VatMath.round2(173.913043), 173.91);
      expect(VatMath.round2(26.086956), 26.09);
    });

    test('is stable for already-rounded values', () {
      expect(VatMath.round2(200.00), 200.00);
      expect(VatMath.round2(0.01), 0.01);
      expect(VatMath.round2(0), 0);
    });
  });

  group('VatMath.split — VAT-inclusive prices (SA default)', () {
    test('R200 full wash splits to net 173.91 + tax 26.09', () {
      final s = VatMath.split(200, rate: rate, pricesIncludeVat: true);
      expect(s.net, 173.91);
      expect(s.tax, 26.09);
      expect(s.total, 200.00);
    });

    test('R100 half wash splits to net 86.96 + tax 13.04', () {
      final s = VatMath.split(100, rate: rate, pricesIncludeVat: true);
      expect(s.net, 86.96);
      expect(s.tax, 13.04);
      expect(s.total, 100.00);
    });

    test('net + tax always reconciles exactly to the total', () {
      // Awkward amounts chosen to stress rounding.
      for (final amount in [1.0, 9.99, 33.33, 149.95, 777.77, 1234.56]) {
        final s = VatMath.split(amount, rate: rate, pricesIncludeVat: true);
        expect(
          VatMath.round2(s.net + s.tax),
          s.total,
          reason: 'net + tax must equal total for R$amount',
        );
      }
    });
  });

  group('VatMath.split — VAT-exclusive prices', () {
    test('adds 15% on top and reconciles', () {
      final s = VatMath.split(200, rate: rate, pricesIncludeVat: false);
      expect(s.net, 200.00);
      expect(s.tax, 30.00);
      expect(s.total, 230.00);
    });
  });

  group('VatMath.split — edge cases', () {
    test('zero and negative amounts carry no tax', () {
      final zero = VatMath.split(0, rate: rate, pricesIncludeVat: true);
      expect(zero.tax, 0);
      final neg = VatMath.split(-50, rate: rate, pricesIncludeVat: true);
      expect(neg.tax, 0);
      expect(neg.net, -50);
    });

    test('zero rate means no tax in either mode', () {
      final inc = VatMath.split(200, rate: 0, pricesIncludeVat: true);
      expect(inc.tax, 0);
      expect(inc.net, 200);
      final exc = VatMath.split(200, rate: 0, pricesIncludeVat: false);
      expect(exc.tax, 0);
      expect(exc.total, 200);
    });
  });

  group('VatMath.sumSplits — the ledger reconciliation guarantee', () {
    test(
        'REGRESSION: 8 full + 2 half washes (R1,800) gives VAT R234.80, '
        'matching the per-invoice ledger — never R234.78 from aggregate math',
        () {
      final prices = [...List.filled(8, 200.0), ...List.filled(2, 100.0)];
      final total = VatMath.sumSplits(
        prices,
        rate: rate,
        pricesIncludeVat: true,
      );
      expect(total.total, 1800.00);
      expect(total.tax, 234.80,
          reason: 'Per-transaction VAT must match the posted ledger');
      expect(total.net, 1565.20);

      // The old, buggy aggregate calculation for the same data:
      final aggregateTax = VatMath.round2(1800 - 1800 / (1 + rate));
      expect(aggregateTax, 234.78,
          reason: 'Documents why aggregate math is wrong: it drifts 2c');
      expect(total.tax, isNot(aggregateTax));
    });

    test('sum of splits equals split-by-split accumulation', () {
      final prices = [200.0, 100.0, 149.99, 89.5, 200.0];
      final summed = VatMath.sumSplits(
        prices,
        rate: rate,
        pricesIncludeVat: true,
      );
      var manual = VatSplit.zero;
      for (final p in prices) {
        manual = manual +
            VatMath.split(p, rate: rate, pricesIncludeVat: true);
      }
      expect(summed.net, manual.net);
      expect(summed.tax, manual.tax);
      expect(summed.total, manual.total);
    });

    test('empty input is zero everywhere', () {
      final s = VatMath.sumSplits(const <double>[],
          rate: rate, pricesIncludeVat: true);
      expect(s.net, 0);
      expect(s.tax, 0);
      expect(s.total, 0);
    });

    test('a month of realistic mixed washes stays internally consistent', () {
      // 60 washes: a plausible busy month at one bay.
      final prices = <double>[
        for (var i = 0; i < 35; i++) 200.0, // full washes
        for (var i = 0; i < 20; i++) 100.0, // half washes
        for (var i = 0; i < 5; i++) 350.0, // valet specials
      ];
      final s =
          VatMath.sumSplits(prices, rate: rate, pricesIncludeVat: true);
      expect(s.total, 10750.00);
      expect(VatMath.round2(s.net + s.tax), s.total,
          reason: 'Period totals must reconcile to the cent');
      // Per-invoice VAT for these amounts: 35×26.09 + 20×13.04 + 5×45.65
      expect(s.tax, VatMath.round2(35 * 26.09 + 20 * 13.04 + 5 * 45.65));
    });
  });
}
