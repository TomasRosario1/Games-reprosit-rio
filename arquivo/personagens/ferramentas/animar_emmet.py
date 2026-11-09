"""Review03: load the approved rig unchanged; bake walking and vehicle entry.
blender -b --python arquivo/personagens/ferramentas/animar_emmet.py -- --preview
blender -b --python arquivo/personagens/ferramentas/animar_emmet.py -- --render
"""
import bpy,math,json,struct,sys,subprocess
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
BASE=Path(__file__).resolve().parent.parent
OUT=BASE/'emmet/revisao_03';OUT.mkdir(exist_ok=True,parents=True)
FRAMES=Path('/tmp/emmet-review-03/frames')
bpy.ops.wm.open_mainfile(filepath=str(BASE/'emmet/revisao_02/emmet_articulacao_02.blend'))
rig=bpy.data.objects['Emmet_Rig_Review02'];model=bpy.data.objects['Emmet_Skin']
rig.name='Emmet_Rig_Animacoes03';rig.animation_data_clear()
REST={b.name:b.matrix_local.copy() for b in rig.data.bones};LENGTH={b.name:b.length for b in rig.data.bones}
ORDER=[b.name for b in rig.data.bones];FPS=24;DURATION=8
# Keep the approved bone placement. Stabilize the trouser seat locally so
# folding the legs does not drag the buttock surface through the seat cushion.
def weight_smooth(a,b,x):
    u=max(0,min(1,(x-a)/(b-a)));return u*u*(3-2*u)
seat_weight_vertices=0
for v in model.data.vertices:
    x,y,z=v.co
    if .75<z<.94 and .07<y<.15 and abs(x)<.21:
        blend=weight_smooth(.75,.82,z)*(1-weight_smooth(.16,.21,abs(x)))*weight_smooth(.07,.12,y)
        if blend>.001:
            old={g.group:g.weight for g in v.groups};pelvis_index=model.vertex_groups['pelvis'].index
            new={k:w*(1-blend) for k,w in old.items()};new[pelvis_index]=new.get(pelvis_index,0)+blend
            for group in model.vertex_groups:group.remove([v.index])
            total=sum(new.values())
            for k,w in new.items():
                if w>1e-7:model.vertex_groups[k].add([v.index],w/total,'REPLACE')
            seat_weight_vertices+=1

metrics={};current='';frame_time=0
V=lambda p:Vector(p)
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def lerp(a,b,t):return V(a).lerp(V(b),smooth(t))
def phase(t,a,b):return smooth((t-a)/(b-a))
def cv(p):return V((-p[0],p[2],p[1]))

def compatible(path):
    data=path.read_bytes();off=12;chunks=[]
    while off<len(data):
        size,kind=struct.unpack_from('<II',data,off);off+=8;chunks.append((kind,data[off:off+size]));off+=size
    g=json.loads(chunks[0][1]);hidden=set()
    def hide(i):
        hidden.add(i)
        for child in g['nodes'][i].get('children',[]):hide(child)
    for i,node in enumerate(g['nodes']):
        if node.get('extensions',{}).get('KHR_node_visibility',{}).get('visible') is False:hide(i)
    for i,node in enumerate(g['nodes']):
        node.get('extensions',{}).pop('KHR_node_visibility',None)
        if i in hidden:node.pop('mesh',None)
    for key in ['extensionsUsed','extensionsRequired']:
        if key in g:g[key]=[x for x in g[key] if x!='KHR_node_visibility']
    j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
    chunks[0]=(0x4e4f534a,j)
    payload=b''.join(struct.pack('<II',len(c),kind)+c for kind,c in chunks)
    out=path.with_name(path.stem.replace('_original','_blender')+'.glb')
    out.write_bytes(struct.pack('<4sII',b'glTF',2,len(payload)+12)+payload)
    return out

def import_vehicle(kind):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(compatible(OUT/'veiculos'/(kind+'_original.glb'))))
    objects=list(set(bpy.context.scene.objects)-before)
    # Godot forward -Z converts to Blender +Y. Turn the imported vehicle so both
    # the approved actor and vehicle face -Y; retain one metric unit per metre.
    turn=Matrix.Rotation(math.pi,4,'Z')
    meshes=[];hinge_children=[]
    for obj in objects:
        if obj.type=='MESH':
            parent=obj.parent
            while parent:
                if parent.name.startswith('PivotPorta'):hinge_children.append(obj);break
                parent=parent.parent
            world=turn@obj.matrix_world
            obj.data.transform(world);obj.parent=None;obj.matrix_world=Matrix.Identity(4)
            meshes.append(obj)
    for obj in objects:
        if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
    return meshes,hinge_children
car_meshes,old_doors=import_vehicle('car')
bike_meshes,_=import_vehicle('motorbike')

def bounds(obj):
    p=[v.co for v in obj.data.vertices]
    return V(tuple(min(v[i]for v in p)for i in range(3))),V(tuple(max(v[i]for v in p)for i in range(3)))
def box(name,at,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if mat:o.data.materials.append(mat)
    return o

def pipe(name,a,b,radius,mat):
    a,b=V(a),V(b);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=radius,depth=(b-a).length,location=(a+b)*.5)
    o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    if mat:o.data.materials.append(mat)
    return o

def cut(obj,at,size):
    cutter=box('Corte_temporario',at,size,None)
    bpy.context.view_layer.objects.active=obj
    m=obj.modifiers.new('Abertura fisica para a entrada','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=cutter
    bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cutter,do_unlink=True)

body=next(o for o in car_meshes if (bounds(o)[1]-bounds(o)[0]).y>3.5 and (bounds(o)[1]-bounds(o)[0]).x>1.5)
paint=body.data.materials[0]
# The game hull is a closed loft. The review needs an actual cabin and aperture,
# rather than moving the actor through the existing opaque slab.
cut(body,(0,.10,1.10),(1.34,1.24,1.52)) # bottom at.34, open cabin below roof
cut(body,(.92,.16,1.0),(.50,1.08,1.30)) # open driver side, sill at.35
for o in old_doors:
    car_meshes.remove(o);bpy.data.objects.remove(o,do_unlink=True)
# Move the B-pillar to the rear edge of the new driver door; source stays intact.
for o in car_meshes:
    lo,hi=bounds(o);size=hi-lo
    if lo.x>.70 and size.x<.08 and .7<size.z<.85 and abs((lo.y+hi.y)*.5-.40)<.05:
        for v in o.data.vertices:v.co.y+=.30
    # Clear glazing in the review lets the body/seat contacts be inspected.
    if (1.6<size.y<2.2 and size.x>1.4 and .8<lo.z<.95 and hi.z>1.55) or any('glass' in m.name.lower() for m in o.data.materials):o.hide_render=True;o['review_glazing_hidden']=True
    center=(lo+hi)*.5
    if len(o.data.vertices)>80 and (center-V((.35,-.48,1.01))).length<.035:
        for v in o.data.vertices:v.co.y+=.20
        o['review_steering_adjusted']=True
assert sum(bool(o.get('review_steering_adjusted',False)) for o in car_meshes)==1
hinge=bpy.data.objects.new('Porta_condutor',None);bpy.context.collection.objects.link(hinge);hinge.location=(.855,-.33,1.05)
new_door=[]
new_door.append(box('Porta_painel',(.875,.17,.75),(.045,.99,.77),paint))
for a,b in [((.875,-.325,1.12),(.68,-.18,1.61)),((.68,-.18,1.61),(.68,.685,1.61)),((.68,.685,1.61),(.875,.685,1.12))]:
    new_door.append(pipe('Moldura_porta',a,b,.018,paint))
handle_mat=bpy.data.materials.new('Puxadores');handle_mat.diffuse_color=(.13,.14,.15,1)
new_door.append(box('Puxador_exterior',(.9,.60,1.03),(.035,.14,.055),handle_mat))
new_door.append(box('Puxador_interior',(.825,.11,1.02),(.035,.18,.045),handle_mat))
for o in new_door:
    world=o.matrix_world.copy();o.parent=hinge;o.matrix_world=world
car_meshes+=new_door
bike_meshes.append(pipe('Descanso_mota',(.17,.25,.39),(.40,.25,.025),.014,handle_mat))
# Static floor and markers are review scenery; they are not exported to clips.
floor_mat=bpy.data.materials.new('Chao_mate');floor_mat.diffuse_color=(.105,.12,.135,1)
floor=box('Chao_revisao',(0,-5,-.035),(50,50,.06),floor_mat)
mark_mat=bpy.data.materials.new('Marcas_solo');mark_mat.diffuse_color=(.23,.26,.29,1)
markers=[]
for y in range(-18,7):markers.append(box('Marca_metro',(0,y,-.002),(6,.013,.005),mark_mat))

state={};POSE={};targets={};active_objects=[]
def reset_body(pos=(0,0,0),yaw=0,lean=0,twist=0,roll=0):
    global POSE,targets
    rig.location=pos;rig.rotation_mode='XYZ';rig.rotation_euler=(0,0,yaw)
    POSE={};targets={}
    for name in ORDER:
        parent=rig.data.bones[name].parent
        POSE[name]=POSE[parent.name]@REST[parent.name].inverted()@REST[name] if parent else REST[name].copy()
        if name=='pelvis':
            head=POSE[name].translation.copy()
            q=Quaternion(V((0,0,1)),twist)@Quaternion(V((0,1,0)),roll)@Quaternion(V((1,0,0)),lean*.30)
            POSE[name]=Matrix.Translation(head)@q.to_matrix().to_4x4()@Matrix.Translation(-head)@POSE[name]
        elif name in ['spine','chest']:
            head=POSE[name].translation.copy();angle=lean*(.42 if name=='spine' else .28)
            POSE[name]=Matrix.Translation(head)@Quaternion(V((1,0,0)),angle).to_matrix().to_4x4()@Matrix.Translation(-head)@POSE[name]

def global_point(p):return rig.matrix_world@p

def to_local(p):return rig.matrix_world.inverted()@V(p)

def align(name,head,tail):
    direction=(tail-head).normalized();old=REST[name].to_3x3().col[1].normalized()
    m=old.rotation_difference(direction).to_matrix().to_4x4()@REST[name];m.translation=head;POSE[name]=m

def solve_pair(a,b,end,target,pole):
    start=POSE[a].translation.copy();offset=target-start;reach=offset.length;l1=LENGTH[a];l2=LENGTH[b]
    d=max(.01,min(reach,l1+l2-.001));direction=offset.normalized()
    target=start+direction*d
    along=(l1*l1-l2*l2+d*d)/(2*d)
    bend=V(pole)-direction*V(pole).dot(direction)
    if bend.length<1e-5:bend=direction.cross(V((1,0,0)))
    bend.normalize();middle=start+direction*along+bend*math.sqrt(max(0,l1*l1-along*along))
    align(a,start,middle);align(b,middle,target)
    return target,max(0,reach-(l1+l2-.001))

shoe={}
for side,sign in [('L',1),('R',-1)]:
    ankle=REST['foot.'+side].translation
    shoe[side]=[v.co-ankle for v in model.data.vertices if v.co.z<.15 and sign*v.co.x>0]

def floor_ankle(side,pitch=0,lift=0):
    q=Quaternion(V((1,0,0)),pitch)
    return -min((q@v).z for v in shoe[side])+lift+.003

def leg(side,ankle,pitch=0,pole=(0,-1,0)):
    name='foot.'+side;target=to_local(ankle)
    target,miss=solve_pair('thigh.'+side,'shin.'+side,name,target,pole)
    m=Quaternion(V((1,0,0)),pitch).to_matrix().to_4x4()@REST[name];m.translation=target;POSE[name]=m
    toe='toe.'+side;POSE[toe]=m@REST[name].inverted()@REST[toe]
    targets[name]=(V(ankle),global_point(target),miss)

def hand(side,palm=None,relaxed=None,elbow=(1,.3,0),weight=1):
    upper='upper_arm.'+side;fore='forearm.'+side;name='hand.'+side
    if palm is None:
        target=V(relaxed);direction=V((0,-.05,-1)).normalized()
    else:
        p=to_local(palm)
        if weight<1:p=V(relaxed)+V((0,-.003,-.065))+(p-V(relaxed)-V((0,-.003,-.065)))*weight
        palm=global_point(p);shoulder=POSE[upper].translation
        direction=(p-shoulder).normalized();target=p-direction*.065
    wrist,miss=solve_pair(upper,fore,name,target,elbow)
    align(name,wrist,wrist+direction*LENGTH[name])
    if palm is not None:targets[name]=(V(palm),global_point(wrist+direction*.065),miss)

def finish():
    # Only one dependency-graph update after all parent-ordered matrices.
    for name in ORDER:
        parent=rig.data.bones[name].parent
        base=POSE[parent.name]@REST[parent.name].inverted()@REST[name] if parent else REST[name]
        rig.pose.bones[name].matrix_basis=base.inverted()@POSE[name]
    bpy.context.view_layer.update()
    for name in ORDER:
        assert max(abs(a-b) for row1,row2 in zip(rig.pose.bones[name].matrix,POSE[name]) for a,b in zip(row1,row2))<.0002,(current,frame_time,name,'pose matrix mismatch')
    data={'time':frame_time,'root':list(rig.location),'targets':{k:{'target':list(t),'actual':list(rig.matrix_world@(rig.pose.bones[k].matrix.translation+(rig.pose.bones[k].matrix.to_3x3().col[1]*.065 if k.startswith('hand.') else V((0,0,0))))),'error':(t-(rig.matrix_world@(rig.pose.bones[k].matrix.translation+(rig.pose.bones[k].matrix.to_3x3().col[1]*.065 if k.startswith('hand.') else V((0,0,0)))))).length,'clamped':m}for k,(t,a,m)in targets.items()}}
    if frame_time>7.4:
        evaluated=model.evaluated_get(bpy.context.evaluated_depsgraph_get());temp=evaluated.to_mesh()
        head=[rig.matrix_world@temp.vertices[v.index].co for v in model.data.vertices if v.co.z>1.55]
        butt=[rig.matrix_world@temp.vertices[v.index].co for v in model.data.vertices if .79<v.co.z<.90 and abs(v.co.x)<.06 and .11<v.co.y<.15]
        data['head_top']=max(p.z for p in head);data['butt_low']=min(p.z for p in butt) if butt else None
        evaluated.to_mesh_clear()
    metrics.setdefault(current,[]).append(data)

def walk_pose(t,pos=None,yaw=0,amount=1):
    period=.9;u=(t/period)%1;speed=.58/(.60*period)
    if pos is None:pos=(.013*math.sin(2*math.pi*u),-speed*t,-.064+.018*math.sin(2*math.pi*u)**2)
    reset_body(pos,yaw,lean=math.radians(2),twist=.035*math.sin(2*math.pi*u),roll=.018*math.sin(2*math.pi*u))
    bpy.context.view_layer.update()
    for side,shift,sign in [('L',0,1),('R',.5,-1)]:
        phase_u=(u+shift)%1
        if phase_u<.6:
            y=-.29+.58*phase_u/.6;lift=0
            pitch=math.radians(-8)*(1-smooth(phase_u/.09)) if phase_u<.09 else math.radians(12)*smooth((phase_u-.47)/.13) if phase_u>.47 else 0
        else:
            s=(phase_u-.6)/.4;y=.29-.58*smooth(s);lift=.105*math.sin(math.pi*s)**1.3;pitch=math.radians(-6)*math.sin(math.pi*s)
        # Feet are placed in world space: stance Y cancels root travel exactly.
        local=V((sign*.13,y,0));world=rig.matrix_world@local;world.x=sign*.13;world.z=floor_ankle(side,pitch,lift)
        leg(side,world,pitch)
        hand(side,relaxed=(sign*.30,.13*math.cos(2*math.pi*(u+shift)),.99),elbow=(sign*.2,1,0))
    finish()

def door_point(local,theta):return hinge.location+Quaternion(V((0,0,1)),theta)@V(local)
def car_pose(t):
    theta=-1.15*phase(t,1.3,2.7)*(1-phase(t,5.0,6.6));hinge.rotation_euler.z=theta
    outer=door_point((.045,.93,-.02),theta)
    inner=door_point((-.03,.44,-.03),theta)
    if t<1.3:
        pos,yaw=car_route(t);lean=math.radians(2+18*phase(t,1.0,1.4))
    elif t<2.7:
        pos=outer+V((.38,.30,-outer.z-.064));yaw=-math.pi/2;lean=math.radians(20)
    elif t<3.6:
        start=door_point((.045,.93,-.02),-1.15)+V((.38,.30,0));start.z=-.064
        pos=lerp(start,(1.12,.40,-.064),(t-2.7)/.9);yaw=-math.pi/2*(1-phase(t,2.7,3.6));lean=math.radians(20)
    elif t<4.6:
        pos=lerp((1.12,.40,-.064),(1.0,.35,-.08),(t-3.6));yaw=0;lean=math.radians(20+40*phase(t,3.6,4.6))
    else:
        pos=lerp((1.,.35,-.08),(.35,.14,-.18),(t-4.6)/1.35);yaw=0;lean=math.radians(60-45*phase(t,4.9,6.0))
    reset_body(pos,yaw,lean);bpy.context.view_layer.update()
    r0=route_feet(3.6,car_route,3.6)['R'];l0=route_feet(3.65,car_route,3.6)['L']
    if t<3.6:
        for side,target in route_feet(t,car_route,3.6).items():leg(side,target)
    else:
        if t<4.6:
            right=lerp(r0,(.50,-.30,.68),(t-3.8)/.8);right.z+=.14*math.sin(math.pi*phase(t,3.8,4.6))
            left=route_feet(min(t,3.65),car_route,3.6)['L']
        else:
            if t<5.1:right=lerp((.50,-.30,.68),(.40,-.30,.46),(t-4.6)/.5)
            elif t<6.2:right=V((.40,-.30,.46))
            else:
                right=lerp((.40,-.30,.46),(.19,-.55,.46),(t-6.2)/.5)
                if t<6.7:right.z+=.025*math.sin(math.pi*phase(t,6.2,6.7))
            if t<5.1:left=V(l0)
            elif t<5.55:left=lerp(l0,(.70,.08,.70),(t-5.1)/.45)
            else:left=lerp((.70,.08,.70),(.51,-.55,.46),(t-5.55)/.65)
        leg('R',right);leg('L',left)
    for side,sign in [('L',1),('R',-1)]:
        contact=None;weight=1
        if side=='L' and t<2.95:
            contact=outer;weight=phase(t,1.0,1.4)*(1-phase(t,2.7,2.95))
        elif side=='L' and 4.9<t<6.9:
            contact=inner.lerp(V((.35+sign*.16,-.28,1.04)),phase(t,6.3,6.9));weight=phase(t,4.9,5.15)
        elif t>5.8:
            contact=V((.35+sign*.16,-.28,1.04));weight=phase(t,5.8,6.4)
        if side=='R' and 4.0<t<5.1:
            contact=V((.855,-.33,1.08));weight=phase(t,4.,4.15)*(1-phase(t,4.85,5.1))
        hand(side,palm=contact,relaxed=(sign*.30,.11*math.cos(t*7+(.0 if side=='L' else math.pi)),1.00),elbow=(sign*.2,1,0),weight=weight)
    finish()

def interpolate_path(t,keys):
    for (a,p),(b,q) in zip(keys,keys[1:]):
        if t<=b:return lerp(p,q,(t-a)/(b-a))
    return V(keys[-1][1])

def car_route(t):
    t=max(0,min(3.6,t))
    if t<1.3:
        return lerp((1.8,1.9,-.064),(1.255,.90,-.064),t/1.3),(-.50+(-math.pi/2+.50)*phase(t,1.,1.3))
    if t<2.7:
        angle=-1.15*phase(t,1.3,2.7)
        p=door_point((.045,.93,-.02),angle)+V((.38,.30,0));p.z=-.064
        return p,-math.pi/2
    start=door_point((.045,.93,-.02),-1.15)+V((.38,.30,0));start.z=-.064
    return lerp(start,(1.12,.40,-.064),(t-2.7)/.9),-math.pi/2*(1-phase(t,2.7,3.6))
def bike_route(t):
    return lerp((.80,1.0,-.064),(.45,-.10,-.064),max(0,min(1.3,t))/1.3),0

def route_feet(t,route,end):
    step=.28;output={}
    def landing(time,side,sign):
        p,yaw=route(min(end,time+step*.5))
        at=V(p)+Quaternion(V((0,0,1)),yaw)@V((sign*.13,.05,0))
        at.z=floor_ankle(side);return at
    for side,sign,offset in [('L',1,0),('R',-1,step)]:
        if t<offset:
            output[side]=landing(0,side,sign);continue
        cycle=math.floor((t-offset)/(2*step));start=offset+cycle*2*step
        before=landing(0 if cycle==0 else start-step,side,sign)
        after=landing(start+step,side,sign)
        if t<start+step and (before-after).length>.01:
            u=(t-start)/step;at=lerp(before,after,u);at.z+=.075*math.sin(math.pi*u)
            output[side]=at
        else:output[side]=after
    return output

def bike_pose(t):
    if t<1.3:pos,yaw=bike_route(t)
    else:
        pos=interpolate_path(t,[(1.3,(.45,-.10,-.064)),(2.,(.45,-.10,-.08)),(3.8,(.15,.15,-.08)),(5.,(0,.15,.11)),(8.,(0,.15,.11))]);yaw=0
    lean=math.radians(2+28*phase(t,.95,1.6)+20*phase(t,3.8,5))
    reset_body(pos,yaw,lean);bpy.context.view_layer.update()
    start=route_feet(1.8,bike_route,1.3)
    left=interpolate_path(t,[(1.3,start['L']),(1.8,start['L']),(1.95,(.52,-.05,floor_ankle('L'))),(3.6,(.52,-.05,floor_ankle('L'))),(4.25,(.43,.06,.49)),(5.,(.30,.05,.535))])
    right=interpolate_path(t,[(1.3,start['R']),(2.,start['R']),(2.8,(.38,.65,1.13)),(3.2,(-.18,.68,1.13)),(3.6,(-.38,.30,.77)),(3.9,(-.30,.05,.535))])
    if 1.8<t<1.95:left.z+=.035*math.sin(math.pi*phase(t,1.8,1.95))
    if t<1.8:
        for side,target in route_feet(t,bike_route,1.3).items():leg(side,target)
    else:
        leg('L',left,pole=(1,-.2,0));leg('R',right,pole=(-1,.3,.2) if 2<t<3.8 else (0,-1,0))
    hand('L',palm=(.30,-.52,1.15),relaxed=(.30,.10*math.cos(t*7),.99),elbow=(.3,1,0),weight=phase(t,1.0,1.8))
    hand('R',palm=(-.30,-.52,1.15),relaxed=(-.30,-.10*math.cos(t*7),.99),elbow=(-.3,1,0),weight=phase(t,3.8,4.8))
    finish()

CLIPS=[('01_andar',walk_pose),('02_entrar_carro',car_pose),('03_montar_mota',bike_pose)]
def visible_for(clip):
    for obj in car_meshes:
        obj.hide_render=clip!='02_entrar_carro' or bool(obj.get('review_glazing_hidden',False));obj.hide_set(obj.hide_render)
    for obj in bike_meshes:
        obj.hide_render=clip!='03_montar_mota';obj.hide_set(obj.hide_render)

def reset():
    rig.animation_data_clear();hinge.animation_data_clear()
    for pb in rig.pose.bones:pb.rotation_mode='QUATERNION';pb.location=(0,0,0);pb.rotation_quaternion=(1,0,0,0);pb.scale=(1,1,1)

# Bake root motion, anatomically solved joints and the actual hinged door.
for current,callback in CLIPS:
    reset();rig.animation_data_create();action=bpy.data.actions.new(current);rig.animation_data.action=action
    hinge.animation_data_create();door_action=bpy.data.actions.new(current+'_porta');hinge.animation_data.action=door_action
    for frame in range(DURATION*FPS):
        frame_time=frame/FPS;callback(frame_time)
        rig.keyframe_insert('location',frame=frame+1);rig.keyframe_insert('rotation_euler',frame=frame+1)
        for name in ORDER:
            pb=rig.pose.bones[name];pb.keyframe_insert('location',frame=frame+1,group=name);pb.keyframe_insert('rotation_quaternion',frame=frame+1,group=name)
        hinge.keyframe_insert('rotation_euler',frame=frame+1)
    action.use_fake_user=True;door_action.use_fake_user=True
    visible_for(current)
    bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=DURATION*FPS;bpy.context.scene.render.fps=FPS
    bpy.context.scene.frame_set(1)
    if '--probe' not in sys.argv:bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(current+'.blend')),compress=True)
# Use one fresh Blender process per source so compatible fake-user actions cannot
# be silently merged into the wrong named clip by the exporter.
if '--probe' not in sys.argv:
    for clip,_ in CLIPS:
        subprocess.run([bpy.app.binary_path,'-t','1','-b','--python',str(BASE/'ferramentas/exportar_animacao_emmet.py'),'--','--clip='+clip],check=True)

reset()
# Render actual baked mesh deformation; no image-generated movement or resampling.
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.display.render_aa='8'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE';scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=True
scene.display.shading.background_type='WORLD';scene.world=bpy.data.worlds.new('Fundo_revisao03');scene.world.color=(.045,.052,.065)
scene.view_settings.view_transform='Standard';scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';scene.camera=cam

def camera_for(clip,t):
    if clip=='01_andar':
        target=V((rig.location.x,rig.location.y,.90));offset=V((3.3,-5.,1.25)) if t<4 else V((5.,.0,.70));cam.data.ortho_scale=3.6
    elif clip=='02_entrar_carro':target=V((.65,.25,.9));offset=V((4.,4.8,2.3)) if t<6 else V((4.,-5.5,2.3));cam.data.ortho_scale=5.9
    else:target=V((.25,.05,.92));offset=V((3.9,5.7,1.9)) if t<4 else V((3.9,-5.7,1.9));cam.data.ortho_scale=4.4
    cam.location=target+offset;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()

if '--preview' in sys.argv or '--render' in sys.argv:
    metrics={}
    for current,callback in CLIPS:
        visible_for(current);folder=FRAMES/current;folder.mkdir(parents=True,exist_ok=True)
        samples=([48] if '--quick' in sys.argv else [0,48,84,108,132,156,180]) if '--preview' in sys.argv else range(FPS*DURATION)
        for frame in samples:
            frame_time=frame/FPS;callback(frame_time);camera_for(current,frame_time)
            scene.render.filepath=str(folder/('%04d.png'%frame));bpy.ops.render.render(write_still=True)
        print('RENDERED',current,flush=True)
# Store only diagnostic contacts and timestamps, no user/game saves.
(OUT/'contactos.json').write_text(json.dumps(metrics,indent=2)+'\n')
report={'source_rig':'../revisao_02/emmet_articulacao_02.blend','approved_rig_unchanged':True,'skin_review_changes':{'trouser_seat_vertices':seat_weight_vertices,'reason':'retain pelvis volume while knees fold into vehicle'},'fps':FPS,'duration_per_clip':DURATION,'vehicle_sources':'scripts/vehicle.gd exported from the actual game','review_only_vehicle_changes':['car cabin and driver-door aperture cut in the closed hull','driver door framed and hinged','driver B-pillar moved to rear of door','steering wheel adjusted20cm toward seat','glazing hidden for inspection','motorbike has visible stationary kickstand'],'clips':[c for c,_ in CLIPS],'game_integration':False,'status':'animacoes_aguardam_feedback'}
(OUT/'relatorio.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print('REVIEW03 COMPLETE',flush=True)
