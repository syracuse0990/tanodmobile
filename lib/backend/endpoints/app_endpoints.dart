class AppEndpoints {
  const AppEndpoints._();

  static const String login = '/login';
  static const String register = '/register';
  static const String registrationRoles = '/register/roles';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String profile = '/profile';
  static const String password = '/password';
  static const String tractors = '/tractors';
  static const String devices = '/devices';
  static const String devicesShare = '/devices/share';
  static const String devicesLiveLocations = '/devices/live-locations';
  static const String devicesFollow = '/devices/follow'; // + /{deviceId}
  static const String devicesTrackData = '/devices/track-data';
  static const String bookings = '/bookings';
  static const String bookingSlots = '/booking-slots';
  static const String myFarmers = '/my-farmers';
  static const String notifications = '/notifications';
  static const String alerts = '/alerts';
  static const String fcmToken = '/fcm-token';
  static const String phoneSendCode = '/phone/send-code';
  static const String phoneVerify = '/phone/verify';
  static const String tickets = '/tickets';

  // TPS endpoints
  static const String tpsDashboard = '/tps/dashboard';
  static const String tpsTickets = '/tps/tickets';
  static const String tpsMaintenances = '/tps/maintenances';
  static const String tpsFeedbacks = '/tps/feedbacks';
  static const String tpsTractors = '/tps/tractors';
  static const String tpsDistributions = '/tps/distributions';
}
