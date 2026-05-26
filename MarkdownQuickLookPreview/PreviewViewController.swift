import AppKit
import QuickLookUI

final class PreviewViewController: NSViewController, @MainActor QLPreviewingController {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.contentView.postsBoundsChangedNotifications = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.frame = NSRect(origin: .zero, size: scrollView.contentSize)

        scrollView.documentView = textView
        view = scrollView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        refreshTextLayout()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping @Sendable (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
                let text = try MarkdownFileReader().readText(from: url)
                let blocks = PreviewLimits().shouldUseSimplifiedPreview(fileSize: fileSize)
                    ? nil
                    : LineMarkdownParser().parse(text)

                DispatchQueue.main.async {
                    let attributed = blocks.map { NativeAttributedStringRenderer().render($0) }
                        ?? NSAttributedString(string: text)
                    self.textView.textStorage?.setAttributedString(attributed)
                    self.refreshTextLayout()
                    handler(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.textView.string = "This Markdown file could not be previewed."
                    self.refreshTextLayout()
                    handler(nil)
                }
            }
        }
    }

    @objc private func scrollViewBoundsDidChange() {
        refreshTextLayout()
        DispatchQueue.main.async { [weak self] in
            self?.refreshTextLayout()
        }
    }

    private func refreshTextLayout() {
        guard let textContainer = textView.textContainer else { return }

        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        textView.layoutManager?.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
        textView.layoutManager?.ensureLayout(for: textContainer)
        textView.needsDisplay = true
        scrollView.contentView.needsDisplay = true
    }
}
