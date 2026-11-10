"""Encode actual review05 mesh motion and keep the approved scooter byte-for-byte."""
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_05'
TEMP = Path('/tmp/emmet-review-05')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
CLIPS = [
    ('01_carro', 'CARRO | MENOS PASSOS', [(0, .7, 'Parado junto da porta'), (.7, 2.7, 'Abrir a porta com os pes parados'), (2.7, 3.6, 'Posicionar para entrar'), (3.6, 4.6, 'Baixar o corpo e colocar a primeira perna'), (4.6, 6.6, 'Sentar, recolher as pernas e fechar a porta'), (6.6, 8, 'Posicao final no volante')]),
    ('02_mota', 'MOTA | PASSAGEM PELO EXTERIOR', [(0, .8, 'Aproximar'), (.8, 1.9, 'Apoiar e inclinar a mota'), (1.9, 3.5, 'Elevar a anca e passar a perna sobre a traseira'), (3.5, 5.8, 'Assentar no banco e endireitar a mota'), (5.8, 8, 'Posicao final no banco e apoios')]),
    ('03_bicicleta', 'BICICLETA | PASSAGEM PELO EXTERIOR', [(0, .8, 'Aproximar'), (.8, 1.9, 'Apoiar e inclinar a bicicleta'), (1.9, 3.5, 'Subir no pedal e passar a perna sobre o selim'), (3.5, 5.8, 'Sentar e endireitar a bicicleta'), (5.8, 8, 'Posicao final com os pes nos pedais')]),
]


def label(text, y, size=22, enable=None):
    result = f"drawtext=fontfile={FONT}:text='{text}':x=30:y={y}:fontsize={size}:fontcolor=white:shadowcolor=black:shadowx=1:shadowy=1"
    return result + (f":enable='{enable}'" if enable else '')


for clip, title, stages in CLIPS:
    filters = [label(title, 18, 28), label('REVISAO 05 | Ajustes ao movimento - arquivo para feedback', 690, 19)]
    for start, end, text in stages:
        filters.append(label(text, 651, 22, f'gte(t,{start})*lt(t,{end})'))
    if clip == '01_carro':
        filters.append(label('Vidros ocultos para observar a entrada', 615, 18))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '24', '-i', str(TEMP / 'frames' / clip / '%04d.png'), '-frames:v', '192', '-vf', ','.join(filters), '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', str(OUT / (clip + '.mp4'))], check=True)
    print('ENCODED', clip, flush=True)
parts = [OUT / (clip + '.mp4') for clip, _, _ in CLIPS] + [BASE / 'emmet/revisao_04/05_subir_trotinete.mp4']
concat = TEMP / 'concat05.txt'
concat.write_text(''.join("file '" + str(part) + "'\n" for part in parts))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', '-movflags', '+faststart', str(OUT / '00_quatro_veiculos.mp4')], check=True)
print('ENCODED full review: corrected car/motorbike/bicycle + unchanged approved scooter', flush=True)
