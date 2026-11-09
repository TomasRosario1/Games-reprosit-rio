"""Blender: validate approved bone rest data, add review cameras and compress sources."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parent.parent;OUT=BASE/'emmet/revisao_03'
bpy.ops.wm.open_mainfile(filepath=str(BASE/'emmet/revisao_02/emmet_articulacao_02.blend'))
reference={b.name:[list(row)for row in b.matrix_local]for b in bpy.data.objects['Emmet_Rig_Review02'].data.bones}
positions=[tuple(v.co)for v in bpy.data.objects['Emmet_Skin'].data.vertices]
records=[]
for name in ['01_andar','02_entrar_carro','03_montar_mota']:
    path=OUT/(name+'.blend');bpy.ops.wm.open_mainfile(filepath=str(path))
    rig=bpy.data.objects['Emmet_Rig_Animacoes03'];model=bpy.data.objects['Emmet_Skin'];scene=bpy.context.scene
    assert len(rig.data.bones)==21
    for bone in rig.data.bones:
        assert max(abs(a-b)for row,old in zip(bone.matrix_local,reference[bone.name])for a,b in zip(row,old))<1e-6
    assert [tuple(v.co)for v in model.data.vertices]==positions
    assert rig.animation_data.action.name==name
    for vertex in model.data.vertices:
        assert len([g for g in vertex.groups if g.weight>1e-6])<=4
        assert abs(sum(g.weight for g in vertex.groups)-1)<1e-5
    bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='Camara_revisao03';cam.data.type='ORTHO';scene.camera=cam
    for frame in range(1,193):
        scene.frame_set(frame);t=(frame-1)/24
        if name=='01_andar':
            target=Vector((rig.location.x,rig.location.y,.9));offset=Vector((3.3,-5,1.25))if t<4 else Vector((5,0,.7));cam.data.ortho_scale=3.6
        elif name=='02_entrar_carro':
            target=Vector((.65,.25,.9));offset=Vector((4,4.8,2.3))if t<6 else Vector((4,-5.5,2.3));cam.data.ortho_scale=5.9
        else:
            target=Vector((.25,.05,.92));offset=Vector((3.9,5.7,1.9))if t<4 else Vector((3.9,-5.7,1.9));cam.data.ortho_scale=4.4
        cam.location=target+offset;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.keyframe_insert('location',frame=frame);cam.keyframe_insert('rotation_euler',frame=frame)
    scene.frame_set(1);scene.render.engine='BLENDER_WORKBENCH';scene.display.render_aa='8'
    scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=True
    scene.display.shading.background_type='WORLD';scene.world=bpy.data.worlds.new('Fundo_revisao03');scene.world.color=(.045,.052,.065)
    scene.view_settings.view_transform='Standard';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    records.append({'clip':name,'bones_unchanged':21,'rest_vertices_unchanged':len(positions),'max_influences':4,'has_review_camera':True,'fps':24,'frames':192})
(OUT/'fontes_validadas.json').write_text(json.dumps(records,indent=2)+'\n')
print('SOURCE REVIEW03: approved bone placement, model rest geometry and normalized skinning validated for3 sources')
