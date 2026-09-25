import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let desktopChannel = FlutterMethodChannel(
      name: "pocketedge/desktop",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    desktopChannel.setMethodCallHandler { call, result in
      guard call.method == "setPersistent" else {
        result(FlutterMethodNotImplemented)
        return
      }
      (NSApp.delegate as? AppDelegate)?.persistentHost = (call.arguments as? Bool) ?? false
      result(nil)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
