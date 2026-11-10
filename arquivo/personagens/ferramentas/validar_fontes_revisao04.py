"""Blender: verify the approved rest rig and mesh, plus editable animation sources."""
import bpy
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_04'
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'emmet/revisao_02/emmet_articulacao_02.blend'))
reference = {b.name: [list(row) for row in b.matrix_local] for b in bpy.data.objects['Emmet_Rig_Review02'].data.bones}
positions = [tuple(v.co) for v in bpy.data.objects['Emmet_Skin'].data.vertices]
uvs = [tuple(loop.uv) for loop in bpy.data.objects['Emmet_Skin'].data.uv_layers.active.data]
records = []
for name in ('04_montar_bicicleta', '05_subir_trotinete'):
    bpy.ops.wm.open_mainfile(filepath=str(OUT / (name + '.blend')))
    rig = bpy.data.objects['Emmet_Rig_Animacoes04']
    model = bpy.data.objects['Emmet_Skin']
    scene = bpy.context.scene
    assert len(rig.data.bones) == 21
    for bone in rig.data.bones:
        assert max(abs(a - b) for row, old in zip(bone.matrix_local, reference[bone.name]) for a, b in zip(row, old)) < 1e-6
    assert [tuple(v.co) for v in model.data.vertices] == positions
    assert [tuple(loop.uv) for loop in model.data.uv_layers.active.data] == uvs
    assert rig.animation_data.action.name == name
    assert scene.render.fps == 24 and (scene.frame_start, scene.frame_end) == (1, 192)
    assert scene.camera and scene.camera.animation_data.action
    for vertex in model.data.vertices:
        assert len([g for g in vertex.groups if g.weight > 1e-6]) <= 4
        assert abs(sum(g.weight for g in vertex.groups) - 1) < 1e-5
    records.append({'clip': name, 'bones_unchanged': 21, 'rest_vertices_unchanged': len(positions), 'uvs_unchanged': True, 'normalized_skin_weights': True, 'has_animated_review_camera': True, 'fps': 24, 'frames': 192})
(OUT / 'fontes_validadas.json').write_text(json.dumps(records, indent=2) + '\n')
print('REVIEW04 SOURCE CHECKS: approved rest bones, mesh, UVs, skin and camera verified')
