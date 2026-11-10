"""Metric kinematics shared by archive reviews; no production game imports."""
import bpy
import math
from mathutils import Matrix, Quaternion, Vector

V = Vector


def smooth(value):
    value = max(0, min(1, value))
    return value * value * (3 - 2 * value)


def phase(t, start, end):
    return smooth((t - start) / (end - start))


def lerp(a, b, value):
    return V(a).lerp(V(b), smooth(value))


def path(t, keys):
    for (start, a), (end, b) in zip(keys, keys[1:]):
        if t <= end:
            return lerp(a, b, (t - start) / (end - start))
    return V(keys[-1][1])


class PoseRig:
    def __init__(self, rig, model):
        self.rig, self.model = rig, model
        self.rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
        self.length = {b.name: b.length for b in rig.data.bones}
        self.order = [b.name for b in rig.data.bones]
        self.shoe = {}
        for side, sign in [('L', 1), ('R', -1)]:
            ankle = self.rest['foot.' + side].translation
            self.shoe[side] = [v.co - ankle for v in model.data.vertices if v.co.z < .15 and sign * v.co.x > 0]

    def floor_ankle(self, side, level=0):
        return level - min(v.z for v in self.shoe[side]) + .003

    def begin(self, position, yaw=0, lean=0):
        self.rig.location = position
        self.rig.rotation_mode = 'XYZ'
        self.rig.rotation_euler = (0, 0, yaw)
        self.pose, self.targets = {}, {}
        for name in self.order:
            parent = self.rig.data.bones[name].parent
            self.pose[name] = self.pose[parent.name] @ self.rest[parent.name].inverted() @ self.rest[name] if parent else self.rest[name].copy()
            amount = .30 if name == 'pelvis' else .42 if name == 'spine' else .28 if name == 'chest' else 0
            if amount:
                head = self.pose[name].translation.copy()
                rotation = Quaternion(V((1, 0, 0)), lean * amount).to_matrix().to_4x4()
                self.pose[name] = Matrix.Translation(head) @ rotation @ Matrix.Translation(-head) @ self.pose[name]
        bpy.context.view_layer.update()

    def align(self, name, head, tail):
        old = self.rest[name].to_3x3().col[1].normalized()
        matrix = old.rotation_difference((tail - head).normalized()).to_matrix().to_4x4() @ self.rest[name]
        matrix.translation = head
        self.pose[name] = matrix

    def pair(self, first, second, target, pole):
        start = self.pose[first].translation.copy()
        offset = target - start
        l1, l2 = self.length[first], self.length[second]
        distance = max(.01, min(offset.length, l1 + l2 - .001))
        direction = offset.normalized()
        target = start + direction * distance
        along = (l1 * l1 - l2 * l2 + distance * distance) / (2 * distance)
        bend = V(pole) - direction * V(pole).dot(direction)
        if bend.length < 1e-5:
            bend = direction.cross(V((1, 0, 0)))
        middle = start + direction * along + bend.normalized() * math.sqrt(max(0, l1 * l1 - along * along))
        self.align(first, start, middle)
        self.align(second, middle, target)
        return target

    def leg(self, side, world, pole=(0, -1, 0), pitch=0, roll=0, twist=0):
        name = 'foot.' + side
        target = self.pair('thigh.' + side, 'shin.' + side, self.rig.matrix_world.inverted() @ V(world), pole)
        if twist:
            self.pose['thigh.' + side] = self.pose['thigh.' + side] @ Matrix.Rotation(twist, 4, 'Y')
        matrix = (Quaternion(V((0, 1, 0)), roll) @ Quaternion(V((1, 0, 0)), pitch)).to_matrix().to_4x4() @ self.rest[name]
        matrix.translation = target
        self.pose[name] = matrix
        self.pose['toe.' + side] = matrix @ self.rest[name].inverted() @ self.rest['toe.' + side]
        self.targets[name] = V(world)

    def hand(self, side, palm=None, weight=1):
        sign = 1 if side == 'L' else -1
        shoulder = self.pose['upper_arm.' + side].translation
        relaxed = shoulder + V((sign * .08, .03, -.46))
        local = self.rig.matrix_world.inverted() @ V(palm) if palm is not None else relaxed
        local = relaxed.lerp(local, weight)
        direction = (local - shoulder).normalized()
        wrist = self.pair('upper_arm.' + side, 'forearm.' + side, local - direction * .065, (sign * .3, 1, 0))
        name = 'hand.' + side
        self.align(name, wrist, wrist + direction * self.length[name])
        self.targets[name] = self.rig.matrix_world @ local

    def apply(self):
        for name in self.order:
            parent = self.rig.data.bones[name].parent
            base = self.pose[parent.name] @ self.rest[parent.name].inverted() @ self.rest[name] if parent else self.rest[name]
            self.rig.pose.bones[name].matrix_basis = base.inverted() @ self.pose[name]
        bpy.context.view_layer.update()
        for name in self.order:
            assert max(abs(a - b) for row, old in zip(self.rig.pose.bones[name].matrix, self.pose[name]) for a, b in zip(row, old)) < .0002
        contacts = {}
        for name, target in self.targets.items():
            matrix = self.rig.pose.bones[name].matrix
            point = matrix.translation + (matrix.to_3x3().col[1] * .065 if name.startswith('hand.') else V((0, 0, 0)))
            actual = self.rig.matrix_world @ point
            contacts[name] = {'target': list(target), 'actual': list(actual), 'error': (target - actual).length}
        return contacts

    def bake(self, frame):
        self.rig.keyframe_insert('location', frame=frame)
        self.rig.keyframe_insert('rotation_euler', frame=frame)
        for name in self.order:
            bone = self.rig.pose.bones[name]
            bone.keyframe_insert('location', frame=frame, group=name)
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=name)
