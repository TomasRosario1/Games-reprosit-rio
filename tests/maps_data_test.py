"""Validate the delivered data without needing Shapely or any network access."""
import hashlib,json,math,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'assets/maps/generated'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def area(points):return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:]+points[:1]))/2
class MapsData(unittest.TestCase):
 def test_sources_are_original(self):
  for f in read(ROOT/'assets/maps/source/provenance.json')['files']:
   data=(ROOT/'assets/maps/source'/f['file']).read_bytes()
   self.assertEqual(len(data),f['bytes']);self.assertEqual(hashlib.sha256(data).hexdigest(),f['sha256'])
 def test_crops_and_required_streets(self):
  m=read(DATA/'manifest.json');ds=m['districts']
  self.assertEqual([d['id'] for d in ds],['saldanha','bairro_alto','pink_street'])
  for d,name in zip(ds,['Avenida da República','Rua da Barroca','Rua Nova do Carvalho']):
   self.assertIn(name,d['road_names']);self.assertGreater(d['stats']['buildings'],50)
   self.assertGreater(len(d['routes']),0)
   x,z=d['spawn'];a,b,c,e=d['bounds'];self.assertTrue(a<x<c and b<z<e)
   for route in d['routes']:
    for x,z in route:self.assertTrue(a-0.002<=x<=c+0.002 and b-0.002<=z<=e+0.002)
   self.assertGreater(len(d['venues']),0)
  self.assertEqual(m['license'],'ODbL-1.0');self.assertIn('OpenStreetMap',m['attribution'])
 def test_geometry_closed_clipped_and_triangulated(self):
  manifest=read(DATA/'manifest.json');districts={d['id']:d for d in manifest['districts']};ids=set();total=0;courtyards=0;source=0;authored=0
  for spec in manifest['sectors']:
   data=read(ROOT/spec['path'].replace('res://',''));a,b,c,e=districts[spec['district']]['bounds'] if spec['district'] in districts else manifest['peninsula']['bounds']
   for f in data['buildings']:
    self.assertNotIn(f['id'],ids);ids.add(f['id']);total+=1
    authored+=bool(f.get('authored'));source+=not f.get('authored',False)
    self.assertTrue(3<=f['height']<=45)
    self.assertEqual(len(f['roof'])%3,0)
    # Concave roofs and courtyard holes must have exactly the footprint area.
    footprint=sum(area(ring) for ring in f['rings'])
    roof=sum(abs(area(f['roof'][i:i+3])) for i in range(0,len(f['roof']),3))
    self.assertAlmostEqual(footprint,roof,delta=max(0.15,footprint*0.001))
    courtyards+=len(f['rings'])>1
    for ring in f['rings']:
     self.assertGreaterEqual(len(ring),3)
     for x,z in ring:
      x+=f['position'][0];z+=f['position'][1]
      self.assertTrue(a-0.003<=x<=c+0.003 and b-0.003<=z<=e+0.003)
   for surface in data['surfaces']:
    self.assertIn(surface['material'],['asphalt','calcada','pink']);self.assertEqual(len(surface['triangles'])%3,0)
  self.assertEqual(source,598);self.assertGreater(authored,150);self.assertEqual(total,source+authored);self.assertGreater(courtyards,0)
 def test_continuous_peninsula_and_shared_ground_profile(self):
  m=read(DATA/'manifest.json');p=m['peninsula'];ground=m['landscape']['ground']
  self.assertGreater(abs(area(p['polygon'])),700000)
  self.assertEqual(len(ground)%3,0)
  profile=p['profile']
  def height(z):
   for (a,y),(b,w) in zip(profile,profile[1:]):
    if a<=z<=b:return y+(w-y)*(z-a)/(b-a)
   self.fail('terrain vertex outside profile')
  triangle_area=0
  for i in range(0,len(ground),3):
   triangle=ground[i:i+3];triangle_area+=abs(area([[v[0],v[2]] for v in triangle]))
   for x,y,z in triangle:self.assertAlmostEqual(y,height(z),delta=0.00051)
  # Land is complete except the existing legacy block, whose own floor is retained.
  self.assertAlmostEqual(triangle_area,abs(area(p['polygon']))-104*104,delta=0.1)
  self.assertEqual([d['ground_height'] for d in m['districts']],[0,8,0])
  self.assertGreaterEqual(len(m['roads']),25)
  self.assertEqual(m['roads'],p['roads'])
  self.assertTrue(all(r['width']>=8 and len(r['points'])>=2 for r in m['roads']))
  self.assertIn('acesso_ponte',{r['id'] for r in m['roads']})
  # Keep the whole physical approach/deck corridor clear after denser infill.
  # A formerly generated block at x228..246,z988.5..1011.5 cut the ramp.
  for spec in m['sectors']:
   for feature in read(ROOT/spec['path'].replace('res://',''))['buildings']:
    x,z=feature['position'];points=[(x+a,z+b) for ring in feature['rings'] for a,b in ring]
    blocked=min(p[0] for p in points)<247 and max(p[0] for p in points)>233 and min(p[1] for p in points)<1070 and max(p[1] for p in points)>981
    self.assertFalse(blocked,feature['id']+' obstructs the bridge corridor')
  # Each preserved source crop has at least two independent street portals.
  for d in m['districts']:
   self.assertIn('west',d['portals']);self.assertIn('east',d['portals'])
   names={r['id'] for r in m['roads']}
   self.assertIn(d['id']+'_poente',names);self.assertIn(d['id']+'_nascente',names)
 def test_safe_runtime_metadata(self):
  m=read(DATA/'manifest.json')
  for d in m['districts']:
   for venue in d['venues']:self.assertEqual(set(venue),{'id','name','position','type'})
  self.assertEqual(len(m['links']),2+1)
  self.assertEqual(m['links'][1]['points'][0],m['districts'][0]['portals']['south'])
  self.assertEqual(m['links'][1]['points'][-1],m['districts'][1]['portals']['north'])
if __name__=='__main__':unittest.main()
