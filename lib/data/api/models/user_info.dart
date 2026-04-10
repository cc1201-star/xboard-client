class UserInfo {
  final int id;
  final String email;
  final String? username;
  final int transferEnable;
  final int upload;
  final int download;
  final int? expiredAt;
  final int balance;
  final int? planId;
  final String uuid;
  final int? remindExpire;
  final int? remindTraffic;
  final int? resetDay;

  UserInfo({
    required this.id,
    required this.email,
    this.username,
    this.transferEnable = 0,
    this.upload = 0,
    this.download = 0,
    this.expiredAt,
    this.balance = 0,
    this.planId,
    required this.uuid,
    this.remindExpire,
    this.remindTraffic,
    this.resetDay,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      username: json['username'] as String?,
      transferEnable: json['transfer_enable'] as int? ?? 0,
      upload: json['u'] as int? ?? 0,
      download: json['d'] as int? ?? 0,
      expiredAt: json['expired_at'] as int?,
      balance: json['balance'] as int? ?? 0,
      planId: json['plan_id'] as int?,
      uuid: json['uuid'] as String? ?? '',
      remindExpire: json['remind_expire'] as int?,
      remindTraffic: json['remind_traffic'] as int?,
      resetDay: json['reset_day'] as int?,
    );
  }
}
