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
