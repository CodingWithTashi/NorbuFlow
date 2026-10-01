import 'package:flutter/foundation.dart';

enum ReportCategory { pujaTsok, membership, buildingFund, butterLamp, general }

@immutable
class CategoryTotal {
  const CategoryTotal(this.category, this.amount);

  final ReportCategory category;

  /// Whole dollars.
  final int amount;
}

@immutable
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.total,
    required this.changePercent,
    required this.byCategory,
  });

  final DateTime month;
  final int total;

  /// Change against the previous month; negative when offerings fell.
  final int changePercent;

  /// Largest first.
  final List<CategoryTotal> byCategory;
}

@immutable
class Donor {
  const Donor({
    required this.id,
    required this.name,
    required this.gifts,
    required this.total,
    required this.hasAddress,
  });

  final String id;
  final String name;

  /// Number of offerings in the tax year.
  final int gifts;
  final int total;

  /// A year-end receipt cannot be issued without a mailing address.
  final bool hasAddress;
}

@immutable
class TaxSummary {
  const TaxSummary({
    required this.year,
    required this.donorCount,
    required this.totalGiven,
    required this.topDonors,
  });

  final int year;
  final int donorCount;
  final int totalGiven;

  /// The donors shown individually; the rest are summarised as a count.
  final List<Donor> topDonors;

  int get missingAddresses => topDonors.where((d) => !d.hasAddress).length;

  int get readyCount => donorCount - missingAddresses;
}

abstract interface class ReportRepository {
  Future<MonthlyReport> fetchMonthlyReport(String templeId, DateTime month);

  Future<TaxSummary> fetchTaxSummary(String templeId, int year);

  Future<void> saveDonorAddress(
    String templeId,
    String donorId,
    String address,
  );
}
