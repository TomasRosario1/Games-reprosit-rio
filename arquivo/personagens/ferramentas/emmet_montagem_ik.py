"""Fit a continuous knee bend around the actual vehicle, without pole flips.

The foot path is authored; only the knee's bend plane is fitted. Candidate
poses retain both bone lengths, keep the knee forward and avoid the torso.
"""
import math
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def capsule_clearance(k, surfaces):
    """Anatomical leg clearance, separate from the baggy trouser surface."""
    hip = k.rig.matrix_world @ k.pose['thigh.R'].translation
    knee = k.rig.matrix_world @ k.pose['shin.R'].translation
    ankle = k.rig.matrix_world @ k.pose['foot.R'].translation
    least = 100.
    penalty = 0.
    for start, end, radius_start, radius_end, samples in [(hip, knee, .065, .060, (.2, .4, .6, .8, 1.)), (knee, ankle, .055, .035, (.2, .4, .6, .8))]:
        for amount in samples:
            point = start.lerp(end, amount)
            radius = radius_start + (radius_end - radius_start) * amount
            for tree, low, high in surfaces:
                if any(point[i] < low[i] - radius or point[i] > high[i] + radius for i in range(3)):
                    continue
                location, normal, _, distance = tree.find_nearest(point)
                signed = distance if (point - location).dot(normal) >= 0 else -distance
                clearance = signed - radius
                least = min(least, clearance)
                penalty += max(0., -clearance) ** 2
    return least, penalty


def knee_pole(rig, world_ankle, degrees):
    hip = rig.pose['thigh.R'].translation
    axis = (rig.rig.matrix_world.inverted() @ Vector(world_ankle) - hip).normalized()
    forward = Vector((0, -1, 0))
    front = forward - axis * forward.dot(axis)
    assert front.length > .03, 'Foot path must not align with the knee reference'
    front.normalize()
    side = axis.cross(front).normalized()
    angle = math.radians(degrees)
    return front * math.cos(angle) + side * math.sin(angle)


def curve_angle(curve, time):
    for (start, a), (end, b) in zip(curve, curve[1:]):
        if time <= end:
            value = max(0., min(1., (time - start) / (end - start)))
            return a + (b - a) * value
    return curve[-1][1]


def fit_knee_path(k, model, parts, pivot, grip_key, kind, pose_callback, tilt_callback, triangles):
    # Use the same linear skinning as the exported GLB, and compare it with
    # Blender once before using it to evaluate possible bend planes.
    positions = np.array([list(v.co) + [1.] for v in model.data.vertices])
    weights = np.zeros((len(k.order), len(positions)))
    bone_index = {name: index for index, name in enumerate(k.order)}
    for vertex in model.data.vertices:
        for group in vertex.groups:
            weights[bone_index[model.vertex_groups[group.group].name], vertex.index] = group.weight
    inverse_rest = {name: k.rest[name].inverted() for name in k.order}
    right_indices = sorted({index for triangle in triangles for index in triangle})
    remap = {index: slot for slot, index in enumerate(right_indices)}
    right_triangles = [tuple(remap[index] for index in triangle) for triangle in triangles]
    model.data.calc_loop_triangles()
    torso_triangles = [tuple(triangle.vertices) for triangle in model.data.loop_triangles if all(model.data.vertices[index].co.z > 1.1 for index in triangle.vertices)]

    def skin():
        transforms = np.array([np.array(k.rig.matrix_world @ k.pose[name] @ inverse_rest[name]) for name in k.order])
        return np.einsum('bv,bij,vj->vi', weights, transforms, positions)[:, :3]

    angles = np.arange(-90., 91., 5.)
    frames = list(range(56, 121, 2))
    costs, knees, raw_hits, clearances = [], [], [], []
    numerical_error = None
    for frame in frames:
        time = frame / 24.
        angle = tilt_callback(pivot, parts, time)
        pose_callback(k, kind, pivot, angle, grip_key, time, 0.)
        ankle_target = k.targets['foot.R'].copy()
        if numerical_error is None:
            k.apply()
            evaluated = model.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            actual = np.array([list(model.matrix_world @ vertex.co) for vertex in mesh.vertices])
            numerical_error = float(np.max(np.abs(actual[right_indices] - skin()[right_indices])))
            evaluated.to_mesh_clear()
            assert numerical_error < .0001, ('Analytical skinning mismatch', numerical_error)
        surfaces = []
        for obj in parts:
            if obj.name.startswith('Descanso'):
                continue
            obj.data.calc_loop_triangles()
            points = np.array([list(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices])
            tree = BVHTree.FromPolygons(points.tolist(), [tuple(triangle.vertices) for triangle in obj.data.loop_triangles], all_triangles=True)
            surfaces.append((tree, points.min(axis=0), points.max(axis=0)))
        body_points = skin()
        torso = BVHTree.FromPolygons(body_points.tolist(), torso_triangles, all_triangles=True)
        row, joint_row, hit_row, clearance_row = [], [], [], []
        for candidate in angles:
            k.leg('R', ankle_target, pole=knee_pole(k, ankle_target, candidate), roll=angle * max(0, min(1, (time - 4.5) / .5)))
            points = skin()[right_indices]
            tree = BVHTree.FromPolygons(points.tolist(), right_triangles, all_triangles=True)
            low, high = points.min(axis=0), points.max(axis=0)
            hits = sum(len(tree.overlap(surface)) for surface, lo, hi in surfaces if np.all(high >= lo) and np.all(hi >= low))
            self_hits = len(tree.overlap(torso))
            hip = k.rig.matrix_world @ k.pose['thigh.R'].translation
            knee = k.rig.matrix_world @ k.pose['shin.R'].translation
            back = max(0, knee.y - hip.y - .10)
            high_knee = max(0, knee.z - hip.z - .18)
            clearance, capsule_penalty = capsule_clearance(k, surfaces)
            # Once seated, garment contact is resolved by the cloth correctives.
            collision_weight = 20. if time < 4.9 else 2.
            row.append(2000000. * capsule_penalty + collision_weight * hits + 500. * self_hits + 100000. * back * back + 10000000. * high_knee * high_knee + .015 * candidate * candidate + (1e8 if back > .06 else 0.))
            joint_row.append(list(knee))
            hit_row.append(hits)
            clearance_row.append(clearance)
        costs.append(row)
        knees.append(joint_row)
        raw_hits.append(hit_row)
        clearances.append(clearance_row)

    costs, knees = np.array(costs), np.array(knees)
    score = costs[0].copy()
    score += .5 * angles * angles  # enter from an ordinary forward-bent stance
    parents = []
    for slot in range(1, len(frames)):
        distances = np.linalg.norm(knees[slot][:, None, :] - knees[slot - 1][None, :, :], axis=2)
        changes = angles[:, None] - angles[None, :]
        transition = .04 * changes * changes + 80. * distances * distances
        transition[np.abs(changes) > 20.] += 1e8
        transition[distances > .23] += 1e8
        alternatives = transition + score[None, :]
        parent = np.argmin(alternatives, axis=1)
        score = costs[slot] + alternatives[np.arange(len(angles)), parent]
        parents.append(parent)
    choice = int(np.argmin(score))
    selected = [choice]
    for parent in reversed(parents):
        choice = int(parent[choice])
        selected.append(choice)
    selected.reverse()
    curve = [(frame / 24., float(angles[choice])) for frame, choice in zip(frames, selected)]
    return curve, {'analytical_skin_error_m': numerical_error, 'control_samples': len(frames), 'angle_step_degrees': 5, 'control_curve': curve, 'raw_vehicle_hits_at_controls': [int(raw_hits[index][choice]) for index, choice in enumerate(selected)], 'anatomical_clearance_m_at_controls': [float(clearances[index][choice]) for index, choice in enumerate(selected)], 'selected_joint_step_at_controls_m': float(np.max(np.linalg.norm(np.diff(np.array([knees[index, choice] for index, choice in enumerate(selected)]), axis=0), axis=1)))}
