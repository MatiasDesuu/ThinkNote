import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Enable custom titlebar for bitsdojo_window
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)

    super.awakeFromNib()
  }

  override func keyDown(with event: NSEvent) {
    // Handle Cmd+W to close window
    if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
      self.performClose(self)
      return
    }
    super.keyDown(with: event)
  }
}
