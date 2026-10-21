"""Crop the user's OSM uploads into offline, metric, independently streamed sectors.

Run with Python + tools/requirements-maps.txt. No network requests or OSM metadata
instructions are executed. Geometry is generated from whitelisted spatial tags.
"""
from __future__ import annotations
from collections import defaultdict
from pathlib import Path
import hashlib, json, math, re, xml.etree.ElementTree as ET
from shapely import constrained_delaunay_triangles, make_valid
from shapely.geometry import Polygon, LineString, Point, box
from shapely.geometry.polygon import orient
from shapely.ops import polygonize, unary_union

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/maps/source'
OUT = ROOT / 'assets/maps/generated'
CONFIG = ROOT / 'tools/map_crops.json'
DRIVE = {'primary','secondary','tertiary','primary_link','secondary_link','tertiary_link','residential','living_street','service','unclassified'}
WALK = {'pedestrian','footway','path','steps','cycleway'}

def compact(value):
    if isinstance(value,float): return round(value,3)
    if isinstance(value,dict): return {k:([round(x,7) for x in v] if k=='geo_origin' else compact(v)) for k,v in value.items()}
    if isinstance(value,(list,tuple)): return [compact(v) for v in value]
    return value

def save(path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(compact(data),ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')

def polygons(geometry):
    if geometry.is_empty: return []
    if geometry.geom_type=='Polygon': return [geometry]
    return [p for g in getattr(geometry,'geoms',[]) for p in polygons(g)]

def lines(geometry):
    if geometry.is_empty: return []
    if geometry.geom_type=='LineString': return [geometry]
    return [p for g in getattr(geometry,'geoms',[]) for p in lines(g)]

def number(text,default):
    match=re.search(r'-?\d+(?:\.\d+)?',str(text or ''))
    return float(match.group()) if match else default

def parse(path):
    if b'<!DOCTYPE' in path.read_bytes()[:8192]: raise ValueError('Unexpected XML doctype')
    root=ET.parse(path).getroot()
    if root.tag!='osm': raise ValueError('Not an OSM document')
    nodes={};ways={};relations=[];pois=[]
    for e in root:
        tags={t.attrib['k']:t.attrib['v'] for t in e.findall('tag')}
        if e.tag=='node':
            at=(float(e.attrib['lat']),float(e.attrib['lon']))
            nodes[e.attrib['id']]=at
            if tags.get('amenity') in {'pub','bar','nightclub','cafe'}: pois.append((e.attrib['id'],at,tags))
        elif e.tag=='way': ways[e.attrib['id']]=([n.attrib['ref'] for n in e.findall('nd')],tags)
        elif e.tag=='relation' and tags.get('type')=='multipolygon' and ('building' in tags or 'building:part' in tags):
            relations.append((e.attrib['id'],[(m.attrib.get('ref'),m.attrib.get('role','outer')) for m in e.findall('member') if m.attrib.get('type')=='way'],tags))
    return nodes,ways,relations,pois,root.find('bounds').attrib

def triangle_points(poly,offset=(0,0)):
    result=[]
    for tri in constrained_delaunay_triangles(poly).geoms:
        coords=list(tri.exterior.coords)[:3]
        if not tri.exterior.is_ccw: coords.reverse()  # Godot's clockwise front faces, viewed from +Y in X/Z.
        result.extend([[x-offset[0],z-offset[1]] for x,z in coords])
    return result

def main():
    config=json.loads(CONFIG.read_text());size=config['sector_size'];cache={}
    manifest={'version':1,'sector_size':size,'attribution':'© OpenStreetMap contributors','license':'ODbL-1.0','source_archive':'Maps.rar','districts':[],'sectors':[],'links':[]}
    OUT.mkdir(parents=True,exist_ok=True)
    for old in OUT.glob('*.json'): old.unlink()
    all_sectors={}
    for spec in config['districts']:
        path=SOURCE/spec['source']
        if path.name not in cache: cache[path.name]=parse(path)
        nodes,ways,relations,pois,source_bounds=cache[path.name]
        lat0,lon0=spec['geo_origin'];ox,oz=spec['world_origin'];bounds=box(*spec['crop'])
        def project(at):
            lat,lon=at
            return ((lon-lon0)*math.pi/180*6371008.8*math.cos(math.radians(lat0)),-(lat-lat0)*math.pi/180*6371008.8)
        def coords(refs):return [project(nodes[n]) for n in refs if n in nodes]
        def sector_at(point):
            x,z=point;gx=math.floor(x/size);gz=math.floor(z/size)
            key=f"{spec['id']}_{gx}_{gz}"
            if key not in all_sectors:
                tile=box(gx*size,gz*size,(gx+1)*size,(gz+1)*size).intersection(bounds)
                if tile.is_empty:return None
                a,b,c,d=tile.bounds
                all_sectors[key]={'id':key,'district':spec['id'],'origin':[ox,oz],'bounds':[ox+a,oz+b,ox+c,oz+d],'buildings':[],'surfaces':[],'lamps':[],'signs':[],'monuments':[],'venues':[]}
            return all_sectors[key]
        # Every crop cell has a ground slab, including cells with no OSM buildings.
        for x in range(math.floor(bounds.bounds[0]/size),math.ceil(bounds.bounds[2]/size)):
            for z in range(math.floor(bounds.bounds[1]/size),math.ceil(bounds.bounds[3]/size)):
                tile=box(x*size,z*size,(x+1)*size,(z+1)*size).intersection(bounds)
                if tile.area>0.01:sector_at(tile.representative_point().coords[0])
        stats=defaultdict(int);building_geometries=[];related_ways=set();objects=[]
        for rid,members,tags in relations:
            outer=[];inner=[]
            for ref,role in members:
                if ref not in ways:continue
                p=coords(ways[ref][0])
                if len(p)>1:
                    (inner if role=='inner' else outer).append(LineString(p));related_ways.add(ref)
            if not outer:continue
            shells=list(polygonize(unary_union(outer)))
            holes=list(polygonize(unary_union(inner))) if inner else []
            shape=unary_union(shells)
            if holes:shape=shape.difference(unary_union(holes))
            objects.append(('relation_'+rid,shape,tags))
        for wid,(refs,tags) in ways.items():
            if wid in related_ways or not ('building' in tags or 'building:part' in tags):continue
            p=coords(refs)
            if len(p)<4 or refs[0]!=refs[-1] or tags.get('building') in {'no','roof'}:continue
            if tags.get('memorial') or tags.get('layer','0').startswith('-'):continue
            objects.append(('way_'+wid,make_valid(Polygon(p)),tags))
        for object_id,shape,tags in objects:
            for part,poly in enumerate(polygons(make_valid(shape).intersection(bounds))):
                if poly.area<4:continue
                poly=orient(poly.simplify(0.12,preserve_topology=True),sign=1)
                center=poly.centroid.coords[0];sector=sector_at(center)
                if sector is None:continue
                levels=max(1,min(12,round(number(tags.get('building:levels'),4 if spec['id']=='saldanha' else 3))))
                inferred=not bool(tags.get('height') or tags.get('building:levels'))
                height=max(3.0,min(45.0,number(tags.get('height'),levels*3.1)))
                rings=[list(poly.exterior.coords)[:-1]]+[list(r.coords)[:-1] for r in poly.interiors]
                feature={'id':f"osm/{spec['id']}/{object_id}/{part}",'position':[ox+center[0],oz+center[1]],'height':height,'inferred_height':inferred,'rings':[[[x-center[0],z-center[1]] for x,z in ring] for ring in rings],'roof':triangle_points(poly,center),'style':int(hashlib.sha256(object_id.encode()).hexdigest()[:4],16)%4}
                sector['buildings'].append(feature);building_geometries.append(poly);stats['buildings']+=1;stats['inferred_heights']+=int(inferred)
        road_items=[];routes=[];major=[];all_road_names=set()
        for wid,(refs,tags) in ways.items():
            kind=tags.get('highway');p=coords(refs)
            if kind not in DRIVE|WALK or len(p)<2 or tags.get('area')=='yes' or tags.get('tunnel')=='yes' or tags.get('layer','0').startswith('-'):continue
            original=LineString(p)
            if not original.intersects(bounds):continue
            lane_default=2 if kind in {'primary','secondary','tertiary'} else 1
            width=number(tags.get('width'),number(tags.get('lanes'),lane_default)*3.1 if kind in DRIVE else 3.4)
            width=max(1.3,min(width,18.0 if kind in DRIVE else 7.0))
            name=tags.get('name','')[:70];is_pink=spec['id']=='pink_street' and name=='Rua Nova do Carvalho'
            surface='pink' if is_pink else 'asphalt' if kind in DRIVE else 'calcada'
            for part,line in enumerate(lines(original.intersection(bounds))):
                if line.length<0.6:continue
                pts=list(line.coords);road_items.append({'id':wid,'name':name,'kind':kind,'width':width,'line':line,'points':pts})
                if name:all_road_names.add(name)
                if kind in {'primary','secondary','tertiary'}:major.append({'name':name,'points':[[ox+x,oz+z] for x,z in pts]})
                road_poly=line.buffer(width*0.5,cap_style='round',join_style='round',quad_segs=2).intersection(bounds)
                for key,sector in list(all_sectors.items()):
                    if sector['district']!=spec['id']:continue
                    a,b,c,d=sector['bounds'];tile=box(a-ox,b-oz,c-ox,d-oz)
                    for piece in polygons(road_poly.intersection(tile)):
                        if piece.area>0.03:sector['surfaces'].append({'material':surface,'triangles':[[x+ox,z+oz] for x,z in triangle_points(piece)]})
                if kind in WALK or kind in {'living_street','residential'}:
                    # Walk out and back on the same legal line, never close via a building.
                    route=[[ox+x,oz+z] for x,z in pts]
                    if line.length>8:routes.append(route+list(reversed(route[:-1])))
                stats['road_segments']+=1
        # Portals are actual road/crop intersections, with outer connectors adapted for the compact map.
        portals={}
        for side,index,value in [('west',0,bounds.bounds[0]),('north',1,bounds.bounds[1]),('south',1,bounds.bounds[3])]:
            candidates=[]
            for road in road_items:
                for point in [road['points'][0],road['points'][-1]]:
                    if abs(point[index]-value)<0.1:
                        score=abs(point[1-index])+ (0 if road['kind'] in DRIVE else 300)
                        candidates.append((score,point))
            if not candidates:raise ValueError(f"No road portal for {spec['id']} {side}")
            point=min(candidates,key=lambda c:c[0])[1]
            portals[side]=[ox+point[0],oz+point[1]]
        focus=[r for r in road_items if r['name']==spec['focus_street']]
        if not focus:raise ValueError('Missing focus street '+spec['focus_street'])
        focus.sort(key=lambda r:r['line'].distance(Point(0,0)))
        focus_line=focus[0]['line'];center=focus_line.interpolate(0.5,normalized=True)
        ahead=focus_line.interpolate(min(focus_line.length,focus_line.length*0.5+12))
        safe=[ox+center.x,oz+center.y]
        venues=[]
        for nid,at,tags in pois:
            point=Point(project(at))
            if not bounds.covers(point):continue
            venues.append({'id':'osm/'+spec['id']+'/poi_'+nid,'name':tags.get('name','Bar')[:48],'position':[ox+point.x,oz+point.y],'type':tags['amenity']})
        if len(routes)>24:routes=sorted(routes,key=lambda r:min((p[0]-safe[0])**2+(p[1]-safe[1])**2 for p in r))[:24]
        if not routes:routes=[[[ox+x,oz+z] for x,z in focus_line.coords]]
        # Sparse warm lights/signs; no web/contact metadata is carried into runtime.
        for road in road_items:
            if road['name']!=spec['focus_street'] and road['kind'] not in {'primary','secondary'}:continue
            line=road['line']
            for distance in range(8,int(line.length),32):
                p=line.interpolate(distance);q=line.interpolate(min(distance+0.2,line.length))
                dx,dz=q.x-p.x,q.y-p.y;length=math.hypot(dx,dz) or 1
                pos=(p.x-dz/length*(road['width']/2+0.6),p.y+dx/length*(road['width']/2+0.6))
                if not bounds.covers(Point(pos)) or any(g.buffer(0.2).contains(Point(pos)) for g in building_geometries):continue
                sector=sector_at(pos)
                if sector:sector['lamps'].append([ox+pos[0],oz+pos[1]])
        sector=sector_at((center.x,center.y))
        heading=focus_line.interpolate(min(focus_line.length,focus_line.length*0.5+1))
        dx,dz=heading.x-center.x,heading.y-center.y;length=math.hypot(dx,dz) or 1
        sign_pos=[safe[0]-dz/length*(focus[0]['width']/2+0.8),safe[1]+dx/length*(focus[0]['width']/2+0.8)]
        sector['signs'].append({'name':spec['label'],'position':sign_pos})
        # Stylised storefronts use source POIs; no interior geometry is present in OSM.
        nightlife=sorted(venues,key=lambda v:(v['type']=='cafe',(v['position'][0]-safe[0])**2+(v['position'][1]-safe[1])**2))[:10]
        for venue in nightlife:
            point=Point(venue['position'][0]-ox,venue['position'][1]-oz)
            block=min(building_geometries,key=lambda poly:poly.distance(point),default=None)
            if block is None or block.distance(point)>12:continue
            road=min(road_items,key=lambda r:r['line'].distance(point))['line']
            street=road.interpolate(road.project(point))
            wall=block.boundary.interpolate(block.boundary.project(street))
            dx,dz=street.x-wall.x,street.y-wall.y;length=math.hypot(dx,dz)
            if length<0.2:continue
            entrance=[wall.x+dx/length*0.15,wall.y+dz/length*0.15]
            sector=sector_at(entrance)
            if sector:sector['venues'].append({'id':venue['id'],'name':venue['name'],'position':[ox+entrance[0],oz+entrance[1]],'yaw':math.atan2(dx,dz)})
        for wid,(refs,tags) in ways.items():
            if tags.get('memorial')=='statue' and 'Saldanha' in tags.get('name',''):
                points=coords(refs)
                if len(points)>=4:
                    at=Polygon(points).centroid
                    if bounds.covers(at):sector_at(at.coords[0])['monuments'].append([ox+at.x,oz+at.y])
        district={'id':spec['id'],'label':spec['label'],'origin':[ox,oz],'bounds':[ox+bounds.bounds[0],oz+bounds.bounds[1],ox+bounds.bounds[2],oz+bounds.bounds[3]],'geo_origin':spec['geo_origin'],'source':spec['source'],'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_bounds':source_bounds,'portals':portals,'spawn':safe,'look_at':[ox+ahead.x,oz+ahead.y],'routes':routes,'major_roads':major,'focus_street':spec['focus_street'],'music':{'id':'music/'+spec['id'],'position':safe,'song':spec['song']},'venues':venues[:16],'stats':dict(stats),'road_names':sorted(all_road_names)}
        manifest['districts'].append(district)
        print(spec['label'],dict(stats),'spawn',compact(safe),'venues',len(venues))
    districts=manifest['districts']
    manifest['links'].append({'id':'lado_b_saldanha','points':[[60,0],[75,0],districts[0]['portals']['west']]})
    for a,b in zip(districts,districts[1:]):
        start=a['portals']['south'];end=b['portals']['north'];z=(start[1]+end[1])*0.5
        manifest['links'].append({'id':a['id']+'_'+b['id'],'points':[start,[start[0],z],[end[0],z],end]})
    for key,sector in sorted(all_sectors.items()):
        # Expand streaming bounds for buildings assigned by centroid that extend across a tile edge.
        a,b,c,d=sector['bounds'];stream=[a,b,c,d]
        for feature in sector['buildings']:
            x,z=feature['position']
            for ring in feature['rings']:
                for dx,dz in ring:
                    stream=[min(stream[0],x+dx),min(stream[1],z+dz),max(stream[2],x+dx),max(stream[3],z+dz)]
        filename=key+'.json';save(OUT/filename,sector)
        manifest['sectors'].append({'id':key,'district':sector['district'],'bounds':sector['bounds'],'stream_bounds':stream,'path':'res://assets/maps/generated/'+filename,'features':['base/'+f['id'] for f in sector['buildings']]+['base/'+v['id'] for v in sector['venues']]+[f'base/osm/lamp/{round(x*1000)}/{round(z*1000)}' for x,z in compact(sector['lamps'])]+(['base/osm/saldanha/monumento'] if sector['monuments'] else [])})
    save(OUT/'manifest.json',manifest)
    print('SECTORS',len(all_sectors),'BUILDINGS',sum(len(s['buildings']) for s in all_sectors.values()))

if __name__=='__main__':main()
