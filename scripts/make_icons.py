"""Renders BoxPilot's icons into assets/images, following each platform's rules.
Expo's prebuild turns them into the native icon sets (see app.json).

Same artwork as the desktop app (crates/app/src/icon_art.rs): a blue-to-violet
diagonal gradient and a white paper plane.

Android (adaptive icons, https://developer.android.com/develop/ui/views/launch/icon_design_adaptive):
  - 108 dp layers; the glyph stays inside the 66 dp safe zone, since launchers
    mask and move the outer ring;
  - background, foreground and a monochrome layer for themed icons (Android 13+);
  - Play Store listing icon: 512 px full-bleed square (Play applies the mask).
  The status bar glyph is a vector in modules/boxpilot-core/android/src/main/res.

iOS (https://developer.apple.com/design/human-interface-guidelines/app-icons):
  - one 1024 px square, opaque, no rounded corners (the system applies the mask);
  - Dark variant: transparent background, coloured glyph (the system adds a dark backdrop);
  - Tinted variant: grayscale glyph on transparent (the system applies the tint).

    python scripts/make_icons.py
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLANE = [(0.20, 0.50), (0.80, 0.22), (0.58, 0.80), (0.46, 0.57)]
C0, C1 = (0x3B, 0x82, 0xF6), (0x8B, 0x5C, 0xF6)


def in_polygon(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def plane_at(scale):
    """The plane scaled about its own centre, centred on the canvas."""
    xs = [p[0] for p in PLANE]
    ys = [p[1] for p in PLANE]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    return [(0.5 + (x - cx) * scale, 0.5 + (y - cy) * scale) for x, y in PLANE]


def gradient(t):
    return [C0[c] + (C1[c] - C0[c]) * t for c in range(3)]


def render_png(size, plane, background, glyph, ss=2):
    """background: 'gradient' (opaque) or None (transparent).
    glyph: 'white', 'gradient', 'gray' or None (background only)."""
    opaque = background is not None
    xs = [p[0] for p in plane] if plane else [0]
    ys = [p[1] for p in plane] if plane else [0]
    x0, x1, y0, y1 = min(xs) * size - 1, max(xs) * size + 1, min(ys) * size - 1, max(ys) * size + 1
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            f = 0.0
            # Only pixels near the glyph need sampling.
            if glyph and x0 <= x <= x1 and y0 <= y <= y1:
                hits = 0
                for sy in range(ss):
                    for sx in range(ss):
                        if in_polygon((x + (sx + 0.5) / ss) / size, (y + (sy + 0.5) / ss) / size, plane):
                            hits += 1
                f = hits / (ss * ss)
            t = (x + y) / (2 * size)
            fg = {"white": [255, 255, 255], "gradient": gradient(t), "gray": [235, 235, 235], None: [0, 0, 0]}[glyph]
            if opaque:
                bg = gradient(t)
                row.extend(round(bg[c] + (fg[c] - bg[c]) * f) for c in range(3))
            else:
                row.extend(round(fg[c]) for c in range(3))
                row.append(round(255 * f))
        rows.append(bytes(row))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    color_type = 2 if opaque else 6
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, color_type, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
        + chunk(b"IEND", b"")
    )


def write(rel, content):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(content)
    print("wrote", rel)


def main():
    out = "assets/images"
    # iOS: the glyph fills more of the square than on Android, where launchers crop.
    ios = plane_at(0.62)
    write(f"{out}/icon.png", render_png(1024, ios, "gradient", "white"))
    write(f"{out}/icon-dark.png", render_png(1024, ios, None, "gradient"))
    write(f"{out}/icon-tinted.png", render_png(1024, ios, None, "gray"))
    # Android adaptive layers: 108 dp canvas, the glyph spans about 48 dp, well
    # inside the 66 dp safe circle.
    android = plane_at(0.46)
    write(f"{out}/adaptive-foreground.png", render_png(1024, android, None, "white"))
    write(f"{out}/adaptive-monochrome.png", render_png(1024, android, None, "white"))
    write(f"{out}/adaptive-background.png", render_png(1024, None, "gradient", None))
    # Launch screen: the glyph alone, on the brand colour set in app.json.
    write(f"{out}/splash-icon.png", render_png(1024, plane_at(0.7), None, "white"))
    # Play Store: full-bleed square; Play rounds the corners itself. Same glyph size
    # relative to the visible area as the adaptive icon (48 / 72 dp).
    write("store/play-icon-512.png", render_png(512, plane_at(0.46 * 108 / 72), "gradient", "white"))


if __name__ == "__main__":
    main()
