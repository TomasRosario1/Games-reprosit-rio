"""Find closed street faces in the supplied Saldanha primary-road graph.
Original OpenStreetMap-derived routes, ODbL 1.0 / © OpenStreetMap contributors.
"""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'assets/maps/generated/manifest.json').read_text())
graph={}
for road in m['districts'][0]['major_roads']:
 points=[tuple(p) for p in road['points']]
 for a,b in zip(points,points[1:]):
  if a!=b:graph.setdefault(a,set()).add(b);graph.setdefault(b,set()).add(a)
order={a:sorted(neighbors,key=lambda b:math.atan2(b[1]-a[1],b[0]-a[0])) for a,neighbors in graph.items()}
seen=set();faces=[]
for a in graph:
 for b in sorted(graph[a]):
  edge=(a,b);face=[]
  if edge in seen:continue
  for _ in range(len(graph)*3):
   if edge in seen:break
   seen.add(edge);u,v=edge;face.append(u);neighbors=order[v];edge=(v,neighbors[(neighbors.index(u)-1)%len(neighbors)])
   if edge==(a,b):
    area=sum(p[0]*q[1]-q[0]*p[1] for p,q in zip(face,face[1:]+face[:1]))/2
    if len(face)>4 and 900<area<3500 and max(p[1] for p in face)>180:
     center=(sum(p[0] for p in face)/len(face),sum(p[1] for p in face)/len(face))
     faces.append((math.dist(center,(258,195)),face))
    break
routes=[[[x,0.08,z] for x,z in face] for _,face in sorted(faces)[:2]]
assert len(routes)==2,'Expected two real road cycles near Praça Duque de Saldanha'
(ROOT/'assets/maps/traffic_routes.json').write_text(json.dumps({'attribution':'© OpenStreetMap contributors','license':'ODbL-1.0','routes':routes},separators=(',',':'))+'\n')
print('Saldanha traffic loops:',[len(route) for route in routes])
