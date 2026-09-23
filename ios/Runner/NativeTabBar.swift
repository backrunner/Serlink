import Flutter
import UIKit

final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    NativeTabBar(frame: frame, id: viewId, messenger: messenger, arguments: args)
  }
}

/// Keep UIKit's default appearance: assigning an opaque/custom appearance here
/// would replace the system Liquid Glass treatment on iOS 26 and later.
final class NativeTabBar: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let container: NativeTabBarContainer
  private let channel: FlutterMethodChannel
  private var labels: [String] = []
  private static let symbols = [
    "square.stack.3d.up", "macwindow", "arrow.up.arrow.down",
    "chevron.left.forwardslash.chevron.right", "gearshape",
  ]
  private static let selectedSymbols = [
    "square.stack.3d.up.fill", "macwindow", "arrow.up.arrow.down",
    "chevron.left.forwardslash.chevron.right", "gearshape.fill",
  ]

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, arguments: Any?) {
    container = NativeTabBarContainer(frame: frame)
    channel = FlutterMethodChannel(name: "serlink/native_tab_bar/\(id)", binaryMessenger: messenger)
    super.init()
    container.bar.delegate = self
    container.onHeightChanged = { [weak self] height in
      self?.channel.invokeMethod("height", arguments: Double(height))
    }
    update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "update":
        self.update(call.arguments)
        self.container.reportHeight(force: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func update(_ arguments: Any?) {
    guard let config = arguments as? [String: Any],
      let nextLabels = config["labels"] as? [String],
      nextLabels.count == Self.symbols.count,
      let index = config["index"] as? Int,
      nextLabels.indices.contains(index)
    else { return }

    if nextLabels != labels {
      labels = nextLabels
      container.bar.items = labels.enumerated().map { index, label in
        let item = UITabBarItem(
          title: label,
          image: UIImage(systemName: Self.symbols[index]),
          selectedImage: UIImage(systemName: Self.selectedSymbols[index])
        )
        item.tag = index
        item.accessibilityIdentifier = "workspace-tab-\(index)"
        return item
      }
    }
    container.bar.selectedItem = container.bar.items?[index]
    container.overrideUserInterfaceStyle = (config["dark"] as? Bool == true) ? .dark : .light
    if let argb = config["tint"] as? NSNumber {
      let value = argb.uint32Value
      container.tintColor = UIColor(
        red: CGFloat((value >> 16) & 0xff) / 255,
        green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255,
        alpha: CGFloat((value >> 24) & 0xff) / 255
      )
    }
    container.setNeedsLayout()
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("select", arguments: item.tag)
  }

  deinit { channel.setMethodCallHandler(nil) }
}

final class NativeTabBarContainer: UIView {
  let bar = UITabBar()
  var onHeightChanged: ((CGFloat) -> Void)?
  private var lastHeight: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    addSubview(bar)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    bar.frame = bounds
    reportHeight()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    setNeedsLayout()
  }

  func reportHeight(force: Bool = false) {
    guard window != nil, bounds.width > 0 else { return }
    let height = bar.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
    guard height > 0, force || abs(height - lastHeight) > 0.5 else { return }
    lastHeight = height
    onHeightChanged?(height)
  }
}
