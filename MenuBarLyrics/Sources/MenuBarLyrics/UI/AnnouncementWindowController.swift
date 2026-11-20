import AppKit

@MainActor
final class AnnouncementWindowController: NSWindowController {
    static let shared = AnnouncementWindowController()

    private let stackView = NSStackView()
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let footerPrefixLabel = NSTextField(labelWithString: "")
    private let footerEmailButton = NSButton(title: "support@notchmuse.com", target: nil, action: nil)
    private let footerIssuesButton = NSButton(title: "GitHub Issues", target: nil, action: nil)
    private var announcementObserver: NSObjectProtocol?
    private var itemURLs: [Int: URL] = [:]

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 440, height: 360)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI()
        observeChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        reloadContent()
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let docView = FlippedContentView()
        docView.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        docView.addSubview(stackView)
        scrollView.documentView = docView

        let footerDivider = NSBox()
        footerDivider.boxType = .separator
        footerDivider.translatesAutoresizingMaskIntoConstraints = false

        footerPrefixLabel.font = .systemFont(ofSize: 11.5)
        footerPrefixLabel.textColor = .secondaryLabelColor

        footerEmailButton.target = self
        footerEmailButton.action = #selector(openSupportEmail)
        footerEmailButton.isBordered = false
        footerEmailButton.font = .systemFont(ofSize: 11.5, weight: .medium)
        footerEmailButton.contentTintColor = NSColor(calibratedRed: 0.95, green: 0.48, blue: 0.16, alpha: 1.0)

        let dotLabel = NSTextField(labelWithString: "·")
        dotLabel.font = .systemFont(ofSize: 11.5)
        dotLabel.textColor = .tertiaryLabelColor

        footerIssuesButton.target = self
        footerIssuesButton.action = #selector(openGitHubIssues)
        footerIssuesButton.isBordered = false
        footerIssuesButton.font = .systemFont(ofSize: 11.5, weight: .medium)
        footerIssuesButton.contentTintColor = NSColor(calibratedRed: 0.95, green: 0.48, blue: 0.16, alpha: 1.0)

        let footerRow = NSStackView(views: [footerPrefixLabel, footerEmailButton, dotLabel, footerIssuesButton])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY
        footerRow.spacing = 6
        footerRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(header)
        contentView.addSubview(scrollView)
        contentView.addSubview(footerDivider)
        contentView.addSubview(footerRow)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            subtitleLabel.topAnchor.constraint(equalTo: header.topAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerDivider.topAnchor),

            footerDivider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            footerDivider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            footerDivider.bottomAnchor.constraint(equalTo: footerRow.topAnchor, constant: -9),

            footerRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            footerRow.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            footerRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            docView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            docView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            docView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            docView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: docView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: docView.bottomAnchor)
        ])
    }

    private func observeChanges() {
        announcementObserver = NotificationCenter.default.addObserver(
            forName: AnnouncementManager.notification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadContent() }
        }
    }

    func reloadIfVisible() {
        guard window?.isVisible == true else { return }
        reloadContent()
    }

    private func reloadContent() {
        let isZh = AppPreferences.language == .simplifiedChinese
        window?.title = isZh ? "更新与公告" : "Updates & Announcements"
        subtitleLabel.stringValue = isZh
            ? "查看 NotchMuse 最新公告与历史版本更新记录"
            : "Latest NotchMuse announcements and release history"
        footerPrefixLabel.stringValue = isZh ? "反馈与交流：" : "Feedback & Support:"

        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        itemURLs.removeAll()

        let items = AnnouncementManager.shared.historyItems
        for (idx, item) in items.enumerated() {
            let card = makeCard(for: item, index: idx, isZh: isZh)
            stackView.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive = true
        }
    }

    private func makeCard(for item: AnnouncementEntry, index: Int, isZh: Bool) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 12
        box.borderWidth = 0.5
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.55)
        box.fillColor = NSColor.controlBackgroundColor
        box.contentViewMargins = NSSize(width: 14, height: 12)
        box.translatesAutoresizingMaskIntoConstraints = false

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        // Meta row: badge + date
        let metaRow = NSStackView()
        metaRow.orientation = .horizontal
        metaRow.alignment = .centerY
        metaRow.spacing = 8

        if let badgeText = item.localizedBadge, !badgeText.isEmpty {
            let badgeBox = NSBox()
            badgeBox.boxType = .custom
            badgeBox.cornerRadius = 5
            badgeBox.borderWidth = 0
            let isLatest = index == 0
            badgeBox.fillColor = isLatest
                ? NSColor(calibratedRed: 1.0, green: 0.54, blue: 0.21, alpha: 0.18)
                : NSColor.quaternaryLabelColor.withAlphaComponent(0.35)
            badgeBox.contentViewMargins = NSSize(width: 6, height: 2)

            let badgeLabel = NSTextField(labelWithString: badgeText)
            badgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
            badgeLabel.textColor = isLatest
                ? NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.12, alpha: 1.0)
                : .secondaryLabelColor
            badgeBox.contentView?.addSubview(badgeLabel)
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            if let cv = badgeBox.contentView {
                NSLayoutConstraint.activate([
                    badgeLabel.topAnchor.constraint(equalTo: cv.topAnchor),
                    badgeLabel.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
                    badgeLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                    badgeLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
                ])
            }
            metaRow.addArrangedSubview(badgeBox)
        }

        if let date = item.date, !date.isEmpty {
            let dateLabel = NSTextField(labelWithString: date)
            dateLabel.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
            dateLabel.textColor = .secondaryLabelColor
            metaRow.addArrangedSubview(dateLabel)
        }

        let titleLabel = NSTextField(wrappingLabelWithString: item.localizedTitle)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isSelectable = true

        let bodyLabel = NSTextField(wrappingLabelWithString: item.localizedBody)
        bodyLabel.font = .systemFont(ofSize: 12.5)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.isSelectable = true

        container.addArrangedSubview(metaRow)
        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(bodyLabel)

        if let safeURL = item.safeURL {
            itemURLs[index] = safeURL
            let linkBtn = NSButton(
                title: isZh ? "在浏览器中查看完整说明 ↗" : "View Full Notes in Browser ↗",
                target: self,
                action: #selector(openEntryLink(_:))
            )
            linkBtn.tag = index
            linkBtn.isBordered = false
            linkBtn.font = .systemFont(ofSize: 12, weight: .medium)
            linkBtn.contentTintColor = NSColor(calibratedRed: 0.95, green: 0.48, blue: 0.16, alpha: 1.0)
            container.addArrangedSubview(linkBtn)
        }

        box.contentView?.addSubview(container)
        if let cv = box.contentView {
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cv.topAnchor),
                container.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
                container.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
            ])
        }
        return box
    }

    @objc private func openEntryLink(_ sender: NSButton) {
        guard let url = itemURLs[sender.tag] else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openSupportEmail() {
        if let url = URL(string: "mailto:support@notchmuse.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGitHubIssues() {
        if let url = URL(string: "https://github.com/Xiye88/NotchMuse/issues") {
            NSWorkspace.shared.open(url)
        }
    }
}

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}
