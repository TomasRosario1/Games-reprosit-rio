"""Export the body, constant left grip, finger pose and vehicle inclination."""
import bpy
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_06'
clip = next(arg.split('=', 1)[1] for arg in sys.argv if arg.startswith('--clip='))
assert clip in ('01_mota', '02_bicicleta')
bpy.ops.wm.open_mainfile(filepath=str(OUT / (clip + '.blend')))
rig, model = bpy.data.objects['Emmet_Rig_Animacoes06'], bpy.data.objects['Emmet_Skin']
pivot = bpy.data.objects['Inclinacao_pela_mao_esquerda']
keep = {rig.animation_data.action, pivot.animation_data.action, model.data.shape_keys.animation_data.action}
for action in list(bpy.data.actions):
    if action not in keep:
        bpy.data.actions.remove(action, do_unlink=True)
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj in (rig, model, pivot) or obj.type == 'MESH' and not obj.hide_render and not obj.name.startswith(('Chao_', 'Marca_')):
        obj.hide_set(False)
        obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT / (clip + '.glb')), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIVE_ACTIONS', export_nla_strips_merged_animation_name=clip, export_anim_slide_to_zero=True)
print('REVIEW06 EXPORTED', clip, flush=True)
