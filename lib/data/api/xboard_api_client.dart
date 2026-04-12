import 'package:dio/dio.dart';
import 'package:xboard_client/core/constants/api_endpoints.dart';
import 'package:xboard_client/core/constants/app_constants.dart';
import 'package:xboard_client/data/api/interceptors/auth_interceptor.dart';

class XboardApiClient {
  late final Dio _dio;
  final AuthInterceptor _authInterceptor;

  XboardApiClient({
    required String baseUrl,
    required AuthInterceptor authInterceptor,
  }) : _authInterceptor = authInterceptor {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _dio.interceptors.add(_authInterceptor);
  }

  // ─── Auth ───
  Future<Response> login(String email, String password) async {
    return _dio.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) async {
    return _dio.post(ApiEndpoints.register, data: {
      'username': email,
      'password': password,
      if (emailCode != null) 'email_code': emailCode,
      if (inviteCode != null) 'invite_code': inviteCode,
    });
  }

  Future<Response> forgotPassword(String email, String emailCode, String newPassword) async {
    return _dio.post(ApiEndpoints.forgotPassword, data: {
      'email': email,
      'email_code': emailCode,
      'password': newPassword,
    });
  }

  Future<Response> token2Login(String token) async {
    return _dio.get(ApiEndpoints.token2Login, queryParameters: {
      'verify': token,
    });
  }

  Future<Response> getQuickLoginUrl({String? redirect}) async {
    return _dio.post(ApiEndpoints.getQuickLoginUrl, data: {
      if (redirect != null) 'redirect': redirect,
    });
  }

  Future<Response> loginWithMailLink(String email, {String? redirect}) async {
    return _dio.post(ApiEndpoints.loginWithMailLink, data: {
      'email': email,
      if (redirect != null) 'redirect': redirect,
    });
  }

  // ─── User ───
  Future<Response> getUserInfo() async {
    return _dio.get(ApiEndpoints.userInfo);
  }

  Future<Response> getSubscribe() async {
    return _dio.get(ApiEndpoints.getSubscribe);
  }

  Future<Response> resetSecurity() async {
    return _dio.get(ApiEndpoints.resetSecurity);
  }

  Future<Response> getStat() async {
    return _dio.get(ApiEndpoints.getStat);
  }

  Future<Response> changePassword(String oldPassword, String newPassword) async {
    return _dio.post(ApiEndpoints.changePassword, data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<Response> updateUser(Map<String, dynamic> data) async {
    return _dio.post(ApiEndpoints.userUpdate, data: data);
  }

  Future<Response> bindEmail(String email, String emailCode) async {
    return _dio.post(ApiEndpoints.bindEmail, data: {
      'email': email,
      'email_code': emailCode,
    });
  }

  Future<Response> sendEmailVerify(String email) async {
    return _dio.post(ApiEndpoints.sendEmailVerify, data: {
      'email': email,
    });
  }

  Future<Response> getActiveSessions() async {
    return _dio.get(ApiEndpoints.getActiveSessions);
  }

  Future<Response> removeActiveSession(String sessionId) async {
    return _dio.post(ApiEndpoints.removeActiveSession, data: {
      'session_id': sessionId,
    });
  }

  Future<Response> checkLogin() async {
    return _dio.get(ApiEndpoints.checkLogin);
  }

  Future<Response> transfer(int amount) async {
    return _dio.post(ApiEndpoints.transfer, data: {
      'transfer_amount': amount,
    });
  }

  Future<Response> getUserQuickLoginUrl({String? redirect}) async {
    return _dio.post(ApiEndpoints.userQuickLoginUrl, data: {
      if (redirect != null) 'redirect': redirect,
    });
  }

  // ─── Plans ───
  Future<Response> getPlans() async {
    return _dio.get(ApiEndpoints.planFetch);
  }

  // ─── Orders ───
  Future<Response> getOrders() async {
    return _dio.get(ApiEndpoints.orderFetch);
  }

  Future<Response> saveOrder(int planId, String period) async {
    return _dio.post(ApiEndpoints.orderSave, data: {
      'plan_id': planId,
      'period': period,
    });
  }

  Future<Response> cancelOrder(String tradeNo) async {
    return _dio.post(ApiEndpoints.orderCancel, data: {
      'trade_no': tradeNo,
    });
  }

  Future<Response> getPaymentMethods() async {
    return _dio.get(ApiEndpoints.paymentMethod);
  }

  Future<Response> checkout(String tradeNo, int methodId) async {
    return _dio.post(ApiEndpoints.orderCheckout, data: {
      'trade_no': tradeNo,
      'method': methodId,
    });
  }

  Future<Response> checkOrder(String tradeNo) async {
    return _dio.get(ApiEndpoints.orderCheck, queryParameters: {
      'trade_no': tradeNo,
    });
  }

  // ─── Traffic Packages ───
  Future<Response> getTrafficPackages() async {
    return _dio.get(ApiEndpoints.trafficPackageFetch);
  }

  Future<Response> getMyPackages() async {
    return _dio.get(ApiEndpoints.trafficPackageMy);
  }

  Future<Response> getPackageStats() async {
    return _dio.get(ApiEndpoints.trafficPackageStats);
  }

  Future<Response> setTrafficPriority(String priority) async {
    return _dio.post(ApiEndpoints.trafficPackageSetPriority, data: {
      'priority': priority,
    });
  }

  Future<Response> purchasePackage(int packageId, {int? repurchaseId}) async {
    return _dio.post(ApiEndpoints.trafficPackagePurchase, data: {
      'package_id': packageId,
      if (repurchaseId != null) 'repurchase_id': repurchaseId,
    });
  }

  Future<Response> reorderPackages(List<int> ids) async {
    return _dio.post(ApiEndpoints.trafficPackageReorder, data: {
      'ids': ids,
    });
  }

  Future<Response> toggleAutoRenew(int packageId, bool autoRenew) async {
    return _dio.post(ApiEndpoints.trafficPackageToggleAutoRenew, data: {
      'id': packageId,
      'auto_renew': autoRenew,
    });
  }

  // ─── Tickets ───
  Future<Response> getTickets() async {
    return _dio.get(ApiEndpoints.ticketFetch);
  }

  Future<Response> saveTicket(String subject, int level, String message) async {
    return _dio.post(ApiEndpoints.ticketSave, data: {
      'subject': subject,
      'level': level,
      'message': message,
    });
  }

  Future<Response> replyTicket(int id, String message) async {
    return _dio.post(ApiEndpoints.ticketReply, data: {
      'id': id,
      'message': message,
    });
  }

  Future<Response> closeTicket(int id) async {
    return _dio.post(ApiEndpoints.ticketClose, data: {
      'id': id,
    });
  }

  Future<Response> withdrawTicket(String method, String account) async {
    return _dio.post(ApiEndpoints.ticketWithdraw, data: {
      'withdraw_method': method,
      'withdraw_account': account,
    });
  }

  // ─── Notices ───
  Future<Response> getNotices() async {
    return _dio.get(ApiEndpoints.noticeFetch);
  }

  // ─── Recharge ───
  Future<Response> saveRechargeOrder(int amount, String period) async {
    return _dio.post(ApiEndpoints.rechargeOrderSave, data: {
      'period': period,
      'amount': amount,
    });
  }

  // ─── Invite ───
  Future<Response> createInviteCode() async {
    return _dio.get(ApiEndpoints.inviteSave);
  }

  Future<Response> getInviteCodes() async {
    return _dio.get(ApiEndpoints.inviteFetch);
  }

  Future<Response> getInviteDetails({int page = 1, int pageSize = 10}) async {
    return _dio.get(ApiEndpoints.inviteDetails, queryParameters: {
      'current': page,
      'page_size': pageSize,
    });
  }

  // ─── Coupon ───
  Future<Response> checkCoupon(String code, {int? planId, String? period}) async {
    return _dio.post(ApiEndpoints.couponCheck, data: {
      'code': code,
      if (planId != null) 'plan_id': planId,
      if (period != null) 'period': period,
    });
  }

  // ─── Gift Card ───
  Future<Response> checkGiftCard(String code) async {
    return _dio.post(ApiEndpoints.giftCardCheck, data: {
      'code': code,
    });
  }

  Future<Response> redeemGiftCard(String code) async {
    return _dio.post(ApiEndpoints.giftCardRedeem, data: {
      'code': code,
    });
  }

  Future<Response> getGiftCardHistory({int page = 1, int perPage = 15}) async {
    return _dio.get(ApiEndpoints.giftCardHistory, queryParameters: {
      'page': page,
      'per_page': perPage,
    });
  }

  Future<Response> getGiftCardDetail(int id) async {
    return _dio.get(ApiEndpoints.giftCardDetail, queryParameters: {
      'id': id,
    });
  }

  Future<Response> getGiftCardTypes() async {
    return _dio.get(ApiEndpoints.giftCardTypes);
  }

  // ─── Knowledge ───
  Future<Response> getKnowledgeList({String? language, String? keyword}) async {
    return _dio.get(ApiEndpoints.knowledgeFetch, queryParameters: {
      if (language != null) 'language': language,
      if (keyword != null) 'keyword': keyword,
    });
  }

  Future<Response> getKnowledgeDetail(int id) async {
    return _dio.get(ApiEndpoints.knowledgeFetch, queryParameters: {
      'id': id,
    });
  }

  Future<Response> getKnowledgeCategories() async {
    return _dio.get(ApiEndpoints.knowledgeCategory);
  }

  // ─── Stats ───
  Future<Response> getTrafficLog() async {
    return _dio.get(ApiEndpoints.trafficLog);
  }

  // ─── Communication ───
  Future<Response> getCommConfig() async {
    return _dio.get(ApiEndpoints.commConfig);
  }

  Future<Response> getStripePublicKey(int paymentId) async {
    return _dio.post(ApiEndpoints.stripePublicKey, data: {
      'id': paymentId,
    });
  }

  Future<Response> trackPv({String? inviteCode}) async {
    return _dio.post(ApiEndpoints.commPv, data: {
      if (inviteCode != null) 'invite_code': inviteCode,
    });
  }

  // ─── Telegram ───
  Future<Response> getTelegramBotInfo() async {
    return _dio.get(ApiEndpoints.telegramBotInfo);
  }

  // ─── Server ───
  Future<Response> getServerList() async {
    return _dio.get(ApiEndpoints.serverFetch);
  }

  // ─── Mihomo (Clash.Meta) Config ───
  Future<Response> fetchMihomoConfig(String subscribeUrl) async {
    final plainDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    return plainDio.get(
      '$subscribeUrl?flag=${AppConstants.mihomoFlag}',
    );
  }
}
