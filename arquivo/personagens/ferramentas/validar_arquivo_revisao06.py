"""Validate exported anatomy, grip timing, vehicle clearance and decoded videos."""
import hashlib
import json
import math
import runpy
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
ROOT = BASE.parents[1]
OUT = BASE / 'emmet/revisao_06'
helpers = runpy.run_path(str(BASE / 'ferramentas/validar_arquivo.py'))
glb, accessor = helpers['glb'], helpers['accessor']
reference, reference_binary = glb(BASE / 'emmet/revisao_02/emmet_articulacao_02.glb')
reference_primitive = reference['meshes'][0]['primitives'][0]
contacts = json.loads((OUT / 'contactos.json').read_text())
records = []


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


for clip in ('01_mota', '02_bicicleta'):
    document, binary = glb(OUT / (clip + '.glb'))
    assert len(document['skins']) == 1 and len(document['skins'][0]['joints']) == 21
    assert len(document['animations']) == 1 and document['animations'][0]['name'] == clip
    assert not any('uri' in item and not item['uri'].startswith('data:') for key in ('buffers', 'images') for item in document.get(key, []))
    actor = next(p for mesh in document['meshes'] for p in mesh['primitives'] if 'JOINTS_0' in p['attributes'])
    root = next(n for n in document['nodes'] if n.get('name') == 'Emmet_Rig_Animacoes06')
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
    assert len(actor['targets']) >= 3
    assert any(channel['target']['path'] == 'weights' for channel in document['animations'][0]['channels'])
    frames = contacts[clip]
    assert len(frames) == 192
    max_error = max(contact['error'] for frame in frames for contact in frame['targets'].values())
    left_error = max(frame['targets']['hand.L']['error'] for frame in frames if frame['time'] >= 1)
    assert max_error < .015 and left_error < .005
    assert all(not frame['intersections'] for frame in frames), (clip, 'leg surface intersects vehicle')
    assert all(frame['tilt_radians'] == 0 for frame in frames if frame['time'] <= 1.15)
    assert all(frame['left_grip'] == 1 for frame in frames if frame['time'] >= 1.083)
    assert max(frame['tilt_radians'] for frame in frames) > math.radians(11.9)
    assert frames[-1]['tilt_radians'] == 0
    crossing = [frame for frame in frames if 2.5 <= frame['time'] <= 5]
    assert max(frame['knee_back_m'] for frame in crossing) < .05
    assert min(frame['forward_knee_bend_m'] for frame in crossing) > 0
    assert max(frame['ankle_back_m'] for frame in crossing) < .3
    knee_report = json.loads((OUT / (clip + '_joelho.json')).read_text())
    assert knee_report['analytical_skin_error_m'] < .0001
    assert min(knee_report['anatomical_clearance_m_at_controls']) >= 0
    records.append({'clip': clip, 'frames': 192, 'max_contact_error_m': max_error, 'max_left_grip_error_m': left_error, 'left_grasp_before_tilt': True, 'approved_rest_model_preserved': True, 'geometry_scope': 'both_leg_surfaces_against_all_visible_vehicle_meshes_except_stand', 'intersection_frames': 0, 'knee_bend_forward': True, 'minimum_anatomical_clearance_at_controls_m': min(knee_report['anatomical_clearance_m_at_controls'])})
    print('ANIMATION OK', clip, 'left-hand-first sequence and vehicle clearance')


def decoded(path):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'framemd5', '-']).decode().splitlines()
    return [row.split(',')[-1].strip() for row in raw if row and not row.startswith('#')]


videos, combined = [], []
for name, count in [('01_mota.mp4', 192), ('02_bicicleta.mp4', 192), ('00_quatro_veiculos.mp4', 768)]:
    path = OUT / name
    info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_entries', 'stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_read_frames:format=duration', '-of', 'json', str(path)]))
    stream = info['streams'][0]
    assert (stream['codec_name'], stream['width'], stream['height'], stream['pix_fmt'], stream['r_frame_rate'], int(stream['nb_read_frames'])) == ('h264', 1280, 720, 'yuv420p', '24/1', count)
    assert abs(float(info['format']['duration']) - count / 24) < .01
    frames = decoded(path)
    unique = len(set(frames))
    assert len(frames) == count and unique > 100
    if name.startswith('00_'):
        combined = frames
    videos.append({'file': name, 'frames': count, 'duration_seconds': count / 24, 'unique_frames': unique, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), **stream})
    print('VIDEO OK', name)

native = json.loads((OUT / 'validacao_godot.json').read_text())
assert native['failures'] == 0 and native['checks'] >= 3000
sources = json.loads((OUT / 'fontes_validadas.json').read_text())
assert len(sources) == 2 and all(record['bones_unchanged'] == 21 for record in sources)
subprocess.run(['git', 'diff', '--exit-code', '31b37fb2a11bffe09158af0c49ea66af2ff147a5', '--', 'arquivo/personagens/emmet/original', 'arquivo/personagens/emmet/revisao_02', 'arquivo/personagens/emmet/revisao_03', 'arquivo/personagens/emmet/revisao_04', 'arquivo/personagens/emmet/revisao_05', 'assets', 'scripts', 'scenes', 'project.godot'], cwd=ROOT, check=True)
car = BASE / 'emmet/revisao_05/01_carro.mp4'
scooter = BASE / 'emmet/revisao_04/05_subir_trotinete.mp4'
assert combined[:192] == decoded(car)
assert combined[-192:] == decoded(scooter)
(OUT / 'validacao.json').write_text(json.dumps({'new_animations': records, 'videos': videos, 'native_godot': native, 'source_checks': sources, 'car_and_scooter_preserved_including_decoded_frames': True, 'previous_reviews_preserved': True, 'game_integration': False, 'status': 'aguarda_feedback_visual'}, indent=2, ensure_ascii=False) + '\n')
print('REVIEW06 VALIDATED; artistic feedback remains separate from these checks')
