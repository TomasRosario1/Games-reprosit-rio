"""Encode actual left-grip-first mounts; concatenate accepted clips unchanged."""
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_06'
TEMP = Path('/tmp/emmet-review-06')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def label(text, y, size=22, enable=None):
    value = f"drawtext=fontfile={FONT}:text='{text}':x=30:y={y}:fontsize={size}:fontcolor=white:shadowcolor=black:shadowx=1:shadowy=1"
    return value + (f":enable='{enable}'" if enable else '')


for clip, title in [('01_mota', 'MOTA'), ('02_bicicleta', 'BICICLETA')]:
    assert all((TEMP / 'frames' / clip / ('%04d.png' % frame)).is_file() for frame in range(192)), 'Render all 192 frames before encoding ' + clip
    stages = [(0, 1.15, 'A mao esquerda agarra primeiro o guiador'), (1.15, 2.5, 'Inclinar mantendo a pega e preparar o apoio'), (2.5, 4.5, 'Dobrar o joelho para a frente e passar por cima'), (4.5, 6.4, 'Assentar e endireitar o veiculo'), (6.4, 8, 'Posicao final nos apoios e no guiador')]
    filters = [label(title + ' | MAO ESQUERDA PRIMEIRO', 18, 28), label('REVISAO 06 | Animacao real do modelo - arquivo para feedback', 690, 19)]
    filters.extend(label(text, 651, 22, f'gte(t,{start})*lt(t,{end})') for start, end, text in stages)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '24', '-i', str(TEMP / 'frames' / clip / '%04d.png'), '-frames:v', '192', '-vf', ','.join(filters), '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-an', str(OUT / (clip + '.mp4'))], check=True)
    print('ENCODED', clip, flush=True)
parts = [BASE / 'emmet/revisao_05/01_carro.mp4', OUT / '01_mota.mp4', OUT / '02_bicicleta.mp4', BASE / 'emmet/revisao_04/05_subir_trotinete.mp4']
concat = TEMP / 'concat.txt'
concat.write_text(''.join("file '" + str(part) + "'\n" for part in parts))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', '-movflags', '+faststart', str(OUT / '00_quatro_veiculos.mp4')], check=True)
print('ENCODED four vehicles; accepted car and scooter were not re-encoded', flush=True)
