"""Clean Codex paintings: force the background to pure white, trim, downscale into assets/."""
from pathlib import Path
from PIL import Image, ImageChops
import numpy as np

ROOT = Path(__file__).parent
SIZES = {"carp_a": 1024, "carp_b": 1024, "willow": 1600, "lotus": 900}

for name, width in SIZES.items():
    src = ROOT / f"{name}.png"
    if not src.exists():
        print("missing", name)
        continue
    img = np.asarray(Image.open(src).convert("RGB")).astype(float)
    # Lift near-white paper to exactly white so multiply leaves no rectangle.
    img = np.clip((img - 6) / (236 - 6), 0, 1) * 255
    im = Image.fromarray(img.astype("uint8"))
    box = ImageChops.difference(im, Image.new("RGB", im.size, "white")).point(lambda v: 255 if v > 12 else 0).getbbox()
    if name != "willow":
        im = im.crop(box)
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(ROOT.parent / "assets" / f"{name}.png")
    print(name, im.size)
