import Flutter
import UIKit
import GoogleMaps // GoogleMaps import 추가

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Info.plist에서 API 키 읽어오기
    if let googleMapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String {
      GMSServices.provideAPIKey(googleMapsApiKey)
    } else {
      print("Error: Google Maps API Key not found in Info.plist")
      // 키가 없을 경우의 처리 로직 (예: 앱 종료 또는 기본 기능만 제공)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
