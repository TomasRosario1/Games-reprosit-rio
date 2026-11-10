"""Review04: mount the actual bicycle and scooter using the approved Emmet rig.

blender -t 4 -b --python arquivo/personagens/ferramentas/animar_veiculos_leves.py -- --preview
blender -t 4 -b --python arquivo/personagens/ferramentas/animar_veiculos_leves.py -- --render
Sources, contacts, cameras and GLBs are generated before rendering any video.
"""
import bpy
import json
import math
import struct
import subprocess
import sys
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_04'
TEMP = Path('/tmp/emmet-review-04')
OUT.mkdir(parents=True, exist_ok=True)
TEMP.mkdir(parents=True, exist_ok=True)
FPS, FRAMES = 24, 192
V = Vector

# Review03 already contains the approved review02 bone placement and the local
# trouser-seat weighting refinement. No previous archive files are overwritten.
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'emmet/revisao_03/03_montar_mota.blend'))
rig = bpy.data.objects['Emmet_Rig_Animacoes03']
model = bpy.data.objects['Emmet_Skin']
rig.name = 'Emmet_Rig_Animacoes04'
for obj in list(bpy.context.scene.objects):
    if obj not in (rig, model):
        bpy.data.objects.remove(obj, do_unlink=True)
rig.animation_data_clear()
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action, do_unlink=True)
REST = {b.name: b.matrix_local.copy() for b in rig.data.bones}
LENGTH = {b.name: b.length for b in rig.data.bones}
ORDER = [b.name for b in rig.data.bones]
assert len(ORDER) == 21


def smooth(value):
    value = max(0, min(1, value))
    return value * value * (3 - 2 * value)


def phase(t, start, end):
    return smooth((t - start) / (end - start))


def lerp(a, b, value):
    return V(a).lerp(V(b), smooth(value))


def path(t, keys):
    for (a, p), (b, q) in zip(keys, keys[1:]):
        if t <= b:
            return lerp(p, q, (t - a) / (b - a))
    return V(keys[-1][1])


def import_vehicle(kind):
    # Blender4.3 cannot load the Godot visibility extension. Keep the original
    # bytes and make a compatibility copy that respects hidden mesh subtrees.
    source = OUT / 'veiculos' / (kind + '_original.glb')
    data = source.read_bytes()
    chunks, offset = [], 12
    while offset < len(data):
        size, code = struct.unpack_from('<II', data, offset)
        offset += 8
        chunks.append((code, data[offset:offset + size]))
        offset += size
    document = json.loads(chunks[0][1])
    hidden = set()

    def hide(index):
        hidden.add(index)
        for child in document['nodes'][index].get('children', []):
            hide(child)

    for index, node in enumerate(document['nodes']):
        if node.get('extensions', {}).get('KHR_node_visibility', {}).get('visible') is False:
            hide(index)
    for index, node in enumerate(document['nodes']):
        node.get('extensions', {}).pop('KHR_node_visibility', None)
        if index in hidden:
            node.pop('mesh', None)
    for key in ('extensionsUsed', 'extensionsRequired'):
        if key in document:
            document[key] = [v for v in document[key] if v != 'KHR_node_visibility']
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    chunks[0] = (0x4e4f534a, encoded)
    payload = b''.join(struct.pack('<II', len(value), code) + value for code, value in chunks)
    compatible = source.with_name(kind + '_blender.glb')
    compatible.write_bytes(struct.pack('<4sII', b'glTF', 2, len(payload) + 12) + payload)
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(compatible))
    added = set(bpy.context.scene.objects) - before
    turn = Matrix.Rotation(math.pi, 4, 'Z')
    meshes = []
    for obj in added:
        if obj.type == 'MESH':
            obj.data.transform(turn @ obj.matrix_world)
            obj.parent = None
            obj.matrix_world = Matrix.Identity(4)
            obj['review_vehicle'] = kind
            meshes.append(obj)
    for obj in added:
        if obj.type != 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    return meshes


vehicles = {kind: import_vehicle(kind) for kind in ('bicycle', 'scooter')}


def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    return result


def box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def pipe(name, start, end, radius, mat):
    start, end = V(start), V(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=(end - start).length, location=(start + end) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (end - start).to_track_quat('Z', 'Y').to_euler()
    obj.data.materials.append(mat)
    return obj


metal = material('Descansos_mate', (.12, .13, .14))
vehicles['bicycle'].append(pipe('Descanso_bicicleta', (.14, .14, .40), (.39, .27, .025), .014, metal))
vehicles['scooter'].append(pipe('Descanso_trotinete', (.12, .36, .14), (.26, .41, .018), .012, metal))
floor_mat = material('Chao_mate', (.105, .12, .135))
marker_mat = material('Marcas_solo', (.23, .26, .29))
box('Chao_revisao', (0, 0, -.035), (20, 20, .06), floor_mat)
for y in range(-8, 9):
    box('Marca_metro', (0, y, -.002), (6, .013, .005), marker_mat)

shoe = {}
for side, sign in [('L', 1), ('R', -1)]:
    ankle = REST['foot.' + side].translation
    shoe[side] = [v.co - ankle for v in model.data.vertices if v.co.z < .15 and sign * v.co.x > 0]


def floor_ankle(side, pitch=0, level=0):
    rotation = Quaternion(V((1, 0, 0)), pitch)
    return level - min((rotation @ vertex).z for vertex in shoe[side]) + .003


POSE, targets, metrics = {}, {}, {}
current, frame_time = '', 0


def reset_body(position, lean=0):
    global POSE, targets
    rig.location = position
    rig.rotation_mode = 'XYZ'
    rig.rotation_euler = (0, 0, 0)
    POSE, targets = {}, {}
    for name in ORDER:
        parent = rig.data.bones[name].parent
        POSE[name] = POSE[parent.name] @ REST[parent.name].inverted() @ REST[name] if parent else REST[name].copy()
        amount = .30 if name == 'pelvis' else .42 if name == 'spine' else .28 if name == 'chest' else 0
        if amount:
            head = POSE[name].translation.copy()
            rotation = Quaternion(V((1, 0, 0)), lean * amount).to_matrix().to_4x4()
            POSE[name] = Matrix.Translation(head) @ rotation @ Matrix.Translation(-head) @ POSE[name]
    bpy.context.view_layer.update()


def align(name, head, tail):
    old = REST[name].to_3x3().col[1].normalized()
    matrix = old.rotation_difference((tail - head).normalized()).to_matrix().to_4x4() @ REST[name]
    matrix.translation = head
    POSE[name] = matrix


def solve_pair(first, second, target, pole):
    start = POSE[first].translation.copy()
    offset = target - start
    reach = offset.length
    l1, l2 = LENGTH[first], LENGTH[second]
    distance = max(.01, min(reach, l1 + l2 - .001))
    direction = offset.normalized()
    target = start + direction * distance
    along = (l1 * l1 - l2 * l2 + distance * distance) / (2 * distance)
    bend = V(pole) - direction * V(pole).dot(direction)
    if bend.length < 1e-5:
        bend = direction.cross(V((1, 0, 0)))
    middle = start + direction * along + bend.normalized() * math.sqrt(max(0, l1 * l1 - along * along))
    align(first, start, middle)
    align(second, middle, target)
    return target


def leg(side, world, pitch=0, pole=(0, -1, 0)):
    name = 'foot.' + side
    target = solve_pair('thigh.' + side, 'shin.' + side, rig.matrix_world.inverted() @ V(world), pole)
    matrix = Quaternion(V((1, 0, 0)), pitch).to_matrix().to_4x4() @ REST[name]
    matrix.translation = target
    POSE[name] = matrix
    POSE['toe.' + side] = matrix @ REST[name].inverted() @ REST['toe.' + side]
    targets[name] = V(world)


def hand(side, palm, weight):
    sign = 1 if side == 'L' else -1
    relaxed = POSE['upper_arm.' + side].translation + V((sign * .08, sign * .075 * math.cos(frame_time * 7), -.40))
    local = rig.matrix_world.inverted() @ V(palm)
    local = (relaxed + V((0, -.003, -.065))).lerp(local, weight)
    direction = (local - POSE['upper_arm.' + side].translation).normalized()
    wrist = solve_pair('upper_arm.' + side, 'forearm.' + side, local - direction * .065, (sign * .3, 1, 0))
    name = 'hand.' + side
    align(name, wrist, wrist + direction * LENGTH[name])
    targets[name] = rig.matrix_world @ local


def finish():
    for name in ORDER:
        parent = rig.data.bones[name].parent
        base = POSE[parent.name] @ REST[parent.name].inverted() @ REST[name] if parent else REST[name]
        rig.pose.bones[name].matrix_basis = base.inverted() @ POSE[name]
    bpy.context.view_layer.update()
    for name in ORDER:
        assert max(abs(a - b) for row, reference in zip(rig.pose.bones[name].matrix, POSE[name]) for a, b in zip(row, reference)) < .0002
    contacts = {}
    for name, target in targets.items():
        matrix = rig.pose.bones[name].matrix
        local = matrix.translation + (matrix.to_3x3().col[1] * .065 if name.startswith('hand.') else V((0, 0, 0)))
        actual = rig.matrix_world @ local
        contacts[name] = {'target': list(target), 'actual': list(actual), 'error': (target - actual).length}
    record = {'time': frame_time, 'root': list(rig.location), 'targets': contacts}
    evaluated = model.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    if frame_time >= 7:
        butt = [rig.matrix_world @ mesh.vertices[v.index].co for v in model.data.vertices if .79 < v.co.z < .90 and abs(v.co.x) < .06 and .11 < v.co.y < .15]
        record['butt_low'] = min(v.z for v in butt)
    for side, sign in [('L', 1), ('R', -1)]:
        sole = [rig.matrix_world @ mesh.vertices[v.index].co for v in model.data.vertices if v.co.z < .15 and sign * v.co.x > 0]
        record['sole_min_' + side] = min(v.z for v in sole)
    evaluated.to_mesh_clear()
    metrics.setdefault(current, []).append(record)


def approach(t, kind):
    return lerp((.78, 1.05, -.064), (.45, .25 if kind == 'bicycle' else .26, -.064), min(t, 1.3) / 1.3)


def approach_feet(t, kind):
    step = .28
    result = {}
    for side, sign, offset in [('L', 1, 0), ('R', -1, step)]:
        def landing(time):
            p = approach(min(1.3, time + step * .5), kind) + V((sign * .13, .05, 0))
            p.z = floor_ankle(side)
            return p
        if t < offset:
            result[side] = landing(0)
            continue
        cycle = math.floor((t - offset) / (step * 2))
        start = offset + cycle * step * 2
        before, after = landing(0 if cycle == 0 else start - step), landing(start + step)
        if t < start + step and (before - after).length > .01:
            u = (t - start) / step
            result[side] = lerp(before, after, u)
            result[side].z += .075 * math.sin(math.pi * u)
        else:
            result[side] = after
    return result


def bicycle_pose(t):
    position = approach(t, 'bicycle') if t < 1.3 else path(t, [(1.3, (.45, .25, -.064)), (2, (.45, .25, -.07)), (3.6, (.15, .30, .04)), (4.8, (0, .23, .18)), (8, (0, .23, .18))])
    lean = math.radians(2 + 40 * phase(t, .95, 1.8) + 5 * phase(t, 3.6, 4.8))
    reset_body(position, lean)
    start = approach_feet(1.8, 'bicycle')
    if t < 1.8:
        for side, at in approach_feet(t, 'bicycle').items():
            leg(side, at)
    else:
        left = path(t, [(1.8, start['L']), (2.0, (.58, .12, floor_ankle('L'))), (2.7, (.58, .12, floor_ankle('L'))), (3.15, (.40, .17, .56)), (3.6, (.22, .18, floor_ankle('L', level=.2775))), (8, (.22, .18, floor_ankle('L', level=.2775)))])
        right = path(t, [(1.8, start['R']), (2.0, start['R']), (2.75, (.32, .71, 1.24)), (3.15, (-.20, .73, 1.24)), (3.65, (-.38, .40, .84)), (4.2, (-.22, .18, floor_ankle('R', level=.5575)))])
        if 1.8 < t < 2:
            left.z += .035 * math.sin(math.pi * phase(t, 1.8, 2))
        leg('L', left, pole=(1, -.2, 0))
        leg('R', right, pole=(-1, .3, .2) if 2 < t < 3.8 else (0, -1, 0))
    hand('L', (.29, -.33, 1.16), phase(t, 1.0, 1.8))
    hand('R', (-.29, -.33, 1.16), phase(t, 3.5, 4.6))
    finish()


def scooter_pose(t):
    position = approach(t, 'scooter') if t < 1.3 else path(t, [(1.3, (.45, .26, -.064)), (2.0, (.33, .10, -.064)), (2.4, (.20, .16, -.064)), (2.55, (.20, .16, -.064)), (3.3, (.05, .16, .07)), (4.2, (0, .16, .10)), (8, (0, .16, .10))])
    lean = math.radians(2 + 24 * phase(t, .95, 1.9) - 6 * phase(t, 3.2, 4.4))
    reset_body(position, lean)
    start = approach_feet(1.8, 'scooter')
    if t < 1.8:
        for side, at in approach_feet(t, 'scooter').items():
            leg(side, at)
    else:
        right = path(t, [(1.8, start['R']), (2.1, (.22, -.04, .40)), (2.4, (-.055, -.08, floor_ankle('R', level=.17))), (8, (-.055, -.08, floor_ankle('R', level=.17)))])
        left = path(t, [(1.8, start['L']), (2.0, (.49, .30, floor_ankle('L'))), (2.55, (.49, .30, floor_ankle('L'))), (3.15, (.30, .26, .46)), (3.7, (.055, .22, floor_ankle('L', level=.17))), (8, (.055, .22, floor_ankle('L', level=.17)))])
        leg('R', right)
        leg('L', left)
    hand('L', (.28, -.42, 1.33), phase(t, 1.1, 2.1))
    hand('R', (-.28, -.42, 1.33), phase(t, 2.3, 3.2))
    finish()


CLIPS = [('04_montar_bicicleta', 'bicycle', bicycle_pose), ('05_subir_trotinete', 'scooter', scooter_pose)]
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.render_aa = '8'
shading = scene.display.shading
shading.light = 'STUDIO'
shading.color_type = 'TEXTURE'
shading.show_shadows = False
shading.show_cavity = True
shading.background_type = 'WORLD'
shading.show_specular_highlight = False
scene.world = bpy.data.worlds.new('Fundo_revisao04')
scene.world.color = (.045, .052, .065)
scene.view_settings.view_transform = 'Standard'
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = 100
scene.render.fps, scene.frame_start, scene.frame_end = FPS, 1, FRAMES
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.name = 'Camara_revisao04'
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.9
scene.camera = camera


def camera_pose(t):
    target = V((.15, .20, 1.02))
    offset = V((3.9, 5.7, 1.7)) if t < 4.5 else V((3.9, -5.7, 1.7))
    camera.location = target + offset
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()


for current, kind, callback in CLIPS:
    rig.animation_data_clear()
    camera.animation_data_clear()
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    rig.animation_data_create()
    action = bpy.data.actions.new(current)
    rig.animation_data.action = action
    for vehicle_kind, objects in vehicles.items():
        for obj in objects:
            obj.hide_render = vehicle_kind != kind
            obj.hide_set(obj.hide_render)
    for frame in range(FRAMES):
        frame_time = frame / FPS
        callback(frame_time)
        rig.keyframe_insert('location', frame=frame + 1)
        rig.keyframe_insert('rotation_euler', frame=frame + 1)
        for name in ORDER:
            bone = rig.pose.bones[name]
            bone.keyframe_insert('location', frame=frame + 1, group=name)
            bone.keyframe_insert('rotation_quaternion', frame=frame + 1, group=name)
        camera_pose(frame_time)
        camera.keyframe_insert('location', frame=frame + 1)
        camera.keyframe_insert('rotation_euler', frame=frame + 1)
    max_error = max(c['error'] for f in metrics[current] for c in f['targets'].values())
    assert max_error < .015, (current, max_error, 'unreachable limb contact')
    action.use_fake_user = True
    scene.frame_set(1)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.region_3d.view_perspective = 'CAMERA'
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    if '--probe' not in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (current + '.blend')), compress=True)
    print('BAKED', current, 'max_contact_error', max_error, flush=True)

(OUT / 'contactos.json').write_text(json.dumps(metrics, indent=2) + '\n')
if '--probe' not in sys.argv:
    for current, _, _ in CLIPS:
        subprocess.run([bpy.app.binary_path, '-t', '1', '-b', '--python', str(BASE / 'ferramentas/exportar_revisao04.py'), '--', '--clip=' + current], check=True)
if '--render' in sys.argv or '--preview' in sys.argv:
    for current, _, _ in CLIPS:
        bpy.ops.wm.open_mainfile(filepath=str(OUT / (current + '.blend')))
        scene = bpy.context.scene
        directory = TEMP / 'frames' / current
        directory.mkdir(parents=True, exist_ok=True)
        samples = [0, 36, 60, 72, 84, 96, 108, 132, 168, 191] if '--preview' in sys.argv else range(FRAMES)
        for frame in samples:
            scene.frame_set(frame + 1)
            scene.render.filepath = str(directory / ('%04d.png' % frame))
            bpy.ops.render.render(write_still=True)
        print('RENDERED', current, flush=True)
print('REVIEW04 SOURCES READY', flush=True)
