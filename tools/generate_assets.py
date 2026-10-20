from PIL import Image,ImageDraw,ImageFilter
import numpy as np, pathlib, wave, subprocess
base=pathlib.Path(__file__).resolve().parents[1]/'assets'; rng=np.random.default_rng(73); n=256

def save(name,col,kind):
 noise=rng.normal(0,8,(n,n,1)); arr=np.clip(np.array(col)[None,None,:]+noise,0,255).astype('uint8')
 im=Image.fromarray(arr);d=ImageDraw.Draw(im)
 if kind=='wall':
  for i in range(55):
   x,y=rng.integers(0,n,2); w,h=rng.integers(3,35,2)
   d.ellipse((int(x),int(y),int(x+w),int(y+h)),fill=tuple(max(0,int(c)-int(rng.integers(8,24))) for c in col))
  for y in range(0,n,64): d.line((0,y,n,y+2),fill=tuple(int(c*.72) for c in col),width=2)
 elif kind=='tile':
  for y in range(0,n,32):
   for x in range(0,n,32):
    d.rectangle((x,y,x+31,y+31),outline=(58,70,81),width=2)
    d.line((x+6,y+16,x+16,y+5,x+26,y+16,x+16,y+27,x+6,y+16),fill=(74,112,133),width=2)
 elif kind=='cobble':
  for y in range(0,n,16):
   for x in range(-8,n,16):
    xx=x+(8 if y%32 else 0); v=int(rng.integers(100,155));black=((xx//16+y//16)%11<2)
    fill=(v,v-4,v-14) if not black else (39,45,47)
    d.rounded_rectangle((xx+1,y+1,xx+15,y+15),radius=2,fill=fill,outline=(53,55,51))
 elif kind=='roof':
  for x in range(0,n,16):
   d.line((x,0,x,n),fill=(79,39,29),width=3);d.line((x+5,0,x+5,n),fill=(164,87,54),width=3)
  for y in range(0,n,32): d.line((0,y,n,y),fill=(63,41,32),width=2)
 elif kind=='wood':
  for x in range(0,n,32):
   d.line((x,0,x,n),fill=(29,27,26),width=2)
   for j in range(4):
    xx=x+int(rng.integers(2,30));d.line((xx,0,xx+2,n),fill=(70,48,34),width=1)
 elif kind=='metal':
  for y in range(0,n,8): d.line((0,y,n,y),fill=tuple(max(0,c-9) for c in col))
 elif kind=='cloth':
  for x in range(0,n,4): d.line((x,0,x,n),fill=tuple(max(0,c-7) for c in col))
 elif kind=='paper':
  for i in range(120):
   x,y=rng.integers(0,n,2);d.point((int(x),int(y)),fill=(160,143,111))
 # Detail preserved, rough surface maps + tangent-space normals from luminance.
 im.save(base/'textures'/f'{name}.png')
 lum=np.asarray(im.convert('L'),dtype=float)/255
 gy,gx=np.gradient(lum);normal=np.dstack((-gx*1.1,-gy*1.1,np.ones((n,n))))
 normal/=np.linalg.norm(normal,axis=2,keepdims=True)
 Image.fromarray(np.clip((normal*.5+.5)*255,0,255).astype('uint8')).save(base/'textures'/f'{name}_normal.png')
 rough=np.clip(rng.normal(215 if kind!='metal' else 165,10,(n,n)),0,255).astype('uint8')
 Image.fromarray(rough).save(base/'textures'/f'{name}_rough.png')
for name,col,kind in [('stucco',(154,139,112),'wall'),('ochre',(160,122,70),'wall'),('blue',(63,91,107),'wall'),('pink',(137,89,88),'wall'),('tiles',(155,179,181),'tile'),('calcada',(138,135,119),'cobble'),('roof',(132,66,43),'roof'),('asphalt',(38,43,47),'grain'),('metal',(53,64,69),'metal'),('wood',(92,62,41),'wood'),('coat',(39,43,49),'cloth'),('paper',(220,207,170),'paper'),('glass',(35,56,64),'metal'),('marking',(190,186,153),'wall')]: save(name,col,kind)
sr=22050
for index,bpm in enumerate([96,108,120]):
 beat=60/bpm;duration=64*beat; length=int(duration*sr);audio=np.zeros(length);rng_audio=np.random.default_rng(index)
 def add(sound,start,gain=1):
  at=int(start*sr);end=min(length,at+len(sound))
  if end>at and at>=0:audio[at:end]+=sound[:end-at]*gain
 for b in range(64):
  t=np.arange(int(.36*sr))/sr
  kick=np.sin(2*np.pi*(46*t+7*(1-np.exp(-t*28))))*np.exp(-t*15)
  if b%4 in [0,2]:add(kick,b*beat,.42)
  ts=np.arange(int(.16*sr))/sr
  if b%4 in [1,3]:add(rng_audio.normal(0,1,len(ts))*np.exp(-ts*32),b*beat,.09)
  for half in [0,.5]:
   th=np.arange(int(.065*sr))/sr;add(rng_audio.normal(0,1,len(th))*np.exp(-th*72), (b+half)*beat,.035)
  f=[73.416,65.406,58.27,65.406][(b//8)%4]
  tb=np.arange(int(beat*.85*sr))/sr;env=np.minimum(tb/.02,1)*np.exp(-tb*3)
  add((np.sin(2*np.pi*f*tb)+.2*np.sin(4*np.pi*f*tb))*env,b*beat,.18)
  if b%2==0:
   fmel=[293.66,349.23,440.,391.99,349.23,293.66,261.63,220.][(b//2+index)%8]
   tm=np.arange(int(beat*1.8*sr))/sr;env=np.minimum(tm/.08,1)*np.exp(-tm*3)
   sound=(np.sin(2*np.pi*fmel*tm)+.15*np.sin(2*np.pi*fmel*2*tm))*env
   add(sound,b*beat,.10);add(sound,(b+.75)*beat,.025)
 audio=np.tanh(audio)*.72
 stereo=np.column_stack([audio,np.roll(audio,21)*.96]);raw=(stereo*32767).astype('<i2')
 wav=base/'audio'/f'demo_{index+1}.wav';ogg=base/'audio'/f'demo_{index+1}.ogg'
 with wave.open(str(wav),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes(raw.tobytes())
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','3',str(ogg)],check=True);wav.unlink()
# Soft synthetic city bed, no third-party recordings.
duration=12; t=np.arange(int(duration*sr))/sr; noise=rng.normal(0,1,len(t)); noise=np.convolve(noise,np.ones(90)/90,mode='same')
audio=.12*noise
for j in range(3):audio+=.008*np.sin(2*np.pi*(45+j*13)*t)*(0.5+0.5*np.sin(2*np.pi*t/duration+j))
raw=(np.column_stack([audio,np.roll(audio,70)])*32767).astype('<i2');wav=base/'audio/city.wav'
with wave.open(str(wav),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes(raw.tobytes())
subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','2',str(base/'audio/city.ogg')],check=True);wav.unlink()
print('14 materiais PBR procedurais, três faixas de ensaio e ambiente de teste criados.')
