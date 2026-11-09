"""Encode the real Blender review03 frames, with labels for feedback timestamps."""
from pathlib import Path
import subprocess
BASE=Path(__file__).resolve().parent.parent
OUT=BASE/'emmet/revisao_03';FRAMES=Path('/tmp/emmet-review-03/frames')
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
CLIPS=[
 ('01_andar','01 | ANDAR',[(0,4,'Vista tres quartos - deslocacao e apoio alternado dos pes'),(4,8,'Vista lateral - passada, joelhos e balanco dos bracos')]),
 ('02_entrar_carro','02 | ENTRAR NO CARRO',[(0,1.3,'Aproximar'),(1.3,2.7,'Abrir a porta'),(2.7,3.6,'Posicionar o corpo junto da entrada'),(3.6,4.6,'Baixar o corpo e colocar a primeira perna'),(4.6,6.6,'Sentar, recolher as pernas e puxar a porta'),(6.6,8,'Maos no volante e pes no interior')]),
 ('03_montar_mota','03 | MONTAR A MOTA',[(0,1.3,'Aproximar'),(1.3,2,'Apoiar no guiador'),(2,3.9,'Passar a perna sobre o banco'),(3.9,5,'Acomodar o corpo e os pes'),(5,8,'Posicao final no banco, guiador e apoios')]),
]
def text(label,x,y,size=22,enable=None):
 value=f"drawtext=fontfile={FONT}:text='{label}':x={x}:y={y}:fontsize={size}:fontcolor=white:shadowcolor=black:shadowx=1:shadowy=1"
 if enable:value+=f":enable='{enable}'"
 return value
for name,title,sections in CLIPS:
 filters=[text(title,30,18,28),text('REVISAO 03 | Animacoes para feedback - ainda fora do jogo',30,690,19)]
 for start,end,label in sections:filters.append(text(label,30,651,22,f'gte(t,{start})*lt(t,{end})'))
 if name=='02_entrar_carro':filters.append(text('Vidros ocultos para observar a entrada e o encaixe',30,615,18))
 subprocess.run(['ffmpeg','-y','-loglevel','error','-framerate','24','-i',str(FRAMES/name/'%04d.png'),'-vf',','.join(filters),'-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(OUT/(name+'.mp4'))],check=True)
 print('ENCODED',name,flush=True)
concat=Path('/tmp/emmet-review-03/concat.txt');concat.write_text(''.join("file '"+str(OUT/(name+'.mp4'))+"'\n"for name,_,_ in CLIPS))
subprocess.run(['ffmpeg','-y','-loglevel','error','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(OUT/'00_animacoes_completas.mp4')],check=True)
print('ENCODED full24secondreview',flush=True)
