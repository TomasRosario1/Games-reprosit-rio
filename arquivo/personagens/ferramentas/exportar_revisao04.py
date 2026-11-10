"""Cold export: keep only the requested body action in the temporary process."""
import bpy
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_04'
clip = next(value.split('=', 1)[1] for value in sys.argv if value.startswith('--clip='))
assert clip in ('04_montar_bicicleta', '05_subir_trotinete')
bpy.ops.wm.open_mainfile(filepath=str(OUT / (clip + '.blend')))
rig = bpy.data.objects['Emmet_Rig_Animacoes04']
model = bpy.data.objects['Emmet_Skin']
assert rig.animation_data.action.name == clip
for action in list(bpy.data.actions):
    if action != rig.animation_data.action:
        bpy.data.actions.remove(action, do_unlink=True)
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
    if obj in (rig, model) or obj.type == 'MESH' and not obj.hide_render and not obj.name.startswith(('Chao_', 'Marca_')):
        obj.hide_set(False)
        obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUT / (clip + '.glb')), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIVE_ACTIONS', export_nla_strips_merged_animation_name=clip, export_anim_slide_to_zero=True)
print('REVIEW04 EXPORTED', clip, flush=True)
