import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    let rootURL: URL?
    let currentFile: URL?

    var body: some View {
        Group {
            if let rootURL {
                List {
                    Section(rootURL.lastPathComponent.removingPercentEncoding ?? rootURL.lastPathComponent) {
                        ForEach(FileEntry.children(of: rootURL)) { entry in
                            FileRow(entry: entry, currentFile: currentFile)
                        }
                    }
                }
                .listStyle(.sidebar)
            } else {
                ContentUnavailableView("No Folder", systemImage: "folder",
                    description: Text("Open a Markdown file to browse its folder."))
            }
        }
        .frame(minWidth: 180)
    }
}

private struct FileRow: View {
    let entry: FileEntry
    let currentFile: URL?

    @State private var expanded = false
    @State private var children: [FileEntry] = []
    @Environment(\.openDocument) private var openDocument

    var body: some View {
        if entry.isDirectory {
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(children) { FileRow(entry: $0, currentFile: currentFile) }
            } label: {
                Label(entry.name, systemImage: "folder")
                    .lineLimit(1)
            }
            .onChange(of: expanded) { _, now in
                if now && children.isEmpty { children = FileEntry.children(of: entry.url) }
            }
        } else {
            Button { open() } label: {
                Label {
                    Text(entry.name).lineLimit(1)
                } icon: {
                    Image(systemName: entry.isMarkdown ? "doc.text" : "doc")
                        .foregroundStyle(entry.isMarkdown ? Color.accentColor : Color.secondary)
                }
            }
            .buttonStyle(.plain)
            .fontWeight(isCurrent ? .semibold : .regular)
            .listRowBackground(isCurrent ? Color.accentColor.opacity(0.15) : nil)
        }
    }

    private var isCurrent: Bool {
        guard let currentFile else { return false }
        return entry.url.standardizedFileURL == currentFile.standardizedFileURL
    }

    private func open() {
        if entry.isMarkdown {
            Task { try? await openDocument(at: entry.url) }
        } else {
            NSWorkspace.shared.open(entry.url)
        }
    }
}

struct FileEntry: Identifiable {
    let url: URL
    let name: String
    let isDirectory: Bool

    var id: URL { url }

    var isMarkdown: Bool {
        ["md", "markdown", "mdown", "mkd", "mdwn", "mkdn"].contains(url.pathExtension.lowercased())
    }

    static func children(of dir: URL) -> [FileEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]) else { return [] }

        return items.compactMap { url -> FileEntry? in
            let vals = try? url.resourceValues(forKeys: Set(keys))
            let isDir = vals?.isDirectory ?? false
            let name = vals?.name ?? url.lastPathComponent
            return FileEntry(url: url, name: name, isDirectory: isDir)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
}
