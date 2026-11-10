"""Pose correctives for baggy trousers: compress cloth around actual vehicle meshes.

The Basis, UVs and approved bones stay unchanged. Only lower-body vertices are
corrected, using inverse linear skinning, and the result is a normal glTF morph.
There is no cloth simulation running in the game or while reviewing the video.
"""
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


def make_corrective(model, rig, triangles, core, name):
    if not model.data.shape_keys:
        model.shape_key_add(name='Basis')
    for key in model.data.shape_keys.key_blocks:
        key.value = 0
    key = model.shape_key_add(name=name)
    key.value = 1
    inverse = {}
    for vertex in model.data.vertices:
        skin = Matrix(tuple(tuple(sum(g.weight * (rig.pose.bones[model.vertex_groups[g.group].name].matrix @ rig.data.bones[model.vertex_groups[g.group].name].matrix_local.inverted())[row][column] for g in vertex.groups) for column in range(4)) for row in range(4)))
        inverse[vertex.index] = (model.matrix_world.to_3x3() @ skin.to_3x3()).inverted_safe()
    surfaces = []
    for obj in core:
        obj.data.calc_loop_triangles()
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        tree = BVHTree.FromPolygons(points, [tuple(t.vertices) for t in obj.data.loop_triangles], all_triangles=True)
        low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
        high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
        # Short solid cushions, unlike tubular frames and tanks.
        seat = len(obj.data.vertices) == 24 and high.z - low.z < .16 and high.y - low.y > .25
        surfaces.append((tree, low, high, seat))
    corrected, residual = set(), 0
    largest = 0
    basis = model.data.shape_keys.key_blocks['Basis']
    for iteration in range(12):
        bpy.context.view_layer.update()
        evaluated = model.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        points = [model.matrix_world @ v.co for v in mesh.vertices]
        tree = BVHTree.FromPolygons(points, triangles, all_triangles=True)
        desired = {}
        residual = 0
        for surface, low, high, seat in surfaces:
            overlap = tree.overlap(surface)
            residual += len(overlap)
            for triangle_index, _ in overlap:
                indices = triangles[triangle_index]
                crosses_crotch = min(model.data.vertices[i].co.x for i in indices) < 0 < max(model.data.vertices[i].co.x for i in indices)
                for index in indices:
                    if model.data.vertices[index].co.z < .16:
                        continue
                    target = desired.setdefault(index, points[index].copy())
                    if seat or crosses_crotch:
                        target.z = max(target.z, high.z + .014)
                    elif model.data.vertices[index].co.x >= 0:
                        target.x = max(target.x, high.x + .014)
                    else:
                        target.x = min(target.x, low.x - .014)
        evaluated.to_mesh_clear()
        if not desired:
            break
        for index, target in desired.items():
            change = target - points[index]
            key.data[index].co += inverse[index] @ change
            corrected.add(index)
            largest = max(largest, change.length)
    key.value = 0
    bpy.context.view_layer.update()
    assert all((v.co - original.co).length == 0 for v, original in zip(model.data.vertices, basis.data))
    return key, {'name': name, 'vertices_corrected': len(corrected), 'largest_iteration_correction_m': largest, 'residual_triangle_pairs': residual, 'iterations': iteration + 1}
