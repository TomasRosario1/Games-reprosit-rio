"""Validate original preservation, isolated archive and actual glTF skin/animation data."""
from pathlib import Path
import json,struct,hashlib,math
BASE=Path(__file__).resolve().parent.parent
ROOT=BASE.parents[1]
def glb(path):
    data=path.read_bytes()
    magic,version,size=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and size==len(data),path
    offset=12;chunks={}
    while offset<len(data):
        length,kind=struct.unpack_from('<II',data,offset);offset+=8
        assert offset+length<=len(data)
        chunks[kind]=data[offset:offset+length];offset+=length
    return json.loads(chunks[0x4e4f534a]),chunks[0x004e4942]
def accessor(g,blob,index):
    a=g['accessors'][index];view=g['bufferViews'][a['bufferView']]
    formats={5121:'B',5123:'H',5125:'I',5126:'f'};widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    kind=formats[a['componentType']];width=widths[a['type']];size=struct.calcsize('<'+kind*width)
    start=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',size)
    assert start+(a['count']-1)*stride+size<=view.get('byteOffset',0)+view['byteLength']<=len(blob)
    values=[struct.unpack_from('<'+kind*width,blob,start+i*stride) for i in range(a['count'])]
    assert all(math.isfinite(v) for row in values for v in row)
    return values
assert (BASE/'.gdignore').exists()
catalog=json.loads((BASE/'catalogo.json').read_text());assert len(catalog['characters'])==20
for char in catalog['characters']:
    p=BASE/char['arquivo'];assert hashlib.sha256(p.read_bytes()).hexdigest()==char['sha256']
    original=ROOT/char['game_scene'].removeprefix('res://')
    assert original.read_bytes()==p.read_bytes(),p
    g,_=glb(p)
    assert not any('uri' in x and not x['uri'].startswith('data:') for k in ['buffers','images'] for x in g.get(k,[]))
original=BASE/catalog['incoming'][0]['original']
assert hashlib.sha256(original.read_bytes()).hexdigest()==catalog['incoming'][0]['sha256']
g,_=glb(original);assert not g.get('skins') and not g.get('animations')
g,blob=glb(BASE/'emmet/revisao_01/emmet_articulacao_01.glb')
assert len(g['skins'])==1 and len(g['skins'][0]['joints'])==21
assert {a['name'] for a in g['animations']}=={'02_bracos','03_pernas','04_tronco'}
for index in range(len(g['accessors'])):accessor(g,blob,index)
for mesh in g['meshes']:
    for primitive in mesh['primitives']:
        weights=accessor(g,blob,primitive['attributes']['WEIGHTS_0'])
        joints=accessor(g,blob,primitive['attributes']['JOINTS_0'])
        assert all(abs(sum(row)-1)<0.0001 and min(row)>=0 for row in weights)
        assert all(0<=j<21 for row in joints for j in row)
assert not any('uri' in x and not x['uri'].startswith('data:') for k in ['buffers','images'] for x in g.get(k,[]))
print('ARCHIVE OK: 20 unchanged game snapshots, intact uploaded original, isolated .gdignore, 21-joint skin, normalized weights and 3 real diagnostic clips')

# Review02: independent geometric containment, plus unchanged rest geometry/UVs.
review2=BASE/'emmet/revisao_02'
if (review2/'emmet_articulacao_02.glb').exists():
    old_g,old_blob=g,blob
    g,blob=glb(review2/'emmet_articulacao_02.glb')
    assert len(g['skins'][0]['joints'])==21
    assert {a['name'] for a in g['animations']}=={'02_bracos','03_pernas','04_tronco'}
    p0=old_g['meshes'][0]['primitives'][0];p=g['meshes'][0]['primitives'][0]
    for attribute in ['POSITION','TEXCOORD_0']:
        assert accessor(old_g,old_blob,p0['attributes'][attribute])==accessor(g,blob,p['attributes'][attribute]),attribute
    assert accessor(old_g,old_blob,p0['indices'])==accessor(g,blob,p['indices'])
    weights=accessor(g,blob,p['attributes']['WEIGHTS_0'])
    assert all(abs(sum(row)-1)<0.0001 and min(row)>=0 for row in weights)
    # glTF coordinates (X,Y,Z) -> Blender coordinates (X,-Z,Y).
    vertices=[(x,-z,y) for x,y,z in accessor(g,blob,p['attributes']['POSITION'])]
    indices=[i[0] for i in accessor(g,blob,p['indices'])]
    def depth_intervals(x,z):
        hits=[]
        for index in range(0,len(indices),3):
            a,b,c=[vertices[i] for i in indices[index:index+3]]
            bx,bz=b[0]-a[0],b[2]-a[2];cx,cz=c[0]-a[0],c[2]-a[2];det=bx*cz-bz*cx
            if abs(det)<1e-10:continue
            u=((x-a[0])*cz-(z-a[2])*cx)/det;v=(bx*(z-a[2])-bz*(x-a[0]))/det
            if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6:hits.append(a[1]+u*(b[1]-a[1])+v*(c[1]-a[1]))
        hits=sorted(set(round(y,6) for y in hits))
        return [(hits[i],hits[i+1]) for i in range(0,len(hits)-1,2)]
    report=json.loads((review2/'relatorio.json').read_text())
    skin=g['skins'][0];binds=accessor(g,blob,skin['inverseBindMatrices'])
    actual_heads={}
    for node_index,m in zip(skin['joints'],binds):
        point=[-sum(m[i*4+j]*m[12+j] for j in range(3)) for i in range(3)]
        actual_heads[g['nodes'][node_index]['name']]=(point[0],-point[2],point[1])
    joints={j['name']:j for j in report['joints']}
    for side in ['L','R']:
        for name in ['upper_arm.','forearm.','hand.']:
            intended=joints[name+side]['head'];actual=actual_heads[name+side]
            assert max(abs(a-b) for a,b in zip(intended,actual))<0.0001,(name,actual,intended)
    for joint in report['arm_fit_sections']:
        x,y,z=joint['point'];intervals=depth_intervals(x,z)
        assert any(a+0.03<y<b-0.03 for a,b in intervals),joint
    samples=0
    for side in ['L','R']:
        for name in ['upper_arm.','forearm.']:
            joint=joints[name+side]
            for t in [0.1,0.25,0.5,0.75,0.9]:
                x,y,z=[(1-t)*a+t*b for a,b in zip(joint['head'],joint['tail'])]
                assert any(a<y<b for a,b in depth_intervals(x,z)),(name,side,t,(x,y,z))
                samples+=1
    print('REVIEW02 OK: actual exported shoulder/elbow/wrist bone pivots match fit, all 8 fitted points have 3cm+ depth margin, %d arm-axis samples inside skin, rest geometry/UVs unchanged'%samples)
