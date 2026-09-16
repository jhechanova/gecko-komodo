import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeAppDataFromBackup()
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Keep URL/user SQLite (and other sandbox files) out of iCloud / device backups
  /// so a restore does not revive a previous session after reinstall.
  private func excludeAppDataFromBackup() {
    let fileManager = FileManager.default
    let urls = [
      fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
      fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first,
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
    ].compactMap { $0 }

    for url in urls {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutableUrl = url
      try? mutableUrl.setResourceValues(values)
    }
  }
}
