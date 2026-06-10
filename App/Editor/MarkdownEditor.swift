import SwiftUI
import AppKit

struct MarkdownEditor: View {
    @Binding var text: String
    @State private var issues: [LintIssue] = []

    var body: some View {
        VStack(spacing: 0) {
            RawTextView(text: $text, issues: issues)
            if !issues.isEmpty {
                Divider()
                LintBar(issues: issues)
            }
        }
        .onAppear { issues = MarkdownLinter.lint(text) }
        .onChange(of: text) { _, new in issues = MarkdownLinter.lint(new) }
    }
}

private struct LintBar: View {
    let issues: [LintIssue]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Label("\(issues.count)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption.bold())
                ForEach(issues.prefix(40)) { issue in
                    Text("L\(issue.line): \(issue.message)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
        }
        .background(.bar)
    }
}

private struct RawTextView: NSViewRepresentable {
    @Binding var text: String
    var issues: [LintIssue]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.string = text

        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.isRichText = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.textContainerInset = NSSize(width: 8, height: 12)
        tv.textColor = .textColor
        tv.backgroundColor = .textBackgroundColor

        // soft wrap to the view width
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true

        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            tv.setSelectedRange(NSRange(location: min(sel.location, (text as NSString).length), length: 0))
        }
        applyUnderlines(tv)
    }

    private func applyUnderlines(_ tv: NSTextView) {
        guard let lm = tv.layoutManager else { return }
        let full = NSRange(location: 0, length: (tv.string as NSString).length)
        lm.removeTemporaryAttribute(.underlineStyle, forCharacterRange: full)
        lm.removeTemporaryAttribute(.underlineColor, forCharacterRange: full)
        let style = NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue
        for issue in issues {
            let r = issue.range
            guard r.length > 0, NSMaxRange(r) <= full.length else { continue }
            lm.addTemporaryAttributes([
                .underlineStyle: style,
                .underlineColor: NSColor.systemOrange
            ], forCharacterRange: r)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RawTextView
        weak var textView: NSTextView?
        init(_ parent: RawTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
