import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../domain/report.dart';

final class FakeReportRepository extends FakeRepository
    implements ReportRepository {
  FakeReportRepository(super.latency);

  static const _byCategory = [
    CategoryTotal(ReportCategory.pujaTsok, 3240),
    CategoryTotal(ReportCategory.membership, 1980),
    CategoryTotal(ReportCategory.buildingFund, 1500),
    CategoryTotal(ReportCategory.butterLamp, 960),
    CategoryTotal(ReportCategory.general, 780),
  ];

  static const _donorCount = 128;
  static const _totalGiven = 64210;

  /// Per temple, so an address saved in one does not leak into the other.
  final Map<String, List<Donor>> _donors = {};

  List<Donor> _donorsOf(String templeId) => _donors.putIfAbsent(
    templeId,
    () => [
      const Donor(
        id: 'd1',
        name: 'Lobsang Gyatso',
        gifts: 15,
        total: 3080,
        hasAddress: true,
      ),
      const Donor(
        id: 'd2',
        name: 'Karma Tsering',
        gifts: 12,
        total: 2160,
        hasAddress: true,
      ),
      const Donor(
        id: 'd3',
        name: 'Tenzin Dolkar',
        gifts: 9,
        total: 1240,
        hasAddress: true,
      ),
      const Donor(
        id: 'd4',
        name: 'Margaret Chen',
        gifts: 4,
        total: 540,
        hasAddress: true,
      ),
      const Donor(
        id: 'd5',
        name: 'David Morrison',
        gifts: 2,
        total: 250,
        hasAddress: false,
      ),
    ],
  );

  @override
  Future<MonthlyReport> fetchMonthlyReport(String templeId, DateTime month) =>
      respond(
        () => MonthlyReport(
          month: month,
          total: _byCategory.fold(0, (sum, c) => sum + c.amount),
          changePercent: 12,
          byCategory: _byCategory,
        ),
      );

  @override
  Future<TaxSummary> fetchTaxSummary(String templeId, int year) => respond(
    () => TaxSummary(
      year: year,
      donorCount: _donorCount,
      totalGiven: _totalGiven,
      topDonors: List.unmodifiable(_donorsOf(templeId)),
    ),
  );

  @override
  Future<void> saveDonorAddress(
    String templeId,
    String donorId,
    String address,
  ) => respond(() {
    final donors = _donorsOf(templeId);
    final index = donors.indexWhere((d) => d.id == donorId);
    if (index < 0) throw const NotFoundFailure();
    final donor = donors[index];
    donors[index] = Donor(
      id: donor.id,
      name: donor.name,
      gifts: donor.gifts,
      total: donor.total,
      hasAddress: true,
    );
  });
}
