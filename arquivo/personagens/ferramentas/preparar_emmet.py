"""Blender: original preserved, candidate rig and joint-check videos only.
Run: blender -b --python arquivo/personagens/ferramentas/preparar_emmet.py
Use -- --preview for one frame per clip; -- --render for the full sequences.
Add --revision=02 after -- to build the arm-centering revision without overwriting01.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Quaternion

BASE = Path(__file__).resolve().parent.parent
REVISION = '02' if '--revision=02' in sys.argv else '01'
OUT = BASE / ('emmet/revisao_'+REVISION)
FRAMES = Path('/tmp/emmet-review/frames' if REVISION=='01' else '/tmp/emmet-review-02/frames')
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
# Fit depth to actual front/back triangle intersections, not the surface facing
# the review camera. Version01 is retained verbatim for comparison.
fit_records=[]
model.data.calc_loop_triangles()
def depth_hits(x,z):
    hits=[]
    for triangle in model.data.loop_triangles:
        a,b,c=[model.data.vertices[i].co for i in triangle.vertices]
        bx,bz=b.x-a.x,b.z-a.z;cx,cz=c.x-a.x,c.z-a.z;det=bx*cz-bz*cx
        if abs(det)<1e-10:continue
        u=((x-a.x)*cz-(z-a.z)*cx)/det;v=(bx*(z-a.z)-bz*(x-a.x))/det
        if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6:hits.append(a.y+u*(b.y-a.y)+v*(c.y-a.y))
    return sorted(set(round(v,7) for v in hits))
def center_point(name,x,z):
    hits=depth_hits(x,z)
    if len(hits)<2:raise RuntimeError('Missing arm cross section '+name)
    intervals=[(hits[i],hits[i+1]) for i in range(0,len(hits)-1,2)]
    front,back=max(intervals,key=lambda p:p[1]-p[0])
    at=(x,(front+back)*.5,z)
    fit_records.append({'joint':name,'point':at,'surface_front_y':front,'surface_back_y':back,'depth_margin_m':(back-front)*.5})
    return at
for side, sign in [('L',1),('R',-1)]:
    def p(x,y,z): return (sign*x,y,z)
    if REVISION=='02':
        shoulder=center_point('shoulder.'+side,sign*.205,1.425)
        elbow=center_point('elbow.'+side,sign*.335,1.205)
        wrist=center_point('wrist.'+side,sign*.45,1.005)
        hand_end=center_point('palm_end.'+side,sign*.505,.89)
    else:
        shoulder=p(.20,0,1.47);elbow=p(.35,-.005,1.21)
        wrist=p(.47,-.025,1.015);hand_end=p(.515,-.035,.86)
    spec.extend([
      ('clavicle.'+side,p(.025,0,1.45),shoulder,'chest'),
      ('upper_arm.'+side,shoulder,elbow,'clavicle.'+side),
      ('forearm.'+side,elbow,wrist,'upper_arm.'+side),
      ('hand.'+side,wrist,hand_end,'forearm.'+side),
      ('thigh.'+side,p(.10,0,.90),p(.115,-.008,.49),'pelvis'),
      ('shin.'+side,p(.115,-.008,.49),p(.13,0,.12),'thigh.'+side),
      ('foot.'+side,p(.13,0,.12),p(.13,-.14,.055),'shin.'+side),
      ('toe.'+side,p(.13,-.14,.055),p(.13,-.20,.055),'foot.'+side),
    ])
arm_data = bpy.data.armatures.new('Emmet_Armature')
rig = bpy.data.objects.new('Emmet_Rig_Review'+REVISION, arm_data)
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
    arm_anchors=[(.94,'hand.'+side),(1.04,'forearm.'+side),(1.15,'forearm.'+side),(1.27,'upper_arm.'+side),(1.46,'upper_arm.'+side),(1.53,'clavicle.'+side)] if REVISION=='01' else [(.95,'hand.'+side),(1.055,'forearm.'+side),(1.145,'forearm.'+side),(1.265,'upper_arm.'+side),(1.42,'upper_arm.'+side),(1.50,'clavicle.'+side)]
    arm=along(z,arm_anchors)
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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/('emmet_articulacao_'+REVISION+'.blend')))
# Build unmuted NLA tracks temporarily so glTF carries separate review animations.
for action in list(bpy.data.actions):
    if action.name not in [x[0] for x in CLIPS]: continue
    if rig.animation_data is None: rig.animation_data_create()
    track=rig.animation_data.nla_tracks.new();track.name=action.name
    track.strips.new(action.name,1,action)
    track.mute=True
bpy.ops.export_scene.gltf(filepath=str(OUT/('emmet_articulacao_'+REVISION+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_nla_strips=True)
rig.animation_data_clear()
report={'status':'aguarda_feedback_articulacao','height_m':1.8,'source_scale_applied':scale,'vertices':len(model.data.vertices),'triangles':sum(len(p.vertices)-2 for p in model.data.polygons),'bones':len(spec),'weight_method':'Blender heat initialized, anatomical-region correction, four normalized influences','unweighted_vertices':0,'max_influences':max(weights),'texture_preserved':True,'clips':[{'id':c,'duration_seconds':d,'description':t,'fps':FPS} for c,d,t in CLIPS],'joints':[{'name':n,'head':h,'tail':t,'parent':p} for n,h,t,p in spec],'limitations':['Not integrated in the game','Weights and bone placement require user visual review','No individual finger rig or cloth simulation','No walking/running/color/shape variants before rig feedback']}
report['revision']=REVISION
report['arm_fit_sections']=fit_records
report['review_display']='actual bones inside wireframe mesh, no camera-depth offset' if REVISION=='02' else 'projected overlay for visibility'
report['rendered_video_ids']=['01_esqueleto_360','02_bracos','03_comparacao_bracos'] if REVISION=='02' else [c for c,_,_ in CLIPS]
(OUT/'relatorio.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
if '--preview' not in sys.argv and '--render' not in sys.argv: sys.exit(0)

# Actual Blender deformation renders. Review01 projects an overlay for visibility;
# review02 renders real bone geometry inside a wireframe at unchanged depth.
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=True
scene.display.shading.background_type='WORLD'
if REVISION=='02':scene.display.render_aa='8'
scene.world=bpy.data.worlds.new('Review world');scene.world.color=(.045,.052,.065)
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=1280 if REVISION=='02' else 960;scene.render.resolution_y=720 if REVISION=='02' else 540;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=4.2;scene.camera=camera
model.hide_render=True
left=bpy.data.objects.new('Deformacao_real',model.data.copy());bpy.context.collection.objects.link(left)
right=bpy.data.objects.new('Mesmo_corpo_esqueleto',left.data);bpy.context.collection.objects.link(right)
if REVISION=='02':
    wire=right.modifiers.new('Malha de arame para ver profundidade real','WIREFRAME')
    wire.thickness=.0015;wire.use_replace=True
    wire_material=bpy.data.materials.new('Malha cinzenta');wire_material.diffuse_color=(.55,.65,.7,1)
    right.material_slots[0].link='OBJECT';right.material_slots[0].material=wire_material
mat=bpy.data.materials.new('Skeleton cyan');mat.diffuse_color=(.0,.85,1,1)
joint_mat=bpy.data.materials.new('Joint yellow');joint_mat.diffuse_color=(1,.65,.02,1)
lines=[];joints=[]
for name,_,_,_ in spec:
    bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.006,depth=1)
    line=bpy.context.object;line.name='Overlay_'+name;line.data.materials.append(mat);lines.append(line)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.012)
    dot=bpy.context.object;dot.name='Joint_'+name;dot.data.materials.append(joint_mat);joints.append(dot)

old_rig=None;old_model=None
if REVISION=='02':
    with bpy.data.libraries.load(str(BASE/'emmet/revisao_01/emmet_articulacao_01.blend'),link=False) as (source,target):
        target.objects=[n for n in source.objects if n in ['Emmet_Rig_Review01','Emmet_Skin']]
    for obj in target.objects:
        bpy.context.collection.objects.link(obj)
        if obj.type=='ARMATURE':old_rig=obj
        elif obj.type=='MESH':old_model=obj;old_model.hide_render=True
    assert old_rig and old_model
    old_rig.animation_data_clear()

def evaluated_copy(obj):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    temp=evaluated.to_mesh();mesh=temp.copy();evaluated.to_mesh_clear()
    return mesh

def view(clip,t):
    global rig,arm_data
    comparison=clip=='03_comparacao_bracos'
    azimuth=2*math.pi*t/8 if clip=='01_esqueleto_360' else (.8 if clip=='03_pernas' else 0)
    focus=1.27 if REVISION=='02' and clip!='01_esqueleto_360' else .91
    camera.data.ortho_scale=3.3 if focus>1 else 4.2
    target=Vector((0,0,focus));camera.location=Vector((5*math.sin(azimuth),-5*math.cos(azimuth),1.05 if REVISION=='01' else focus+.05))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    right_axis=camera.rotation_euler.to_matrix()@Vector((1,0,0))
    near=(camera.location-target).normalized()
    left.location=-right_axis*.70;right.location=right_axis*.70
    actual_clip='02_bracos' if comparison else clip
    pose(actual_clip,t)
    stale={left.data,right.data}
    if comparison:
        new_rig,new_data=rig,arm_data
        try:
            rig,arm_data=old_rig,old_rig.data
            pose(actual_clip,t)
        finally:
            rig,arm_data=new_rig,new_data
        left.data=evaluated_copy(old_model)
        right.data=evaluated_copy(model)
    else:
        mesh=evaluated_copy(model);left.data=mesh;right.data=mesh
    for mesh in stale:
        if mesh.users==0:bpy.data.meshes.remove(mesh)
    if REVISION=='02':
        wire.show_render=not comparison
        right.material_slots[0].material=model.data.materials[0] if comparison else wire_material
    for line,dot,(name,_,_,_) in zip(lines,joints,spec):
        line.hide_render=comparison;dot.hide_render=comparison
        bone=rig.pose.bones[name]
        a=rig.matrix_world@bone.head+right.location
        b=rig.matrix_world@bone.tail+right.location
        # Parallel projection moves lines closer without altering screen positions.
        if REVISION=='01':a+=near*.48;b+=near*.48
        line.location=(a+b)*.5
        line.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();line.scale.z=(b-a).length
        dot.location=a
    bpy.context.view_layer.update()

render_clips=CLIPS if REVISION=='01' else [CLIPS[0],CLIPS[1],('03_comparacao_bracos',8,'Comparacao dos bracos - anterior e corrigido')]
for clip,duration,title in render_clips:
    folder=FRAMES/clip;folder.mkdir(parents=True,exist_ok=True)
    samples=[48] if '--preview' in sys.argv else range(duration*FPS)
    for frame in samples:
        view(clip,frame/FPS)
        scene.render.filepath=str(folder/('%04d.png'%frame))
        bpy.ops.render.render(write_still=True)
    print('CLIP COMPLETE',clip,flush=True)
print('REVIEW RENDER COMPLETE',flush=True)
