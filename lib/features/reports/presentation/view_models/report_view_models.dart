import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/validators.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/report_repositories.dart';
import '../../domain/report.dart';

/// This month's offerings for the current temple.
final monthlyReportProvider = FutureProvider.autoDispose<MonthlyReport>((ref) {
  final templeId = ref.watch(activeTempleIdProvider);
  final month = ref.watch(todayProvider).firstOfMonth;
  return ref
      .watch(reportRepositoryProvider)
      .fetchMonthlyReport(templeId, month);
});

/// Year-end tax receipts for the current tax year.
class TaxViewModel extends AsyncNotifier<TaxSummary> {
  late String _templeId;

  @override
  Future<TaxSummary> build() {
    _templeId = ref.watch(activeTempleIdProvider);
    final year = ref.watch(todayProvider).year;
    return ref.watch(reportRepositoryProvider).fetchTaxSummary(_templeId, year);
  }

  /// Why [address] cannot be saved, or null if it can.
  ValidationIssue? validateAddress(String address) =>
      Validators.required(address, ValidationIssue.addressRequired);

  /// Saves a donor's mailing address so their receipt can be issued.
  Future<bool> saveAddress(Donor donor, String address) async {
    final result = await runCommand(
      ref,
      () => ref
          .read(reportRepositoryProvider)
          .saveDonorAddress(_templeId, donor.id, address.trim()),
      source: 'tax.saveDonorAddress',
    );
    if (result.isOk && ref.mounted) {
      ref.invalidateSelf();
      await future;
    }
    return result.isOk;
  }
}

final taxViewModelProvider =
    AsyncNotifierProvider.autoDispose<TaxViewModel, TaxSummary>(
      TaxViewModel.new,
    );
