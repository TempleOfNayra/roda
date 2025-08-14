import Flutter
import UIKit
import GoogleMaps
import GooglePlaces

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps and Places API key (using the same unrestricted key)
    GMSServices.provideAPIKey("AIzaSyD0RWCliozfGpgzQX-cJDFFHV224-bNwGY")
    GMSPlacesClient.provideAPIKey("AIzaSyD0RWCliozfGpgzQX-cJDFFHV224-bNwGY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
