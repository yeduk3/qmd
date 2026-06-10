import Foundation

struct LintIssue: Identifiable {
    let id = UUID()
    let line: Int          // 1-based
    let range: NSRange     // range in the full text
    let message: String
}

/// Lightweight line-based markdown linter (a small markdownlint subset).
enum MarkdownLinter {
    static func lint(_ text: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let ns = text as NSString
        var lineNo = 0
        var blankRun = 0
        var fenceOpen = false
        var fenceToggles = 0
        var dollarBlocks = 0

        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length),
                               options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            lineNo += 1
            let line = ns.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // fenced code tracking (``` or ~~~)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fenceToggles += 1
                fenceOpen.toggle()
            }
            guard !fenceOpen || trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") else {
                // inside code fence: only count display-math? skip lint
                if line.isEmpty { blankRun += 1 } else { blankRun = 0 }
                return
            }

            // MD010 hard tabs
            if let r = line.range(of: "\t") {
                let loc = lineRange.location + line.distance(from: line.startIndex, to: r.lowerBound)
                issues.append(LintIssue(line: lineNo, range: NSRange(location: loc, length: 1),
                                        message: "Hard tab — use spaces (MD010)"))
            }

            // MD009 trailing whitespace
            if line.count > trimmedTrailing(line).count && !line.isEmpty {
                let tail = trimmedTrailing(line).count
                let len = line.count - tail
                issues.append(LintIssue(line: lineNo,
                                        range: NSRange(location: lineRange.location + tail, length: len),
                                        message: "Trailing whitespace (MD009)"))
            }

            // MD018 no space after hash in heading
            if let m = line.range(of: #"^#{1,6}[^#\s]"#, options: .regularExpression) {
                let loc = lineRange.location + line.distance(from: line.startIndex, to: m.lowerBound)
                issues.append(LintIssue(line: lineNo, range: NSRange(location: loc, length: 1),
                                        message: "Add a space after # in heading (MD018)"))
            }

            // blank line runs (MD012)
            if line.isEmpty {
                blankRun += 1
                if blankRun == 2 {
                    issues.append(LintIssue(line: lineNo, range: lineRange,
                                            message: "Multiple consecutive blank lines (MD012)"))
                }
            } else {
                blankRun = 0
            }

            // display math fences $$
            let dollars = line.components(separatedBy: "$$").count - 1
            dollarBlocks += dollars
        }

        if fenceToggles % 2 != 0 {
            issues.append(LintIssue(line: lineNo, range: NSRange(location: max(0, ns.length - 1), length: 0),
                                    message: "Unclosed code fence (```)"))
        }
        if dollarBlocks % 2 != 0 {
            issues.append(LintIssue(line: lineNo, range: NSRange(location: max(0, ns.length - 1), length: 0),
                                    message: "Unbalanced $$ math block"))
        }
        // MD047 final newline
        if !text.isEmpty && !text.hasSuffix("\n") {
            issues.append(LintIssue(line: lineNo, range: NSRange(location: max(0, ns.length - 1), length: 0),
                                    message: "File should end with a single newline (MD047)"))
        }
        return issues
    }

    private static func trimmedTrailing(_ s: String) -> String {
        var end = s.endIndex
        while end > s.startIndex {
            let prev = s.index(before: end)
            if s[prev] == " " || s[prev] == "\t" { end = prev } else { break }
        }
        return String(s[s.startIndex..<end])
    }
}
