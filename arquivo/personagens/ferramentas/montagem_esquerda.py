"""Review06: left-hand grip, tilt, then a folded forward-knee straddle mount.

Only the two rejected mounts are rebuilt; the accepted car and scooter stay
byte-for-byte intact. Use --probe, --preview or --render, optionally --only=kind.
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
from emmet_montagem_ik import fit_knee_path, knee_pole, curve_angle

OUT = BASE / 'emmet/revisao_06'
TEMP = Path('/tmp/emmet-review-06')
OUT.mkdir(parents=True, exist_ok=True)
TEMP.mkdir(parents=True, exist_ok=True)
FPS, FRAMES = 24, 192
CLIPS = [('01_mota', 'motorbike', '02_mota'), ('02_bicicleta', 'bicycle', '03_bicicleta')]
only = next((arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--only=')), None)
if only:
    CLIPS = [entry for entry in CLIPS if entry[1] == only]
diagnostics, cloth_reports = {}, {}
if only:
    for filename, container in [('contactos.json', diagnostics), ('roupa.json', cloth_reports)]:
        if (OUT / filename).exists():
            container.update(json.loads((OUT / filename).read_text()))


class MountRig(PoseRig):
    def begin_mount(self, position, lean, time, roll=0):
        super().begin(position, lean=lean)
        self.rig.rotation_euler.y = roll
        # Shoulder protraction is a normal clavicle rotation, not a new rest rig.
        clavicle = 'clavicle.L'
        head = self.pose[clavicle].translation.copy()
        rotation = Matrix.Rotation(-math.radians(20) * phase(time, .1, .85), 4, 'Z')
        self.pose[clavicle] = Matrix.Translation(head) @ rotation @ Matrix.Translation(-head) @ self.pose[clavicle]
        descendants = {clavicle}
        for name in self.order:
            parent = self.rig.data.bones[name].parent
            if parent and parent.name in descendants:
                self.pose[name] = self.pose[parent.name] @ self.rest[parent.name].inverted() @ self.rest[name]
                descendants.add(name)
        bpy.context.view_layer.update()


def bounds(obj):
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return V(tuple(min(p[i] for p in points) for i in range(3))), V(tuple(max(p[i] for p in points) for i in range(3)))


def leg_triangles(model, side=None):
    model.data.calc_loop_triangles()
    names = {group.index: group.name for group in model.vertex_groups}
    selected = set()
    for vertex in model.data.vertices:
        weight = sum(group.weight for group in vertex.groups if names[group.group].startswith(('thigh.', 'shin.', 'foot.', 'toe.')) and (side is None or names[group.group].endswith('.' + side)))
        if weight > .5:
            selected.add(vertex.index)
    return [tuple(triangle.vertices) for triangle in model.data.loop_triangles if all(index in selected for index in triangle.vertices)]


def intersections(model, triangles, parts):
    evaluated = model.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    points = [model.matrix_world @ vertex.co for vertex in mesh.vertices]
    tree = BVHTree.FromPolygons(points, triangles, all_triangles=True)
    result = {}
    for obj in parts:
        obj.data.calc_loop_triangles()
        surface = BVHTree.FromPolygons([obj.matrix_world @ vertex.co for vertex in obj.data.vertices], [tuple(triangle.vertices) for triangle in obj.data.loop_triangles], all_triangles=True)
        overlap = tree.overlap(surface)
        if overlap:
            result[obj.name] = len(overlap)
    evaluated.to_mesh_clear()
    return result


def prepare(clip, kind, source):
    bpy.ops.wm.open_mainfile(filepath=str(BASE / 'emmet/revisao_05' / (source + '.blend')))
    scene = bpy.context.scene
    scene.frame_set(1)
    rig = bpy.data.objects['Emmet_Rig_Animacoes05']
    model = bpy.data.objects['Emmet_Skin']
    if model.data.shape_keys:
        model.shape_key_clear()
    parts = [obj for obj in scene.objects if obj.type == 'MESH' and obj != model and not obj.hide_render and not obj.name.startswith(('Chao_', 'Marca_'))]
    for obj in parts:
        world = obj.matrix_world.copy()
        obj.data = obj.data.copy()
        obj.data.transform(world)
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
    keep = {rig, model, *parts}
    keep.update(obj for obj in scene.objects if obj.name.startswith(('Chao_', 'Marca_')))
    for obj in list(scene.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    rig.name = 'Emmet_Rig_Animacoes06'
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action, do_unlink=True)
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    rig.location = (0, 0, 0)
    rig.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    pivot = bpy.data.objects.new('Inclinacao_pela_mao_esquerda', None)
    bpy.context.collection.objects.link(pivot)
    for obj in parts:
        obj.parent = pivot
        obj.matrix_parent_inverse = Matrix.Identity(4)
    k = MountRig(rig, model)
    # A small pose corrective closes the existing low-poly fingers around the bar.
    basis = model.shape_key_add(name='Basis')
    grip_key = model.shape_key_add(name='Mao_esquerda_pega')
    hand_rest = k.rest['hand.L']
    grip_vertices = 0
    for vertex in model.data.vertices:
        weight = sum(group.weight for group in vertex.groups if model.vertex_groups[group.group].name == 'hand.L')
        local = hand_rest.inverted() @ vertex.co
        if weight > .5 and local.y > .075 and abs(local.z) < .05:
            distance = local.y - .075
            radius = max(.032, distance / math.radians(145))
            angle = distance / radius
            folded = local.copy()
            folded.y = .075 + (radius + local.z) * math.sin(angle)
            folded.z = -radius + (radius + local.z) * math.cos(angle)
            blend = phase(local.y, .075, .10)
            grip_key.data[vertex.index].co = vertex.co.lerp(hand_rest @ folded, blend)
            grip_vertices += 1
    assert grip_vertices > 5
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.render_aa = '8'
    shading = scene.display.shading
    shading.light, shading.color_type = 'STUDIO', 'TEXTURE'
    shading.show_shadows, shading.show_cavity, shading.show_specular_highlight = False, True, False
    shading.background_type = 'WORLD'
    scene.world.color = (.045, .052, .065)
    scene.view_settings.view_transform = 'Standard'
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = 1280, 720, 100
    scene.render.fps, scene.frame_start, scene.frame_end = FPS, 1, FRAMES
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = 'Camara_pega_e_joelho'
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 4.4 if kind == 'motorbike' else 3.9
    target, offset = V((.1, .0, .95)), V((1.5, -6.0, 2.2))
    camera.location = target + offset
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    return scene, rig, model, k, parts, pivot, grip_key


def tilt(pivot, parts, time):
    # No inclination before the left hand has reached and closed on the grip.
    angle = math.radians(12) * phase(time, 1.15, 2.0) * (1 - phase(time, 5.0, 6.4))
    pivot.rotation_euler = (0, angle, 0)
    rotation = Matrix.Rotation(angle, 4, 'Y')
    lowest = min((rotation @ obj.matrix_local @ vertex.co).z for obj in parts if not obj.name.startswith('Descanso') for vertex in obj.data.vertices)
    pivot.location.z = .002 - lowest
    bpy.context.view_layer.update()
    return angle


def pose(k, kind, pivot, angle, grip_key, time, knee_override=None):
    motor = kind == 'motorbike'
    final = V((0, .15 if motor else .23, .11 if motor else .18))
    seated = pivot.matrix_world @ final
    position = path(time, [(0, (.54, -.20, -.064)), (1.0, (.54, -.20, -.064)), (2., (.72, -.12, -.08)), (2.5, (.72, -.12, -.08)), (3.2, (.60, -.10 if motor else .04, .24)), (3.8, (.40, -.04 if motor else .06, .25)), (4.4, (.18, .10, .24)), (5., (.13, .15 if motor else .23, .17 if motor else .23)), (5.7, seated), (8, seated)])
    lean = math.radians(18 + 42 * phase(time, 1.2, 3.0) - (15 if motor else 20) * phase(time, 5.6, 6.6))
    body_roll = angle * phase(time, 4.8, 5.7)
    k.begin_mount(position, lean, time, body_roll)
    vehicle_point = lambda point: pivot.matrix_world @ V(point)
    bar_z = 1.152 if motor else 1.162
    bar_y = -.52 if motor else -.33
    bar_x = .30 if motor else .29
    left_grip = vehicle_point((bar_x, bar_y, bar_z))
    right_grip = vehicle_point((-bar_x, bar_y, bar_z))
    left_peg = vehicle_point((.30, .05, .540) if motor else (.22, .18, k.floor_ankle('L', .5595)))
    right_peg = vehicle_point((-.30, .05, .540) if motor else (-.22, .18, k.floor_ankle('R', .2795)))
    left_ground = V((.67, -.16, k.floor_ankle('L')))
    right_ground = V((.44, -.16, k.floor_ankle('R')))
    left = path(time, [(0, left_ground), (1.75, left_ground), (2.2, (.55, -.02, .75)), (2.5, left_peg), (8, left_peg)])
    high = 1.27 if motor else 1.28
    # The heel follows behind the bent knee by a normal lower-leg length.
    # Putting the raised heel in front of the hip folds the knee down into the
    # tank/frame; it must lead up, with the heel following across the saddle.
    right = path(time, [(0, right_ground), (2.5, right_ground), (2.95, (.72, .05, .73)), (3.3, (.72, .06 if motor else .16, high)), (3.6, (.36, .02 if motor else .14, high + .02)), (3.95, (-.02, .08 if motor else .18, high)), (4.4, (-.25, .12, .91)), (5.0, right_peg), (8, right_peg)])
    # Always bend the knee towards the front of the character, never backwards.
    right_pole = V((1, -1, .1)).lerp(V((1, -1, .6)), phase(time, 2.9, 3.3))
    right_pole = right_pole.lerp(V((-1, -1, .15)), phase(time, 4., 5.1))
    if knee_override is not None:
        right_pole = knee_pole(k, right, knee_override)
    elif getattr(k, 'knee_curve', None):
        fitted = curve_angle(k.knee_curve, time)
        if time < k.knee_curve[0][0]:
            fitted *= phase(time, 2.05, k.knee_curve[0][0])
        right_pole = knee_pole(k, right, fitted)
    k.leg('L', left, pole=(1, -.4, 0), roll=angle * phase(time, 2.25, 2.5))
    k.leg('R', right, pole=right_pole, roll=angle * phase(time, 4.5, 5.0))
    k.hand('L', left_grip, phase(time, .15, 1.0))
    # Keep the free hand above the vehicle until it joins the far grip later.
    free_hand = k.rig.matrix_world @ (k.pose['upper_arm.R'].translation + V((-.08, .10, -.12)))
    middle_bar = vehicle_point((.08, bar_y, bar_z))
    assistance = middle_bar.lerp(right_grip, phase(time, 3.3, 4.5))
    k.hand('R', free_hand.lerp(assistance, phase(time, 1.25, 2.2)), 1)
    grip_key.value = phase(time, .85, 1.05)


for clip, kind, source in CLIPS:
    scene, rig, model, k, parts, pivot, grip_key = prepare(clip, kind, source)
    solid_parts = [obj for obj in parts if not obj.name.startswith('Descanso')]
    triangles = leg_triangles(model)
    right_triangles = leg_triangles(model, 'R')
    k.knee_curve, knee_report = fit_knee_path(k, model, parts, pivot, grip_key, kind, pose, tilt, right_triangles)
    (OUT / (clip + '_joelho.json')).write_text(json.dumps(knee_report, indent=2) + '\n')
    cloth_keys = []
    cloth_times = (3.2, 3.4, 3.6, 3.8, 4.0, 97 / 24, 98 / 24, 99 / 24, 100 / 24, 4.2, 103 / 24, 104 / 24, 4.5, 4.8, 5.1, 5.4, 5.8, 6.4)
    cloth_reports[clip] = []
    for number, sample in enumerate(cloth_times):
        angle = tilt(pivot, parts, sample)
        pose(k, kind, pivot, angle, grip_key, sample)
        k.apply()
        key, report = make_corrective(model, rig, triangles, solid_parts, 'Roupa_ao_sentar_%d' % number)
        cloth_keys.append(key)
        report['sample_time'] = sample
        cloth_reports[clip].append(report)
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.new(clip)
    records, previous, max_step = [], {}, 0
    max_step_event = None
    for frame in range(FRAMES):
        time = frame / FPS
        for key in cloth_keys:
            key.value = 0
        angle = tilt(pivot, parts, time)
        pose(k, kind, pivot, angle, grip_key, time)
        targets = k.apply()
        bpy.context.view_layer.update()
        joints = {name: rig.matrix_world @ rig.pose.bones[name].matrix.translation for name in k.order}
        if previous:
            step, name = max(((point - previous[name]).length, name) for name, point in joints.items())
            if step > max_step:
                max_step = step
                max_step_event = (time, name)
        previous = joints
        hip, knee, ankle = joints['thigh.R'], joints['shin.R'], joints['foot.R']
        raw_right_hits = intersections(model, right_triangles, solid_parts) if 2.5 <= time <= 4.9 else {}
        for number, (sample, key) in enumerate(zip(cloth_times, cloth_keys)):
            key.value = (phase(time, cloth_times[number - 1], sample) if number else phase(time, 3.0, 3.2)) * (1 - phase(time, sample, cloth_times[number + 1]) if number < len(cloth_keys) - 1 else 1)
            key.keyframe_insert('value', frame=frame + 1)
        bpy.context.view_layer.update()
        all_hits = intersections(model, triangles, solid_parts)
        axis = ankle - hip
        forward_bend = -(knee - hip - axis * (knee - hip).dot(axis) / axis.length_squared).y
        records.append({'time': time, 'root': list(rig.location), 'tilt_radians': angle, 'left_grip': grip_key.value, 'targets': targets, 'right_hip': list(hip), 'right_knee': list(knee), 'right_ankle': list(ankle), 'knee_back_m': knee.y - hip.y, 'ankle_back_m': ankle.y - hip.y, 'forward_knee_bend_m': forward_bend, 'intersections': all_hits, 'raw_swing_leg_intersections': raw_right_hits})
        k.bake(frame + 1)
        pivot.keyframe_insert('location', frame=frame + 1)
        pivot.keyframe_insert('rotation_euler', frame=frame + 1)
        grip_key.keyframe_insert('value', frame=frame + 1)
    rig.animation_data.action.use_fake_user = True
    diagnostics[clip] = records
    (OUT / 'contactos.json').write_text(json.dumps(diagnostics, indent=2) + '\n')
    (OUT / 'roupa.json').write_text(json.dumps(cloth_reports, indent=2) + '\n')
    error = max(contact['error'] for record in records for contact in record['targets'].values())
    hand_error = max(record['targets']['hand.L']['error'] for record in records if record['time'] >= 1)
    hits = [(record['time'], record['intersections']) for record in records if record['intersections']]
    worst_back = max(record['knee_back_m'] for record in records if 2.5 <= record['time'] <= 5.)
    print('BAKED', clip, 'max_error', error, 'left_grip_error', hand_error, 'joint_step', max_step, max_step_event, 'knee_back', worst_back, 'hits', hits, flush=True)
    if '--probe' not in sys.argv:
        assert error < .015 and hand_error < .005, (clip, 'unreachable contact', error, hand_error)
        assert max_step < .15 and worst_back < .05, (clip, 'unnatural knee', max_step, worst_back)
        assert not hits, (clip, 'leg surface intersects vehicle', hits)
        scene.frame_set(1)
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == 'VIEW_3D':
                    area.spaces.active.region_3d.view_perspective = 'CAMERA'
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (clip + '.blend')), compress=True)
        subprocess.run([bpy.app.binary_path, '-t', '1', '-b', '--python-exit-code', '1', '--python', str(BASE / 'ferramentas/exportar_revisao06.py'), '--', '--clip=' + clip], check=True)
    if '--preview' in sys.argv or '--render' in sys.argv:
        folder = TEMP / 'frames' / clip
        folder.mkdir(parents=True, exist_ok=True)
        for frame in ([0, 20, 28, 45, 60, 72, 80, 88, 96, 106, 120, 144, 180] if '--preview' in sys.argv else range(FRAMES)):
            scene.frame_set(frame + 1)
            scene.render.filepath = str(folder / ('%04d.png' % frame))
            bpy.ops.render.render(write_still=True)
        print('RENDERED', clip, flush=True)

(OUT / 'contactos.json').write_text(json.dumps(diagnostics, indent=2) + '\n')
(OUT / 'roupa.json').write_text(json.dumps(cloth_reports, indent=2) + '\n')
print('REVIEW06 READY', flush=True)
