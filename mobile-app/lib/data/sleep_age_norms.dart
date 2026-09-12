/// Sleep norm data for different age groups
/// Based on pediatric research and AAP guidelines
class SleepNorm {
  final double minHours;
  final double maxHours;
  final String label;

  const SleepNorm({
    required this.minHours,
    required this.maxHours,
    required this.label,
  });

  /// Get the average recommended hours
  double get averageHours => (minHours + maxHours) / 2;

  /// Check if given hours is within recommended range
  bool isWithinRange(double hours) {
    return hours >= minHours && hours <= maxHours;
  }

  /// Get status message for given hours
  String getStatusMessage(double hours) {
    if (hours < minHours) {
      final diff = (minHours - hours).toStringAsFixed(1);
      return 'Below recommended range by $diff hours';
    } else if (hours > maxHours) {
      final diff = (hours - maxHours).toStringAsFixed(1);
      return 'Above recommended range by $diff hours';
    } else {
      return 'Within recommended range';
    }
  }

  @override
  String toString() {
    return 'SleepNorm($label: ${minHours.toStringAsFixed(1)}-${maxHours.toStringAsFixed(1)} hours)';
  }
}

/// Age-based sleep duration norms
/// Source: American Academy of Pediatrics (AAP) Sleep Guidelines
class SleepAgeNorms {
  SleepAgeNorms._(); // Private constructor - use as static class

  /// Sleep norms by age in months
  /// Key: Starting age in months for this range
  static final Map<int, SleepNorm> _norms = {
    0: const SleepNorm(
      minHours: 14,
      maxHours: 17,
      label: '0-3 months',
    ),
    4: const SleepNorm(
      minHours: 12,
      maxHours: 15,
      label: '4-11 months',
    ),
    12: const SleepNorm(
      minHours: 11,
      maxHours: 14,
      label: '1-2 years',
    ),
    24: const SleepNorm(
      minHours: 10,
      maxHours: 13,
      label: '2-3 years',
    ),
    36: const SleepNorm(
      minHours: 10,
      maxHours: 13,
      label: '3-5 years',
    ),
    60: const SleepNorm(
      minHours: 9,
      maxHours: 12,
      label: '5+ years',
    ),
  };

  /// Get all norms
  static Map<int, SleepNorm> getNorms() => Map.from(_norms);

  /// Get appropriate norm for given age in months
  static SleepNorm getNormForAge(int ageInMonths) {
    // Find the highest age bracket that's <= the baby's age
    int? applicableAge;
    for (var age in _norms.keys.toList()..sort((a, b) => b.compareTo(a))) {
      if (ageInMonths >= age) {
        applicableAge = age;
        break;
      }
    }

    // Default to newborn range if age is negative or very young
    applicableAge ??= 0;

    return _norms[applicableAge]!;
  }

  /// Get norm by age label (e.g., "4-11 months")
  static SleepNorm? getNormByLabel(String label) {
    return _norms.values.firstWhere(
      (norm) => norm.label == label,
      orElse: () => _norms[0]!,
    );
  }

  /// Calculate age in months from birth date
  static int calculateAgeInMonths(DateTime birthDate) {
    final now = DateTime.now();
    final years = now.year - birthDate.year;
    final months = now.month - birthDate.month;
    final days = now.day - birthDate.day;

    int totalMonths = (years * 12) + months;

    // Adjust if birth day hasn't occurred yet in current month
    if (days < 0) {
      totalMonths--;
    }

    return totalMonths < 0 ? 0 : totalMonths;
  }

  /// Get age bracket label for given age in months
  static String getAgeBracketLabel(int ageInMonths) {
    return getNormForAge(ageInMonths).label;
  }

  /// Check if sleep hours are appropriate for age
  static bool isAppropriateForAge(int ageInMonths, double sleepHours) {
    final norm = getNormForAge(ageInMonths);
    return norm.isWithinRange(sleepHours);
  }

  /// Get status message for given age and sleep hours
  static String getStatusMessage(int ageInMonths, double sleepHours) {
    final norm = getNormForAge(ageInMonths);
    return norm.getStatusMessage(sleepHours);
  }

  /// Get all age brackets as list
  static List<String> getAllAgeBrackets() {
    return _norms.values.map((norm) => norm.label).toList();
  }
}
