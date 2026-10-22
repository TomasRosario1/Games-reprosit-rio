"""Authored compact Lisbon peninsula around the creator's original OSM crops.

The shore, elevation and linking streets are game design geometry, not claims of
geographical accuracy. Source footprint IDs and source local metre scales remain.
"""
import hashlib,math
from shapely.geometry import Polygon,LineString,Point,box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from shapely import constrained_delaunay_triangles

# The Saldanha frontage and all of its entry thresholds sit on the same flat
# platform. Start the hill beyond that block, rather than burying its doors.
PROFILE=[[-900,0],[320,0],[380,8],[710,8],[780,0],[1300,0]]
SHORE=[[-110,-180],[535,-180],[570,100],[570,600],[530,920],[480,1020],[350,1070],[150,1060],[20,980],[-50,800],[-95,420],[-110,100]]
def height(z):
 for (a,y),(b,w) in zip(PROFILE,PROFILE[1:]):
  if a<=z<=b:return y+(w-y)*(z-a)/(b-a)
 return 0

def triangles(poly,offset=(0,0)):
 out=[]
 for t in constrained_delaunay_triangles(poly).geoms:
  p=list(t.exterior.coords)[:3]
  if not t.exterior.is_ccw:p.reverse()
  out.extend([[x-offset[0],z-offset[1]] for x,z in p])
 return out

def compose(manifest,sectors,size):
 land=Polygon(SHORE)
 districts=manifest['districts'];a,b,c=districts
 roads=[]
 def road(id,points,width=11,label=''):
  roads.append({'id':id,'points':points,'width':width,'label':label})
 road('avenida_poente',[[65,80],[65,940]],12,'Avenida da Madrugada')
 road('avenida_nascente',[[435,-120],[435,972]],13,'Avenida do Tejo')
 road('rua_ocidental',[[-35,90],[-35,860],[20,940],[65,940]],8,'Rua da Esperança')
 road('rua_oriental',[[495,-90],[495,900],[435,940]],9,'Rua dos Navegantes')
 road('avenida_norte',[[65,-120],[435,-120]],12,'Avenidas Novas')
 road('lado_b_poente',[[75,0],[75,80],[65,80]],10,'Lado B')
 for z in [200,450,580,840]:
  road('travessa_poente_'+str(z),[[-35,z],[65,z]],8,'Travessa da Noite')
  road('travessa_nascente_'+str(z),[[435,z],[495,z]],8,'Travessa do Tejo')
 for z,label in [(320,'Rua das Avenidas'),(710,'Rua da Vida Noturna'),(972,'Avenida Ribeirinha')]:
  road('travessia_'+str(z),[[65,z],[435,z]],13,label)
 road('saldanha_norte',[a['portals']['north'],[a['portals']['north'][0],-120]],12,'Avenida da República')
 for d in districts:
  west=d['portals']['west'];east=d['portals']['east']
  road(d['id']+'_poente',[[65,west[1]],west],10,d['label'])
  road(d['id']+'_nascente',[east,[435,east[1]]],10,d['label'])
 road('pink_cais',[c['portals']['south'],[c['portals']['south'][0],972]],11,'Cais do Sodré')
 road('acesso_ponte',[[240,972],[240,985]],11,'Ponte 25 de Abril')
 # Links retained for existing progress/route tools; these are now normal streets
 # on solid land with perpendicular city roads, never suspended narrow strips.
 for link in manifest['links']:road(link['id'],link['points'],12,link['id'].replace('_',' ').title())
 roads_union=unary_union([LineString(r['points']).buffer(r['width']/2+2.5,join_style='round') for r in roads])
 source_areas=unary_union([box(*d['bounds']).buffer(1) for d in districts])
 reserved=unary_union([box(221,270,319,311),box(135,653,233,701),box(256,981,354,1022),box(-50,-60,76,62),box(230,975,250,1080)])
 source_blocks=[];source_roads=[]
 for sector in sectors.values():
  for feature in sector['buildings']:
   x,z=feature['position']
   rings=[[(x+a,z+b) for a,b in ring] for ring in feature['rings']]
   source_blocks.append(Polygon(rings[0],rings[1:]))
  for surface in sector['surfaces']:
   vertices=surface['triangles']
   source_roads.extend(Polygon(vertices[i:i+3]) for i in range(0,len(vertices),3))
 source_occupied=unary_union(source_blocks)
 source_road_area=unary_union(source_roads)
 frontages=[]
 # The occupied venues belong to real street rooms: another urban frontage
 # faces them across the road, rather than an isolated row in empty paving.
 for name,start,z,widths in [('saldanha',232,341,[14,12,17,11,16,12]),('bairro_alto',145,732,[11,15,12,17,13]),('pink_street',263,950,[12,13,11,14,12,13])]:
  cursor=start
  for index,width in enumerate(widths):
   poly=box(cursor,z-9,cursor+width,z+9)
   if not poly.intersects(source_occupied) and not poly.intersects(source_road_area) and not poly.intersects(roads_union):
    frontages.append((name,index,poly))
   cursor+=width+0.55
 frontage_area=unary_union([p for _,_,p in frontages])
 # Blocks fill the streets outside the preserved OSM districts. Different widths,
 # roofs and five-six-floor ranges create continuous facades, not one demo lane.
 count=0
 for iz,z in enumerate(range(-92,1002,26)):
  for ix,x in enumerate(range(-62,522,23)):
   digest=int(hashlib.sha256(f'{x}:{z}'.encode()).hexdigest()[:8],16)
   w=15+(digest%5);depth=19+((digest>>3)%6)
   poly=box(x-w/2,z-depth/2,x+w/2,z+depth/2)
   if not land.buffer(-12).covers(poly) or source_areas.intersects(poly) or reserved.intersects(poly) or roads_union.intersects(poly) or frontage_area.intersects(poly):continue
   # Keep stepped streets unobstructed; closed blocks may use a short plinth.
   center=poly.centroid.coords[0];gx=math.floor(x/size);gz=math.floor(z/size);key=f'urban_{gx}_{gz}'
   if key not in sectors:
    sectors[key]={'id':key,'district':'urban','origin':[0,0],'bounds':[gx*size,gz*size,(gx+1)*size,(gz+1)*size],'buildings':[],'surfaces':[],'lamps':[],'signs':[],'monuments':[],'venues':[]}
   poly=orient(poly,sign=1)
   ring=[[a-x,b-z] for a,b in list(poly.exterior.coords)[:-1]]
   h=(3+(digest>>6)%4)*3.1
   sectors[key]['buildings'].append({'id':f'lisboa/urban/block_{ix}_{iz}','position':[x,z],'height':h,'inferred_height':False,'authored':True,'rings':[ring],'roof':triangles(poly,center),'style':digest%4})
   count+=1
 for name,index,poly in frontages:
  poly=orient(poly,sign=1);x,z=poly.centroid.coords[0];gx=math.floor(x/size);gz=math.floor(z/size);key=f'urban_{gx}_{gz}'
  if key not in sectors:sectors[key]={'id':key,'district':'urban','origin':[0,0],'bounds':[gx*size,gz*size,(gx+1)*size,(gz+1)*size],'buildings':[],'surfaces':[],'lamps':[],'signs':[],'monuments':[],'venues':[]}
  ring=[[a-x,b-z] for a,b in list(poly.exterior.coords)[:-1]]
  sectors[key]['buildings'].append({'id':f'lisboa/urban/frontage_{name}_{index}','position':[x,z],'height':(3+index%3)*3.1,'inferred_height':False,'authored':True,'rings':[ring],'roof':triangles(poly,(x,z)),'style':index%4})
  count+=1
 # Split land at regularly spaced rows and profile breakpoints: the ground
 # collision really slopes and uses the same height function as roads/actors.
 ground=[]
 zs=sorted(set(range(-180,1081,24))|{320,380,710,780,1070})
 for x in range(-120,576,24):
  for z0,z1 in zip(zs,zs[1:]):
   tile=land.intersection(box(x,z0,x+24,z1)).difference(box(-42,-52,62,52))
   pieces=[tile] if tile.geom_type=='Polygon' else list(getattr(tile,'geoms',[]))
   for p in pieces:
    if p.geom_type!='Polygon' or p.area<0.01:continue
    for xx,zz in triangles(p):ground.append([xx,height(zz),zz])
 # Shore walls and promenade are visible physical bounds, leaving the northern
 # connection backed by actual inaccessible hills, not invisible edge blockers.
 manifest['peninsula']={'polygon':SHORE,'bounds':[-110,-180,570,1070],'profile':PROFILE,'area_m2':round(land.area),'description':'Composição original compacta inspirada em Lisboa; relevo e costa autorais','roads':roads,'infill_buildings':count}
 manifest['landscape']={'ground':ground,'shore':SHORE,'profile':PROFILE}
 manifest['roads']=roads
 manifest['places']=[{'id':'saldanha','label':'Saldanha','position':a['spawn'],'height':0},{'id':'bairro_alto','label':'Bairro Alto','position':b['spawn'],'height':8},{'id':'pink_street','label':'Pink Street / Cais do Sodré','position':c['spawn'],'height':0},{'id':'cais','label':'Cais do Tejo','position':[390,972],'height':0}]
 for d in districts:d['ground_height']=height(d['spawn'][1])
 print('PENINSULA',round(land.area),'m²; urban infill',count,'buildings; authored roads',len(roads),'; facing nightlife buildings',len(frontages))
