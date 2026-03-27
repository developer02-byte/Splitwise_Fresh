import 'package:fpdart/fpdart.dart';

/// Dart Utility for calculating the 5 standard Split Modes locally in real-time.
/// Solves the "leftover cents" rounding problem (e.g. $10.00 / 3 = $3.34, $3.33, $3.33).
class SplitCalculator {
  
  /// Applies Equal split distributing the remainder penny-by-penny
  static Either<String, List<int>> calculateEqual(int totalCents, int numPeople) {
    if (numPeople <= 0) return const Left("Number of participants must be > 0");
    if (totalCents < 0) return const Left("Amount cannot be negative");

    int baseAmount = totalCents ~/ numPeople;
    int remainder = totalCents % numPeople;

    List<int> splits = List.filled(numPeople, baseAmount);
    
    // Distribute the remainder cents consistently to the first N users
    for (int i = 0; i < remainder; i++) {
      splits[i] += 1;
    }

    return Right(splits);
  }

  /// Validates an Exact split
  static Either<String, List<int>> validateExact(int totalCents, List<int> exactSplits) {
    int sum = exactSplits.fold(0, (prev, amt) => prev + amt);
    if (sum != totalCents) {
      return Left("Splits sum to \$${sum/100}, but total is \$${totalCents/100}");
    }
    return Right(exactSplits);
  }

  /// Applies Percentage split, truncating decimals and giving remainder to the first person
  static Either<String, List<int>> calculatePercentage(int totalCents, List<double> percentages) {
    double sumPct = percentages.fold(0.0, (p, c) => p + c);
    if ((sumPct - 100).abs() > 0.01) return const Left("Percentages must sum to exactly 100%");

    List<int> splits = [];
    int runningTotal = 0;

    for (int i = 0; i < percentages.length - 1; i++) {
      int amt = (totalCents * (percentages[i] / 100)).round();
      splits.add(amt);
      runningTotal += amt;
    }
    
    // Last person strictly gets the exact mathematical remainder
    splits.add(totalCents - runningTotal);
    return Right(splits);
  }

  /// Applies Share-based split (e.g. Alice drank 3 beers, Bob 1 (4 total shares))
  static Either<String, List<int>> calculateShares(int totalCents, List<int> shares) {
    int totalShares = shares.fold(0, (p, c) => p + c);
    if (totalShares == 0) return const Left("Total shares cannot be 0");

    List<double> percentages = shares.map((s) => (s / totalShares) * 100).toList();
    return calculatePercentage(totalCents, percentages);
  }
}
