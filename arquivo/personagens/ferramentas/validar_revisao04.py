"""Validate all four vehicle clips, native import evidence and decoded real videos."""
import hashlib
import json
import math
import re
import runpy
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_04'
ROOT = BASE.parents[1]
helpers = runpy.run_path(str(BASE / 'ferramentas/validar_arquivo.py'))
glb, accessor = helpers['glb'], helpers['accessor']
manifest = json.loads((OUT / 'veiculos.json').read_text())
source = (ROOT / 'scripts/vehicle.gd').read_text()
configured = set(re.findall(r'"([a-z]+)"', re.search(r'if type not in \[([^]]+)\]', source).group(1)))
assert {v['type'] for v in manifest['vehicles']} == configured == {'car', 'motorbike', 'bicycle', 'scooter'}
ref, ref_binary = glb(BASE / 'emmet/revisao_02/emmet_articulacao_02.glb')
ref_primitive = ref['meshes'][0]['primitives'][0]
records = []


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


for vehicle in manifest['vehicles']:
    clip_path = (OUT / vehicle['glb']).resolve()
    g, binary = glb(clip_path)
    assert len(g['skins']) == 1 and len(g['skins'][0]['joints']) == 21
    assert len(g['animations']) == 1 and g['animations'][0]['name'] == vehicle['clip']
    for sampler in g['animations'][0]['samplers']:
        times = accessor(g, binary, sampler['input'])
        assert abs(times[0][0]) < .0001 and abs(times[-1][0] - 191 / 24) < .01
    assert not any('uri' in value and not value['uri'].startswith('data:') for key in ('buffers', 'images') for value in g.get(key, []))
    actor = next(p for m in g['meshes'] for p in m['primitives'] if 'JOINTS_0' in p['attributes'])
    root = next(n for n in g['nodes'] if n.get('name') in ('Emmet_Rig_Animacoes03', 'Emmet_Rig_Animacoes04'))
    origin, q, scale = root.get('translation', [0, 0, 0]), root.get('rotation', [0, 0, 0, 1]), root.get('scale', [1, 1, 1])

    def canonical(point):
        v = [point[i] - origin[i] for i in range(3)]
        xyz = [-q[i] for i in range(3)]
        t = [2 * x for x in cross(xyz, v)]
        u = cross(xyz, t)
        return [(v[i] + q[3] * t[i] + u[i]) / scale[i] for i in range(3)]

    actual = {}
    for pos, uv in zip(accessor(g, binary, actor['attributes']['POSITION']), accessor(g, binary, actor['attributes']['TEXCOORD_0'])):
        actual.setdefault(uv, []).append(canonical(pos))
    for pos, uv in zip(accessor(ref, ref_binary, ref_primitive['attributes']['POSITION']), accessor(ref, ref_binary, ref_primitive['attributes']['TEXCOORD_0'])):
        points = actual[uv]
        nearest = min(range(len(points)), key=lambda i: math.dist(pos, points[i]))
        assert math.dist(pos, points.pop(nearest)) < .00001
    assert all(not points for points in actual.values())
    weights = accessor(g, binary, actor['attributes']['WEIGHTS_0'])
    assert all(abs(sum(row) - 1) < .0001 and min(row) >= 0 for row in weights)
    assert all(0 <= j < 21 for row in accessor(g, binary, actor['attributes']['JOINTS_0']) for j in row)
    records.append({'type': vehicle['type'], 'clip': vehicle['clip'], 'bones': 21, 'rest_geometry_and_uv_preserved': True, 'glb_sha256': hashlib.sha256(clip_path.read_bytes()).hexdigest()})
    print('GLB OK', vehicle['type'], vehicle['clip'])

contacts = json.loads((OUT / 'contactos.json').read_text())
for clip, frames in contacts.items():
    assert len(frames) == 192
    max_error = max(c['error'] for frame in frames for c in frame['targets'].values())
    assert max_error < .015, (clip, max_error)
    assert max(math.dist(a['root'], b['root']) for a, b in zip(frames, frames[1:])) < .10
    assert min(min(f['sole_min_L'], f['sole_min_R']) for f in frames) > -.015
    if clip == '04_montar_bicicleta':
        assert abs(frames[-1]['butt_low'] - 1.035) < .02
        crossing = [f['targets']['foot.R']['actual'][2] for f in frames if 2.75 <= f['time'] <= 3.15]
        assert min(crossing) - .12 > 1.035 + .04
        for side, height in [('L', .2775), ('R', .5575)]:
            assert abs(frames[-1]['sole_min_' + side] - height) < .01
    else:
        for side in ('L', 'R'):
            assert abs(frames[-1]['sole_min_' + side] - .17) < .01
        # The first foot must be planted before the other one leaves the floor.
        f = frames[60]
        assert abs(f['sole_min_R'] - .17) < .01 and f['sole_min_L'] < .01
    print('CONTACTS OK', clip, 'max error', round(max_error, 6))

videos = []
video_paths = [((OUT / v['video']).resolve(), 192) for v in manifest['vehicles']] + [(OUT / '00_todos_os_veiculos.mp4', 768)]
for video, expected_count in video_paths:
    info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames', '-show_entries', 'stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_read_frames:format=duration', '-of', 'json', str(video)]))
    stream = info['streams'][0]
    assert (stream['codec_name'], stream['width'], stream['height'], stream['pix_fmt'], stream['r_frame_rate'], int(stream['nb_read_frames'])) == ('h264', 1280, 720, 'yuv420p', '24/1', expected_count)
    assert abs(float(info['format']['duration']) - expected_count / 24) < .01
    checksums = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(video), '-f', 'framemd5', '-']).decode().splitlines()
    unique = len({row.split(',')[-1].strip() for row in checksums if row and not row.startswith('#')})
    assert unique > 100
    videos.append({'file': str(video.relative_to(BASE)), 'frames': expected_count, 'duration_seconds': expected_count / 24, 'unique_decoded_frames': unique, 'sha256': hashlib.sha256(video.read_bytes()).hexdigest(), **stream})
    print('VIDEO OK', video.name, expected_count, 'frames')

sources = json.loads((OUT / 'fontes_validadas.json').read_text())
assert len(sources) == 2 and all(v['bones_unchanged'] == 21 and v['uvs_unchanged'] for v in sources)
native = json.loads((OUT / 'validacao_godot.json').read_text())
assert native['failures'] == 0 and native['checks'] >= 1540 and native['max_contact_error_m'] < .015
subprocess.run(['git', 'diff', '--exit-code', 'c7d85815ada35a4b28e678fea6786be33ba32fb5', '--', 'arquivo/personagens/emmet/revisao_02', 'arquivo/personagens/emmet/revisao_03', 'assets', 'scripts', 'scenes', 'project.godot'], cwd=ROOT, check=True)
(OUT / 'validacao.json').write_text(json.dumps({'vehicles': records, 'videos': videos, 'native_godot': native, 'new_sources': sources, 'previous_reviews_preserved': True, 'game_integration': False, 'status': 'aguarda_feedback_das_animacoes'}, indent=2, ensure_ascii=False) + '\n')
print('REVIEW04 VALIDATED: all four current vehicle types covered; game and previous reviews preserved')
