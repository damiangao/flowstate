#!/usr/bin/env bash
set -euo pipefail

OPEN_APP=0
INSTALL_APP=0
INSTALL_HOOKS=0
for arg in "$@"; do
  case "$arg" in
    --open) OPEN_APP=1 ;;
    --install) INSTALL_APP=1 ;;
    --install-hooks) INSTALL_HOOKS=1 ;;
    -h|--help)
      cat <<'USAGE'
Usage: ./scripts/build-app.sh [--install] [--open] [--install-hooks]

Builds .build/FlowState.app from the SwiftPM release executable.

Options:
  --install        Copy the app to /Applications/FlowState.app
  --open           Open the built or installed app after building
  --install-hooks  Merge FlowState hooks into ~/.claude/settings.json
USAGE
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

install_hooks() {
  if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required to install hooks\n' >&2
    exit 1
  fi

  local settings_dir="$HOME/.claude"
  local settings="$settings_dir/settings.json"
  local tmp
  mkdir -p "$settings_dir"
  tmp="$(mktemp)"

  if [ -f "$settings" ]; then
    if ! jq empty "$settings" >/dev/null 2>&1; then
      printf 'Not modifying invalid JSON: %s\n' "$settings" >&2
      rm -f "$tmp"
      exit 1
    fi
    cp "$settings" "$settings.bak"
  else
    printf '{}\n' > "$settings"
  fi

  jq --arg cmd "$ROOT/hooks/flowstate-hook.sh" '
    def without_flowstate:
      map(
        if (.hooks? | type) == "array" then
          .hooks = (.hooks | map(select(((.command? // "") | endswith("flowstate-hook.sh")) | not)))
        else . end
      )
      | map(select(((.hooks? | type) != "array") or (.hooks | length > 0)));

    .hooks = (.hooks // {})
    | reduce ["Stop", "Notification", "UserPromptSubmit"][] as $event (
        .;
        .hooks[$event] = ((.hooks[$event] // [] | without_flowstate) + [{"hooks":[{"type":"command","command":$cmd}]}])
      )
  ' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  printf 'Installed FlowState hooks in %s\n' "$settings"
  [ -f "$settings.bak" ] && printf 'Backup: %s\n' "$settings.bak"
}

swift build -c release --product FlowState
BIN_DIR="$(swift build -c release --show-bin-path)"
SOURCE_BIN="$BIN_DIR/FlowState"
APP="$ROOT/.build/FlowState.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

if [ ! -x "$SOURCE_BIN" ]; then
  printf 'Expected executable not found: %s\n' "$SOURCE_BIN" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$SOURCE_BIN" "$MACOS/FlowState"
chmod +x "$MACOS/FlowState"

ICONSET="$ROOT/.build/FlowState.iconset"
ICON_SWIFT="$ROOT/.build/generate-flowstate-icon.swift"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cat > "$ICON_SWIFT" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let specs = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

for (points, scale) in specs {
    let pixels = points * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.cgContext.setAllowsAntialiasing(true)

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    rect.fill()

    let inset = CGFloat(pixels) * 0.06
    let base = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: CGFloat(pixels) * 0.2, yRadius: CGFloat(pixels) * 0.2)
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.14, alpha: 1).setFill()
    base.fill()

    let text = "FS" as NSString
    let font = NSFont.systemFont(ofSize: CGFloat(pixels) * 0.38, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let size = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (CGFloat(pixels) - size.width) / 2, y: (CGFloat(pixels) - size.height) / 2), withAttributes: attrs)

    let dotSize = CGFloat(pixels) * 0.16
    NSColor.systemYellow.setFill()
    NSBezierPath(ovalIn: NSRect(x: CGFloat(pixels) * 0.62, y: CGFloat(pixels) * 0.18, width: dotSize, height: dotSize)).fill()
    NSColor.systemRed.setFill()
    NSBezierPath(ovalIn: NSRect(x: CGFloat(pixels) * 0.74, y: CGFloat(pixels) * 0.18, width: dotSize, height: dotSize)).fill()

    NSGraphicsContext.restoreGraphicsState()

    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    let url = URL(fileURLWithPath: output).appendingPathComponent(name)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}
SWIFT
swift "$ICON_SWIFT" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$RESOURCES/FlowState.icns"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>FlowState</string>
  <key>CFBundleDisplayName</key>
  <string>FlowState</string>
  <key>CFBundleExecutable</key>
  <string>FlowState</string>
  <key>CFBundleIdentifier</key>
  <string>dev.flowstate.FlowState</string>
  <key>CFBundleIconFile</key>
  <string>FlowState</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>FlowState uses Apple Events to jump back to the Terminal tab that needs your attention.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

TARGET_APP="$APP"
if [ "$INSTALL_APP" -eq 1 ]; then
  TARGET_APP="/Applications/FlowState.app"
  rm -rf "$TARGET_APP"
  cp -R "$APP" "$TARGET_APP"
fi

if [ "$INSTALL_HOOKS" -eq 1 ]; then
  install_hooks
fi

printf 'Built %s\n' "$APP"
if [ "$INSTALL_APP" -eq 1 ]; then
  printf 'Installed %s\n' "$TARGET_APP"
fi
printf 'Run: open "%s"\n' "$TARGET_APP"

if [ "$OPEN_APP" -eq 1 ]; then
  open "$TARGET_APP"
fi
