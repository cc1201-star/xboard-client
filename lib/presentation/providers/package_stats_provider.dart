import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xboard_client/presentation/providers/auth_provider.dart';

class PackageStatsState {
  final int totalBytes;
  final int usedBytes;
  final int packageCount;
  final String priority;
  final bool hasData;

  const PackageStatsState({
    this.totalBytes = 0,
    this.usedBytes = 0,
    this.packageCount = 0,
    this.priority = 'plan',
    this.hasData = false,
  });

  PackageStatsState copyWith({
    int? totalBytes,
    int? usedBytes,
    int? packageCount,
    String? priority,
    bool? hasData,
  }) => PackageStatsState(
        totalBytes: totalBytes ?? this.totalBytes,
        usedBytes: usedBytes ?? this.usedBytes,
        packageCount: packageCount ?? this.packageCount,
        priority: priority ?? this.priority,
        hasData: hasData ?? this.hasData,
      );
}

class PackageStatsNotifier extends StateNotifier<PackageStatsState> {
  final Ref _ref;
  PackageStatsNotifier(this._ref) : super(const PackageStatsState());

  Future<void> refresh() async {
    final client = _ref.read(apiClientProvider);
    if (client == null) return;
    try {
      final resp = await client.getPackageStats();
      final data = resp.data['data'] as Map<String, dynamic>?;
      if (data == null) return;
      state = state.copyWith(
        totalBytes: (data['total_bytes'] as num?)?.toInt() ?? 0,
        usedBytes: (data['used_bytes'] as num?)?.toInt() ?? 0,
        packageCount: (data['package_count'] as num?)?.toInt() ?? 0,
        priority: data['traffic_use_priority'] as String? ?? 'plan',
        hasData: true,
      );
    } catch (_) {}
  }

  Future<void> setPriority(String p) async {
    final client = _ref.read(apiClientProvider);
    if (client == null) return;
    state = state.copyWith(priority: p);
    try {
      await client.setTrafficPriority(p);
    } catch (_) {
      // revert silently if failed — keep UI responsive
    }
  }
}

final packageStatsProvider =
    StateNotifierProvider<PackageStatsNotifier, PackageStatsState>((ref) {
  return PackageStatsNotifier(ref);
});
