"""Encode actual Blender frames as browser-compatible H.264 videos. No synthetic motion."""
import subprocess,json
from pathlib import Path
BASE=Path(__file__).resolve().parent.parent
OUT=BASE/'emmet/revisao_01';FRAMES=Path('/tmp/emmet-review/frames')
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
clips=[
 ('01_esqueleto_360','01 | ENCAIXE DO ESQUELETO - VISTA 360',[(0,8,'Modelo parado; camera roda para ver frente, lado e costas')]),
 ('02_bracos','02 | BRACOS',[(0,3,'Cotovelos - flexao'),(3,6,'Ombros - elevacao lateral'),(6,8,'Pulsos - rotacao')]),
 ('03_pernas','03 | PERNAS',[(0,4,'Anca, joelho e tornozelo esquerdos'),(4,8,'Anca, joelho e tornozelo direitos')]),
 ('04_tronco','04 | TRONCO E CABECA',[(0,3,'Cabeca e pescoco - rotacao'),(3,6,'Tronco - torcao'),(6,8,'Coluna - inclinacao')]),
]
for name,title,sections in clips:
    def text(value,x,y,size=18,enable=None):
        f=f"drawtext=fontfile={font}:text='{value}':x={x}:y={y}:fontsize={size}:fontcolor=white:shadowcolor=black:shadowx=1:shadowy=1"
        if enable:f+=f":enable='{enable}'"
        return f
    filters=[text(title,22,12,20),text('Corpo deformado',150,45,16),text('Mesma pose + esqueleto sobreposto',540,45,16),text('REVISAO 01 | Testes de articulacao - nao integrado no jogo',22,510,15)]
    for a,b,label in sections: filters.append(text(label,22,484,17,f'gte(t,{a})*lt(t,{b})'))
    command=['ffmpeg','-y','-loglevel','error','-framerate','24','-i',str(FRAMES/name/'%04d.png'),'-vf',','.join(filters),'-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(OUT/(name+'.mp4'))]
    subprocess.run(command,check=True)
    print('ENCODED',name,flush=True)
# Concatenation preserves the exact rendered sequences and their on-screen labels.
concat=Path('/tmp/emmet-review/concat.txt')
concat.write_text(''.join("file '"+str(OUT/(name+'.mp4'))+"'\n" for name,_,_ in clips))
subprocess.run(['ffmpeg','-y','-loglevel','error','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(OUT/'00_revisao_completa.mp4')],check=True)
print('ENCODED full32secondreview',flush=True)
