import AppKit
import QuickLookUI

final class PreviewViewController: NSViewController, @MainActor QLPreviewingController {
    private let textView = NSTextView()
    private let scrollView = NSScrollView()

    override func loadView() {
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

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
                    handler(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.textView.string = "This Markdown file could not be previewed."
                    handler(nil)
                }
            }
        }
    }
}
