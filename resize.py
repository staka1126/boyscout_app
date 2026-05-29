from PIL import Image
import os

src = './Copilot_20260529_171055.png'  # ダウンロードした画像のパス
img = Image.open(src).convert('RGBA')

data = list(img.getdata())
new_data = [(0,0,0,0) if (r<30 and g<30 and b<30) else (r,g,b,a) for r,g,b,a in data]
img.putdata(new_data)

bbox = img.getbbox()
cropped = img.crop(bbox)
size = max(cropped.size)
square = Image.new('RGBA', (size, size), (0,0,0,0))
square.paste(cropped, ((size-cropped.width)//2, (size-cropped.height)//2))

sizes = {
    'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192,
}
base = '/home/takaaki/git-work/BoyScout/boyscout_app/android/app/src/main/res'
for folder, px in sizes.items():
    resized = square.resize((px, px), Image.LANCZOS)
    bg = Image.new('RGB', (px, px), (255,255,255))
    bg.paste(resized, (0,0), resized)
    bg.save(f'{base}/{folder}/ic_launcher.png')
    bg.save(f'{base}/{folder}/ic_launcher_round.png')
    print(f'{folder}: OK')
