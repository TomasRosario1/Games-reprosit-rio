"""Rebuild original window facades using this project's own PBR wall textures."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'assets/textures';out=ROOT/'assets/maps/textures';out.mkdir(parents=True,exist_ok=True)
for i,key in enumerate(['city_plaster','city_ochre','city_pink','city_blue']):
 im=Image.open(source/(key+'.png')).convert('RGB').resize((256,256));d=ImageDraw.Draw(im)
 glow=Image.new('RGB',(256,256));gd=ImageDraw.Draw(glow)
 for x in (30,150):
  d.rectangle((x-4,48,x+68,207),fill=(69,64,56));d.rectangle((x,52,x+64,200),fill=(123,112,92))
  for row in range(2):
   for col in range(2):
    xx=x+5+col*29;yy=59+row*68;lit=(i+col+row)%3==0
    d.rectangle((xx,yy,xx+24,yy+61),fill=(164,147,91) if lit else (35,44,44))
    if lit:gd.rectangle((xx,yy,xx+24,yy+61),fill=(164,147,91))
    d.line((xx+2,yy+3,xx+22,yy+3),fill=(193,172,106) if lit else (63,66,60),width=2)
  d.rectangle((x-5,202,x+69,209),fill=(108,99,84))
 d.rectangle((0,246,255,251),fill=(99,93,81))
 im.save(out/('facade_%d.png'%i));glow.save(out/('facade_%d_emission.png'%i))
 for suffix in ('normal','rough'): Image.open(source/(key+'_'+suffix+'.png')).save(out/('facade_%d_%s.png'%(i,suffix)))
