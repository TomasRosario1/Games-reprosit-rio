"""Generate original Lisbon architecture textures, deterministically, offline.

Requires Pillow and NumPy. Facades repeat over 5.6m x 3.1m (two windows / one
floor). Their emission maps are black outside individual lit glass panes; use
StandardMaterial3D.EMISSION_OP_MULTIPLY. No photographs or external game assets.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/textures"
OUT.mkdir(parents=True, exist_ok=True)


def rgb(value):
    return tuple(max(0, min(255, round(v))) for v in value)


def noise_field(width, height, seed, strength=1.0):
    rng = np.random.default_rng(seed)
    field = np.zeros((height, width), dtype=np.float32)
    for scale, amplitude in ((90, 3.6), (28, 1.8), (7, 0.65), (1, 0.28)):
        size = (max(3, width // scale), max(3, height // scale))
        raw = rng.normal(127, 25, size[::-1]).clip(0, 255).astype(np.uint8)
        layer = Image.fromarray(raw).resize((width, height), Image.Resampling.BICUBIC)
        field += (np.asarray(layer, dtype=np.float32) - 127) * amplitude / 25
    return field * strength


def aged_surface(size, base, seed, strength=2.0):
    w, h = size
    field = noise_field(w, h, seed, strength)
    data = np.asarray(base, dtype=np.float32)[None, None, :] + field[..., None]
    return Image.fromarray(data.clip(0, 255).astype(np.uint8), "RGB")


def finish(name, image, height=None, roughness=None, emission=None):
    image.save(OUT / f"{name}.png", optimize=True)
    w, h = image.size
    if height is None:
        height = Image.fromarray((127 + noise_field(w, h, 922, 0.75)).clip(0, 255).astype(np.uint8))
    if roughness is None:
        roughness = Image.fromarray((205 + noise_field(w, h, 212, 0.9)).clip(0, 255).astype(np.uint8))
    values = np.asarray(height.filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float32) / 255.0
    dz, dx = np.gradient(values)
    normals = np.stack((-dx * 7.0, dz * 7.0, np.ones_like(dx)), axis=2)
    normals /= np.linalg.norm(normals, axis=2)[..., None]
    normal_image = Image.fromarray(((normals + 1) * 127.5).clip(0, 255).astype(np.uint8), "RGB")
    normal_image.save(OUT / f"{name}_normal.png", optimize=True)
    roughness.convert("RGB").save(OUT / f"{name}_rough.png", optimize=True)
    if emission is not None:
        emission.save(OUT / f"{name}_emission.png", optimize=True)


def stone_trim(draw, box, base, seed):
    x0, y0, x1, y1 = box
    rng = np.random.default_rng(seed)
    draw.rectangle(box, fill=rgb(base))
    draw.line((x0, y0, x1, y0), fill=rgb(np.array(base) + 16), width=3)
    draw.line((x0, y0, x0, y1), fill=rgb(np.array(base) + 9), width=3)
    draw.line((x1, y0, x1, y1), fill=rgb(np.array(base) - 19), width=4)
    for _ in range(22):
        x = int(rng.integers(x0, max(x0 + 1, x1)))
        y = int(rng.integers(y0, max(y0 + 1, y1)))
        draw.line((x, y, x + int(rng.integers(2, 7)), y), fill=rgb(np.array(base) - int(rng.integers(4, 15))), width=1)


def facade(style):
    w, h = 1024, 512
    bases = ((153, 148, 131), (163, 132, 91), (139, 151, 149), (159, 144, 137))
    stone = ((166, 162, 147), (155, 149, 129), (166, 165, 150), (154, 149, 136))[style]
    base = np.array(bases[style])
    image = aged_surface((w, h), base, 310 + style, 2.4)
    draw = ImageDraw.Draw(image)
    height = Image.fromarray((128 + noise_field(w, h, 710 + style, 0.8)).clip(0, 255).astype(np.uint8))
    hd = ImageDraw.Draw(height)
    rough = Image.fromarray((214 + noise_field(w, h, 315 + style, 1.2)).clip(0, 255).astype(np.uint8))
    rd = ImageDraw.Draw(rough)
    glow = Image.new("RGB", (w, h))
    gd = ImageDraw.Draw(glow)
    rng = np.random.default_rng(1801 + style)
    # Damp streaks and the sediment below cornices do not become a checker pattern.
    overlay = Image.new("RGBA", image.size)
    od = ImageDraw.Draw(overlay)
    for _ in range(54):
        x = int(rng.integers(0, w))
        y = int(rng.choice((0, 15, 350, 425)))
        length = int(rng.integers(20, 130))
        od.rectangle((x, y, x + int(rng.integers(3, 15)), min(h, y + length)), fill=(38, 42, 29, int(rng.integers(8, 27))))
    overlay = overlay.filter(ImageFilter.GaussianBlur(6))
    image = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(image)
    # Thin stone floor-line/cornice; the sides join when tiled.
    for y, width, tone in ((7, 6, base - 27), (17, 4, base + 14), (493, 8, base - 26), (504, 6, base + 11)):
        draw.line((0, y, w, y), fill=rgb(tone), width=width)
        hd.line((0, y, w, y), fill=145 if y < 20 else 139, width=width)
    if style == 2:
        # A muted tiled dado exists on the plaster, not high-contrast pixel noise.
        for x in range(0, w, 43):
            for y in range(25, 490, 43):
                draw.rectangle((x + 1, y + 1, x + 41, y + 41), outline=(112, 130, 132), width=1)
    for index, cx in enumerate((256, 768)):
        left, right, top, bottom = cx - 102, cx + 102, 71, 429
        # Broad limestone surround with a recessed dark cavity, lintel and sill.
        stone_trim(draw, (left - 19, top - 17, right + 19, bottom + 14), stone, style * 99 + index)
        draw.rectangle((left - 3, top - 3, right + 5, bottom + 4), fill=(37, 37, 31))
        hd.rectangle((left - 19, top - 17, right + 19, bottom + 14), fill=168)
        hd.rectangle((left - 3, top - 3, right + 5, bottom + 4), fill=65)
        rd.rectangle((left - 19, top - 17, right + 19, bottom + 14), fill=194)
        frame = ((79, 76, 63), (74, 78, 61), (89, 99, 88), (102, 82, 64))[style]
        draw.rectangle((left + 5, top + 5, right - 5, bottom - 5), fill=frame)
        lit = (style, index) in ((0, 0), (1, 1), (3, 0))
        closed_shutters = (style == 2 and index == 0) or (style == 3 and index == 1)
        if closed_shutters:
            shutter = ((71, 80, 66), (87, 88, 69), (70, 91, 85), (91, 78, 67))[style]
            draw.rectangle((left + 13, top + 13, right - 13, bottom - 13), fill=shutter)
            for yy in range(top + 18, bottom - 12, 11):
                draw.line((left + 15, yy, right - 15, yy), fill=rgb(np.array(shutter) - 16), width=2)
                draw.line((left + 15, yy + 3, right - 15, yy + 3), fill=rgb(np.array(shutter) + 8), width=1)
                hd.line((left + 15, yy, right - 15, yy), fill=115, width=2)
            draw.line((cx, top + 10, cx, bottom - 8), fill=(47, 51, 42), width=5)
            rd.rectangle((left + 13, top + 13, right - 13, bottom - 13), fill=203)
        else:
            for row in range(3):
                y0 = top + 17 + row * 107
                y1 = y0 + 98
                for col in range(2):
                    x0 = left + 17 + col * 91
                    x1 = x0 + 81
                    tint = (139, 118, 73) if lit else (36 + row * 2, 45 + col * 2, 46 + row)
                    draw.rectangle((x0, y0, x1, y1), fill=tint)
                    draw.line((x0 + 4, y0 + 3, x1 - 4, y0 + 3), fill=(173, 149, 93) if lit else (55, 64, 63), width=2)
                    draw.line((x0 + 5, y0 + 4, x0 + 5, y1 - 5), fill=(145, 125, 80) if lit else (45, 56, 57), width=1)
                    rd.rectangle((x0, y0, x1, y1), fill=90)
                    hd.rectangle((x0, y0, x1, y1), fill=90)
                    # Half-drawn curtains and uneven interior illumination.
                    if lit:
                        gd.rectangle((x0, y0, x1, y1), fill=(124 + 11 * row, 103 + 7 * row, 62))
                        for xx in range(x0 + 7, min(x1, x0 + 26), 5):
                            draw.line((xx, y0 + 2, xx, y1), fill=(114, 101, 74), width=3)
                            gd.line((xx, y0 + 2, xx, y1), fill=(76, 64, 40), width=3)
                    elif row == 0:
                        draw.line((x0 + 10, y0 + 7, x0 + 32, y1 - 12), fill=(51, 61, 60), width=2)
        # Projecting limestone sill and long weather streak beneath it.
        draw.rectangle((left - 26, bottom + 10, right + 26, bottom + 23), fill=rgb(np.array(stone) - 18))
        draw.line((left - 26, bottom + 10, right + 26, bottom + 10), fill=rgb(np.array(stone) + 9), width=3)
        hd.rectangle((left - 26, bottom + 10, right + 26, bottom + 23), fill=179)
    # Sparse hairline cracks connect broad stains rather than outlining every pixel.
    for _ in range(6):
        x = int(rng.choice((45, 470, 550, 970))) + int(rng.integers(-20, 20))
        y = int(rng.integers(85, 400))
        points = [(x, y)]
        for _ in range(5):
            x += int(rng.integers(-5, 7)); y += int(rng.integers(3, 10)); points.append((x, y))
        draw.line(points, fill=rgb(base - 30), width=1)
    finish(f"facade_{style}", image, height, rough, glow)


def plaster():
    image = aged_surface((512, 512), (163, 155, 137), 813, 2.2)
    overlay = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(overlay)
    rng = np.random.default_rng(338)
    for _ in range(13):
        x = int(rng.integers(0, 512)); y = int(rng.integers(0, 512))
        draw.ellipse((x, y, x + int(rng.integers(25, 105)), y + int(rng.integers(20, 85))), fill=(81, 80, 65, 28))
    overlay = overlay.filter(ImageFilter.GaussianBlur(13))
    image = Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")
    finish("plaster_plain", image)


def wood_floor():
    w, h = 1024, 512
    rng = np.random.default_rng(511)
    image = aged_surface((w, h), (85, 64, 45), 612, 1.8)
    draw = ImageDraw.Draw(image)
    height = Image.new("L", image.size, 127); hd = ImageDraw.Draw(height)
    rough = Image.new("L", image.size, 184); rd = ImageDraw.Draw(rough)
    for row, y in enumerate(range(0, h, 64)):
        for col, x in enumerate(range(-256 if row % 2 else 0, w, 512)):
            tone = int(rng.integers(-6, 7))
            draw.rectangle((x, y, x + 511, y + 63), fill=(85 + tone, 64 + tone, 45 + tone))
            draw.line((x, y, x + 511, y), fill=(43, 33, 25), width=2)
            draw.line((x, y + 3, x + 511, y + 3), fill=(104 + tone, 79 + tone, 54 + tone), width=1)
            draw.line((x, y, x, y + 63), fill=(48, 36, 27), width=2)
            hd.line((x, y, x + 511, y), fill=80, width=2)
            hd.line((x, y, x, y + 63), fill=80, width=2)
            rd.rectangle((x + 15, y + 8, x + 490, y + 55), fill=int(rng.integers(165, 193)))
            for _ in range(32):
                yy = y + int(rng.integers(6, 60)); xx = x + int(rng.integers(0, 450))
                points = [(xx + step * 15, yy + math.sin(step * 0.7 + yy) * 1.4) for step in range(int(rng.integers(3, 20)))]
                draw.line(points, fill=(76 + tone, 56 + tone, 38 + tone), width=1)
            for nx in (x + 8, x + 502):
                for ny in (y + 10, y + 53):draw.ellipse((nx, ny, nx + 2, ny + 2), fill=(35, 31, 25))
    finish("wood_floor", image, height, rough)


def wood_door():
    w, h = 512, 1024
    image = aged_surface((w, h), (77, 57, 40), 445, 2.3)
    draw = ImageDraw.Draw(image)
    height = Image.new("L", image.size, 135); hd = ImageDraw.Draw(height)
    rough = Image.new("L", image.size, 199); rd = ImageDraw.Draw(rough)
    rng = np.random.default_rng(24)
    for _ in range(180):
        x = int(rng.integers(0, w)); y = int(rng.integers(0, h)); length = int(rng.integers(20, 200))
        draw.line((x, y, x + int(rng.integers(-2, 3)), min(h, y + length)), fill=(66, 48, 33), width=1)
    for top, bottom in ((68, 270), (324, 636), (690, 955)):
        for left, right in ((44, 237), (275, 468)):
            stone_trim(draw, (left, top, right, bottom), (96, 73, 49), left + top)
            draw.rectangle((left + 12, top + 12, right - 12, bottom - 12), fill=(50, 37, 27))
            draw.rectangle((left + 20, top + 20, right - 20, bottom - 20), fill=(73, 53, 36))
            draw.line((left + 20, top + 20, right - 20, top + 20), fill=(106, 81, 54), width=3)
            hd.rectangle((left, top, right, bottom), fill=158)
            hd.rectangle((left + 12, top + 12, right - 12, bottom - 12), fill=87)
            hd.rectangle((left + 20, top + 20, right - 20, bottom - 20), fill=142)
            for xx in range(left + 28, right - 25, 8):
                draw.line((xx, top + 24, xx + 2, bottom - 23), fill=(67, 48, 32), width=1)
    for box in ((12, 10, 28, 1013), (484, 10, 500, 1013)):
        draw.rectangle(box, fill=(44, 35, 27)); hd.rectangle(box, fill=106)
    draw.rectangle((415, 493, 436, 572), fill=(46, 39, 27))
    draw.ellipse((418, 492, 434, 509), fill=(151, 122, 66))
    draw.line((426, 508, 426, 548), fill=(139, 110, 57), width=7)
    draw.ellipse((419, 541, 433, 556), fill=(116, 90, 48))
    rd.rectangle((415, 493, 436, 572), fill=99)
    # Scuffed kickboard and faded edge wear.
    draw.rectangle((29, 981, 481, 1011), fill=(57, 45, 34))
    for _ in range(80):
        x = int(rng.integers(30, 480)); y = int(rng.integers(978, 1011))
        draw.line((x, y, x + int(rng.integers(2, 18)), y), fill=(105, 85, 58), width=1)
    finish("wood_door", image, height, rough)


def azulejo():
    size = 512
    image = aged_surface((size, size), (188, 185, 165), 200, 0.8)
    draw = ImageDraw.Draw(image)
    height = Image.new("L", image.size, 135); hd = ImageDraw.Draw(height)
    rough = Image.new("L", image.size, 128); rd = ImageDraw.Draw(rough)
    blue, faint = (47, 78, 117), (109, 132, 148)
    for ty in range(0, size, 128):
        for tx in range(0, size, 128):
            draw.rectangle((tx, ty, tx + 127, ty + 127), outline=(109, 114, 106), width=2)
            hd.rectangle((tx, ty, tx + 127, ty + 127), outline=80, width=2)
            draw.rectangle((tx + 8, ty + 8, tx + 119, ty + 119), outline=faint, width=2)
            cx, cy = tx + 64, ty + 64
            for angle in range(0, 360, 45):
                r = math.radians(angle)
                points = [(cx + math.cos(r + a) * rr, cy + math.sin(r + a) * rr) for a, rr in ((-0.16, 12), (-0.13, 42), (0, 51), (0.13, 42), (0.16, 12))]
                draw.polygon(points, fill=blue)
            draw.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), fill=(68, 98, 135))
            draw.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(182, 182, 164))
            for xx, yy in ((tx + 17, ty + 17), (tx + 111, ty + 17), (tx + 17, ty + 111), (tx + 111, ty + 111)):
                draw.ellipse((xx - 3, yy - 3, xx + 3, yy + 3), fill=faint)
    finish("azulejo_blue", image, height, rough)


def roof():
    w, h = 512, 512
    image = aged_surface((w, h), (116, 72, 49), 115, 1.5)
    draw = ImageDraw.Draw(image)
    height = Image.new("L", image.size, 127); hd = ImageDraw.Draw(height)
    rough = Image.new("L", image.size, 218)
    rng = np.random.default_rng(18)
    for row, y in enumerate(range(-64, h, 128)):
        for x in range(-32 if row % 2 else 0, w, 64):
            tone = int(rng.integers(-12, 13))
            for u in range(64):
                curve = math.cos((u / 64 - 0.5) * math.pi)
                col = (101 + tone + curve * 27, 62 + tone * 0.6 + curve * 17, 43 + tone * 0.5 + curve * 11)
                draw.line((x + u, y, x + u, y + 126), fill=rgb(col), width=1)
                hd.line((x + u, y, x + u, y + 126), fill=round(90 + curve * 70), width=1)
            draw.line((x, y + 119, x + 63, y + 119), fill=(61 + tone, 43, 32), width=5)
            hd.line((x, y + 119, x + 63, y + 119), fill=74, width=5)
    finish("roof_terracotta", image, height, rough)


def paving():
    w, h = 512, 512
    image = aged_surface((w, h), (125, 124, 112), 119, 1.1)
    draw = ImageDraw.Draw(image)
    height = Image.new("L", image.size, 128); hd = ImageDraw.Draw(height)
    rng = np.random.default_rng(120)
    for row, y in enumerate(range(-30, h, 34)):
        for x in range(-32 if row % 2 else -16, w, 39):
            left = x + int(rng.integers(-2, 3)); top = y + int(rng.integers(-2, 3))
            right = left + int(rng.integers(32, 38)); bottom = top + int(rng.integers(28, 33))
            band = abs((left - 58 * math.sin(top * math.pi / 256)) % 512 - 256) < 22
            tone = int(rng.integers(-9, 10))
            base = (72 + tone, 76 + tone, 71 + tone) if band else (151 + tone, 149 + tone, 132 + tone)
            draw.rounded_rectangle((left, top, right, bottom), radius=3, fill=base)
            draw.line((left + 3, top + 2, right - 3, top + 2), fill=rgb(np.array(base) + 6), width=1)
            hd.rounded_rectangle((left, top, right, bottom), radius=3, fill=int(rng.integers(129, 145)))
    finish("calcada_lisbon", image, height, Image.new("L", image.size, 207))
    for name, base, seed in (("street_asphalt", (49, 51, 49), 78), ("pink_paving", (128, 69, 83), 79)):
        image = aged_surface((w, h), base, seed, 0.95)
        draw = ImageDraw.Draw(image)
        rng = np.random.default_rng(seed)
        for _ in range(4):
            x = int(rng.integers(0, w)); y = int(rng.integers(0, h))
            points = [(x, y)]
            for _ in range(12):
                x += int(rng.integers(-8, 9)); y += int(rng.integers(5, 15)); points.append((x, y))
            draw.line(points, fill=rgb(np.array(base) - 9), width=1)
        finish(name, image, roughness=Image.new("L", image.size, 203))


if __name__ == "__main__":
    for style in range(4):
        facade(style)
    plaster(); wood_floor(); wood_door(); azulejo(); roof(); paving()
    print("Generated four original Lisbon facade atlases and eight PBR architectural surface sets.")
