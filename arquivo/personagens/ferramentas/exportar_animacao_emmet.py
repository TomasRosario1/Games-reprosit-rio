"""Export one source in a fresh Blender process, avoiding cross-export action caches."""
import bpy,sys
from pathlib import Path
BASE=Path(__file__).resolve().parent.parent;OUT=BASE/'emmet/revisao_03'
clip=next(v.split('=',1)[1]for v in sys.argv if v.startswith('--clip='))
assert clip in ['01_andar','02_entrar_carro','03_montar_mota']
bpy.ops.wm.open_mainfile(filepath=str(OUT/(clip+'.blend')))
rig=bpy.data.objects['Emmet_Rig_Animacoes03'];model=bpy.data.objects['Emmet_Skin']
assert rig.animation_data.action.name==clip
# Remove other fake-user actions only in this temporary export process. Blender
# 4.3 otherwise merges compatible actions into the requested merged clip name.
keep={rig.animation_data.action}
if clip=='02_entrar_carro':keep.add(bpy.data.objects['Porta_condutor'].animation_data.action)
for action in list(bpy.data.actions):
    if action not in keep:bpy.data.actions.remove(action,do_unlink=True)
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);model.hide_set(False);rig.select_set(True);model.select_set(True)
if clip!='01_andar':
    for o in bpy.context.scene.objects:
        if o.type=='MESH' and o!=model and not o.hide_render and not o.name.startswith(('Chao_','Marca_')):
            o.hide_set(False);o.select_set(True)
    if clip=='02_entrar_carro':
        door=bpy.data.objects['Porta_condutor'];door.hide_set(False);door.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/(clip+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_nla_strips_merged_animation_name=clip,export_anim_slide_to_zero=True)
print('FRESH ANIMATION EXPORT',clip,flush=True)
