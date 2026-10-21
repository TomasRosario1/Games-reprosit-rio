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
  manifest=read(DATA/'manifest.json');districts={d['id']:d for d in manifest['districts']};ids=set();total=0;courtyards=0
  for spec in manifest['sectors']:
   data=read(ROOT/spec['path'].replace('res://',''));a,b,c,e=districts[spec['district']]['bounds']
   for f in data['buildings']:
    self.assertNotIn(f['id'],ids);ids.add(f['id']);total+=1
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
  self.assertEqual(total,598);self.assertGreater(courtyards,0)
 def test_safe_runtime_metadata(self):
  m=read(DATA/'manifest.json')
  for d in m['districts']:
   for venue in d['venues']:self.assertEqual(set(venue),{'id','name','position','type'})
  self.assertEqual(len(m['links']),2+1)
  self.assertEqual(m['links'][1]['points'][0],m['districts'][0]['portals']['south'])
  self.assertEqual(m['links'][1]['points'][-1],m['districts'][1]['portals']['north'])
if __name__=='__main__':unittest.main()
