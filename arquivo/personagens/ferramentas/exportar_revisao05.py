"""Export each review05 scene in a fresh Blender process, including vehicle tilt."""
import bpy
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_05'
clip = next(value.split('=', 1)[1] for value in sys.argv if value.startswith('--clip='))
assert clip in ('01_carro', '02_mota', '03_bicicleta')
bpy.ops.wm.open_mainfile(filepath=str(OUT / (clip + '.blend')))
rig = bpy.data.objects['Emmet_Rig_Animacoes05']
model = bpy.data.objects['Emmet_Skin']
assert rig.animation_data.action.name == clip
parents = [o for o in bpy.context.scene.objects if o.name in ('Porta_condutor', 'Inclinacao_veiculo')]
keep = {rig.animation_data.action, *(o.animation_data.action for o in parents if o.animation_data)}
if model.data.shape_keys and model.data.shape_keys.animation_data:
    keep.add(model.data.shape_keys.animation_data.action)
for action in list(bpy.data.actions):
    if action not in keep:
        bpy.data.actions.remove(action, do_unlink=True)
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj in (rig, model, *parents) or obj.type == 'MESH' and not obj.hide_render and not obj.name.startswith(('Chao_', 'Marca_')):
        obj.hide_set(False)
        obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT / (clip + '.glb')), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIVE_ACTIONS', export_nla_strips_merged_animation_name=clip, export_anim_slide_to_zero=True)
print('REVIEW05 EXPORTED', clip, flush=True)
