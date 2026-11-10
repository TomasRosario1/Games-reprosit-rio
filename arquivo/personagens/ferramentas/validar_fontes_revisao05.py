"""Blender validation of the approved rest model and the new editable sources."""
import bpy
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_05'
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'emmet/revisao_02/emmet_articulacao_02.blend'))
reference = {bone.name: [list(row) for row in bone.matrix_local] for bone in bpy.data.objects['Emmet_Rig_Review02'].data.bones}
positions = [tuple(vertex.co) for vertex in bpy.data.objects['Emmet_Skin'].data.vertices]
uvs = [tuple(loop.uv) for loop in bpy.data.objects['Emmet_Skin'].data.uv_layers.active.data]
records = []
for clip in ('01_carro', '02_mota', '03_bicicleta'):
    bpy.ops.wm.open_mainfile(filepath=str(OUT / (clip + '.blend')))
    scene = bpy.context.scene
    rig, model = bpy.data.objects['Emmet_Rig_Animacoes05'], bpy.data.objects['Emmet_Skin']
    assert len(rig.data.bones) == 21
    for bone in rig.data.bones:
        assert max(abs(a - b) for row, old in zip(bone.matrix_local, reference[bone.name]) for a, b in zip(row, old)) < 1e-6
    assert [tuple(v.co) for v in model.data.vertices] == positions
    assert [tuple(loop.uv) for loop in model.data.uv_layers.active.data] == uvs
    assert rig.animation_data.action.name == clip
    assert scene.render.fps == 24 and (scene.frame_start, scene.frame_end) == (1, 192)
    assert scene.camera and scene.camera.animation_data.action
    for vertex in model.data.vertices:
        assert abs(sum(g.weight for g in vertex.groups) - 1) < 1e-5
        assert len([g for g in vertex.groups if g.weight > 1e-6]) <= 4
    correctives = []
    if clip != '01_carro':
        keys = model.data.shape_keys.key_blocks
        assert len(keys) == 7
        assert [tuple(v.co) for v in keys['Basis'].data] == positions
        for key in list(keys)[1:]:
            modified = [index for index, (v, original) in enumerate(zip(key.data, keys['Basis'].data)) if (v.co - original.co).length > 1e-6]
            assert modified and all(model.data.vertices[index].co.z < .9 for index in modified)
            correctives.append({'name': key.name, 'vertices': len(modified), 'only_lower_body': True})
    records.append({'clip': clip, 'bones_unchanged': 21, 'rest_vertices_unchanged': len(positions), 'uvs_unchanged': True, 'normalized_weights': True, 'has_review_camera': True, 'clothing_correctives': correctives, 'fps': 24, 'frames': 192})
(OUT / 'fontes_validadas.json').write_text(json.dumps(records, indent=2) + '\n')
print('REVIEW05 SOURCE CHECKS: approved rest bones, mesh, UVs and editable clips verified')
