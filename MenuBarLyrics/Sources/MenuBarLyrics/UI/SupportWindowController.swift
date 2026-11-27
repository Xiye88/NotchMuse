import AppKit
import CoreImage
import ImageIO

@MainActor
final class SupportWindowController: NSWindowController {
    private static let evmAddress = "0x6c0275e975818e99d078ee2348576e2d9608f6d6"
    private static let qqGroupID = "1137981671"
    private var copyResets: [ObjectIdentifier: DispatchWorkItem] = [:]
    private let supporters = NSTextField(wrappingLabelWithString: L10n.text("Thanks to everyone supporting NotchMuse."))

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 680),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L10n.text("Support NotchMuse")
        window.center()
        super.init(window: window)
        buildContent()
        loadSupporters()
    }

    required init?(coder: NSCoder) { nil }

    private func buildContent() {
        guard let window else { return }
        let body = NSStackView()
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 18
        body.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        body.addArrangedSubview(heading(L10n.text("Support NotchMuse"), size: 24))
        let intro = label(L10n.text("NotchMuse is a free passion project built with love. If it brightens your listening, feel free to buy me a coffee or join the user group."))
        body.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -56).isActive = true

        let methods = NSStackView()
        methods.orientation = .horizontal
        methods.alignment = .top
        methods.spacing = 18
        methods.distribution = .fillEqually
        methods.addArrangedSubview(supportCard(title: L10n.text("WeChat Pay"), image: Self.weChatQRImage()))
        let copyGroupID = NSButton(title: L10n.text("Copy Group ID"), target: self, action: #selector(copyGroupID(_:)))
        methods.addArrangedSubview(supportCard(title: L10n.text("QQ User Group"), image: Self.qqGroupQRImage(),
                                              details: [label(Self.qqGroupID)], action: copyGroupID))
        let copyAddress = NSButton(title: L10n.text("Copy Address"), target: self, action: #selector(copyAddress(_:)))
        let address = Self.evmAddress
        methods.addArrangedSubview(supportCard(title: "USDT · EVM", image: Self.qrImage(address), details: [
            label("ETH · BSC · Arbitrum · Optimism"),
            label(L10n.text("EVM networks · USDT only")),
            label(String(address.prefix(4)) + "…" + String(address.suffix(4)))
        ], action: copyAddress))
        body.addArrangedSubview(methods)
        methods.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -56).isActive = true
        body.addArrangedSubview(heading(L10n.text("Supporters"), size: 17))
        supporters.font = .systemFont(ofSize: 13)
        supporters.textColor = .secondaryLabelColor
        body.addArrangedSubview(supporters)

        window.contentView = body
    }

    private func supportCard(title: String, image: NSImage?, details: [NSView] = [], action: NSButton? = nil) -> NSView {
        let card = SupportCardView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1

        let imageView = PixelSharpImageView(frame: .zero)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setAccessibilityLabel(title)
        let content = NSStackView(views: [heading(title, size: 14), imageView] + details)
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 9
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 350),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            imageView.widthAnchor.constraint(equalToConstant: 180),
            imageView.heightAnchor.constraint(equalToConstant: 180)
        ])
        for detail in details {
            detail.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor).isActive = true
            (detail as? NSTextField)?.alignment = .center
        }
        if let action {
            action.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(action)
            NSLayoutConstraint.activate([
                action.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                action.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
                action.topAnchor.constraint(greaterThanOrEqualTo: content.bottomAnchor, constant: 8)
            ])
        }
        return card
    }

    private func heading(_ text: String, size: CGFloat) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: .semibold)
        return field
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: 12)
        field.textColor = .secondaryLabelColor
        return field
    }

    private static func qrImage(_ value: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let code = filter.outputImage else { return nil }
        let image = code.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        let extent = image.extent.insetBy(dx: -16, dy: -16)
        let background = CIImage(color: .white).cropped(to: extent)
        guard let cgImage = CIContext().createCGImage(image.composited(over: background), from: extent) else { return nil }
        return NSImage(cgImage: cgImage, size: extent.size)
    }

    static func supportResource(_ name: String, extension ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        // SwiftPM's generated accessor traps when its sidecar is absent. A packaged app uses Contents/Resources.
        guard Bundle.main.bundleURL.pathExtension != "app" else { return nil }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }

    private static func weChatQRImage() -> NSImage? {
        guard let url = supportResource("WeChatSupport", extension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let cropped = original.cropping(to: CGRect(x: 300, y: 382, width: 640, height: 640)) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }

    private static func qqGroupQRImage() -> NSImage? {
        supportResource("qq-group-qr", extension: "png").flatMap(NSImage.init(contentsOf:))
    }

    @objc private func copyGroupID(_ sender: NSButton) {
        copy(Self.qqGroupID, sender: sender, title: "Copy Group ID", feedback: "Copied ✓")
    }

    @objc private func copyAddress(_ sender: NSButton) {
        copy(Self.evmAddress, sender: sender, title: "Copy Address", feedback: "Copied")
    }

    private func copy(_ value: String, sender: NSButton, title: String, feedback: String) {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(value, forType: .string) else { return }
        sender.title = L10n.text(feedback)
        if value == Self.qqGroupID { InteractionSoundEngine.shared.play(.landed) }
        let id = ObjectIdentifier(sender)
        copyResets[id]?.cancel()
        let reset = DispatchWorkItem { [weak self, weak sender] in
            sender?.title = L10n.text(title)
            self?.copyResets.removeValue(forKey: id)
        }
        copyResets[id] = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: reset)
    }

    private func loadSupporters() {
        guard let url = URL(string: "https://raw.githubusercontent.com/Xiye88/NotchMuse/main/docs/support/supporters.json") else { return }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let people = try? JSONDecoder().decode([Supporter].self, from: data), !people.isEmpty else { return }
            self?.supporters.stringValue = people.map { "\($0.name) · \($0.displayAmount)" }.joined(separator: "\n")
        }
    }
}

private final class SupportCardView: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshColors()
    }

    private func refreshColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}

private final class PixelSharpImageView: NSImageView {
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        super.draw(dirtyRect)
    }
}

private struct Supporter: Decodable {
    let name: String
    let displayAmount: String
}
