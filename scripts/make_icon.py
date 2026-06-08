"""
make_icon.py — Genera el icono de escritorio de Odysseus (el barquito).

Crea:
  - odysseus.ico               (icono multi-tamano para el acceso directo)
  - odysseus-icon-preview.png  (imagen 256px para el splash del lanzador)

Uso:
  python scripts/make_icon.py [directorio_salida]   (por defecto: carpeta del repo)
"""
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow no esta instalado. Ejecuta: pip install pillow")

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

S = 256
sc = S / 32.0
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# fondo oscuro redondeado (combina con el tema oscuro de Odysseus)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(6 * sc), fill=(24, 27, 33, 255))

accent = (224, 108, 117, 255)   # #e06c75 (salmon de marca)
accent2 = (180, 86, 94, 255)    # tono mas oscuro para la segunda vela


def P(x, y):
    return (x * sc, y * sc)


# velas
d.polygon([P(16, 4), P(16, 22), P(6, 22)], fill=accent)
d.polygon([P(16, 8), P(16, 22), P(24, 22)], fill=accent2)


# ola (dos curvas bezier cuadraticas)
def quad(p0, p1, p2, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        out.append((x, y))
    return out


wave = quad(P(4, 24.5), P(10, 20.5), P(16, 24.5)) + quad(P(16, 24.5), P(22, 28.5), P(28, 24.5))
d.line(wave, fill=accent, width=int(2.2 * sc), joint="curve")

ico_path = os.path.join(out_dir, "odysseus.ico")
png_path = os.path.join(out_dir, "odysseus-icon-preview.png")
img.save(ico_path, sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
img.save(png_path)
print("Creado:", ico_path)
print("Creado:", png_path)
