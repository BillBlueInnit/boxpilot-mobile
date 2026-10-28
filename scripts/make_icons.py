"""Renders BoxPilot's icon for Android and iOS, following each platform's rules.

Same artwork as the desktop app (crates/app/src/icon_art.rs): a blue-to-violet
diagonal gradient and a white paper plane.

Android (adaptive icons, https://developer.android.com/develop/ui/views/launch/icon_design_adaptive):
  - 108 dp layers; the glyph stays inside the 66 dp safe zone, since launchers
    mask and move the outer ring;
  - background, foreground and a monochrome layer for themed icons (Android 13+);
  - status bar and Quick Settings glyph: white silhouette on transparent, 24 dp;
  - Play Store listing icon: 512 px full-bleed square (Play applies the mask).
  minSdk is 29, so no legacy bitmap launcher icons are needed.

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


def render_png(size, plane, background, glyph, ss=3):
    """background: 'gradient' (opaque) or None (transparent).
    glyph: 'white', 'gradient' or 'gray'."""
    opaque = background is not None
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            hits = 0
            for sy in range(ss):
                for sx in range(ss):
                    u = (x + (sx + 0.5) / ss) / size
                    v = (y + (sy + 0.5) / ss) / size
                    if in_polygon(u, v, plane):
                        hits += 1
            f = hits / (ss * ss)
            t = (x + y) / (2 * size)
            fg = {"white": [255, 255, 255], "gradient": gradient(t), "gray": [235, 235, 235]}[glyph]
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


def path_data(pts, size):
    d = " ".join(f"{'M' if i == 0 else 'L'}{x * size:.2f},{y * size:.2f}" for i, (x, y) in enumerate(pts))
    return d + " Z"


def write(rel, content):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if isinstance(content, bytes):
        with open(path, "wb") as f:
            f.write(content)
    else:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
    print("wrote", rel)


def remove(rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path):
        os.remove(path)
        print("removed", rel)


def android():
    res = "android/app/src/main/res"
    # 108 dp canvas; the glyph spans about 48 dp, well inside the 66 dp safe circle.
    fg = plane_at(0.46)
    write(f"{res}/drawable/ic_launcher_background.xml", """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:pathData="M0,0 L108,0 L108,108 L0,108 Z">
        <aapt:attr name="android:fillColor">
            <gradient android:type="linear"
                android:startX="0" android:startY="0" android:endX="108" android:endY="108"
                android:startColor="#FF3B82F6" android:endColor="#FF8B5CF6" />
        </aapt:attr>
    </path>
</vector>
""")
    plane_xml = f"""<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FFFFFFFF" android:pathData="{path_data(fg, 108)}" />
</vector>
"""
    write(f"{res}/drawable/ic_launcher_foreground.xml", plane_xml)
    write(f"{res}/drawable/ic_launcher_monochrome.xml", plane_xml)
    write(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
""")
    # Status bar / Quick Settings: a silhouette with ~2 dp padding on a 24 dp grid.
    write(f"{res}/drawable/ic_stat_boxpilot.xml", f"""<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF" android:pathData="{path_data(plane_at(1.15), 24)}" />
</vector>
""")
    for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
        remove(f"{res}/mipmap-{density}/ic_launcher.png")
    # Play Store: full-bleed square; Play rounds the corners itself. Same glyph size
    # relative to the visible area as the adaptive icon (48 / 72 dp).
    write("store/play-icon-512.png", render_png(512, plane_at(0.46 * 108 / 72), "gradient", "white"))


def ios():
    icon_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for f in os.listdir(os.path.join(ROOT, icon_dir)):
        if f.endswith(".png"):
            os.remove(os.path.join(ROOT, icon_dir, f))
    glyph = plane_at(0.62)
    write(f"{icon_dir}/icon-1024.png", render_png(1024, glyph, "gradient", "white", ss=2))
    write(f"{icon_dir}/icon-1024-dark.png", render_png(1024, glyph, None, "gradient", ss=2))
    write(f"{icon_dir}/icon-1024-tinted.png", render_png(1024, glyph, None, "gray", ss=2))
    write(f"{icon_dir}/Contents.json", """{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-1024-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-1024-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""")


if __name__ == "__main__":
    android()
    ios()
