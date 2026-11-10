"""Validate new GLBs, geometry clearance, foot planting and actual decoded videos."""
import hashlib
import json
import math
import runpy
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
ROOT = BASE.parents[1]
OUT = BASE / 'emmet/revisao_05'
helpers = runpy.run_path(str(BASE / 'ferramentas/validar_arquivo.py'))
glb, accessor = helpers['glb'], helpers['accessor']
reference, reference_binary = glb(BASE / 'emmet/revisao_02/emmet_articulacao_02.glb')
reference_primitive = reference['meshes'][0]['primitives'][0]
contacts = json.loads((OUT / 'contactos.json').read_text())
geometry = json.loads((OUT / 'geometria.json').read_text())
records = []


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


for clip in ('01_carro', '02_mota', '03_bicicleta'):
    document, binary = glb(OUT / (clip + '.glb'))
    assert len(document['skins']) == 1 and len(document['skins'][0]['joints']) == 21
    assert len(document['animations']) == 1 and document['animations'][0]['name'] == clip
    assert not any('uri' in item and not item['uri'].startswith('data:') for key in ('buffers', 'images') for item in document.get(key, []))
    actor = next(p for mesh in document['meshes'] for p in mesh['primitives'] if 'JOINTS_0' in p['attributes'])
    root = next(n for n in document['nodes'] if n.get('name') == 'Emmet_Rig_Animacoes05')
    origin, rotation, scale = root.get('translation', [0, 0, 0]), root.get('rotation', [0, 0, 0, 1]), root.get('scale', [1, 1, 1])

    def canonical(point):
        v = [point[index] - origin[index] for index in range(3)]
        xyz = [-rotation[index] for index in range(3)]
        temp = [2 * value for value in cross(xyz, v)]
        second = cross(xyz, temp)
        return [(v[index] + rotation[3] * temp[index] + second[index]) / scale[index] for index in range(3)]

    actual = {}
    for pos, uv in zip(accessor(document, binary, actor['attributes']['POSITION']), accessor(document, binary, actor['attributes']['TEXCOORD_0'])):
        actual.setdefault(uv, []).append(canonical(pos))
    for pos, uv in zip(accessor(reference, reference_binary, reference_primitive['attributes']['POSITION']), accessor(reference, reference_binary, reference_primitive['attributes']['TEXCOORD_0'])):
        candidates = actual[uv]
        nearest = min(range(len(candidates)), key=lambda index: math.dist(pos, candidates[index]))
        assert math.dist(pos, candidates.pop(nearest)) < 1e-5
    assert all(not candidates for candidates in actual.values())
    assert all(abs(sum(weights) - 1) < .0001 for weights in accessor(document, binary, actor['attributes']['WEIGHTS_0']))
    for sampler in document['animations'][0]['samplers']:
        times = accessor(document, binary, sampler['input'])
        assert abs(times[0][0]) < .001 and abs(times[-1][0] - 191 / 24) < .01
    frames = contacts[clip]
    assert len(frames) == 192
    max_error = max(contact['error'] for frame in frames for contact in frame['targets'].values())
    assert max_error < .015
    assert max(math.dist(a['root'], b['root']) for a, b in zip(frames, frames[1:])) < .1
    if clip == '01_carro':
        assert len(geometry[clip]) == 65 and all(not sample['intersections'] for sample in geometry[clip])
        opening = [frame for frame in frames if frame['time'] < 2.7]
        assert all(math.dist(frame['root'], frames[0]['root']) < 1e-6 for frame in opening)
        for side in ('L', 'R'):
            points = [frame['targets']['foot.' + side]['actual'] for frame in opening]
            assert max(math.dist(point, points[0]) for point in points) < 1e-5
    else:
        assert len(geometry[clip]) == 192
        assert all(not frame['intersections'] for frame in geometry[clip])
        assert max(frame['tilt_radians'] for frame in frames) > math.radians(9.9)
        assert frames[-1]['tilt_radians'] == 0
        assert len(actor['targets']) == 6
        assert any(channel['target']['path'] == 'weights' for channel in document['animations'][0]['channels'])
    records.append({'clip': clip, 'frames': 192, 'max_contact_error_m': max_error, 'approved_rest_model_preserved': True, 'geometry_scope': 'stationary_opening_body_excluding_arms' if clip == '01_carro' else 'legs_versus_vehicle_core_entire_clip', 'geometry_sample_frames': len(geometry[clip]), 'intersection_frames': sum(bool(frame['intersections']) for frame in geometry[clip])})
    print('ANIMATION OK', clip, 'contacts and geometry')

videos = []
combined_frames = []
for name, frame_count in [('01_carro.mp4', 192), ('02_mota.mp4', 192), ('03_bicicleta.mp4', 192), ('00_quatro_veiculos.mp4', 768)]:
    path = OUT / name
    info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_entries', 'stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_read_frames:format=duration', '-of', 'json', str(path)]))
    stream = info['streams'][0]
    assert (stream['codec_name'], stream['width'], stream['height'], stream['pix_fmt'], stream['r_frame_rate'], int(stream['nb_read_frames'])) == ('h264', 1280, 720, 'yuv420p', '24/1', frame_count)
    assert abs(float(info['format']['duration']) - frame_count / 24) < .01
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'framemd5', '-']).decode().splitlines()
    unique = len({row.split(',')[-1].strip() for row in raw if row and not row.startswith('#')})
    if name == '00_quatro_veiculos.mp4':
        combined_frames = [row.split(',')[-1].strip() for row in raw if row and not row.startswith('#')]
    assert unique > 100
    videos.append({'file': name, 'frames': frame_count, 'duration_seconds': frame_count / 24, 'unique_frames': unique, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), **stream})
    print('VIDEO OK', name)

native = json.loads((OUT / 'validacao_godot.json').read_text())
assert native['failures'] == 0 and native['checks'] >= 2400
sources = json.loads((OUT / 'fontes_validadas.json').read_text())
assert len(sources) == 3 and all(record['bones_unchanged'] == 21 for record in sources)
subprocess.run(['git', 'diff', '--exit-code', '00bc8f9e46e2200cb105befbc97ffbe9a45d47cf', '--', 'arquivo/personagens/emmet/revisao_02', 'arquivo/personagens/emmet/revisao_03', 'arquivo/personagens/emmet/revisao_04', 'assets', 'scripts', 'scenes', 'project.godot'], cwd=ROOT, check=True)
scooter = BASE / 'emmet/revisao_04/05_subir_trotinete.mp4'
scooter_reference = next(item for item in json.loads((BASE / 'emmet/revisao_04/validacao.json').read_text())['videos'] if item['file'].endswith('05_subir_trotinete.mp4'))
assert hashlib.sha256(scooter.read_bytes()).hexdigest() == scooter_reference['sha256']
approved_frames = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(scooter), '-f', 'framemd5', '-']).decode().splitlines()
approved_frames = [row.split(',')[-1].strip() for row in approved_frames if row and not row.startswith('#')]
assert combined_frames[-192:] == approved_frames
(OUT / 'validacao.json').write_text(json.dumps({'new_animations': records, 'videos': videos, 'native_godot': native, 'source_checks': sources, 'approved_scooter_unchanged': True, 'approved_scooter_sha256': scooter_reference['sha256'], 'previous_reviews_preserved': True, 'game_integration': False, 'status': 'novas_animacoes_aguardam_feedback'}, indent=2, ensure_ascii=False) + '\n')
print('REVIEW05 VALIDATED: planted car opening, revised two-wheel mounts and unchanged approved scooter')
