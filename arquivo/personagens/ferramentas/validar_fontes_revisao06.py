"""Check the approved anatomy and editable sources without resaving them."""
import bpy
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_06'
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'emmet/revisao_02/emmet_articulacao_02.blend'))
reference = {bone.name: [list(row) for row in bone.matrix_local] for bone in bpy.data.objects['Emmet_Rig_Review02'].data.bones}
positions = [tuple(vertex.co) for vertex in bpy.data.objects['Emmet_Skin'].data.vertices]
uvs = [tuple(loop.uv) for loop in bpy.data.objects['Emmet_Skin'].data.uv_layers.active.data]
records = []
for clip in ('01_mota', '02_bicicleta'):
    bpy.ops.wm.open_mainfile(filepath=str(OUT / (clip + '.blend')))
    scene = bpy.context.scene
    rig, model = bpy.data.objects['Emmet_Rig_Animacoes06'], bpy.data.objects['Emmet_Skin']
    assert len(rig.data.bones) == 21
    for bone in rig.data.bones:
        assert max(abs(a - b) for row, old in zip(bone.matrix_local, reference[bone.name]) for a, b in zip(row, old)) < 1e-6
    assert [tuple(v.co) for v in model.data.vertices] == positions
    assert [tuple(loop.uv) for loop in model.data.uv_layers.active.data] == uvs
    assert rig.animation_data.action.name == clip
    assert scene.render.fps == 24 and (scene.frame_start, scene.frame_end) == (1, 192)
    assert scene.camera and not scene.camera.animation_data
    for vertex in model.data.vertices:
        assert abs(sum(g.weight for g in vertex.groups) - 1) < 1e-5
        assert len([g for g in vertex.groups if g.weight > 1e-6]) <= 4
    keys = model.data.shape_keys.key_blocks
    assert len(keys) >= 3
    assert [tuple(v.co) for v in keys['Basis'].data] == positions
    correctives = []
    for key in list(keys)[1:]:
        modified = [index for index, (v, original) in enumerate(zip(key.data, keys['Basis'].data)) if (v.co - original.co).length > 1e-6]
        if key.name == 'Mao_esquerda_pega':
            assert modified
            assert all(any(model.vertex_groups[g.group].name == 'hand.L' and g.weight > .5 for g in model.data.vertices[index].groups) for index in modified)
        else:
            assert all(model.data.vertices[index].co.z < .9 for index in modified)
        correctives.append({'name': key.name, 'vertices': len(modified), 'scope': 'left_fingers' if key.name == 'Mao_esquerda_pega' else 'lower_body_clothing'})
    records.append({'clip': clip, 'bones_unchanged': 21, 'rest_vertices_unchanged': len(positions), 'uvs_unchanged': True, 'normalized_weights': True, 'static_review_camera': True, 'pose_correctives': correctives, 'fps': 24, 'frames': 192})
(OUT / 'fontes_validadas.json').write_text(json.dumps(records, indent=2) + '\n')
print('REVIEW06 SOURCES: approved rest bones, mesh, UVs and editable clips verified')
