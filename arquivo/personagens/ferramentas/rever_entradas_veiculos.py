"""Review05: planted car-door opening and clearance-aware two-wheel mounts.

Only archive data are changed. Sources from reviews03/04 stay untouched.
Use --probe, --preview or --render; --only=car|motorbike|bicycle limits the job.
"""
import bpy
import json
import math
import subprocess
import sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

BASE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE / 'ferramentas'))
from emmet_cinematica import PoseRig, V, phase, lerp, path
from emmet_roupa_sentada import make_corrective

OUT = BASE / 'emmet/revisao_05'
TEMP = Path('/tmp/emmet-review-05')
OUT.mkdir(parents=True, exist_ok=True)
TEMP.mkdir(parents=True, exist_ok=True)
FPS, FRAMES = 24, 192
CLIPS = [
    ('01_carro', 'car', 'revisao_03/02_entrar_carro.blend'),
    ('02_mota', 'motorbike', 'revisao_03/03_montar_mota.blend'),
    ('03_bicicleta', 'bicycle', 'revisao_04/04_montar_bicicleta.blend'),
]
only = next((v.split('=', 1)[1] for v in sys.argv if v.startswith('--only=')), None)
if only:
    CLIPS = [entry for entry in CLIPS if entry[1] == only]
contacts, clearances, source_checks, cloth_reports = {}, {}, [], {}
if only:
    for filename, target in [('contactos.json', contacts), ('geometria.json', clearances), ('roupa.json', cloth_reports)]:
        stored = OUT / filename
        if stored.exists():
            target.update(json.loads(stored.read_text()))
    stored = OUT / 'fontes.json'
    if stored.exists():
        selected = {clip for clip, _, _ in CLIPS}
        source_checks = [entry for entry in json.loads(stored.read_text()) if entry['clip'] not in selected]


def world_bounds(obj):
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return V(tuple(min(p[i] for p in points) for i in range(3))), V(tuple(max(p[i] for p in points) for i in range(3)))


def prepare(clip, kind, source):
    bpy.ops.wm.open_mainfile(filepath=str(BASE / 'emmet' / source))
    scene = bpy.context.scene
    scene.frame_set(1)
    rig = next(o for o in scene.objects if o.type == 'ARMATURE')
    model = bpy.data.objects['Emmet_Skin']
    vehicle = [o for o in scene.objects if o.type == 'MESH' and o != model and not o.hide_render and not o.name.startswith(('Chao_', 'Marca_'))]
    # Keep only this source's visible review vehicle, scenery and body.
    keep = {rig, model, *vehicle}
    keep.update(o for o in scene.objects if o.name.startswith(('Chao_', 'Marca_')))
    if kind == 'car':
        keep.add(bpy.data.objects['Porta_condutor'])
    for obj in list(scene.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    rig.name = 'Emmet_Rig_Animacoes05'
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action, do_unlink=True)
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    kinematics = PoseRig(rig, model)
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.render_aa = '8'
    shading = scene.display.shading
    shading.light, shading.color_type = 'STUDIO', 'TEXTURE'
    shading.show_shadows, shading.show_cavity = False, True
    shading.show_specular_highlight = False
    shading.background_type = 'WORLD'
    scene.world.color = (.045, .052, .065)
    scene.view_settings.view_transform = 'Standard'
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.resolution_percentage = 100
    scene.render.fps, scene.frame_start, scene.frame_end = FPS, 1, FRAMES
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = 'Camara_revisao05'
    camera.data.type = 'ORTHO'
    scene.camera = camera
    pivot = None
    if kind != 'car':
        # Real saddles narrow towards the nose. The source rectangular blocks
        # occupied the inner-thigh space even in an otherwise correct pose.
        seat_suffix = '67' if kind == 'motorbike' else '33'
        for obj in vehicle:
            if obj.name.rsplit('_', 1)[-1] == seat_suffix:
                lo, hi = world_bounds(obj)
                narrow = .075 / .195 if kind == 'motorbike' else .035 / .125
                for vertex in obj.data.vertices:
                    amount = max(0, min(1, (vertex.co.y - lo.y) / (hi.y - lo.y)))
                    vertex.co.x *= narrow + (1 - narrow) * amount
        if kind == 'bicycle':
            # Rotate the crank half a turn: the near pedal starts high and can
            # support the mounting step. This changes a mechanical pose only.
            crank = Matrix.Translation(V((0, .12, .40))) @ Matrix.Rotation(math.pi, 4, 'X') @ Matrix.Translation(V((0, -.12, -.40)))
            for obj in vehicle:
                if obj.name.rsplit('_', 1)[-1] in {'35', '36', '37', '38'}:
                    obj.data.transform(obj.matrix_world.inverted() @ crank @ obj.matrix_world)
        pivot = bpy.data.objects.new('Inclinacao_veiculo', None)
        bpy.context.collection.objects.link(pivot)
        for obj in vehicle:
            world = obj.matrix_world.copy()
            obj.parent = pivot
            obj.matrix_world = world
    return scene, rig, model, kinematics, vehicle, pivot, camera


def core_geometry(kind, vehicle):
    core = []
    for obj in vehicle:
        lo, hi = world_bounds(obj)
        size = hi - lo
        if obj.name.startswith('Descanso'):
            continue
        if kind == 'motorbike':
            if obj.name.rsplit('_', 1)[-1] in {'56', '60', '62', '63', '66', '67', '68', '71', '73'}:
                core.append(obj)
        elif kind == 'bicycle':
            if obj.name.rsplit('_', 1)[-1] in {'5', '16', '25', '26', '27', '28', '29', '30', '33'}:
                core.append(obj)
    return core


def leg_triangles(model):
    model.data.calc_loop_triangles()
    groups = {g.index: g.name for g in model.vertex_groups}
    indices = set()
    for vertex in model.data.vertices:
        weight = sum(g.weight for g in vertex.groups if groups[g.group].startswith(('thigh.', 'shin.', 'foot.', 'toe.')))
        if weight > .5:
            indices.add(vertex.index)
    return [tuple(tri.vertices) for tri in model.data.loop_triangles if all(v in indices for v in tri.vertices)]


def body_without_arms(model):
    model.data.calc_loop_triangles()
    names = {group.index: group.name for group in model.vertex_groups}
    body = {vertex.index for vertex in model.data.vertices if sum(group.weight for group in vertex.groups if names[group.group].startswith(('upper_arm.', 'forearm.', 'hand.'))) < .3}
    return [tuple(triangle.vertices) for triangle in model.data.loop_triangles if all(index in body for index in triangle.vertices)]


def intersection_report(model, triangles, core):
    evaluated = model.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    vertices = [model.matrix_world @ v.co for v in mesh.vertices]
    tree = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
    collisions = {}
    for obj in core:
        obj.data.calc_loop_triangles()
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        surface = BVHTree.FromPolygons(points, [tuple(t.vertices) for t in obj.data.loop_triangles], all_triangles=True)
        overlap = tree.overlap(surface)
        if overlap:
            collisions[obj.name] = len(overlap)
    evaluated.to_mesh_clear()
    return collisions


def set_vehicle_tilt(pivot, objects, t):
    angle = math.radians(10) * phase(t, .7, 1.7) * (1 - phase(t, 4.0, 5.6))
    pivot.rotation_euler = (0, angle, 0)
    rotation = Matrix.Rotation(angle, 4, 'Y')
    # Tyres stay on the floor; rolling about the frame origin would sink one side.
    lowest = min((rotation @ obj.matrix_local @ vertex.co).z for obj in objects if not obj.name.startswith('Descanso') for vertex in obj.data.vertices)
    pivot.location.z = .002 - lowest
    bpy.context.view_layer.update()
    return angle


def camera_pose(camera, kind, t):
    if kind == 'car':
        target, offset = V((.65, .25, .9)), V((4, 4.8, 2.3)) if t < 6.2 else V((4, -5.5, 2.3))
        camera.data.ortho_scale = 5.8
    else:
        # Rear three-quarter view reveals the entire crossing above the saddle.
        target = V((.20, .30, 1.0))
        offset = V((3.7, 5.5, 2.1)) if t < 5.3 else V((4.0, -5.7, 1.6))
        camera.data.ortho_scale = 4.4 if kind == 'motorbike' else 4.0
    camera.location = target + offset
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()


def car_pose(k, hinge, t):
    theta = -1.15 * phase(t, .7, 2.2) * (1 - phase(t, 5., 6.6))
    hinge.rotation_euler.z = theta
    bpy.context.view_layer.update()
    outer = hinge.matrix_world @ V((.045, .93, -.02))
    inner = hinge.matrix_world @ V((-.03, .44, -.03))
    # No approach loop and no walking around the opening door.
    if t < 2.7:
        # Stand behind the swept door, rather than inside its opening arc.
        position, yaw, lean = V((1.25, .94, -.064)), 0, math.radians(8)
    elif t < 3.6:
        position = lerp((1.25, .94, -.064), (1.12, .40, -.064), (t - 2.7) / .9)
        yaw, lean = 0, math.radians(8 + 12 * phase(t, 2.7, 3.6))
    elif t < 4.6:
        position = lerp((1.12, .40, -.064), (1.0, .35, -.08), t - 3.6)
        yaw, lean = 0, math.radians(20 + 40 * phase(t, 3.6, 4.6))
    else:
        position = lerp((1., .35, -.08), (.35, .14, -.18), (t - 4.6) / 1.35)
        yaw, lean = 0, math.radians(60 - 45 * phase(t, 4.9, 6.0))
    k.begin(position, yaw, lean)
    left_start = V((1.38, .98, k.floor_ankle('L')))
    right_start = V((1.18, .98, k.floor_ankle('R')))
    left_entry = V((1.25, .45, k.floor_ankle('L')))
    right_entry = V((.99, .45, k.floor_ankle('R')))
    if t < 2.7:
        left, right = left_start, right_start
    elif t < 3.6:
        left = lerp(left_start, left_entry, (t - 2.7) / .4)
        if t < 3.1:
            left.z += .035 * math.sin(math.pi * phase(t, 2.7, 3.1))
        right = lerp(right_start, right_entry, (t - 3.15) / .45)
        if t > 3.15:
            right.z += .035 * math.sin(math.pi * phase(t, 3.15, 3.6))
    elif t < 4.6:
        left = left_entry
        right = lerp(right_entry, (.50, -.30, .68), (t - 3.8) / .8)
        right.z += .14 * math.sin(math.pi * phase(t, 3.8, 4.6))
    else:
        right = path(t, [(4.6, (.50, -.30, .68)), (5.1, (.40, -.30, .46)), (6.2, (.40, -.30, .46)), (6.7, (.19, -.55, .46))])
        left = path(t, [(4.6, left_entry), (5.1, left_entry), (5.55, (.70, .08, .70)), (6.2, (.51, -.55, .46))])
    k.leg('L', left)
    k.leg('R', right)
    # Pull the first part of the stroke, release, let the hinged door swing open.
    if t < 1.8:
        k.hand('R', outer, phase(t, .2, .65) * (1 - phase(t, 1.0, 1.5)))
    elif 3.75 < t < 5.25:
        k.hand('R', (.855, -.33, 1.08), phase(t, 3.75, 4.3) * (1 - phase(t, 4.75, 5.25)))
    else:
        k.hand('R', (.19, -.28, 1.04), phase(t, 5.8, 6.4))
    if 4.9 < t < 6.9:
        k.hand('L', inner.lerp(V((.51, -.28, 1.04)), phase(t, 6.3, 6.9)), phase(t, 4.9, 5.15))
    else:
        k.hand('L', (.51, -.28, 1.04), phase(t, 5.8, 6.4))


def mount_pose(k, kind, pivot, angle, t):
    motor = kind == 'motorbike'
    # Mount from outside the rear of the saddle. Step onto the near peg/pedal
    # before crossing: raising only the foot previously left the thigh in the frame.
    position = path(t, [(0, (.68, .86, -.064)), (.8, (.60, .53, -.064)), (1.7, (.60, .42, -.064)), (1.9, (.60, .36, -.064)), (2.6, (.52, .30, .27)), (3.4, (.30, .30, .29)), (4.0, (.18, .26, .30)), (4.5, (.05, .20 if motor else .28, .25)), (5.8, (0, .15 if motor else .23, .11 if motor else .18)), (8, (0, .15 if motor else .23, .11 if motor else .18))])
    lean = math.radians(2 + 80 * phase(t, .65, 1.7) - (32 if motor else 35) * phase(t, 3.8, 5.6))
    k.begin(position, lean=lean)
    vehicle_point = lambda point: pivot.matrix_world @ V(point)
    grips = {'L': (.30 if motor else .29, -.52 if motor else -.33, 1.15 if motor else 1.16), 'R': (-.30 if motor else -.29, -.52 if motor else -.33, 1.15 if motor else 1.16)}
    left_peg = (.30, .05, .535) if motor else (.22, .18, k.floor_ankle('L', .5575))
    right_peg = (-.30, .05, .535) if motor else (-.22, .18, k.floor_ankle('R', .2775))
    left_target, right_target = vehicle_point(left_peg), vehicle_point(right_peg)
    left_ground, right_ground = V((.74, .58, k.floor_ankle('L'))), V((.54, .58, k.floor_ankle('R')))
    if t < .8:
        # Two deliberate approach steps, then planted feet until the mount.
        left = lerp((.81, .86, k.floor_ankle('L')), left_ground, t / .4)
        if t < .4:
            left.z += .065 * math.sin(math.pi * phase(t, 0, .4))
        right = lerp((.55, .86, k.floor_ankle('R')), right_ground, (t - .4) / .4)
        if t > .4:
            right.z += .065 * math.sin(math.pi * phase(t, .4, .8))
    else:
        left = path(t, [(.8, left_ground), (1.15, left_ground), (1.55, (.52, .30, .75)), (1.9, left_target), (8, left_target)])
        right = path(t, [(.8, right_ground), (1.9, right_ground), (2.8, (.62, .98, 1.30)), (3.25, (-.08, 1.00, 1.30)), (3.85, (-.46, .67, .99)), (4.5, right_target), (8, right_target)])
    # Opening the knee backwards and upwards keeps the whole leg above the tail.
    pole = V((1, -.2, 0)).lerp(V((0, 1, 1.5)), phase(t, 1.7, 2.15))
    pole = pole.lerp(V((-1, -.2, .4)), phase(t, 3.25, 3.85))
    pole = pole.lerp(V((-1, -.2, 0)), phase(t, 3.85, 4.35))
    thigh_twist = math.radians(-30) * phase(t, 3.8, 5.6)
    k.leg('L', left, pole=(1, -.2, 0), roll=angle * phase(t, 1.55, 1.9), twist=thigh_twist)
    k.leg('R', right, pole=pole, roll=angle * phase(t, 4., 4.5), twist=-thigh_twist)
    # The near right hand steadies the tank/saddle while mounting. Reaching the
    # distant handle with the left hand from the rear stretched the arm.
    support = vehicle_point((.05, -.05, 1.02) if motor else (0, -.24, 1.055))
    k.hand('L', vehicle_point(grips['L']), phase(t, 3.8, 5.2))
    k.hand('R', support.lerp(vehicle_point(grips['R']), phase(t, 3.8, 5.2)), phase(t, .65, 1.6))


for clip, kind, source in CLIPS:
    scene, rig, model, k, vehicle, pivot, camera = prepare(clip, kind, source)
    cores = vehicle if kind == 'car' else core_geometry(kind, vehicle)
    triangles = body_without_arms(model) if kind == 'car' else leg_triangles(model)
    cloth_keys = []
    cloth_times = (4.4, 4.8, 5.1, 5.4, 5.7, 6.0)
    if kind != 'car':
        cloth_reports[clip] = []
        for number, sample_time in enumerate(cloth_times):
            angle = set_vehicle_tilt(pivot, vehicle, sample_time)
            mount_pose(k, kind, pivot, angle, sample_time)
            k.apply()
            key, report = make_corrective(model, rig, triangles, cores, 'Roupa_sentada_%d' % number)
            cloth_keys.append(key)
            report['sample_time'] = sample_time
            cloth_reports[clip].append(report)
    hinge = bpy.data.objects.get('Porta_condutor') if kind == 'car' else None
    if hinge:
        hinge.animation_data_clear()
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.new(clip)
    records, geometry = [], []
    previous_joints, max_joint_step = {}, 0
    for frame in range(FRAMES):
        t = frame / FPS
        angle = set_vehicle_tilt(pivot, vehicle, t) if pivot else 0
        if kind == 'car':
            car_pose(k, hinge, t)
        else:
            mount_pose(k, kind, pivot, angle, t)
        solved = k.apply()
        joints = {name: rig.matrix_world @ rig.pose.bones[name].matrix.translation for name in k.order}
        if previous_joints:
            max_joint_step = max(max_joint_step, max((point - previous_joints[name]).length for name, point in joints.items()))
        previous_joints = joints
        if cloth_keys:
            weights = [(phase(t, cloth_times[i - 1], sample) if i else phase(t, 3.7, 4.25)) * (1 - phase(t, sample, cloth_times[i + 1]) if i < len(cloth_keys) - 1 else 1) for i, sample in enumerate(cloth_times)]
            for key, weight in zip(cloth_keys, weights):
                key.value = weight
                key.keyframe_insert('value', frame=frame + 1)
            bpy.context.view_layer.update()
        record = {'time': t, 'root': list(rig.location), 'tilt_radians': angle, 'targets': solved}
        records.append(record)
        if cores and (kind != 'car' or t < 2.7):
            geometry.append({'time': t, 'intersections': intersection_report(model, triangles, cores)})
        k.bake(frame + 1)
        animated = [pivot] if pivot else [hinge]
        for obj in animated:
            obj.keyframe_insert('location', frame=frame + 1)
            obj.keyframe_insert('rotation_euler', frame=frame + 1)
        camera_pose(camera, kind, t)
        camera.keyframe_insert('location', frame=frame + 1)
        camera.keyframe_insert('rotation_euler', frame=frame + 1)
    contacts[clip], clearances[clip] = records, geometry
    rig.animation_data.action.use_fake_user = True
    scene.frame_set(1)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.region_3d.view_perspective = 'CAMERA'
    error = max(c['error'] for record in records for c in record['targets'].values())
    overlaps = [(r['time'], r['intersections']) for r in geometry if r['intersections']]
    assert error < .015, (clip, 'unreachable contact', error)
    assert not overlaps, (clip, 'leg intersects vehicle core', overlaps)
    assert max_joint_step < .15, (clip, 'abrupt joint displacement', max_joint_step)
    print('BAKED', clip, 'max_contact_error', error, 'geometry_collisions', overlaps, flush=True)
    if '--probe' not in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (clip + '.blend')), compress=True)
    source_checks.append({'clip': clip, 'source': source, 'bones': 21, 'fps': 24, 'frames': FRAMES})
    if '--preview' in sys.argv or '--render' in sys.argv:
        folder = TEMP / 'frames' / clip
        folder.mkdir(parents=True, exist_ok=True)
        samples = [0, 24, 42, 54, 66, 72, 78, 84, 96, 108, 132, 168] if '--preview' in sys.argv else range(FRAMES)
        for frame in samples:
            scene.frame_set(frame + 1)
            scene.render.filepath = str(folder / ('%04d.png' % frame))
            bpy.ops.render.render(write_still=True)
        print('RENDERED', clip, flush=True)
    if '--probe' not in sys.argv:
        subprocess.run([bpy.app.binary_path, '-t', '1', '-b', '--python-exit-code', '1', '--python', str(BASE / 'ferramentas/exportar_revisao05.py'), '--', '--clip=' + clip], check=True)

for filename, values in [('contactos.json', contacts), ('geometria.json', clearances), ('fontes.json', source_checks), ('roupa.json', cloth_reports)]:
    (OUT / filename).write_text(json.dumps(values, indent=2) + '\n')
print('REVIEW05 READY', flush=True)
