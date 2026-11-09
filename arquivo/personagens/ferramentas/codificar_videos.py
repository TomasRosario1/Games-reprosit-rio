"""Encode actual Blender frames as browser-compatible H.264 videos. No synthetic motion."""
import subprocess,json,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent.parent
REVISION='02' if '--revision=02' in sys.argv else '01'
OUT=BASE/('emmet/revisao_'+REVISION);FRAMES=Path('/tmp/emmet-review/frames' if REVISION=='01' else '/tmp/emmet-review-02/frames')
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
clips=[
 ('01_esqueleto_360','01 | ENCAIXE DO ESQUELETO - VISTA 360',[(0,8,'Modelo parado; camera roda para ver frente, lado e costas')]),
 ('02_bracos','02 | BRACOS',[(0,3,'Cotovelos - flexao'),(3,6,'Ombros - elevacao lateral'),(6,8,'Pulsos - rotacao')]),
 ('03_pernas','03 | PERNAS',[(0,4,'Anca, joelho e tornozelo esquerdos'),(4,8,'Anca, joelho e tornozelo direitos')]),
 ('04_tronco','04 | TRONCO E CABECA',[(0,3,'Cabeca e pescoco - rotacao'),(3,6,'Tronco - torcao'),(6,8,'Coluna - inclinacao')]),
]
if REVISION=='02':
    clips=[
      ('01_esqueleto_360','01 | BRACOS RECENTRADOS - VISTA 360',[(0,8,'Vista 360 - profundidade real, sem deslocar os ossos para a camera')]),
      ('02_bracos','02 | BRACOS - ENCAIXE CORRIGIDO',[(0,3,'Cotovelos - flexao'),(3,6,'Ombros - elevacao lateral'),(6,8,'Pulsos - rotacao')]),
      ('03_comparacao_bracos','03 | COMPARACAO ANTERIOR / CORRIGIDO',[(0,3,'Mesmo teste - cotovelos'),(3,6,'Mesmo teste - ombros'),(6,8,'Mesmo teste - pulsos')]),
    ]
for name,title,sections in clips:
    def text(value,x,y,size=18,enable=None):
        f=f"drawtext=fontfile={font}:text='{value}':x={x}:y={y}:fontsize={size}:fontcolor=white:shadowcolor=black:shadowx=1:shadowy=1"
        if enable:f+=f":enable='{enable}'"
        return f
    filters=[text(title,22,12,20),text('Corpo deformado',150,45,16),text('Mesma pose + esqueleto sobreposto',540,45,16),text('REVISAO 01 | Testes de articulacao - nao integrado no jogo',22,510,15)]
    if REVISION=='02':
        labels=('Revisao 01 - anterior','Revisao 02 - corrigida') if name=='03_comparacao_bracos' else ('Corpo deformado','Malha + ossos reais por dentro')
        filters=[text(title,30,15,26),text(labels[0],240,61,22),text(labels[1],750,61,22),text('REVISAO 02 | Encaixe dos bracos - aguarda o teu feedback',30,690,19)]
    for a,b,label in sections: filters.append(text(label,30 if REVISION=='02' else 22,655 if REVISION=='02' else 484,22 if REVISION=='02' else 17,f'gte(t,{a})*lt(t,{b})'))
    command=['ffmpeg','-y','-loglevel','error','-framerate','24','-i',str(FRAMES/name/'%04d.png'),'-vf',','.join(filters),'-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(OUT/(name+'.mp4'))]
    subprocess.run(command,check=True)
    print('ENCODED',name,flush=True)
# Concatenation preserves the exact rendered sequences and their on-screen labels.
concat=Path('/tmp/emmet-review/concat.txt' if REVISION=='01' else '/tmp/emmet-review-02/concat.txt')
concat.write_text(''.join("file '"+str(OUT/(name+'.mp4'))+"'\n" for name,_,_ in clips))
subprocess.run(['ffmpeg','-y','-loglevel','error','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(OUT/'00_revisao_completa.mp4')],check=True)
print('ENCODED full%dsecondreview' % (len(clips)*8),flush=True)
