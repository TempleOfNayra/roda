class AppConfig {
  AppConfig._();
  
  // Feature Flags
  static const bool enableHonorSystem = true;
  static const bool enableGoogleSignIn = true;
  static const bool enableAppleSignIn = true;
  static const bool enableLocationServices = true;
  static const bool enablePushNotifications = false;
  static const bool enableAnalytics = false;
  
  // Payment Configuration
  static const bool requirePaymentForAttendance = false;
  static const List<PaymentMethod> enabledPaymentMethods = [
    PaymentMethod.venmo,
    PaymentMethod.payPal,
    PaymentMethod.zelle,
    PaymentMethod.honorSystem,
  ];
  
  // Schedule Configuration
  static const bool allowRecurringClasses = true;
  static const int maxClassesPerWeek = 7;
  static const int defaultClassDurationMinutes = 60;
  static const int minClassDurationMinutes = 30;
  static const int maxClassDurationMinutes = 180;
  
  // Map Configuration
  static const bool showAllClassesOnMap = true;
  static const bool allowMapClustering = true;
  static const double maxSearchRadius = 100.0; // km
  
  // User Configuration
  static const bool requireEmailVerification = false;
  static const bool allowProfileEditing = true;
  static const bool allowGroupSwitching = true;
  
  // Teacher Configuration
  static const bool allowMultipleGroups = false;
  static const bool requireTeacherVerification = false;
  static const int maxStudentsPerClass = 50;
  
  // Development Configuration
  static const bool enableDebugMode = true; // Set to false for production
  static const bool enableMockData = false;
  static const bool logNetworkRequests = false;
  
  // Refresh Intervals (in seconds)
  static const int mapRefreshInterval = enableDebugMode ? 1 : 5;
  static const int dashboardRefreshInterval = enableDebugMode ? 2 : 10;
  static const int scheduleRefreshInterval = enableDebugMode ? 3 : 15;
}

enum PaymentMethod {
  venmo,
  payPal,
  zelle,
  honorSystem,
}