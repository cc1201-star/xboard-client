class ApiEndpoints {
  // Auth
  static const String login = '/api/v1/passport/auth/login';
  static const String register = '/api/v1/passport/auth/register';
  static const String forgotPassword = '/api/v1/passport/auth/forget';
  static const String token2Login = '/api/v1/passport/auth/token2Login';
  static const String getQuickLoginUrl = '/api/v1/passport/auth/getQuickLoginUrl';
  static const String loginWithMailLink = '/api/v1/passport/auth/loginWithMailLink';

  // User
  static const String userInfo = '/api/v1/user/info';
  static const String userUpdate = '/api/v1/user/update';
  static const String getSubscribe = '/api/v1/user/getSubscribe';
  static const String resetSecurity = '/api/v1/user/resetSecurity';
  static const String changePassword = '/api/v1/user/changePassword';
  static const String bindEmail = '/api/v1/user/bindEmail';
  static const String getActiveSessions = '/api/v1/user/getActiveSession';
  static const String removeActiveSession = '/api/v1/user/removeActiveSession';
  static const String getStat = '/api/v1/user/getStat';
  static const String checkLogin = '/api/v1/user/checkLogin';
  static const String transfer = '/api/v1/user/transfer';
  static const String userQuickLoginUrl = '/api/v1/user/getQuickLoginUrl';

  // Server
  static const String serverFetch = '/api/v1/user/server/fetch';

  // Plans
  static const String planFetch = '/api/v1/user/plan/fetch';

  // Orders
  static const String orderFetch = '/api/v1/user/order/fetch';
  static const String orderSave = '/api/v1/user/order/save';
  static const String orderCancel = '/api/v1/user/order/cancel';
  static const String orderCheckout = '/api/v1/user/order/checkout';
  static const String orderCheck = '/api/v1/user/order/check';
  static const String paymentMethod = '/api/v1/user/order/getPaymentMethod';

  // Traffic Packages
  static const String trafficPackageFetch = '/api/v1/user/traffic-package/fetch';
  static const String trafficPackageMy = '/api/v1/user/traffic-package/mine';
  static const String trafficPackagePurchase = '/api/v1/user/traffic-package/purchase';
  static const String trafficPackageReorder = '/api/v1/user/traffic-package/reorder';
  static const String trafficPackageToggleAutoRenew = '/api/v1/user/traffic-package/toggle-auto-renew';
  static const String trafficPackageStats = '/api/v1/user/traffic-package/stats';
  static const String trafficPackageSetPriority = '/api/v1/user/traffic-package/set-priority';

  // Recharge
  static const String rechargeOrderSave = '/api/v1/user/order/save';

  // Tickets
  static const String ticketFetch = '/api/v1/user/ticket/fetch';
  static const String ticketSave = '/api/v1/user/ticket/save';
  static const String ticketReply = '/api/v1/user/ticket/reply';
  static const String ticketClose = '/api/v1/user/ticket/close';
  static const String ticketWithdraw = '/api/v1/user/ticket/withdraw';

  // Notices
  static const String noticeFetch = '/api/v1/user/notice/fetch';

  // Invite
  static const String inviteSave = '/api/v1/user/invite/save';
  static const String inviteFetch = '/api/v1/user/invite/fetch';
  static const String inviteDetails = '/api/v1/user/invite/details';

  // Coupon
  static const String couponCheck = '/api/v1/user/coupon/check';

  // Gift Card
  static const String giftCardCheck = '/api/v1/user/gift-card/check';
  static const String giftCardRedeem = '/api/v1/user/gift-card/redeem';
  static const String giftCardHistory = '/api/v1/user/gift-card/history';
  static const String giftCardDetail = '/api/v1/user/gift-card/detail';
  static const String giftCardTypes = '/api/v1/user/gift-card/types';

  // Knowledge
  static const String knowledgeFetch = '/api/v1/user/knowledge/fetch';
  static const String knowledgeCategory = '/api/v1/user/knowledge/getCategory';

  // Stats
  static const String trafficLog = '/api/v1/user/stat/getTrafficLog';

  // Communication
  static const String sendEmailVerify = '/api/v1/passport/comm/sendEmailVerify';
  static const String commConfig = '/api/v1/user/comm/config';
  static const String stripePublicKey = '/api/v1/user/comm/getStripePublicKey';
  static const String commPv = '/api/v1/passport/comm/pv';

  // Telegram
  static const String telegramBotInfo = '/api/v1/user/telegram/getBotInfo';
}
