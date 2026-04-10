class SubscribeInfo {
  final int? planId;
  final String? token;
  final String? subscribeUrl;
  final int? expiredAt;
  final int upload;
  final int download;
  final int transferEnable;
  final String? email;
  final String? uuid;
  final int? deviceLimit;
  final int? speedLimit;
  final int? nextResetAt;
  final int? resetDay;
  final PlanInfo? plan;

  SubscribeInfo({
    this.planId,
    this.token,
    this.subscribeUrl,
    this.expiredAt,
    this.upload = 0,
    this.download = 0,
    this.transferEnable = 0,
    this.email,
    this.uuid,
    this.deviceLimit,
    this.speedLimit,
    this.nextResetAt,
    this.resetDay,
    this.plan,
  });

  int get totalUsed => upload + download;
  int get remaining => (transferEnable - totalUsed).clamp(0, transferEnable);
  double get usagePercent => transferEnable > 0 ? totalUsed / transferEnable : 0;

  bool get isExpired {
    if (expiredAt == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(expiredAt! * 1000)
        .isBefore(DateTime.now());
  }

  String get expiredDateStr {
    if (expiredAt == null || expiredAt == 0) return '永不过期';
    final date = DateTime.fromMillisecondsSinceEpoch(expiredAt! * 1000);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  factory SubscribeInfo.fromJson(Map<String, dynamic> json) {
    return SubscribeInfo(
      planId: json['plan_id'] as int?,
      token: json['token'] as String?,
      subscribeUrl: json['subscribe_url'] as String?,
      expiredAt: json['expired_at'] as int?,
      upload: json['u'] as int? ?? 0,
      download: json['d'] as int? ?? 0,
      transferEnable: json['transfer_enable'] as int? ?? 0,
      email: json['email'] as String?,
      uuid: json['uuid'] as String?,
      deviceLimit: json['device_limit'] as int?,
      speedLimit: json['speed_limit'] as int?,
      nextResetAt: json['next_reset_at'] as int?,
      resetDay: json['reset_day'] as int?,
      plan: json['plan'] != null
          ? PlanInfo.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PlanInfo {
  final String name;
  final int? speedLimit;
  final int? deviceLimit;

  PlanInfo({
    required this.name,
    this.speedLimit,
    this.deviceLimit,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      name: json['name'] as String? ?? 'Unknown',
      speedLimit: json['speed_limit'] as int?,
      deviceLimit: json['device_limit'] as int?,
    );
  }
}
