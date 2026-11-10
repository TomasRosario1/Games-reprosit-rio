"""Encode two new real 3D clips and assemble the four-vehicle review."""
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_04'
TEMP = Path('/tmp/emmet-review-04')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
CLIPS = [
    ('04_montar_bicicleta', 'BICICLETA', [(0, 1.3, 'Aproximar'), (1.3, 2, 'Apoiar a mao no guiador'), (2, 3.6, 'Passar a perna sobre o selim e apoiar no pedal'), (3.6, 4.8, 'Sentar e ajustar maos e pes'), (4.8, 8, 'Posicao final no selim, guiador e pedais')]),
    ('05_subir_trotinete', 'TROTINETE', [(0, 1.3, 'Aproximar'), (1.3, 2, 'Agarrar o guiador e preparar o apoio'), (2, 2.4, 'Colocar o primeiro pe na plataforma'), (2.4, 4.2, 'Transferir o peso e subir o outro pe'), (4.2, 8, 'Posicao final com maos e pes nos apoios')]),
]


def label(text, y, size=22, enable=None):
    result = f"drawtext=fontfile={FONT}:text='{text}':x=30:y={y}:fontsize={size}:fontcolor=white:shadowcolor=black:shadowx=1:shadowy=1"
    return result + (f":enable='{enable}'" if enable else '')


for name, title, sections in CLIPS:
    filters = [label(title, 18, 28), label('REVISAO 04 | Animacoes para feedback - ainda fora do jogo', 690, 19)]
    for start, end, text in sections:
        filters.append(label(text, 651, 22, f'gte(t,{start})*lt(t,{end})'))
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '24', '-i', str(TEMP / 'frames' / name / '%04d.png'), '-frames:v', '192', '-vf', ','.join(filters), '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', str(OUT / (name + '.mp4'))], check=True)
    print('ENCODED', name, flush=True)
parts = [BASE / 'emmet/revisao_03/02_entrar_carro.mp4', BASE / 'emmet/revisao_03/03_montar_mota.mp4'] + [OUT / (name + '.mp4') for name, _, _ in CLIPS]
concat = TEMP / 'concat.txt'
concat.write_text(''.join("file '" + str(part) + "'\n" for part in parts))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', '-movflags', '+faststart', str(OUT / '00_todos_os_veiculos.mp4')], check=True)
print('ENCODED all four vehicles, 32 seconds', flush=True)
