import os
try:
    from PIL import Image
except ImportError:
    print('PIL missing')
    raise
for name in ['graphics/Dungeon(1).png','graphics/Dungeon(2).png','graphics/Dungeon(3).png','graphics/Dungeon(4).png']:
    if os.path.exists(name):
        img = Image.open(name).convert('RGB')
        print(name, img.mode, img.size)
        colors = img.getcolors(maxcolors=1000000)
        if colors is None:
            print('Too many colors')
        else:
            colors = sorted(colors, key=lambda x: x[0], reverse=True)
            print('Top colors:', colors[:20])
        w, h = img.size
        samples = [(w//2, h//2), (10,10), (100,100), (w-10,h-10), (w//4, h//4), (w//2, h//4), (w//4, h//2)]
        for x, y in samples:
            if 0 <= x < w and 0 <= y < h:
                print('sample', x, y, img.getpixel((x,y)))
    else:
        print(name, 'MISSING')
