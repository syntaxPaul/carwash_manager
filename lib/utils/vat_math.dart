/// Canonical VAT arithmetic for WashDesk.
///
/// There must be exactly ONE way VAT is computed in this app, and it must
/// match the ledger. The ledger (bookkeeping_service.dart) splits VAT per
/// transaction and rounds each split to 2 decimals — which is also how SARS
/// expects VAT to be determined (per tax invoice). Reports must therefore
/// sum per-transaction splits, never apply the rate to an aggregate total.
///
/// Aggregate math (total / 1.15) drifts from the ledger by a few cents as
/// per-transaction rounding accumulates, producing reports that don't tie
/// to the trial balance.
library vat_math;

class VatSplit {
  final double net;
  final double tax;
  final double total;

  const VatSplit({required this.net, required this.tax, required this.total});

  static const zero = VatSplit(net: 0, tax: 0, total: 0);

  VatSplit operator +(VatSplit other) => VatSplit(
        net: VatMath.round2(net + other.net),
        tax: VatMath.round2(tax + other.tax),
        total: VatMath.round2(total + other.total),
      );
}

class VatMath {
  VatMath._();

  static double round2(double value) => (value * 100).roundToDouble() / 100;

  /// Split a single transaction amount into net + VAT.
  ///
  /// [gross] is the transaction amount as captured.
  /// [rate] is the VAT rate (e.g. 0.15).
  /// [pricesIncludeVat] — when true, [gross] is VAT-inclusive and VAT is
  /// extracted; when false, [gross] is the net and VAT is added on top.
  ///
  /// Mirrors the ledger's `_splitFromGross` behaviour exactly: round the
  /// net, derive tax as the remainder (inclusive) or round the computed tax
  /// (exclusive), so net + tax always reconciles to the total.
  static VatSplit split(
    double gross, {
    required double rate,
    required bool pricesIncludeVat,
  }) {
    final amount = round2(gross);
    if (amount <= 0 || rate <= 0) {
      return VatSplit(net: amount, tax: 0, total: amount);
    }
    if (pricesIncludeVat) {
      final net = round2(amount / (1 + rate));
      final tax = round2(amount - net);
      return VatSplit(net: net, tax: tax, total: amount);
    }
    final tax = round2(amount * rate);
    return VatSplit(net: amount, tax: tax, total: round2(amount + tax));
  }

  /// Sum per-transaction VAT splits over a set of amounts.
  ///
  /// This is the ONLY correct way to compute VAT for a period in reports:
  /// it reproduces what the ledger posted, transaction by transaction.
  static VatSplit sumSplits(
    Iterable<double> amounts, {
    required double rate,
    required bool pricesIncludeVat,
  }) {
    var acc = VatSplit.zero;
    for (final amount in amounts) {
      acc = acc + split(amount, rate: rate, pricesIncludeVat: pricesIncludeVat);
    }
    return acc;
  }
}
