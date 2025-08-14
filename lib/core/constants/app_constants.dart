class AppConstants {
  AppConstants._();
  
  // App Info
  static const String appName = 'RODA';
  static const String appDescription = 'Capoeira Class & Roda Tracker';
  
  // Time Constants
  static const int sessionTimeoutMinutes = 30;
  static const int classScheduleWeeksAhead = 12;
  
  // Map Constants
  static const double defaultMapZoom = 12.0;
  static const double searchRadiusKm = 50.0;
  
  // Validation Constants
  static const int minPasswordLength = 6;
  static const int minAge = 13;
  static const int maxAge = 100;
  
  // Days of Week
  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  
  static const List<String> daysOfWeekShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  
  // Payment Methods
  static const List<String> paymentMethods = [
    'Venmo',
    'PayPal',
    'Zelle',
    'Honor System',
  ];
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
  static const String classesCollection = 'classes';
  
  // Shared Preferences Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyUserRole = 'user_role';
  static const String keyLastLocation = 'last_location';
}