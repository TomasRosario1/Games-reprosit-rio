"""Original low-poly people for Album Visual. Run: blender -b --python tools/generate_characters.py
No external models, clothing, skeletons or animation data are used.
"""
import bpy, math, json, random
from mathutils import Vector
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'characters';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=OUT/'source';SOURCE.mkdir(exist_ok=True);(SOURCE/'.gdignore').write_text('')
PI=math.pi
# Names describe visual wardrobes, not personality or moral behaviour.
PEOPLE=[
 ('male','beto','Camisa e malha','shirt','slim','short',1.83,(.17,.24,.32),(.47,.44,.35),0),
 ('male','alternativo','Casaco comprido','longcoat','slim','sidepart',1.86,(.12,.14,.15),(.15,.16,.17),1),
 ('male','chunga','Fato de treino','tracksuit','track','fade',1.77,(.16,.22,.30),(.13,.19,.27),2),
 ('male','emo','T-shirt e jeans justos','tshirt','skinny','fringe',1.74,(.105,.11,.13),(.12,.13,.16),3),
 ('male','normal','Blusão e ganga','jacket','jeans','short',1.80,(.29,.26,.21),(.18,.23,.29),4),
 ('male','indie','Camisa aberta','overshirt','slim','curly',1.88,(.34,.25,.18),(.29,.27,.20),5),
 ('male','alternativo','Casaco técnico','hoodie','cargo','buzz',1.79,(.18,.23,.19),(.13,.15,.13),6),
 ('male','normal','Sweat e calças largas','sweat','wide','short',1.72,(.39,.37,.33),(.18,.18,.20),7),
 ('male','beto','Polo e chinos','polo','slim','sidepart',1.85,(.29,.15,.18),(.48,.43,.32),8),
 ('male','indie','Blusão de ganga','denim','straight','long',1.81,(.20,.26,.33),(.17,.15,.14),9),
 ('female','beto','Gabardina e saia reta','coat','pencil','bob',1.72,(.48,.42,.32),(.17,.19,.23),10),
 ('female','alternativo','Casaco e saia rodada','jacket','flared','wavy',1.69,(.15,.18,.17),(.25,.13,.18),11),
 ('female','chunga','Sweat e cargo','hoodie','cargo','pony',1.67,(.28,.18,.21),(.20,.23,.20),12),
 ('female','emo','T-shirt e saia plissada','tshirt','pleated','fringe',1.65,(.12,.12,.15),(.22,.18,.24),13),
 ('female','normal','Malha e jeans','sweat','jeans','bob',1.73,(.29,.31,.27),(.17,.23,.30),14),
 ('female','indie','Camisa e saia longa','overshirt','longskirt','long',1.76,(.40,.31,.23),(.25,.28,.23),15),
 ('female','alternativo','Blusão e calças largas','denim','wide','curly',1.70,(.17,.23,.29),(.15,.15,.17),16),
 ('female','normal','Casaco curto e saia','jacket','aline','pony',1.62,(.31,.18,.16),(.36,.31,.23),17),
 ('female','beto','Malha e calças direitas','polo','straight','wavy',1.78,(.32,.28,.24),(.28,.29,.31),18),
 ('female','indie','Casaco comprido e ganga','longcoat','slim','long',1.74,(.20,.23,.24),(.19,.23,.28),19),
]
SKINS=[(.58,.40,.29),(.67,.48,.35),(.44,.29,.21),(.73,.56,.43),(.52,.35,.26),(.65,.46,.33),(.35,.23,.18),(.72,.53,.40),(.60,.43,.33),(.48,.31,.23)]
HAIRS=[(.095,.075,.060),(.065,.052,.045),(.045,.038,.034),(.13,.085,.055),(.18,.12,.075),(.26,.19,.10),(.05,.043,.04),(.22,.12,.075),(.09,.07,.055),(.12,.09,.06)]


def atlas(index, top, bottom):
    """A textured 4x4 atlas: grain, seams, cloth folds, dirt and shoe wear."""
    rng=np.random.default_rng(410+index)
    skin=np.array(SKINS[index%10]);hair=np.array(HAIRS[index%10])
    colors=[skin,top,bottom,(.62,.60,.53),hair,(.105,.105,.10),(.69,.67,.58),(.13,.12,.10),(.25,.26,.25),bottom,top,(.23,.22,.20),(.55,.48,.31),(.33,.32,.29),skin*np.array([.72,.56,.52]),(.06,.055,.05)]
    data=np.zeros((512,512,4),dtype=np.float32);data[:,:,3]=1
    yy,xx=np.mgrid[:128,:128]
    for i,color in enumerate(colors):
        grain=rng.normal(1,.032,(128,128))
        if i not in (0,4,14):
            grain+=.032*np.cos(xx*.48)+.018*np.cos(yy*.71)
            grain-=.12*np.exp(-((xx-22)/7)**2)+.07*np.exp(-((xx-102)/5)**2)
            grain-=.07*np.cos(xx*.075+np.sin(yy*.04))*np.sin(yy*.055)
        else: grain+=.018*np.cos(yy*.05)
        if i in (1,2,9,10):
            grain[:,5:7]*=.63;grain[:,121:123]*=.66
            grain[5:7,:]*=.64;grain[121:123,:]*=.66
            grain[8:10,::4]*=1.25
        pix=np.clip(np.array(color)[None,None,:]*grain[:,:,None],0,1)
        sy,sx=divmod(i,4);data[sy*128:(sy+1)*128,sx*128:(sx+1)*128,:3]=pix
    # Shirt chest panel: collar/placket and deliberately generic printed marks.
    x0,y0=128,0
    if index%3==0:
        data[y0+32:y0+61,x0+52:x0+76,:3]*=.55
        data[y0+36:y0+39,x0+55:x0+73,:3]=(.65,.62,.55)
        data[y0+45:y0+48,x0+56:x0+72,:3]=(.48,.45,.40)
    image=bpy.data.images.new('urban_cloth_%02d'%index,width=512,height=512,alpha=True)
    image.pixels.foreach_set(data.reshape(-1));image.filepath_raw=str(OUT/('person_%02d_atlas.png'%index));image.file_format='PNG';image.save()
    material=bpy.data.materials.new('Urban fabric %02d'%index);material.use_nodes=True
    bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.88
    tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
    material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    noise=material.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=145
    bump=material.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.09;bump.inputs['Distance'].default_value=.008
    material.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);material.node_tree.links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
    return material

class Body:
    def __init__(self):self.v=[];self.f=[];self.uv=[];self.weights=[]
    def vertex(self,p,w):self.v.append(tuple(p));self.weights.append(w);return len(self.v)-1
    def face(self,verts,uv):self.f.append(tuple(verts));self.uv.append(uv)
    def cell(self,u,v,tile):
        return ((tile%4+(0.02+.96*u))/4,(tile//4+(0.02+.96*v))/4)
    def loft(self,rings,tile,weights,segments=10,pleat=0,skip=None):
        # rings: (center x,y,z,radius x,radius y). Seam UVs keep textile resolution stable.
        allrows=[]
        for ri,(cx,cy,z,rx,ry) in enumerate(rings):
            row=[]
            for j in range(segments):
                a=2*PI*j/segments
                r=1+pleat*(1 if j%2==0 else -1)
                w=weights(ri,j,a) if callable(weights) else weights
                row.append(self.vertex((cx+rx*math.cos(a)*r,cy+ry*math.sin(a)*r,z),w))
            allrows.append(row)
        for i in range(len(rings)-1):
            for j in range(segments):
                if skip and skip(i,j,segments):continue
                jj=(j+1)%segments
                points=(allrows[i][j],allrows[i][jj],allrows[i+1][jj],allrows[i+1][j])
                u0=j/segments;u1=(j+1)/segments;v0=i/(len(rings)-1);v1=(i+1)/(len(rings)-1)
                self.face(points,[self.cell(u0,v0,tile),self.cell(u1,v0,tile),self.cell(u1,v1,tile),self.cell(u0,v1,tile)])
        # End caps are triangulated gently, avoiding a cuboid silhouette.
        for row,ri,reverse in [(allrows[0],0,True),(allrows[-1],len(rings)-1,False)]:
            cx,cy,z,rx,ry=rings[ri]
            w=weights(ri,0,0) if callable(weights) else weights
            cap=self.vertex((cx,cy,z),w)
            for j in range(segments):
                ids=(cap,row[(j+1)%segments],row[j]) if reverse else (cap,row[j],row[(j+1)%segments])
                self.face(ids,[self.cell(.5,.5,tile),self.cell(.5+.45*math.cos(j*2*PI/segments),.5+.45*math.sin(j*2*PI/segments),tile),self.cell(.5,.9,tile)])
    def ellipsoid(self,center,scale,tile,bone,segments=8,rings=5):
        cx,cy,cz=center;rx,ry,rz=scale
        rr=[]
        for i in range(rings+1):
            a=-PI/2+PI*i/rings
            rr.append((cx,cy,cz+rz*math.sin(a),max(.002,rx*math.cos(a)),max(.002,ry*math.cos(a))))
        self.loft(rr,tile,{bone:1},segments)
    def polygon(self,points,tile,bone):
        idx=[self.vertex(p,{bone:1}) for p in points]
        self.face(idx,[self.cell(i%2,(i//2)%2,tile) for i in range(len(idx))])
    def mesh(self,name,material,rig):
        data=bpy.data.meshes.new(name);data.from_pydata(self.v,[],self.f);data.update()
        obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(material)
        uv=data.uv_layers.new(name='UrbanAtlas')
        for poly,faceuv in zip(data.polygons,self.uv):
            poly.use_smooth=True
            for li,co in zip(poly.loop_indices,faceuv):uv.data[li].uv=co
        groups={}
        for i,w in enumerate(self.weights):
            total=sum(w.values())
            for bone,value in w.items():
                if value<.001:continue
                if bone not in groups:groups[bone]=obj.vertex_groups.new(name=bone)
                groups[bone].add([i],value/total,'REPLACE')
        arm=obj.modifiers.new('Human skeleton','ARMATURE');arm.object=rig
        obj.parent=rig
        return obj


def mix_z(z, joint, a, b, spread=.075):
    t=max(0,min(1,(z-joint+spread)/(spread*2)))
    return {a:t,b:1-t}

def make_body(index,entry,rig,material):
    gender,style,name,top,bottom,hair,height,tc,bc,_=entry
    female=gender=='female';bulk=[1.02,.96,1.13,.90,1.06,.94,1.15,1.07,1.01,.98][index%10]
    body=Body();hip=.162 if female else .148;waist=.125 if female else .148;chest=.173 if female else .195
    hip*=bulk;waist*=bulk;chest*=bulk
    top_tile=1
    # Torso silhouette explicitly models pelvis, waist, ribcage, chest and trapezius.
    torso=[(0,0,.94,hip,.102),(0,0,1.02,hip*1.04,.111),(0,-.004,1.11,waist,.095),(0,0,1.23,chest*.94,.112),(0,.007,1.34,chest,.123),(0,0,1.43,.226*bulk,.108),(0,0,1.49,.193*bulk,.09),(0,0,1.55,.069,.067)]
    if top in ['hoodie','sweat']:torso=[(x,y,z,rx*1.10,ry*1.11) for x,y,z,rx,ry in torso]
    if top in ['longcoat','coat']:
        torso=[(0,0,.58,.205*bulk,.126),(0,0,.78,.19*bulk,.122)]+torso
    def torso_w(ri,j,a):
        z=torso[ri][2]
        if z<1.04:return {'pelvis':1}
        if z<1.21:return mix_z(z,1.12,'spine','pelvis')
        return mix_z(z,1.33,'chest','spine')
    body.loft(torso,top_tile,torso_w,segments=12)
    # Neck follows an actual taper rather than the top of a rectangular torso.
    body.loft([(0,0,1.50,.068,.064),(0,.002,1.59,.063,.06),(0,.005,1.635,.07,.062)],0,{'neck':1},10)
    # Clothed collar / shirt opening, gently standing away from the chest.
    front=.125
    if top in ['shirt','polo','overshirt','longcoat','coat']:
        body.polygon([(-.07,front,1.47),(-.025,front+.004,1.36),(0,front+.006,1.49),(-.04,.09,1.535)],3,'chest')
        body.polygon([(.07,front,1.47),(.04,.09,1.535),(0,front+.006,1.49),(.025,front+.004,1.36)],3,'chest')
    else:
        body.loft([(0,.002,1.515,.074,.068),(0,.002,1.535,.070,.064)],top_tile,{'neck':1},12)
    if top in ['longcoat','coat','jacket','denim','overshirt']:
        for s in [-1,1]:
            body.polygon([(s*.055,.14,1.50),(s*.135,.122,1.39),(s*.065,.13,1.23),(s*.022,.14,1.37)],10,'chest')
    # Jaw, cheeks, temple and skull contours. Slight sex variation; adult proportions.
    width=.96 if female else 1.0
    head=[(0,.016,1.615,.047*width,.052),(0,.022,1.638,.071*width,.066),(0,.015,1.685,.093*width,.083),(0,.004,1.746,.103*width,.091),(0,-.002,1.802,.097*width,.088),(0,-.005,1.842,.073*width,.069),(0,-.007,1.86,.022,.024)]
    body.loft(head,0,{'head':1},12)
    # Nose bridge and tip have their own planes. Small ears, lips, eyelids and brows.
    body.loft([(0,.086,1.696,.021,.018),(0,.127,1.713,.021,.024),(0,.114,1.749,.011,.014),(0,.090,1.769,.010,.012)],0,{'head':1},6)
    for s in [-1,1]:
        body.ellipsoid((s*.103,-.002,1.735),(.017,.023,.036),0,'head',6,4)
        body.ellipsoid((s*.041,.087,1.757),(.024,.009,.010),6,'head',8,3)
        body.ellipsoid((s*.041,.094,1.756),(.009,.004,.008),7,'head',6,3)
        body.polygon([(s*.020,.098,1.779),(s*.068,.085,1.779),(s*.066,.087,1.785),(s*.019,.099,1.784)],4,'head')
    body.ellipsoid((0,.089,1.672),(.031,.006,.005),14,'head',8,3)
    # Upper arms: contoured deltoid/biceps -> elbow -> forearm -> wrist, skinning blends.
    sleeve_short=top in ['tshirt','polo','shirt']
    for s,side in [(-1,'L'),(1,'R')]:
        arm=[(s*.205,0,1.475,.071*bulk,.076),(s*.239,0,1.435,.078*bulk,.080),(s*.266,0,1.35,.070*bulk,.071),(s*.287,.003,1.24,.054*bulk,.057),(s*.297,.006,1.19,.052,.054),(s*.311,.014,1.10,.052,.055),(s*.327,.018,.98,.037,.041),(s*.330,.020,.94,.033,.037)]
        def arm_w(ri,j,a,side=side):return mix_z(arm[ri][2],1.19,'upper_arm.'+side,'forearm.'+side,.07)
        if sleeve_short:
            body.loft(arm[:4],top_tile,lambda ri,j,a,side=side:{'upper_arm.'+side:1},10)
            rest=arm[3:]
            body.loft(rest,0,lambda ri,j,a,side=side:mix_z(rest[ri][2],1.19,'upper_arm.'+side,'forearm.'+side,.065),10)
        else:body.loft(arm,top_tile,arm_w,10)
        handbone='hand.'+side
        body.loft([(s*.33,.019,.955,.034,.036),(s*.338,.029,.92,.045,.025),(s*.342,.032,.865,.042,.023),(s*.34,.034,.837,.026,.018)],0,{handbone:1},8)
        body.ellipsoid((s*.303,.052,.901),(.018,.018,.036),0,handbone,6,3)
        # Hip/thigh, patella and calf shapes; skin or trousers depending on outfit.
        leg=[(s*.092,0,.975,.096*bulk,.106),(s*.099,.005,.90,.094*bulk,.107),(s*.103,.014,.79,.085*bulk,.095),(s*.105,.015,.64,.065*bulk,.072),(s*.105,.014,.54,.055*bulk,.061),(s*.104,.005,.49,.054*bulk,.060),(s*.102,-.010,.38,.063*bulk,.069),(s*.101,-.006,.25,.046*bulk,.049),(s*.100,0,.12,.033,.039)]
        if bottom in ['wide','track','cargo','straight']:
            extra={'wide':.038,'track':.021,'cargo':.027,'straight':.015}[bottom]
            leg=[(x,y,z,rx+extra,ry+extra*.6) for x,y,z,rx,ry in leg]
        if bottom=='skinny':leg=[(x,y,z,rx*.89,ry*.89) for x,y,z,rx,ry in leg]
        tile=0 if bottom in ['pencil','flared','pleated','longskirt','aline'] else 2
        body.loft(leg,tile,lambda ri,j,a,side=side:mix_z(leg[ri][2],.535,'thigh.'+side,'shin.'+side,.07),10)
        # Shoe has toe-box, heel, sole and ankle rather than a rectangular foot.
        body.loft([(s*.1,.055,.018,.071,.145),(s*.1,.055,.048,.078,.153),(s*.1,.050,.080,.078,.150),(s*.1,.028,.119,.070,.127),(s*.1,.002,.163,.044,.060)],5,{'foot.'+side:1},10)
        body.loft([(s*.1,.055,.018,.073,.147),(s*.1,.055,.040,.080,.155)],11,{'foot.'+side:1},10)
        # A subtle seam/lace patch defines footwear without high geometry cost.
        body.polygon([(s*.1-.036,.07,.14),(s*.1+.036,.07,.14),(s*.1+.03,.15,.10),(s*.1-.03,.15,.10)],6,'foot.'+side)
    if bottom in ['pencil','flared','pleated','longskirt','aline']:
        end={'pencil':.56,'flared':.57,'pleated':.64,'longskirt':.30,'aline':.68}[bottom]
        radius={'pencil':.165,'flared':.28,'pleated':.245,'longskirt':.29,'aline':.235}[bottom]*bulk
        skirt=[(0,0,end,radius,.13 if bottom=='pencil' else radius*.66),(0,0,(end+.99)*.5,(radius+hip)*.5,.13),(0,0,.99,hip*1.04,.112),(0,0,1.055,waist*1.08,.102)]
        body.loft(skirt,9,lambda ri,j,a:{'pelvis':1},segments=16 if bottom=='pleated' else 12,pleat=.045 if bottom=='pleated' else 0)
    # Hair changes the silhouette. Long/bob styles leave the face open below forehead.
    if hair in ['long','wavy','bob','fringe','pony']:
        bottomz={'long':1.30,'wavy':1.43,'bob':1.59,'fringe':1.67,'pony':1.68}[hair]
        hr=[(0,-.037,bottomz,.12,.074),(0,-.025,1.68,.121,.104),(0,-.010,1.79,.111,.105),(0,-.013,1.847,.084,.08),(0,-.013,1.881,.018,.02)]
        def skip(i,j,n):
            a=(j+.5)*2*PI/n
            return i<2 and math.sin(a)>.23
        body.loft(hr,4,{'head':1},12,pleat=.035 if hair=='wavy' else 0,skip=skip)
        if hair=='pony':
            body.ellipsoid((0,-.13,1.67),(.056,.055,.16),4,'head',8,5)
        if hair=='fringe':
            body.polygon([(-.105,.065,1.817),(.07,.101,1.818),(.057,.102,1.719),(-.04,.105,1.772)],4,'head')
    else:
        hr=[(0,-.014,1.775,.106,.09),(0,-.012,1.827,.096,.089),(0,-.012,1.866,.060,.061),(0,-.012,1.879,.012,.015)]
        if hair=='buzz':hr=[(x,y,z-.014,rx*.97,ry*.97) for x,y,z,rx,ry in hr]
        body.loft(hr,4,{'head':1},12,pleat=.035 if hair=='curly' else 0)
        if hair=='curly':
            for k in range(7):
                a=2*PI*k/7
                body.ellipsoid((.07*math.cos(a),-.008+.06*math.sin(a),1.846),(.035,.033,.037),4,'head',6,3)
    if index in [0,8,10,18]:
        # A collar line gives the conservative wardrobes a visibly different neckline.
        body.loft([(0,0,1.53,.074,.070),(0,0,1.56,.068,.064)],3,{'neck':1},10)
    if top=='hoodie':
        body.ellipsoid((0,-.075,1.485),(.102,.066,.075),10,'chest',10,4)
    if index in [5,11,16]:
        # Small shoulder strap: wardrobe prop, not a separate box-shaped body.
        body.polygon([(-.16,.125,1.46),(-.12,.13,1.46),(.16,.119,.99),(.12,.12,.99)],5,'spine')
    mesh=body.mesh('person_%02d'%index,material,rig)
    return mesh


def build_rig():
    arm=bpy.data.armatures.new('LisboaHumanSkeleton');rig=bpy.data.objects.new('HumanRig',arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    defs=[('root',(0,0,0),(0,0,.15),None),('pelvis',(0,0,.96),(0,0,1.10),'root'),('spine',(0,0,1.10),(0,0,1.33),'pelvis'),('chest',(0,0,1.33),(0,0,1.53),'spine'),('neck',(0,0,1.53),(0,0,1.635),'chest'),('head',(0,0,1.635),(0,0,1.86),'neck')]
    for s,side in [(-1,'L'),(1,'R')]:
        defs += [('upper_arm.'+side,(s*.22,0,1.475),(s*.297,.006,1.19),'chest'),('forearm.'+side,(s*.297,.006,1.19),(s*.33,.02,.94),'upper_arm.'+side),('hand.'+side,(s*.33,.02,.94),(s*.34,.03,.84),'forearm.'+side),('thigh.'+side,(s*.095,0,.96),(s*.105,.014,.535),'pelvis'),('shin.'+side,(s*.105,.014,.535),(s*.1,0,.12),'thigh.'+side),('foot.'+side,(s*.1,0,.12),(s*.1,.20,.07),'shin.'+side)]
    for name,head,tail,parent in defs:
        bone=arm.edit_bones.new(name);bone.head=head;bone.tail=tail
        if parent:bone.parent=arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
    return rig


def make_animations(rig):
    """Bake anatomical joint positions, expressed in armature/world axes.

    Blender pose-bone local Y follows a bone, so a root.location.z is not world
    up. Older clips accidentally translated crouch along the street and an IK
    pole flipped the feet backwards. Every frame now solves a forward-knee
    two-link chain and independently preserves the toe's +Y forward direction.
    The exporter converts this shared +Y forward / +Z up convention to Godot
    -Z forward / +Y up. No runtime IK or external animation assets are needed.
    """
    from mathutils import Matrix, Quaternion
    scene=bpy.context.scene;scene.render.fps=30
    rests={bone.name:bone.matrix_local.copy() for bone in rig.data.bones}
    lengths={bone.name:bone.length for bone in rig.data.bones}
    order=[bone.name for bone in rig.data.bones]
    clips=[('idle',54),('walk',27),('run',21),('crouch',36),('crouch_idle',54),('jump',18),('fall',24),('land',12),('talk',48),('flinch',18),('dance',40)]
    result=[]
    def refresh():bpy.context.view_layer.update()
    def set_matrix(name,matrix):
        rig.pose.bones[name].matrix=matrix
        refresh()
    def parent_rest_pose(name):
        pb=rig.pose.bones[name]
        return pb.parent.matrix @ rests[pb.parent.name].inverted() @ rests[name] if pb.parent else rests[name].copy()
    def rotate(name,axis,angle):
        base=parent_rest_pose(name);head=base.translation.copy()
        rot=Quaternion(Vector(axis),angle).to_matrix().to_4x4()
        set_matrix(name,Matrix.Translation(head) @ rot @ Matrix.Translation(-head) @ base)
    def align(name,head,tail):
        old=rests[name].to_3x3().col[1].normalized()
        delta=old.rotation_difference((tail-head).normalized()).to_matrix().to_4x4()
        matrix=delta @ rests[name];matrix.translation=head
        set_matrix(name,matrix)
    def leg(side,ankle,foot_pitch=0):
        thigh='thigh.'+side;shin='shin.'+side;foot='foot.'+side
        hip=parent_rest_pose(thigh).translation
        offset=ankle-hip;distance=offset.length
        l1=lengths[thigh];l2=lengths[shin]
        distance=max(.03,min(distance,l1+l2-.001))
        direction=offset.normalized();ankle=hip+direction*distance
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        pole=Vector((0,1,0));pole=(pole-direction*pole.dot(direction)).normalized()
        knee=hip+direction*along+pole*math.sqrt(max(0,l1*l1-along*along))
        align(thigh,hip,knee);align(shin,knee,ankle)
        orientation=Quaternion(Vector((1,0,0)),foot_pitch).to_matrix().to_4x4() @ rests[foot]
        orientation.translation=ankle
        set_matrix(foot,orientation)
    def arm(side,hand,elbow_hint):
        upper='upper_arm.'+side;fore='forearm.'+side;handbone='hand.'+side
        shoulder=parent_rest_pose(upper).translation
        offset=hand-shoulder;distance=min(offset.length,lengths[upper]+lengths[fore]-.004)
        direction=offset.normalized();hand=shoulder+direction*distance
        l1=lengths[upper];l2=lengths[fore];along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        pole=(elbow_hint-direction*elbow_hint.dot(direction)).normalized()
        elbow=shoulder+direction*along+pole*math.sqrt(max(0,l1*l1-along*along))
        align(upper,shoulder,elbow);align(fore,elbow,hand)
        palm=parent_rest_pose(handbone);palm.translation=hand;set_matrix(handbone,palm)
    for clip,length in clips:
        rig.animation_data_clear()
        action=bpy.data.actions.new(clip);rig.animation_data_create();rig.animation_data.action=action
        for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
        for f in range(length+1):
            phase=2*PI*f/length
            for pb in rig.pose.bones:
                pb.location=(0,0,0);pb.rotation_quaternion=(1,0,0,0);pb.scale=(1,1,1)
            refresh()
            feet={};pitches={};crouched=clip in ['crouch','crouch_idle']
            moving=clip in ['walk','run','crouch']
            if moving:
                span={'walk':.82,'run':1.12,'crouch':.38}[clip]
                stance=.60 if clip!='run' else .42
                for side,shift in [('L',0),('R',.5)]:
                    t=(f/length+shift)%1
                    if t<stance:
                        portion=t/stance;y=span*(.5-portion);lift=0
                        pitch=(.10*(1-portion*4) if portion<.25 else -.15*((portion-.75)*4) if portion>.75 else 0)
                    else:
                        portion=(t-stance)/(1-stance);y=span*(-.5+portion)
                        lift=math.sin(portion*PI)*(.23 if clip=='run' else .09 if clip=='walk' else .055)
                        pitch=-.08*math.sin(portion*PI)
                    feet[side]=Vector((-.10 if side=='L' else .10,y,.12+lift));pitches[side]=pitch
            else:
                feet={side:Vector((s*.10,0,.12)) for s,side in [(-1,'L'),(1,'R')]};pitches={'L':0,'R':0}
            if crouched:
                root_offset=Vector((.006*math.sin(phase),-.14,-.555+.006*math.cos(phase*2)))
            elif moving:
                reach=max(abs(feet[side].y) for side in feet)
                max_height=.12+math.sqrt(max(.05,(lengths['thigh.L']+lengths['shin.L']-.006)**2-reach**2))
                hip_height=min(.94,max_height-.014)
                root_offset=Vector((.009*math.sin(phase),0,hip_height-.96))
            else:root_offset=Vector((0,0,.002*math.sin(phase)))
            if clip=='jump':
                feet['L']=Vector((-.1,.10,.36));feet['R']=Vector((.1,-.18,.31));root_offset.z=-.04
            elif clip=='fall':
                feet['L']=Vector((-.1,.03,.16));feet['R']=Vector((.1,-.06,.20));root_offset.z=-.025
            elif clip=='land':root_offset=Vector((0,-.025,-.16*math.sin(PI*f/length)))
            elif clip=='dance':root_offset.z=.018*math.sin(phase*2)-.025
            elif clip=='flinch':root_offset.z=-.035*math.sin(PI*f/length)
            set_matrix('root',Matrix.Translation(root_offset) @ rests['root'])
            rotate('pelvis',(0,0,1),(.035 if moving else .012)*math.sin(phase))
            rotate('spine',(1,0,0),-.36 if crouched else -.08 if clip=='run' else -.015)
            rotate('chest',(1,0,0),-.19 if crouched else -.08 if clip=='run' else .008*math.sin(phase))
            if clip in ['walk','run','dance']:
                base=rig.pose.bones['chest'].matrix.copy();pivot=base.translation.copy()
                twist=Quaternion(Vector((0,0,1)),-.055*math.sin(phase)).to_matrix().to_4x4()
                set_matrix('chest',Matrix.Translation(pivot) @ twist @ Matrix.Translation(-pivot) @ base)
            rotate('neck',(1,0,0),.20 if crouched else 0)
            rotate('head',(1,0,0),.18 if crouched else .012*math.sin(phase))
            for s,side in [(-1,'L'),(1,'R')]:
                arm_phase=phase+(PI if side=='R' else 0)
                shoulder=parent_rest_pose('upper_arm.'+side).translation
                if crouched:
                    hand=Vector((s*.29,.32-feet[side].y*.25 if moving else .32,.70))
                    hint=Vector((s*.3,-.25,-1))
                elif clip=='run':
                    hand=shoulder+Vector((s*.10,-.08-feet[side].y*.45,-.28))
                    hint=Vector((s*.45,-.7,-1))
                elif clip=='walk':
                    hand=shoulder+Vector((s*.09,-feet[side].y*.54,-.48))
                    hint=Vector((s*.35,-.6,-1))
                elif clip=='dance' and side=='R':
                    hand=Vector((s*.24,.25,1.55+.035*math.sin(phase*2)));hint=Vector((s*.9,-1,0))
                elif clip=='talk':
                    hand=shoulder+Vector((s*.10,.17+.045*math.sin(phase+s),-.30));hint=Vector((s*.5,-.6,-1))
                elif clip in ['jump','fall']:
                    hand=shoulder+Vector((s*.22,.06,-.25));hint=Vector((s*.7,-.4,-1))
                elif clip=='flinch':
                    hit=math.sin(PI*f/length);hand=shoulder+Vector((s*.10,.20*hit,-.45+.15*hit));hint=Vector((s*.6,-.5,-1))
                else:
                    hand=shoulder+Vector((s*.11,.018,-.51));hint=Vector((s*.5,-.5,-1))
                arm(side,hand,hint)
                leg(side,feet[side],pitches[side])
            for pb in rig.pose.bones:
                pb.keyframe_insert('location',frame=f)
                pb.keyframe_insert('rotation_quaternion',frame=f)
                pb.keyframe_insert('scale',frame=f)
        action.use_fake_user=True;result.append(action)
        for curve in action.fcurves:
            for point in curve.keyframe_points:point.interpolation='LINEAR'
    rig.animation_data_clear()
    for action in result:
        track=rig.animation_data_create().nla_tracks.new();track.name=action.name
        strip=track.strips.new(action.name,0,action);strip.action_frame_start=0;strip.action_frame_end=action.frame_range[1];track.mute=True
    return result


def main():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    rig=build_rig();actions=make_animations(rig)
    catalog=[]
    for index,entry in enumerate(PEOPLE):
        material=atlas(index,entry[7],entry[8]);mesh=make_body(index,entry,rig,material)
        rig.name='HumanRig';rig.scale=(entry[6]/1.86,)*3
        rig.animation_data.action=actions[0]
        scene=bpy.context.scene;scene.frame_set(0)
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
        path=OUT/('person_%02d.glb'%index)
        # Export actions separately, with sampling so baked deformation is portable.
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_skins=True,export_yup=True,export_materials='EXPORT',export_image_format='AUTO')
        triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
        catalog.append({'id':index,'gender':entry[0],'style':entry[1],'name':entry[2],'outfit':entry[3]+' / '+entry[4],'height':entry[6],'scene':'res://assets/characters/'+path.name,'triangles':triangles,'animations':[a.name for a in actions],'pose_revision':2,'forward_axis':'-Z','locomotion_reference_speed':{'walk':1.52,'run':3.81,'crouch':.53}})
        print('CHARACTER',index,'triangles',triangles,flush=True)
        if index==0:
            bpy.ops.file.pack_all()
            bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'human_source.blend'))
        bpy.data.objects.remove(mesh,do_unlink=True)
    (OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    (OUT/'README.md').write_text('# Personagens originais\n\n20 adultos low-poly (10 homens e 10 mulheres) criados proceduralmente para este projeto. Não usam modelos ou animações GTA. Malhas trianguladas no GLB, texturas urbanas originais e rig humano de 18 ossos com movimentos anatómicos cozidos nos clips. Os joelhos são resolvidos para a frente, os pés mantêm a orientação do rosto e o agachar baixa a bacia no eixo vertical. Há clips próprios de agachar parado, salto, queda e aterragem.\n\nRegenerar: `blender -b --python tools/generate_characters.py`. `source/human_source.blend` contém o primeiro corpo e rig para edição no Blender; os restantes GLB também podem ser importados. As identidades são estudos de guarda-roupa e não determinam a personalidade dos NPCs.\n\nOs clips são animação original por articulações, sem captura de movimento nem dados dos jogos de referência. O controlador conserva a fase da passada ao mudar de velocidade e sobe degraus baixos com folga para a cabeça.\n')
    print('DONE 20 originals',flush=True)

if __name__=='__main__':main()
