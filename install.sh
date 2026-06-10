#!/bin/bash
# Build (Release) + install to /Applications + register + set default md handler + reset Quick Look.
set -e
cd "$(dirname "$0")"

DD="${QMD_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/qmd-build}"
./build.sh Release
APP="$DD/Build/Products/Release/qmd.app"

LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "Install -> /Applications/qmd.app"
rm -rf /Applications/qmd.app
cp -R "$APP" /Applications/qmd.app

# avoid duplicate bundle-id copies confusing Launch Services
"$LSREG" -u "$APP" 2>/dev/null || true
"$LSREG" -f /Applications/qmd.app

# set qmd as default app for Markdown
swift - <<'SWIFT' 2>/dev/null || true
import AppKit
import UniformTypeIdentifiers
let sem = DispatchSemaphore(value: 0)
if let md = UTType("net.daringfireball.markdown") {
    Task {
        try? await NSWorkspace.shared.setDefaultApplication(
            at: URL(fileURLWithPath: "/Applications/qmd.app"), toOpen: md)
        sem.signal()
    }
    sem.wait()
}
SWIFT

qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
echo "Done. Default md app + Quick Look ready."
