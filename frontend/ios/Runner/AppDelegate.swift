import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Safely set up method channel after Flutter engine is initialized
    // Use optional binding and optional casting to prevent crashes
    if let window = self.window,
       let controller = window.rootViewController as? FlutterViewController {
      let securityChannel = FlutterMethodChannel(name: "com.budgetapp/security",
                                                  binaryMessenger: controller.binaryMessenger)
      
      securityChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "enableScreenshotProtection" {
          self.enableScreenshotProtection()
          result(true)
        } else if call.method == "disableScreenshotProtection" {
          self.disableScreenshotProtection()
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return result
  }
  
  private var protectionView: UIView?
  
  private func enableScreenshotProtection() {
    // Create a blurred/black view to show in app switcher
    if let window = self.window {
      // Remove existing protection view if any
      if let existingView = protectionView {
        existingView.removeFromSuperview()
      }
      
      // Create a new protection view
      let secureView = UIView(frame: window.bounds)
      secureView.backgroundColor = UIColor.black
      secureView.tag = 999999
      secureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      
      // Add blur effect for better visual
      if #available(iOS 10.0, *) {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = secureView.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        secureView.addSubview(blurView)
      }
      
      window.addSubview(secureView)
      window.bringSubviewToFront(secureView)
      protectionView = secureView
    }
  }
  
  private func disableScreenshotProtection() {
    // Remove the screenshot protection view
    if let window = self.window, let secureView = window.viewWithTag(999999) {
      secureView.removeFromSuperview()
      protectionView = nil
    }
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    // App is going to background - enable protection for app switcher
    enableScreenshotProtection()
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    // App is becoming active - disable protection
    disableScreenshotProtection()
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Ensure protection is enabled when app enters background
    enableScreenshotProtection()
  }
}
