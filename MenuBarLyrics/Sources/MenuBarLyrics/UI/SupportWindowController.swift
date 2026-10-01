import AppKit
import CoreImage

@MainActor
final class SupportWindowController: NSWindowController {
    private static let evmAddress = "0x6c0275e975818e99d078ee2348576e2d9608f6d6"
    private static let tronAddress = "TCTrNcvTD3QE7opC61mKoTyUmRkKos6jan"
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
        body.addArrangedSubview(label(L10n.text("Your support helps keep NotchMuse improving.")))

        let methods = NSStackView()
        methods.orientation = .horizontal
        methods.alignment = .top
        methods.spacing = 18
        methods.distribution = .fillEqually
        methods.addArrangedSubview(paymentCard(title: L10n.text("WeChat Pay"),
                                                detail: "", image: NSImage(contentsOfFile: Bundle.main.path(forResource: "WeChatSupport", ofType: "jpg") ?? ""),
                                                address: nil))
        methods.addArrangedSubview(paymentCard(title: "USDT · BNB Smart Chain", detail: "BEP20",
                                                image: Self.qrImage(Self.evmAddress), address: Self.evmAddress))
        methods.addArrangedSubview(paymentCard(title: "USDT · TRON", detail: "TRC20",
                                                image: Self.qrImage(Self.tronAddress), address: Self.tronAddress))
        body.addArrangedSubview(methods)
        methods.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -56).isActive = true
        body.addArrangedSubview(label(L10n.text("Check the selected network and send USDT only.")))
        body.addArrangedSubview(heading(L10n.text("Supporters"), size: 17))
        supporters.font = .systemFont(ofSize: 13)
        supporters.textColor = .secondaryLabelColor
        body.addArrangedSubview(supporters)

        window.contentView = body
    }

    private func paymentCard(title: String, detail: String, image: NSImage?, address: String?) -> NSView {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .centerX
        card.spacing = 9
        card.edgeInsets = NSEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.addArrangedSubview(heading(title, size: 14))
        if let image {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyDown
            imageView.widthAnchor.constraint(equalToConstant: 170).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 230).isActive = true
            card.addArrangedSubview(imageView)
        }
        if !detail.isEmpty { card.addArrangedSubview(label(detail)) }
        if let address {
            let addressLabel = label(address)
            addressLabel.lineBreakMode = .byCharWrapping
            addressLabel.alignment = .center
            card.addArrangedSubview(addressLabel)
            let copy = NSButton(title: L10n.text("Copy Address"), target: self, action: #selector(copyAddress(_:)))
            copy.identifier = NSUserInterfaceItemIdentifier(address)
            card.addArrangedSubview(copy)
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
        guard let image = filter.outputImage,
              let cgImage = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 180, height: 180))
    }

    @objc private func copyAddress(_ sender: NSButton) {
        guard let address = sender.identifier?.rawValue else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
    }

    private func loadSupporters() {
        guard let url = URL(string: "https://raw.githubusercontent.com/Xiye88/NotchMuse/main/docs/support/supporters.json") else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let people = try? JSONDecoder().decode([Supporter].self, from: data), !people.isEmpty else { return }
            supporters.stringValue = people.map { "\($0.name) · \($0.displayAmount)" }.joined(separator: "\n")
        }
    }
}

private struct Supporter: Decodable {
    let name: String
    let displayAmount: String
}
