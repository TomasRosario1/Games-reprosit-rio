"""Original, seamless urban material studies. Optional regeneration; no game dependency."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
ROOT.mkdir(parents=True, exist_ok=True)
RNG = np.random.default_rng(812)
N = 256

def material(name, color, kind, rough=210):
    fine = RNG.normal(0, 2.4, (N, N, 1))
    broad = np.asarray(Image.fromarray(RNG.integers(0,255,(32,32),dtype=np.uint8)).resize((N,N),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(7)), dtype=float)
    arr = np.clip(np.array(color)[None,None,:] + fine + (broad[:,:,None]-127)*.065,0,255).astype('uint8')
    img = Image.fromarray(arr); d=ImageDraw.Draw(img)
    if kind == 'stone':
        for y in range(0,N,64):
            d.line((0,y,N,y),fill=tuple(int(c*.77) for c in color),width=1)
            for x in range(-64,N,128):
                xx=x+(64 if (y//64)%2 else 0)
                d.line((xx,y,xx,y+64),fill=tuple(int(c*.80) for c in color),width=1)
        for i in range(45):
            x,y=map(int,RNG.integers(0,N,2)); d.point((x,y),fill=tuple(int(c*.77) for c in color))
    elif kind == 'plaster':
        # Small flecks and broad damp staining, avoiding giant repeated circles.
        for i in range(150):
            x,y=map(int,RNG.integers(0,N,2)); d.line((x,y,x+int(RNG.integers(1,3)),y),fill=tuple(int(c*.90) for c in color))
    elif kind == 'pavement':
        for y in range(0,N,16):
            for x in range(0,N,16):
                xx=x+(8 if (y//16)%2 else 0)
                v=int(RNG.integers(-9,9)); col=tuple(max(0,min(255,c+v)) for c in color)
                if (x//16+y//16*3)%17 in (0,1):col=(66+v,67+v,63+v)
                d.rounded_rectangle((xx,y,xx+14,y+14),radius=1,fill=col,outline=(87,86,78))
    elif kind == 'road':
        for i in range(2000):
            x,y=map(int,RNG.integers(0,N,2));v=int(RNG.integers(-13,14));d.point((x,y),fill=tuple(max(0,c+v) for c in color))
        for x,y in [(20,23),(173,95)]:
            d.line([(x,y),(x+13,y+6),(x+17,y+23),(x+29,y+31)],fill=(21,24,25),width=1)
    elif kind == 'leaf':
        for i in range(300):
            x,y=map(int,RNG.integers(0,N,2));v=int(RNG.integers(-15,16));d.ellipse((x,y,x+4,y+7),fill=(max(0,color[0]+v),max(0,color[1]+v),max(0,color[2]+v)))
    elif kind == 'roof':
        for x in range(0,N,24):
            d.line((x,0,x,N),fill=(55,37,29),width=2)
            d.line((x+6,0,x+6,N),fill=(144,90,59),width=3)
        for y in range(0,N,48):d.line((0,y,N,y),fill=(62,43,32),width=1)
    elif kind == 'granite':
        for i in range(1000):
            x,y=map(int,RNG.integers(0,N,2));v=int(RNG.integers(35,102));d.point((x,y),fill=(v,v+1,v+2))
    img.save(ROOT/(name+'.png'))
    lum=np.asarray(img.convert('L'),dtype=float)/255
    gy,gx=np.gradient(lum)
    normal=np.dstack((-gx*.32,-gy*.32,np.ones((N,N))))
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    Image.fromarray(((normal*.5+.5)*255).astype('uint8')).save(ROOT/(name+'_normal.png'))
    Image.fromarray(np.clip(RNG.normal(rough,4,(N,N)),0,255).astype('uint8')).save(ROOT/(name+'_rough.png'))

for args in [('city_stone',(135,128,109),'stone'),('city_plaster',(135,125,103),'plaster'),('city_ochre',(139,119,84),'plaster'),('city_pink',(123,107,101),'plaster'),('city_blue',(88,102,105),'plaster'),('city_calcada',(154,151,135),'pavement'),('city_asphalt',(43,44,44),'road',150),('city_leaf',(36,54,33),'leaf'),('city_roof',(110,66,41),'roof'),('city_granite',(66,68,69),'granite')]:material(*args)
# Soft original flare mask for warm fixtures, not a light/geometry substitute.
y,x=np.mgrid[:128,:128];r=np.sqrt((x-63.5)**2+(y-63.5)**2)/63.5
alpha=np.clip(np.exp(-r*7)*(1-r),0,1)
rgba=np.zeros((128,128,4),dtype=np.uint8);rgba[:,:,:3]=(255,196,104);rgba[:,:,3]=(alpha*190).astype('uint8')
Image.fromarray(rgba).save(ROOT/'city_flare.png')
print('City materials created.')
