import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var foregroundChannel: FlutterMethodChannel?
  private var notificationClientReady = false
  private var pendingNotificationPayloads: [[String: Any]] = []

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
    foregroundChannel = FlutterMethodChannel(
      name: "notif_app/foreground_notification",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    foregroundChannel?.setMethodCallHandler { call, result in
      if call.method == "getDeliveredNotifications" {
        self.replyWithDeliveredNotifications(result)
      } else if call.method == "clientReady" {
        self.notificationClientReady = true
        self.flushPendingNotifications()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    importDeliveredNotifications()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    importDeliveredNotifications()
  }

  /// Background alerts are shown by iOS and are not delivered to Dart.
  /// Pull whatever is still in Notification Center into the in-app list.
  func importDeliveredNotifications() {
    guard foregroundChannel != nil else { return }
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      let payloads = notifications.compactMap { self.notificationPayload($0) }
      DispatchQueue.main.async {
        for payload in payloads {
          self.foregroundChannel?.invokeMethod("onForegroundNotification", arguments: payload)
        }
      }
    }
  }

  private func replyWithDeliveredNotifications(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
      let payloads = notifications.compactMap { self.notificationPayload($0) }
      DispatchQueue.main.async {
        result(payloads)
      }
    }
  }

  /// Show a banner and keep the notification in Notification Center while the
  /// app is open. Firebase only sets the deprecated alert option, which iOS 14+
  /// does not display. The in-app list is updated through
  /// `forwardForegroundNotification`.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    forwardForegroundNotification(notification)
    let present: UNNotificationPresentationOptions = [.banner, .list, .badge, .sound]
    var didComplete = false
    super.userNotificationCenter(center, willPresent: notification) { _ in
      guard !didComplete else { return }
      didComplete = true
      completionHandler(present)
    }
    if !didComplete {
      didComplete = true
      completionHandler(present)
    }
  }

  /// A tap removes the alert from Notification Center, so it must be stored
  /// here. Queue it when Dart is not listening yet (cold start from a tap).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    forwardForegroundNotification(response.notification)
    var didComplete = false
    super.userNotificationCenter(center, didReceive: response) {
      guard !didComplete else { return }
      didComplete = true
      completionHandler()
    }
    if !didComplete {
      didComplete = true
      completionHandler()
    }
  }

  /// Tells Dart to store the notification. Firebase's callbacks do not run for
  /// every foreground delivery or notification tap.
  private func forwardForegroundNotification(_ notification: UNNotification) {
    guard let payload = notificationPayload(notification) else { return }
    if notificationClientReady, foregroundChannel != nil {
      foregroundChannel?.invokeMethod("onForegroundNotification", arguments: payload)
    } else {
      pendingNotificationPayloads.append(payload)
    }
  }

  private func flushPendingNotifications() {
    let pending = pendingNotificationPayloads
    pendingNotificationPayloads = []
    for payload in pending {
      foregroundChannel?.invokeMethod("onForegroundNotification", arguments: payload)
    }
  }

  private func notificationPayload(_ notification: UNNotification) -> [String: Any]? {
    let content = notification.request.content
    let userInfo = content.userInfo
    if userInfo["payload"] != nil && userInfo["presentAlert"] != nil {
      return nil
    }

    let messageId = stringValue(userInfo["gcm.message_id"])
      ?? stringValue(userInfo["google.message_id"])
      ?? stringValue(userInfo["message_id"])
      ?? notification.request.identifier

    var data: [String: String] = [:]
    for (key, value) in userInfo {
      guard let key = key as? String else { continue }
      if key == "aps" || key.hasPrefix("gcm.") || key.hasPrefix("google.") {
        continue
      }
      if let text = stringValue(value) {
        data[key] = text
      }
    }

    let title = content.title.isEmpty ? "Notification" : content.title
    let receivedAt = Int(notification.date.timeIntervalSince1970 * 1000)
    return [
      "messageId": messageId,
      "title": title,
      "body": content.body,
      "data": data,
      "receivedAt": receivedAt,
    ]
  }

  private func stringValue(_ value: Any?) -> String? {
    if let text = value as? String {
      return text.isEmpty ? nil : text
    }
    if let number = value as? NSNumber {
      return number.stringValue
    }
    return nil
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
