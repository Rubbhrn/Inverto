"""Rebuild Inverto's code-drawn brand assets (requires Pillow and fonttools)."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'assets/branding'
FONT = ROOT / 'assets/fonts'

# The same upward chart as the original in-app mark, with rounded strokes.
SIZE = 1024
image = Image.new('RGB', (SIZE, SIZE))
pixels = image.load()
for y in range(SIZE):
    for x in range(SIZE):
        t = (x + y) / (2 * (SIZE - 1))
        pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip((29, 105, 79), (10, 44, 36)))
draw = ImageDraw.Draw(image)
points = [(284, 654), (410, 523), (503, 597), (727, 371)]
draw.line(points, fill='white', width=58, joint='curve')
for x, y in points:
    draw.ellipse((x - 29, y - 29, x + 29, y + 29), fill='white')
draw.line([(581, 371), (727, 371), (727, 517)], fill='white', width=58, joint='curve')
for x, y in [(581, 371), (727, 371), (727, 517)]:
    draw.ellipse((x - 29, y - 29, x + 29, y + 29), fill='white')
image.save(BRAND / 'inverto-icon.png')
res = ROOT / 'android/app/src/main/res'
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    image.resize((size, size), Image.Resampling.LANCZOS).save(res / f'mipmap-{density}/ic_launcher.png')

# Static instances give consistent weights on Android and Flutter web.
if '--icons-only' in sys.argv:
    sys.exit(0)

source = FONT / 'Inter-Variable.ttf'
for weight, name in [(400, 'Regular'), (500, 'Medium'), (600, 'SemiBold'), (700, 'Bold'), (800, 'ExtraBold')]:
    font = TTFont(source)
    instance = instantiateVariableFont(font, {'wght': weight, 'opsz': 24}, inplace=True)
    instance.save(FONT / f'Inter-{name}.ttf')
