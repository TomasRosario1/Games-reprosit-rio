"""Blender: original preserved, candidate rig and joint-check videos only.
Run: blender -b --python arquivo/personagens/ferramentas/preparar_emmet.py
Use -- --preview for one frame per clip; -- --render for the full sequences.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Quaternion

BASE = Path(__file__).resolve().parent.parent
OUT = BASE / 'emmet/revisao_01'
FRAMES = Path('/tmp/emmet-review/frames')
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE/'emmet/original/gta_sa_emmet.glb'))
model = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
points = [model.matrix_world @ v.co for v in model.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
origin = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
scale = 1.8/(hi.z-lo.z)
for vertex, point in zip(model.data.vertices, points):
    vertex.co = (point-origin)*scale
model.parent = None
model.matrix_world.identity()
model.name = 'Emmet_Skin'
# Weld UV-split coincident vertices for a connected heat solve. UV loops survive.
bpy.context.view_layer.objects.active = model
model.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.00001)
bpy.ops.object.mode_set(mode='OBJECT')
for obj in list(bpy.context.scene.objects):
    if obj != model: bpy.data.objects.remove(obj, do_unlink=True)

spec = [
 ('pelvis',(0,0,.90),(0,0,1.03),None),
 ('spine',(0,0,1.03),(0,0,1.23),'pelvis'),
 ('chest',(0,0,1.23),(0,0,1.45),'spine'),
 ('neck',(0,0,1.45),(0,-.005,1.57),'chest'),
 ('head',(0,-.005,1.57),(0,-.005,1.78),'neck'),
]
for side, sign in [('L',1),('R',-1)]:
    def p(x,y,z): return (sign*x,y,z)
    spec.extend([
      ('clavicle.'+side,p(.025,0,1.45),p(.20,0,1.47),'chest'),
      ('upper_arm.'+side,p(.20,0,1.47),p(.35,-.005,1.21),'clavicle.'+side),
      ('forearm.'+side,p(.35,-.005,1.21),p(.47,-.025,1.015),'upper_arm.'+side),
      ('hand.'+side,p(.47,-.025,1.015),p(.515,-.035,.86),'forearm.'+side),
      ('thigh.'+side,p(.10,0,.90),p(.115,-.008,.49),'pelvis'),
      ('shin.'+side,p(.115,-.008,.49),p(.13,0,.12),'thigh.'+side),
      ('foot.'+side,p(.13,0,.12),p(.13,-.14,.055),'shin.'+side),
      ('toe.'+side,p(.13,-.14,.055),p(.13,-.20,.055),'foot.'+side),
    ])
arm_data = bpy.data.armatures.new('Emmet_Armature')
rig = bpy.data.objects.new('Emmet_Rig_Review01', arm_data)
bpy.context.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for name, head, tail, parent in spec:
    bone = arm_data.edit_bones.new(name);bone.head=head;bone.tail=tail
    if parent: bone.parent=arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front = True; rig.display_type = 'WIRE'
# Automatic weighting is a review candidate, not an artistic approval.
bpy.ops.object.select_all(action='DESELECT')
model.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
if not any(m.type=='ARMATURE' for m in model.modifiers):
    raise RuntimeError('Armature binding failed')
# Heat alone can pull the open jacket front into the forearms. Constrain the
# anatomical regions, blending across shoulders, elbows, knees and ankles.
def smooth(a,b,x):
    t=max(0.0,min(1.0,(x-a)/(b-a)));return t*t*(3-2*t)
def mix(a,b,t):
    result={k:v*(1-t) for k,v in a.items()}
    for k,v in b.items(): result[k]=result.get(k,0)+v*t
    return {k:v for k,v in result.items() if v>0.00001}
def along(z,anchors):
    if z<=anchors[0][0]:return {anchors[0][1]:1}
    for (a,name),(b,next_name) in zip(anchors,anchors[1:]):
        if z<=b:return mix({name:1},{next_name:1},smooth(a,b,z))
    return {anchors[-1][1]:1}
for vertex in model.data.vertices:
    x,y,z=vertex.co;ax=abs(x);side='L' if x>=0 else 'R'
    torso=along(z,[(.97,'pelvis'),(1.16,'spine'),(1.38,'chest'),(1.53,'neck'),(1.64,'head')])
    if z<.98:
        leg=along(z,[(.045,'toe.'+side),(.10,'foot.'+side),(.20,'shin.'+side),(.42,'shin.'+side),(.57,'thigh.'+side),(.84,'thigh.'+side),(.98,'pelvis')])
        # The hanging hem is attached to the pelvis, not stretched with the knee.
        coat=smooth(.80,.90,z)*max(smooth(.16,.22,ax),smooth(.075,.12,abs(y)))
        torso=mix(leg,{'pelvis':1},coat)
    arm=along(z,[(.94,'hand.'+side),(1.04,'forearm.'+side),(1.15,'forearm.'+side),(1.27,'upper_arm.'+side),(1.46,'upper_arm.'+side),(1.53,'clavicle.'+side)])
    inner=.24-.07*smooth(1.36,1.49,z)
    arm_amount=smooth(inner,inner+.065,ax) if .70<z<1.55 else 0
    result=mix(torso,arm,arm_amount)
    for group in model.vertex_groups:group.remove([vertex.index])
    for name,weight in result.items():model.vertex_groups[name].add([vertex.index],weight,'REPLACE')
# Limit to four influences for ordinary game skinning; normalize every vertex.
weights=[]
for v in model.data.vertices:
    assigned=sorted([(g.group,g.weight) for g in v.groups if g.weight>1e-7],key=lambda x:-x[1])[:4]
    if not assigned: raise RuntimeError('Unweighted vertex %d'%v.index)
    total=sum(w for _,w in assigned)
    for group in model.vertex_groups: group.remove([v.index])
    for group,weight in assigned: model.vertex_groups[group].add([v.index],weight/total,'REPLACE')
    weights.append(len(assigned))

FPS=24
CLIPS=[
 ('01_esqueleto_360',8,'Encaixe do esqueleto - frente, lado e costas'),
 ('02_bracos',8,'Cotovelos, ombros e pulsos'),
 ('03_pernas',8,'Anca, joelhos e tornozelos'),
 ('04_tronco',8,'Coluna, pescoco e cabeca'),
]
D2R=math.pi/180

def rotation(name, axis, degrees):
    bone = rig.pose.bones[name]
    rest = arm_data.bones[name].matrix_local.to_quaternion()
    bone.rotation_mode='QUATERNION'
    bone.rotation_quaternion=rest.inverted() @ Quaternion(Vector(axis),degrees*D2R) @ rest

def pose(clip,t):
    for bone in rig.pose.bones:
        bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion();bone.location=(0,0,0)
    if clip=='02_bracos':
        if t<3:
            a=math.sin(math.pi*min(t,3)/3)**2
            rotation('forearm.L',(1,0,0),-95*a)
            rotation('forearm.R',(1,0,0),-70*a)
        elif t<6:
            a=math.sin(math.pi*(t-3)/3)**2
            rotation('upper_arm.L',(0,1,0),-42*a)
            rotation('upper_arm.R',(0,1,0),42*a)
        else:
            a=math.sin(2*math.pi*(t-6)/2)
            for s in ['L','R']: rotation('hand.'+s,(0,0,1),30*a)
    elif clip=='03_pernas':
        if t<4:
            a=math.sin(math.pi*t/4)**2
            rotation('thigh.L',(1,0,0),-45*a)
            rotation('shin.L',(1,0,0),85*a)
            rotation('foot.L',(1,0,0),-25*a)
        else:
            a=math.sin(math.pi*(t-4)/4)**2
            rotation('thigh.R',(1,0,0),-45*a)
            rotation('shin.R',(1,0,0),85*a)
            rotation('foot.R',(1,0,0),-25*a)
    elif clip=='04_tronco':
        if t<3:
            a=math.sin(2*math.pi*t/3)
            rotation('head',(0,0,1),35*a)
            rotation('neck',(0,0,1),8*a)
        elif t<6:
            a=math.sin(2*math.pi*(t-3)/3)
            rotation('chest',(0,0,1),22*a)
            rotation('spine',(0,0,1),8*a)
        else:
            a=math.sin(math.pi*(t-6)/2)**2
            rotation('spine',(1,0,0),20*a)
            rotation('chest',(1,0,0),15*a)
    bpy.context.view_layer.update()

# Bake only diagnostic poses; walking/running/variants await the user's rig review.
for clip,duration,title in CLIPS:
    if clip=='01_esqueleto_360': continue
    rig.animation_data_clear()
    for frame in range(1,duration*FPS+1,2):
        t=(frame-1)/FPS;pose(clip,t)
        for bone in rig.pose.bones:
            bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
    action=rig.animation_data.action;action.name=clip
    track=rig.animation_data.nla_tracks.new();track.name=clip
    strip=track.strips.new(clip,1,action);strip.action_frame_start=1;strip.action_frame_end=duration*FPS-1
    track.mute=True
    # Keep all actions available without layering joint tests on one another.
    action.use_fake_user=True
    rig.animation_data.action=None
pose('01_esqueleto_360',0)
rig.animation_data_clear()
# Actions still have fake users; Blender source opens at the neutral candidate.
bpy.ops.object.select_all(action='DESELECT');model.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'emmet_articulacao_01.blend'))
# Build unmuted NLA tracks temporarily so glTF carries separate review animations.
for action in list(bpy.data.actions):
    if action.name not in [x[0] for x in CLIPS]: continue
    if rig.animation_data is None: rig.animation_data_create()
    track=rig.animation_data.nla_tracks.new();track.name=action.name
    track.strips.new(action.name,1,action)
    track.mute=True
bpy.ops.export_scene.gltf(filepath=str(OUT/'emmet_articulacao_01.glb'),export_format='GLB',use_selection=True,export_animations=True,export_nla_strips=True)
rig.animation_data_clear()
report={'status':'aguarda_feedback_articulacao','height_m':1.8,'source_scale_applied':scale,'vertices':len(model.data.vertices),'triangles':sum(len(p.vertices)-2 for p in model.data.polygons),'bones':len(spec),'weight_method':'Blender heat initialized, anatomical-region correction, four normalized influences','unweighted_vertices':0,'max_influences':max(weights),'texture_preserved':True,'clips':[{'id':c,'duration_seconds':d,'description':t,'fps':FPS} for c,d,t in CLIPS],'joints':[{'name':n,'head':h,'tail':t,'parent':p} for n,h,t,p in spec],'limitations':['Not integrated in the game','Weights and bone placement require user visual review','No individual finger rig or cloth simulation','No walking/running/color/shape variants before rig feedback']}
(OUT/'relatorio.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
if '--preview' not in sys.argv and '--render' not in sys.argv: sys.exit(0)

# Actual Blender deformation renders. The right panel projects the *real posed*
# joints towards the orthographic camera to make internal bones visible through skin.
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=True
scene.display.shading.background_type='WORLD'
scene.world=bpy.data.worlds.new('Review world');scene.world.color=(.045,.052,.065)
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=960;scene.render.resolution_y=540;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=4.2;scene.camera=camera
model.hide_render=True
left=bpy.data.objects.new('Deformacao_real',model.data.copy());bpy.context.collection.objects.link(left)
right=bpy.data.objects.new('Mesmo_corpo_esqueleto',left.data);bpy.context.collection.objects.link(right)
mat=bpy.data.materials.new('Skeleton cyan');mat.diffuse_color=(.0,.85,1,1)
joint_mat=bpy.data.materials.new('Joint yellow');joint_mat.diffuse_color=(1,.65,.02,1)
lines=[];joints=[]
for name,_,_,_ in spec:
    bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.006,depth=1)
    line=bpy.context.object;line.name='Overlay_'+name;line.data.materials.append(mat);lines.append(line)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.012)
    dot=bpy.context.object;dot.name='Joint_'+name;dot.data.materials.append(joint_mat);joints.append(dot)

def view(clip,t):
    azimuth=2*math.pi*t/8 if clip=='01_esqueleto_360' else (.8 if clip=='03_pernas' else 0)
    target=Vector((0,0,.91));camera.location=Vector((5*math.sin(azimuth),-5*math.cos(azimuth),1.05))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    right_axis=camera.rotation_euler.to_matrix()@Vector((1,0,0))
    near=(camera.location-target).normalized()
    left.location=-right_axis*.70;right.location=right_axis*.70
    pose(clip,t)
    depsgraph=bpy.context.evaluated_depsgraph_get()
    evaluated=model.evaluated_get(depsgraph);temp=evaluated.to_mesh()
    # A fresh evaluated mesh preserves UV loops and the texture on both panels.
    old=left.data;mesh=temp.copy();left.data=mesh;right.data=mesh
    evaluated.to_mesh_clear()
    if old.users==0:bpy.data.meshes.remove(old)
    for line,dot,(name,_,_,_) in zip(lines,joints,spec):
        bone=rig.pose.bones[name]
        a=rig.matrix_world@bone.head+right.location
        b=rig.matrix_world@bone.tail+right.location
        # Parallel projection moves lines closer without altering screen positions.
        a+=near*.48;b+=near*.48
        line.location=(a+b)*.5
        line.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();line.scale.z=(b-a).length
        dot.location=a
    bpy.context.view_layer.update()

for clip,duration,title in CLIPS:
    folder=FRAMES/clip;folder.mkdir(parents=True,exist_ok=True)
    samples=[48] if '--preview' in sys.argv else range(duration*FPS)
    for frame in samples:
        view(clip,frame/FPS)
        scene.render.filepath=str(folder/('%04d.png'%frame))
        bpy.ops.render.render(write_still=True)
    print('CLIP COMPLETE',clip,flush=True)
print('REVIEW RENDER COMPLETE',flush=True)
