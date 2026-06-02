#!/usr/bin/env python3
"""Generate the Browser Picker app icon (.icns) using AppKit / Core Graphics via PyObjC.

Design (see DESIGN.md): a Big Sur "squircle" with a vertical blue gradient,
a simple white browser-window glyph, and a branching "fork in the road"
motif below it — three diverging paths ending in dots, representing the
choice of which browser/profile a link opens in.

Usage: python3 generate_icon.py <output.icns>
"""
import sys
import subprocess
import tempfile
import os


def generate_icon(output_path):
    """Render PNGs at all required sizes and pack them into a .icns."""
    iconset_dir = tempfile.mkdtemp(suffix=".iconset")

    # (filename, pixel size) pairs that iconutil expects.
    variants = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, size in variants:
        png_path = os.path.join(iconset_dir, filename)
        create_icon_png(png_path, size)

    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", output_path],
        check=True,
    )
    subprocess.run(["rm", "-rf", iconset_dir])
    print(f"    Icon generated: {output_path}")


def create_icon_png(path, size):
    """Draw the icon at the given pixel size via AppKit, with a PNG fallback."""
    script = ICON_SCRIPT.format(size=size, path=path)
    try:
        subprocess.run(
            [sys.executable, "-c", script],
            check=True, capture_output=True, text=True,
        )
        if not os.path.exists(path) or os.path.getsize(path) == 0:
            raise RuntimeError("empty output")
    except Exception:
        create_fallback_png(path, size)


# Rendered in a separate interpreter so a PyObjC import failure on the build
# host degrades gracefully to the pure-Python fallback below.
ICON_SCRIPT = r'''
import math
import Cocoa
import AppKit

S = float({size})

img = AppKit.NSImage.alloc().initWithSize_((S, S))
img.lockFocus()

ctx = AppKit.NSGraphicsContext.currentContext()
ctx.setImageInterpolation_(AppKit.NSImageInterpolationHigh)


def color(r, g, b, a=1.0):
    return Cocoa.NSColor.colorWithRed_green_blue_alpha_(r, g, b, a)


def squircle(rect, radius):
    # Continuous-corner rounded rect, close to Apple's superellipse.
    x, y, w, h = rect
    p = Cocoa.NSBezierPath.bezierPath()
    p.appendBezierPathWithRoundedRect_xRadius_yRadius_(((x, y), (w, h)), radius, radius)
    return p


# --- Rounded-rect background with a top-down blue gradient ---
inset = S * 0.085           # icon grid leaves a transparent margin
corner = S * 0.225          # Big Sur corner radius ~ 22.5% of the icon
bg_rect = (inset, inset, S - 2 * inset, S - 2 * inset)
bg = squircle(bg_rect, corner)

top = color(0.27, 0.56, 1.0)      # bright azure
bottom = color(0.10, 0.33, 0.92)  # deeper blue
gradient = AppKit.NSGradient.alloc().initWithStartingColor_endingColor_(top, bottom)
gradient.drawInBezierPath_angle_(bg, -90.0)

# Subtle top highlight for a glossy, dimensional feel.
hi = squircle((inset, inset + (S - 2 * inset) * 0.5,
               S - 2 * inset, (S - 2 * inset) * 0.5), corner)
g2 = AppKit.NSGradient.alloc().initWithStartingColor_endingColor_(
    color(1, 1, 1, 0.16), color(1, 1, 1, 0.0))
g2.drawInBezierPath_angle_(hi, -90.0)

white = color(1, 1, 1, 1.0)
faint = color(1, 1, 1, 0.55)

# --- Browser window glyph (upper portion) ---
win_w = (S - 2 * inset) * 0.50
win_h = win_w * 0.62
win_x = (S - win_w) / 2.0
win_y = S * 0.50
win_r = win_w * 0.13
win = squircle((win_x, win_y, win_w, win_h), win_r)
white.setFill()
win.fill()

# Title bar separator + traffic-light dots.
bar_y = win_y + win_h - win_h * 0.30
sep = Cocoa.NSBezierPath.bezierPath()
sep.setLineWidth_(max(1.0, S * 0.006))
sep.moveToPoint_((win_x, bar_y))
sep.lineToPoint_((win_x + win_w, bar_y))
color(0.10, 0.33, 0.92, 0.30).setStroke()
sep.stroke()

dot_r = win_h * 0.07
dot_y = win_y + win_h - win_h * 0.155
for i in range(3):
    dx = win_x + win_w * 0.12 + i * (dot_r * 3.0)
    d = Cocoa.NSBezierPath.bezierPathWithOvalInRect_(
        ((dx - dot_r, dot_y - dot_r), (dot_r * 2, dot_r * 2)))
    color(0.27, 0.56, 1.0, 0.9).setFill()
    d.fill()

# --- Branching "fork in the road" motif below the window ---
lw = max(1.5, S * 0.028)
white.setStroke()
faint.setStroke()

trunk_x = S / 2.0
trunk_top = win_y - S * 0.015
trunk_mid = win_y - S * 0.095   # where paths diverge
branch_y = inset + (S - 2 * inset) * 0.14
spread = win_w * 0.62

white.setStroke()
trunk = Cocoa.NSBezierPath.bezierPath()
trunk.setLineWidth_(lw)
trunk.setLineCapStyle_(AppKit.NSLineCapStyleRound)
trunk.moveToPoint_((trunk_x, trunk_top))
trunk.lineToPoint_((trunk_x, trunk_mid))
trunk.stroke()

end_r = lw * 0.95
for dx in (-spread, 0.0, spread):
    bx = trunk_x + dx
    branch = Cocoa.NSBezierPath.bezierPath()
    branch.setLineWidth_(lw)
    branch.setLineCapStyle_(AppKit.NSLineCapStyleRound)
    branch.setLineJoinStyle_(AppKit.NSLineJoinStyleRound)
    branch.moveToPoint_((trunk_x, trunk_mid))
    # gentle curve out to each destination
    ctrl_y = (trunk_mid + branch_y) / 2.0
    branch.curveToPoint_controlPoint1_controlPoint2_(
        (bx, branch_y),
        (trunk_x, ctrl_y),
        (bx, trunk_mid - (trunk_mid - branch_y) * 0.35))
    white.setStroke()
    branch.stroke()
    # destination dot
    dot = Cocoa.NSBezierPath.bezierPathWithOvalInRect_(
        ((bx - end_r, branch_y - end_r), (end_r * 2, end_r * 2)))
    white.setFill()
    dot.fill()

img.unlockFocus()

tiff = img.TIFFRepresentation()
bitmap = AppKit.NSBitmapImageRep.alloc().initWithData_(tiff)
png = bitmap.representationUsingType_properties_(4, {{}})  # 4 = NSBitmapImageFileTypePNG
png.writeToFile_atomically_("{path}", True)
'''


def create_fallback_png(path, size):
    """Minimal solid-blue PNG so the build never fails if PyObjC is missing."""
    import struct
    import zlib

    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    raw = b''
    for _ in range(size):
        raw += b'\x00' + bytes([45, 110, 245]) * size
    data = (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw)) +
            chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(data)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: generate_icon.py <output.icns>")
        sys.exit(1)
    generate_icon(sys.argv[1])
