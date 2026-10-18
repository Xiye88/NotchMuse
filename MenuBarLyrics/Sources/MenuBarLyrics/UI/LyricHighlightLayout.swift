import AppKit
import LyricsCore

/// Measures the same font and prefixes used to draw the lyric. Token count is not pixel width.
@MainActor
enum LyricHighlightLayout {
    static func progress(_ highlight: LyricHighlight, text: String, font: NSFont, prefix: String = "") -> CGFloat {
        let display = prefix + text
        let total = (display as NSString).size(withAttributes: [.font: font]).width
        guard total > 0 else { return 0 }
        let before = ((prefix + highlight.prefixBefore) as NSString).size(withAttributes: [.font: font]).width
        let through = ((prefix + highlight.prefixThrough) as NSString).size(withAttributes: [.font: font]).width
        return max(0, min(1, (before + max(0, through - before) * highlight.fraction) / total))
    }

    /// Wrapped lyrics need a path through glyphs rather than a sweep across both rows at once.
    static func clipRects(_ highlight: LyricHighlight, text: String, font: NSFont, rect: NSRect) -> [NSRect] {
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let manager = NSLayoutManager()
        let container = NSTextContainer(containerSize: rect.size)
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        let beforeCount = (highlight.prefixBefore as NSString).length
        let throughCount = (highlight.prefixThrough as NSString).length
        let completed = manager.glyphRange(forCharacterRange: NSRange(location: 0, length: beforeCount), actualCharacterRange: nil)
        let active = manager.glyphRange(forCharacterRange: NSRange(location: beforeCount, length: throughCount - beforeCount), actualCharacterRange: nil)
        func rectangles(_ range: NSRange) -> [NSRect] {
            guard range.length > 0 else { return [] }
            var result: [NSRect] = []
            manager.enumerateEnclosingRects(forGlyphRange: range, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { bounds, _ in result.append(bounds) }
            return result
        }
        var result = rectangles(completed)
        let activeRects = rectangles(active)
        var remaining = activeRects.reduce(CGFloat(0)) { $0 + $1.width } * highlight.fraction
        for bounds in activeRects where remaining > 0 {
            var part = bounds
            part.size.width = min(part.width, remaining)
            result.append(part)
            remaining -= part.width
        }
        return result.map { NSRect(x: rect.minX + $0.minX, y: rect.maxY - $0.maxY, width: $0.width, height: $0.height) }
    }
}
