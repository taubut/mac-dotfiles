import Cocoa
import Foundation

// MARK: - GitHub API (single tree request)

struct GitHubFile {
    let name: String
    let downloadURL: String
}

// Holds the entire repo structure - fetched once, cached to disk
class RepoData {
    static let shared = RepoData()
    var categories: [String: [GitHubFile]] = [:]
    var sortedCategoryNames: [String] = []

    private var cacheURL: URL {
        let wallDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".wallpicker")
        try? FileManager.default.createDirectory(at: wallDir, withIntermediateDirectories: true)
        return wallDir.appendingPathComponent("repo_cache.json")
    }

    func load() {
        // Try disk cache first (valid for 24 hours)
        if loadFromDisk() { return }
        // Try API
        if loadFromAPI() { saveToDisk(); return }
        // Fallback: try disk cache even if stale
        let _ = loadFromDisk(ignoreAge: true)
    }

    private func loadFromDisk(ignoreAge: Bool = false) -> Bool {
        guard FileManager.default.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = json["timestamp"] as? Double,
              let catsJson = json["categories"] as? [String: [[String: String]]] else { return false }

        // Check if cache is less than 24 hours old
        if !ignoreAge && Date().timeIntervalSince1970 - timestamp > 86400 { return false }

        var cats: [String: [GitHubFile]] = [:]
        for (cat, files) in catsJson {
            cats[cat] = files.compactMap { dict in
                guard let name = dict["name"], let url = dict["url"] else { return nil }
                return GitHubFile(name: name, downloadURL: url)
            }
        }
        self.categories = cats
        self.sortedCategoryNames = cats.keys.sorted()
        return !cats.isEmpty
    }

    private func saveToDisk() {
        var catsJson: [String: [[String: String]]] = [:]
        for (cat, files) in categories {
            catsJson[cat] = files.map { ["name": $0.name, "url": $0.downloadURL] }
        }
        let json: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "categories": catsJson
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: cacheURL)
        }
    }

    private func loadFromAPI() -> Bool {
        let url = URL(string: "https://api.github.com/repos/dharmx/walls/git/trees/main?recursive=1")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        var success = false
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { sem.signal() }
            // Check for rate limit or error
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 { return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tree = json["tree"] as? [[String: Any]] else { return }

            var cats: [String: [GitHubFile]] = [:]
            let imageExts = Set(["jpg", "jpeg", "png", "webp", "bmp", "gif"])

            for item in tree {
                guard let path = item["path"] as? String,
                      let type = item["type"] as? String,
                      type == "blob" else { continue }

                let parts = path.split(separator: "/", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let category = String(parts[0])
                let filename = String(parts[1])
                guard !category.hasPrefix(".") else { continue }
                guard !filename.contains("/") else { continue }

                let ext = (filename as NSString).pathExtension.lowercased()
                guard imageExts.contains(ext) else { continue }

                let downloadURL = "https://raw.githubusercontent.com/dharmx/walls/main/\(path)"
                let file = GitHubFile(name: filename, downloadURL: downloadURL)
                cats[category, default: []].append(file)
            }

            self.categories = cats
            self.sortedCategoryNames = cats.keys.sorted()
            success = !cats.isEmpty
        }.resume()
        sem.wait()
        return success
    }
}

func downloadImage(url: String) -> NSImage? {
    guard let url = URL(string: url) else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    var result: NSImage?
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, _, _ in
        defer { sem.signal() }
        if let data = data {
            result = NSImage(data: data)
        }
    }.resume()
    sem.wait()
    return result
}

func setWallpaper(imageURL: String) {
    guard let url = URL(string: imageURL) else { return }
    var request = URLRequest(url: url)
    request.timeoutInterval = 60
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, _, _ in
        defer { sem.signal() }
        guard let data = data else { return }
        let filename = (url.lastPathComponent as NSString).deletingPathExtension
        let ext = url.pathExtension
        let wallDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".wallpicker")
        try? FileManager.default.createDirectory(at: wallDir, withIntermediateDirectories: true)
        let dest = wallDir.appendingPathComponent("\(filename).\(ext)")
        try? data.write(to: dest)
        let saveDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Wallpapers")
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let saveDest = saveDir.appendingPathComponent("\(filename).\(ext)")
        try? FileManager.default.copyItem(at: dest, to: saveDest)
        let catppuccinifyPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/catppuccinify").path
        if FileManager.default.fileExists(atPath: catppuccinifyPath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [catppuccinifyPath, saveDest.path]
            process.currentDirectoryURL = saveDir
            try? process.run()
            process.waitUntilExit()
        }
        let catppuccinFile = saveDir.appendingPathComponent("\(filename)-catppuccin-macchiato.\(ext)")
        let wallpaperToSet = FileManager.default.fileExists(atPath: catppuccinFile.path) ? catppuccinFile : dest
        DispatchQueue.main.async {
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(wallpaperToSet, for: screen, options: [:])
            }
        }
        // Generate colors from wallpaper with pywal and update sketchybar/borders
        let walProcess = Process()
        walProcess.executableURL = URL(fileURLWithPath: "/Users/taubut/Library/Python/3.9/bin/wal")
        walProcess.arguments = ["-i", wallpaperToSet.path, "-n", "-s", "-t", "-e", "-q"]
        try? walProcess.run()
        walProcess.waitUntilExit()
        let colorProcess = Process()
        colorProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        colorProcess.arguments = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/wal-sketchybar").path]
        try? colorProcess.run()
        colorProcess.waitUntilExit()
    }.resume()
    sem.wait()
}

// MARK: - Caches

class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "thumbnailCache", attributes: .concurrent)
    func get(_ key: String) -> NSImage? { queue.sync { cache[key] } }
    func set(_ key: String, image: NSImage) { queue.async(flags: .barrier) { self.cache[key] = image } }
}

class FullImageCache {
    static let shared = FullImageCache()
    private var cache: [String: NSImage] = [:]
    private let queue = DispatchQueue(label: "fullImageCache", attributes: .concurrent)
    func get(_ key: String) -> NSImage? { queue.sync { cache[key] } }
    func set(_ key: String, image: NSImage) { queue.async(flags: .barrier) { self.cache[key] = image } }
}

// MARK: - Theme

struct Theme {
    static let bg = NSColor(white: 0.06, alpha: 0.75)
    static let cardBg = NSColor(white: 0.12, alpha: 0.85)
    static let cardHover = NSColor(white: 0.18, alpha: 0.95)
    static let accent = NSColor(red: 0.38, green: 0.60, blue: 1.0, alpha: 1.0)
    static let textPrimary = NSColor.white
    static let textSecondary = NSColor(white: 0.55, alpha: 1.0)
    static let border = NSColor(white: 0.20, alpha: 0.4)
    static let thumbPlaceholder = NSColor(white: 0.12, alpha: 1.0)
    static let overlayBg = NSColor(white: 0.0, alpha: 0.75)
}

// MARK: - Gradient Layer Helper

func makeGradientLayer(frame: CGRect, topColor: CGColor, bottomColor: CGColor) -> CAGradientLayer {
    let g = CAGradientLayer()
    g.frame = frame
    g.colors = [topColor, bottomColor]
    g.startPoint = CGPoint(x: 0.5, y: 0)
    g.endPoint = CGPoint(x: 0.5, y: 1)
    return g
}

// MARK: - Blur View

class BlurView: NSVisualEffectView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Category Card (with preview image)

class CategoryCard: NSView {
    var category: String = ""
    var onClick: ((String) -> Void)?
    private let imgView = NSImageView()
    private let gradientView = NSView()
    private let label = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = Theme.cardBg.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Theme.border.cgColor
        layer?.masksToBounds = true

        imgView.imageScaling = .scaleAxesIndependently
        imgView.wantsLayer = true
        imgView.imageAlignment = .alignCenter
        addSubview(imgView)

        gradientView.wantsLayer = true
        addSubview(gradientView)

        label.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.wantsLayer = true
        label.shadow = {
            let s = NSShadow()
            s.shadowColor = NSColor(white: 0, alpha: 0.9)
            s.shadowOffset = NSSize(width: 0, height: -1)
            s.shadowBlurRadius = 3
            return s
        }()
        addSubview(label)

        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = NSColor(white: 0.85, alpha: 0.8)
        countLabel.alignment = .left
        countLabel.isBezeled = false
        countLabel.drawsBackground = false
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.wantsLayer = true
        countLabel.shadow = {
            let s = NSShadow()
            s.shadowColor = NSColor(white: 0, alpha: 0.8)
            s.shadowOffset = NSSize(width: 0, height: -1)
            s.shadowBlurRadius = 2
            return s
        }()
        addSubview(countLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, count: Int) {
        category = name
        label.stringValue = name.capitalized
        countLabel.stringValue = "\(count) wallpapers"
    }

    func setPreviewImage(_ image: NSImage?) {
        imgView.image = image
        if image != nil {
            layer?.backgroundColor = NSColor.black.cgColor
        }
    }

    override func layout() {
        super.layout()
        imgView.frame = bounds

        let gradH = bounds.height * 0.35
        gradientView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: gradH)

        gradientView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        let g = makeGradientLayer(
            frame: gradientView.bounds,
            topColor: NSColor.clear.cgColor,
            bottomColor: NSColor(white: 0, alpha: 0.9).cgColor
        )
        gradientView.layer?.addSublayer(g)

        label.frame = NSRect(x: 10, y: 8, width: bounds.width - 20, height: 20)
        countLabel.frame = NSRect(x: 10, y: -4, width: bounds.width - 20, height: 16)
    }

    override func updateTrackingAreas() {
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().layer?.borderColor = Theme.accent.withAlphaComponent(0.6).cgColor
        }
        layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.position = CGPoint(x: frame.midX, y: frame.midY)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            self.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 1.04, y: 1.04))
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().layer?.borderColor = Theme.border.cgColor
            self.animator().layer?.setAffineTransform(.identity)
        }
    }

    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 0.97, y: 0.97))
        }
    }

    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().layer?.setAffineTransform(.identity)
        }
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) { onClick?(category) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Wallpaper Thumbnail Card

class WallpaperCard: NSView {
    var fileInfo: GitHubFile?
    var onPreview: ((GitHubFile) -> Void)?
    let imgView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private let overlay = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = Theme.thumbPlaceholder.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Theme.border.cgColor
        layer?.masksToBounds = true

        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.wantsLayer = true
        addSubview(imgView)

        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(overlay)

        nameLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = Theme.textSecondary
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.isBezeled = false
        nameLabel.drawsBackground = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        addSubview(nameLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(file: GitHubFile) {
        fileInfo = file
        nameLabel.stringValue = file.name
        imgView.image = nil
    }

    override func layout() {
        super.layout()
        let labelH: CGFloat = 26
        imgView.frame = NSRect(x: 0, y: labelH, width: bounds.width, height: bounds.height - labelH)
        overlay.frame = imgView.frame
        nameLabel.frame = NSRect(x: 4, y: 3, width: bounds.width - 8, height: labelH - 6)
    }

    override func updateTrackingAreas() {
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().layer?.borderColor = Theme.accent.withAlphaComponent(0.6).cgColor
        }
        layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.position = CGPoint(x: frame.midX, y: frame.midY)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            self.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 1.04, y: 1.04))
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().layer?.borderColor = Theme.border.cgColor
            self.animator().layer?.setAffineTransform(.identity)
        }
    }

    override func mouseDown(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 0.97, y: 0.97))
        }
    }

    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.animator().layer?.setAffineTransform(.identity)
        }
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc), let file = fileInfo {
            onPreview?(file)
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Preview Overlay

class PreviewOverlay: NSView {
    var onClose: (() -> Void)?

    private let blurBg = BlurView(frame: .zero)
    private let darkBg = NSView()
    private let imageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let setButton = NSButton()
    private let closeButton = NSButton()
    private let spinner = NSProgressIndicator()
    private var file: GitHubFile?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        autoresizingMask = [.width, .height]

        blurBg.material = .fullScreenUI
        blurBg.autoresizingMask = [.width, .height]
        addSubview(blurBg)

        darkBg.wantsLayer = true
        darkBg.layer?.backgroundColor = Theme.overlayBg.cgColor
        darkBg.autoresizingMask = [.width, .height]
        addSubview(darkBg)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 2
        imageView.layer?.borderColor = NSColor(white: 0.3, alpha: 0.5).cgColor
        addSubview(imageView)

        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = Theme.textSecondary
        nameLabel.alignment = .center
        nameLabel.isBezeled = false
        nameLabel.drawsBackground = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        addSubview(nameLabel)

        setButton.title = "Set as Wallpaper"
        setButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        setButton.wantsLayer = true
        setButton.layer?.cornerRadius = 18
        setButton.layer?.backgroundColor = Theme.accent.cgColor
        setButton.isBordered = false
        setButton.contentTintColor = .white
        setButton.target = self
        setButton.action = #selector(setWallpaperClicked)
        addSubview(setButton)

        closeButton.title = "Cancel"
        closeButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 16
        closeButton.layer?.backgroundColor = NSColor(white: 0.25, alpha: 0.6).cgColor
        closeButton.isBordered = false
        closeButton.contentTintColor = Theme.textPrimary
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        addSubview(closeButton)

        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.appearance = NSAppearance(named: .darkAqua)
        spinner.isHidden = true
        addSubview(spinner)

        alphaValue = 0
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(file: GitHubFile, in parentView: NSView) {
        self.file = file
        frame = parentView.bounds
        blurBg.frame = bounds
        darkBg.frame = bounds
        parentView.addSubview(self)

        nameLabel.stringValue = file.name
        layoutElements()

        imageView.image = ThumbnailCache.shared.get(file.downloadURL)
        spinner.frame = NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32)
        spinner.isHidden = false
        spinner.startAnimation(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }

        let url = file.downloadURL
        DispatchQueue.global(qos: .userInitiated).async {
            let img: NSImage?
            if let cached = FullImageCache.shared.get(url) {
                img = cached
            } else if let downloaded = downloadImage(url: url) {
                FullImageCache.shared.set(url, image: downloaded)
                img = downloaded
            } else {
                img = nil
            }
            DispatchQueue.main.async {
                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true
                if let img = img { self.imageView.image = img }
            }
        }
    }

    private func layoutElements() {
        let bottomBar: CGFloat = 70
        let pad: CGFloat = 30

        imageView.frame = NSRect(x: pad, y: bottomBar + 10, width: bounds.width - pad * 2, height: bounds.height - bottomBar - pad - 10)
        nameLabel.frame = NSRect(x: pad, y: bottomBar - 20, width: bounds.width - pad * 2, height: 18)

        let btnW: CGFloat = 180
        let btnH: CGFloat = 36
        let cancelW: CGFloat = 90
        let gap: CGFloat = 12
        let totalW = btnW + gap + cancelW
        let startX = bounds.midX - totalW / 2

        closeButton.frame = NSRect(x: startX, y: 16, width: cancelW, height: 32)
        setButton.frame = NSRect(x: startX + cancelW + gap, y: 14, width: btnW, height: btnH)
    }

    @objc func setWallpaperClicked() {
        guard let file = file else { return }
        setButton.title = "Applying..."
        setButton.isEnabled = false
        setButton.layer?.backgroundColor = Theme.accent.withAlphaComponent(0.5).cgColor

        DispatchQueue.global(qos: .userInitiated).async {
            setWallpaper(imageURL: file.downloadURL)
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    @objc func closeClicked() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.removeFromSuperview()
            self.onClose?()
        })
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if !imageView.frame.contains(loc)
            && !setButton.frame.contains(loc)
            && !closeButton.frame.contains(loc) {
            closeClicked()
        }
    }
}

// MARK: - Main Window Controller

class WallPickerController: NSObject, NSSearchFieldDelegate {
    let window: NSWindow
    let blurView: BlurView
    let mainView: NSView
    var scrollView: NSScrollView!
    var contentView: NSView!
    var searchField: NSSearchField!
    var statusLabel: NSTextField!
    var backButton: NSButton!
    var titleLabel: NSTextField!
    var subtitleLabel: NSTextField!
    var previewOverlay: PreviewOverlay?

    var categories: [String] = []
    var allCategories: [String] = []
    var currentCategory: String?
    var currentImages: [GitHubFile] = []

    let thumbWidth: CGFloat = 230
    let thumbHeight: CGFloat = 155
    let padding: CGFloat = 14

    override init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        let winW: CGFloat = min(1060, screenFrame.width - 60)
        let winH: CGFloat = min(740, screenFrame.height - 60)
        let winX = screenFrame.midX - winW / 2
        let winY = screenFrame.midY - winH / 2

        window = NSWindow(
            contentRect: NSRect(x: winX, y: winY, width: winW, height: winH),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.minSize = NSSize(width: 540, height: 420)
        window.hasShadow = true

        blurView = BlurView(frame: window.contentView!.bounds)
        blurView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(blurView)

        let darkOverlay = NSView(frame: window.contentView!.bounds)
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = Theme.bg.cgColor
        darkOverlay.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(darkOverlay)

        mainView = NSView(frame: window.contentView!.bounds)
        mainView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(mainView)

        super.init()

        setupUI()
        loadRepo()

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                if let preview = self?.previewOverlay, preview.superview != nil {
                    preview.closeClicked()
                } else {
                    NSApplication.shared.terminate(nil)
                }
                return nil
            }
            return event
        }
    }

    func setupUI() {
        let topBarHeight: CGFloat = 90
        let bounds = mainView.bounds

        titleLabel = NSTextField(labelWithString: "WallPicker")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = Theme.textPrimary
        titleLabel.frame = NSRect(x: 80, y: bounds.height - 46, width: 300, height: 28)
        titleLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        mainView.addSubview(titleLabel)

        subtitleLabel = NSTextField(labelWithString: "Choose a collection")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = Theme.textSecondary
        subtitleLabel.frame = NSRect(x: 80, y: bounds.height - 64, width: 300, height: 16)
        subtitleLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        mainView.addSubview(subtitleLabel)

        backButton = NSButton(frame: NSRect(x: 16, y: bounds.height - topBarHeight + 12, width: 60, height: 28))
        backButton.isBordered = false
        backButton.title = "< Back"
        backButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        backButton.contentTintColor = Theme.accent
        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.autoresizingMask = [.maxXMargin, .minYMargin]
        backButton.isHidden = true
        mainView.addSubview(backButton)

        searchField = NSSearchField(frame: NSRect(x: 20, y: bounds.height - topBarHeight + 12, width: min(280, bounds.width - 280), height: 28))
        searchField.placeholderString = "Search collections..."
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.delegate = self
        searchField.appearance = NSAppearance(named: .darkAqua)
        mainView.addSubview(searchField)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: bounds.width - 200, y: bounds.height - topBarHeight + 16, width: 180, height: 16)
        statusLabel.alignment = .right
        statusLabel.textColor = Theme.textSecondary
        statusLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        statusLabel.autoresizingMask = [.minXMargin, .minYMargin]
        mainView.addSubview(statusLabel)

        let sep = NSView(frame: NSRect(x: 20, y: bounds.height - topBarHeight, width: bounds.width - 40, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = Theme.border.cgColor
        sep.autoresizingMask = [.width, .minYMargin]
        mainView.addSubview(sep)

        let scrollFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - topBarHeight - 1)
        scrollView = NSScrollView(frame: scrollFrame)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.scrollerKnobStyle = .light

        contentView = NSView(frame: NSRect(x: 0, y: 0, width: scrollFrame.width, height: scrollFrame.height))
        contentView.autoresizingMask = [.width]
        scrollView.documentView = contentView

        mainView.addSubview(scrollView)
    }

    func loadRepo() {
        statusLabel.stringValue = "Loading..."

        // Show spinner
        let spinner = NSProgressIndicator(frame: NSRect(x: scrollView.frame.width / 2 - 16, y: scrollView.frame.height / 2, width: 32, height: 32))
        spinner.style = .spinning
        spinner.appearance = NSAppearance(named: .darkAqua)
        spinner.startAnimation(nil)
        contentView.addSubview(spinner)

        DispatchQueue.global(qos: .userInitiated).async {
            RepoData.shared.load()
            DispatchQueue.main.async {
                spinner.removeFromSuperview()
                self.allCategories = RepoData.shared.sortedCategoryNames
                self.categories = self.allCategories
                if self.allCategories.isEmpty {
                    self.statusLabel.stringValue = "Rate limited"
                    let msg = NSTextField(labelWithString: "GitHub API rate limit hit.\nTry again in a few minutes.")
                    msg.font = NSFont.systemFont(ofSize: 14)
                    msg.textColor = Theme.textSecondary
                    msg.alignment = .center
                    msg.maximumNumberOfLines = 2
                    msg.frame = NSRect(x: 0, y: self.scrollView.frame.height / 2 - 20, width: self.scrollView.frame.width, height: 50)
                    self.contentView.addSubview(msg)
                } else {
                    self.showCategories()
                    self.loadCategoryPreviews()
                }
            }
        }
    }

    func loadCategoryPreviews() {
        let repo = RepoData.shared
        let loadQueue = DispatchQueue(label: "categoryPreviews", attributes: .concurrent)
        for cat in allCategories {
            guard let files = repo.categories[cat], let first = files.first else { continue }
            loadQueue.async {
                // Check cache first
                if ThumbnailCache.shared.get("cat_\(cat)") != nil { return }
                guard let img = downloadImage(url: first.downloadURL) else { return }
                let thumbSize = NSSize(width: 300, height: 180)
                let thumb = NSImage(size: thumbSize)
                thumb.lockFocus()
                img.draw(in: NSRect(origin: .zero, size: thumbSize),
                         from: NSRect(origin: .zero, size: img.size),
                         operation: .copy, fraction: 1.0)
                thumb.unlockFocus()
                ThumbnailCache.shared.set("cat_\(cat)", image: thumb)

                DispatchQueue.main.async {
                    if self.currentCategory == nil {
                        for sub in self.contentView.subviews {
                            if let card = sub as? CategoryCard, card.category == cat {
                                card.setPreviewImage(thumb)
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    func showCategories() {
        currentCategory = nil
        backButton.isHidden = true
        searchField.isHidden = false
        searchField.frame.origin.x = 20
        titleLabel.stringValue = "WallPicker"
        subtitleLabel.stringValue = "Choose a collection"
        subtitleLabel.isHidden = false
        statusLabel.stringValue = "\(categories.count) collections"

        contentView.subviews.forEach { $0.removeFromSuperview() }

        let viewWidth = scrollView.frame.width
        let cardW: CGFloat = 185
        let cardH: CGFloat = 120
        let hPad: CGFloat = 14
        let vPad: CGFloat = 14
        let sideInset: CGFloat = 24
        let usableWidth = viewWidth - sideInset * 2
        let cols = max(1, Int((usableWidth + hPad) / (cardW + hPad)))
        let rows = Int(ceil(Double(categories.count) / Double(cols)))
        let totalHeight = max(scrollView.frame.height, CGFloat(rows) * (cardH + vPad) + vPad + 24)

        contentView.frame = NSRect(x: 0, y: 0, width: viewWidth, height: totalHeight)

        let repo = RepoData.shared
        for (i, cat) in categories.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = sideInset + CGFloat(col) * (cardW + hPad)
            let y = totalHeight - CGFloat(row + 1) * (cardH + vPad) - 12

            let card = CategoryCard(frame: NSRect(x: x, y: y, width: cardW, height: cardH))
            let count = repo.categories[cat]?.count ?? 0
            card.configure(name: cat, count: count)
            card.onClick = { [weak self] name in
                self?.loadCategory(name)
            }
            if let cached = ThumbnailCache.shared.get("cat_\(cat)") {
                card.setPreviewImage(cached)
            }
            contentView.addSubview(card)
        }
    }

    func loadCategory(_ category: String) {
        currentCategory = category
        backButton.isHidden = false
        searchField.isHidden = true
        titleLabel.stringValue = category.capitalized
        subtitleLabel.stringValue = "Click to preview"

        let images = RepoData.shared.categories[category] ?? []
        currentImages = images
        statusLabel.stringValue = "\(images.count) wallpapers"
        showImages()
    }

    func showImages() {
        contentView.subviews.forEach { $0.removeFromSuperview() }

        guard !currentImages.isEmpty else {
            statusLabel.stringValue = "Empty"
            let emptyLabel = NSTextField(labelWithString: "No wallpapers in this collection")
            emptyLabel.font = NSFont.systemFont(ofSize: 14)
            emptyLabel.textColor = Theme.textSecondary
            emptyLabel.alignment = .center
            emptyLabel.frame = NSRect(x: 0, y: scrollView.frame.height / 2, width: scrollView.frame.width, height: 24)
            contentView.addSubview(emptyLabel)
            return
        }

        let viewWidth = scrollView.frame.width
        let sideInset: CGFloat = 24
        let usableWidth = viewWidth - sideInset * 2
        let cols = max(1, Int((usableWidth + padding) / (thumbWidth + padding)))
        let rows = Int(ceil(Double(currentImages.count) / Double(cols)))
        let labelH: CGFloat = 28
        let cellHeight = thumbHeight + labelH + padding
        let totalHeight = max(scrollView.frame.height, CGFloat(rows) * cellHeight + padding + 24)

        contentView.frame = NSRect(x: 0, y: 0, width: viewWidth, height: totalHeight)

        for (i, file) in currentImages.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = sideInset + CGFloat(col) * (thumbWidth + padding)
            let y = totalHeight - CGFloat(row + 1) * cellHeight - 12

            let card = WallpaperCard(frame: NSRect(x: x, y: y, width: thumbWidth, height: thumbHeight + labelH))
            card.configure(file: file)
            card.onPreview = { [weak self] file in
                self?.showPreview(file: file)
            }
            contentView.addSubview(card)

            let rawURL = file.downloadURL
            DispatchQueue.global(qos: .utility).async {
                let img: NSImage?
                if let cached = ThumbnailCache.shared.get(rawURL) {
                    img = cached
                } else if let downloaded = downloadImage(url: rawURL) {
                    let thumbSize = NSSize(width: 230, height: 155)
                    let thumb = NSImage(size: thumbSize)
                    thumb.lockFocus()
                    downloaded.draw(in: NSRect(origin: .zero, size: thumbSize),
                                   from: NSRect(origin: .zero, size: downloaded.size),
                                   operation: .copy, fraction: 1.0)
                    thumb.unlockFocus()
                    ThumbnailCache.shared.set(rawURL, image: thumb)
                    img = thumb
                } else {
                    img = nil
                }
                DispatchQueue.main.async {
                    card.imgView.image = img
                    if img != nil {
                        card.layer?.backgroundColor = Theme.cardBg.cgColor
                    }
                }
            }
        }
    }

    func showPreview(file: GitHubFile) {
        let preview = PreviewOverlay(frame: mainView.bounds)
        preview.onClose = { [weak self] in
            self?.previewOverlay = nil
        }
        previewOverlay = preview
        preview.show(file: file, in: mainView)
    }

    @objc func goBack() {
        categories = allCategories
        searchField.stringValue = ""
        showCategories()
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            categories = allCategories
        } else {
            categories = allCategories.filter { $0.lowercased().contains(query) }
        }
        showCategories()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: WallPickerController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        controller = WallPickerController()
        controller.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
