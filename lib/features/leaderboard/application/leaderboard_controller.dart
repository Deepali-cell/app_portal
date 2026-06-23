import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/leaderboard_repository.dart';
import '../domain/models.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
    (ref) => LeaderboardRepository(ref.watch(dioProvider)));

/// Current selection (metric + optional custom range).
class LeaderboardQuery {
  const LeaderboardQuery({
    this.metric = LeaderboardMetric.dealsWon,
    this.from,
    this.to,
  });
  final LeaderboardMetric metric;
  final DateTime? from;
  final DateTime? to;

  LeaderboardQuery copyWith({
    LeaderboardMetric? metric,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) =>
      LeaderboardQuery(
        metric: metric ?? this.metric,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}

final leaderboardQueryProvider =
    NotifierProvider<LeaderboardQueryController, LeaderboardQuery>(
        LeaderboardQueryController.new);

class LeaderboardQueryController extends Notifier<LeaderboardQuery> {
  @override
  LeaderboardQuery build() => const LeaderboardQuery();
  void setMetric(LeaderboardMetric m) =>
      state = state.copyWith(metric: m);
  void setRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(from: from, to: to);
  void clearRange() => state = state.copyWith(clearDates: true);
}

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardSnapshot>((ref) {
  final q = ref.watch(leaderboardQueryProvider);
  return ref.read(leaderboardRepositoryProvider).fetch(
        metric: q.metric,
        from: q.from,
        to: q.to,
      );
});
