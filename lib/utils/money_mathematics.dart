class MoneyMathematics {
  /// Structure:
  /// - 0.5% for >= 10,000 ETB
  /// - 0.1% for < 10,000 ETB
  /// - Special discount: Up to 90% discount on the fee for transactions > 1M ETB
  static double calculateFee(double amount) {
    double rate;
    if (amount >= 10000) {
      rate = 0.005; // 0.5%
    } else {
      rate = 0.001; // 0.1%
    }

    double fee = amount * rate;

    // Apply 90% discount on the FEE (not the rate) for > 1M
    if (amount >= 1000000) {
      fee = fee * 0.1; // 90% discount means they pay 10%
    }

    return fee;
  }

  /// Points logic:
  /// - 1 point for every 100 ETB of "interaction" (contribution/deposit)
  /// - Bonus for larger transactions
  static int calculatePoints(double amount, String action) {
    int basePoints = (amount / 100).floor();

    // Bonus for high interaction
    if (amount >= 10000) {
      basePoints += 50;
    }
    if (amount >= 100000) {
      basePoints += 500;
    }

    return basePoints;
  }
}
