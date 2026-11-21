"""Draws the leRep icon into art/ (512, 400, 256 and 128 px PNGs; 400 is the CurseForge and Wago
avatar), the in-game icon leRep/Media/Icon.tga (128 px; the game reads TGA with power-of-two sizes;
the .toc's IconTexture, the window and the minimap button use it), and the listing banner
art/lerep-banner.png (1600x500: the icon, the name, the tagline and a sample of a plan's route).

The design: a writ (a parchment with a red wax seal) and a rising rank chevron, on a deep blue
rounded square (the game's reputation bars are blue). The same build as leProfit's and leBoof's
icons (from leProfit's script), our own art.

Needs Pillow, and the Inter font for the banner (bold and semibold): it looks in .scratch/fonts/
(Inter-Bold.ttf, Inter-SemiBold.ttf), or point LEREP_FONT_BOLD and LEREP_FONT_SEMI at the files.
Run: python3 art/make_logo.py
"""
import os
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
GAME_ICON = ROOT / "leRep" / "Media" / "Icon.tga"
S = 2048  # draw big, downsample for smooth edges

BLUE_TOP = (40, 86, 160)
BLUE_BOT = (10, 22, 52)
RIM = (140, 190, 255)
PAPER_TOP = (250, 236, 200)
PAPER_BOT = (214, 186, 132)
PAPER_EDGE = (150, 112, 60)
INK = (120, 88, 50)
WAX = (178, 34, 34)
WAX_DARK = (110, 16, 16)
GOLD_TOP = (255, 226, 130)
GOLD_BOT = (214, 150, 40)
GLOW = (150, 200, 255)


def vgrad(w, h, top, bot):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def rounded_mask(box, radius):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def draw_icon():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad, radius = 40, 360
    body = rounded_mask([pad, pad, S - pad, S - pad], radius)

    # Background: blue gradient, a soft light from the top, a thin bright rim.
    bg = vgrad(S, S, BLUE_TOP, BLUE_BOT).convert("RGBA")
    light = Image.new("L", (S, S), 0)
    ImageDraw.Draw(light).ellipse([-S * 0.2, -S * 0.75, S * 1.2, S * 0.55], fill=60)
    light = light.filter(ImageFilter.GaussianBlur(160))
    bg = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), bg, light)
    img.paste(bg, (0, 0), body)
    rim = ImageChops.subtract(body, rounded_mask([pad + 34, pad + 34, S - pad - 34, S - pad - 34], radius - 34))
    img.paste(Image.new("RGBA", (S, S), RIM + (255,)), (0, 0), rim.point(lambda v: v * 0.5))

    # The writ: a parchment sheet, slightly tilted, with rolled ends and lines of writing.
    sheet = Image.new("L", (S, S), 0)
    left, top, right, bottom = 560, 470, 1400, 1580
    ImageDraw.Draw(sheet).rounded_rectangle([left, top, right, bottom], radius=60, fill=255)
    rolls = Image.new("L", (S, S), 0)
    dr = ImageDraw.Draw(rolls)
    dr.rounded_rectangle([left - 70, top - 70, right + 70, top + 70], radius=70, fill=255)
    dr.rounded_rectangle([left - 70, bottom - 70, right + 70, bottom + 70], radius=70, fill=255)
    paper = ImageChops.lighter(sheet, rolls).rotate(-8, resample=Image.BICUBIC, center=(S / 2, S / 2))
    rolls = rolls.rotate(-8, resample=Image.BICUBIC, center=(S / 2, S / 2))
    shadow = paper.filter(ImageFilter.GaussianBlur(50)).point(lambda v: v * 0.6)
    img.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (30, 60), shadow)
    glow = paper.filter(ImageFilter.GaussianBlur(140)).point(lambda v: v * 0.35)
    img.paste(Image.new("RGBA", (S, S), GLOW + (255,)), (0, 0), ImageChops.multiply(glow, body))
    img.paste(vgrad(S, S, PAPER_TOP, PAPER_BOT).convert("RGBA"), (0, 0), paper)
    img.paste(Image.new("RGBA", (S, S), PAPER_EDGE + (255,)), (0, 0), rolls.point(lambda v: v * 0.55))
    lines = Image.new("L", (S, S), 0)
    dl = ImageDraw.Draw(lines)
    for i, w in enumerate((640, 560, 600, 420)):
        y = top + 200 + i * 130
        dl.rounded_rectangle([left + 100, y, left + 100 + w, y + 46], radius=23, fill=255)
    lines = lines.rotate(-8, resample=Image.BICUBIC, center=(S / 2, S / 2))
    img.paste(Image.new("RGBA", (S, S), INK + (255,)), (0, 0), lines.point(lambda v: v * 0.7))

    # The wax seal at the bottom right, with a gold rank chevron pointing up.
    cx, cy, r = 1330, 1420, 300
    seal = Image.new("L", (S, S), 0)
    ImageDraw.Draw(seal).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    img.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (0, 40), seal.filter(ImageFilter.GaussianBlur(40)).point(lambda v: v * 0.6))
    img.paste(vgrad(S, S, WAX, WAX_DARK).convert("RGBA"), (0, 0), seal)
    ring = Image.new("L", (S, S), 0)
    ImageDraw.Draw(ring).ellipse([cx - r + 50, cy - r + 50, cx + r - 50, cy + r - 50], outline=255, width=26)
    img.paste(Image.new("RGBA", (S, S), WAX_DARK + (255,)), (0, 0), ring)
    chevron = Image.new("L", (S, S), 0)
    dc = ImageDraw.Draw(chevron)
    for dy in (-60, 70):
        dc.line([(cx - 150, cy + 60 + dy), (cx, cy - 80 + dy), (cx + 150, cy + 60 + dy)], fill=255, width=64, joint="curve")
    img.paste(vgrad(S, S, GOLD_TOP, GOLD_BOT).convert("RGBA"), (0, 0), chevron)

    # Keep everything inside the rounded square.
    img.putalpha(ImageChops.multiply(img.getchannel("A"), body))
    return img


FONTS = ROOT / ".scratch" / "fonts"
BOLD = os.environ.get("LEREP_FONT_BOLD", str(FONTS / "Inter-Bold.ttf"))
SEMI = os.environ.get("LEREP_FONT_SEMI", str(FONTS / "Inter-SemiBold.ttf"))
TAGLINE = "The cheapest gold path to rep and Favor."
# A sample of a plan's route: step, rep, Favor, cost.
SAMPLE = [
    ("Craftsman's Writ: Lesser Mana Potion", "+75", "", "45s"),
    ("Fill 10 Waylaid Crate: Apprentice Ore", "", "+50", "3g 10s"),
    ("Return 12 crates with receipts", "+600", "-180", "2g 40s"),
]


def banner(icon):
    from PIL import ImageFont
    W, H = 1600, 500
    img = vgrad(W, H, BLUE_TOP, BLUE_BOT).convert("RGBA")
    light = Image.new("L", (W, H), 0)
    ImageDraw.Draw(light).ellipse([-200, -500, 1100, 300], fill=50)
    light = light.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGBA", (W, H), (255, 255, 255, 255)), img, light)
    img.alpha_composite(icon.resize((380, 380), Image.LANCZOS), (60, 60))
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(BOLD, 140)
    tag = ImageFont.truetype(SEMI, 44)
    row = ImageFont.truetype(SEMI, 28)
    d.text((500, 52), "leRep", font=title, fill=GOLD_TOP)
    d.line([(506, 228), (1530, 228)], fill=GOLD_BOT + (255,), width=3)
    d.text((506, 244), TAGLINE, font=tag, fill=(226, 236, 250))
    # The sample rows, with the columns right-aligned like the addon's.
    cols = (1240, 1370, 1520)
    y = 322
    for name, rep, favor, cost in SAMPLE:
        d.text((510, y), name, font=row, fill=(255, 255, 255))
        for x, text, color in zip(cols, (rep, favor, cost), ((120, 200, 255), GOLD_TOP, (230, 230, 230))):
            w = d.textlength(text, font=row)
            d.text((x - w, y), text, font=row, fill=color)
        y += 46
    img.convert("RGB").save(ART / "lerep-banner.png")
    # Checks without looking at it: the text fits, the rows sit inside the canvas and clear of the
    # columns.
    tb = d.textbbox((500, 52), "leRep", font=title)
    tg = d.textbbox((506, 244), TAGLINE, font=tag)
    widest = max(d.textlength(s[0], font=row) for s in SAMPLE)
    print("title", tb, "tagline", tg, "fits:", tg[2] < W - 40 and tb[3] < 228,
          "rows end at y", y, "names end at x", 510 + widest, "(rep column starts near", cols[0] - 80, ")")


def main():
    ART.mkdir(exist_ok=True)
    big = draw_icon()
    for px in (512, 400, 256, 128):
        big.resize((px, px), Image.LANCZOS).save(ART / f"lerep-icon-{px}.png")
    GAME_ICON.parent.mkdir(exist_ok=True)
    big.resize((128, 128), Image.LANCZOS).save(GAME_ICON)
    print(f"Wrote art/lerep-icon-{{512,400,256,128}}.png and {GAME_ICON.relative_to(ROOT)}")
    if os.path.exists(BOLD) and os.path.exists(SEMI):
        banner(big)
        print("Wrote art/lerep-banner.png")
    else:
        print("No Inter font files (.scratch/fonts, or LEREP_FONT_BOLD and LEREP_FONT_SEMI): skipped the banner")


if __name__ == "__main__":
    main()
