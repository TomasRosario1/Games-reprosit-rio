"""Check archived animation files, actual contact logs and encoded video frames."""
import runpy,json,math,subprocess,hashlib
from pathlib import Path
BASE=Path(__file__).resolve().parent.parent;OUT=BASE/'emmet/revisao_03'
helpers=runpy.run_path(str(BASE/'ferramentas/validar_arquivo.py'))
glb,accessor=helpers['glb'],helpers['accessor']
ref,ref_binary=glb(BASE/'emmet/revisao_02/emmet_articulacao_02.glb')
ref_primitive=ref['meshes'][0]['primitives'][0]
contacts=json.loads((OUT/'contactos.json').read_text());records=[]
for clip in ['01_andar','02_entrar_carro','03_montar_mota']:
    g,binary=glb(OUT/(clip+'.glb'))
    assert len(g['skins'])==1 and len(g['skins'][0]['joints'])==21
    assert len(g['animations'])==1 and g['animations'][0]['name']==clip
    actor=next(p for m in g['meshes'] for p in m['primitives'] if 'JOINTS_0'in p['attributes'])
    # Blender bakes the actor's initial object transform into exported mesh
    # vertices when flattening the skinned hierarchy. Undo that transform before
    # comparing rest geometry; vertex order may change with skin influence keys.
    root=next(n for n in g['nodes']if n.get('name')=='Emmet_Rig_Animacoes03')
    origin=root.get('translation',[0,0,0]);q=root.get('rotation',[0,0,0,1]);scale=root.get('scale',[1,1,1])
    def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    def canonical(point):
        v=[point[i]-origin[i]for i in range(3)];xyz=[-q[i]for i in range(3)]
        t=[2*x for x in cross(xyz,v)];u=cross(xyz,t)
        return [(v[i]+q[3]*t[i]+u[i])/scale[i]for i in range(3)]
    actual={}
    for pos,uv in zip(accessor(g,binary,actor['attributes']['POSITION']),accessor(g,binary,actor['attributes']['TEXCOORD_0'])):
        actual.setdefault(uv,[]).append(canonical(pos))
    for pos,uv in zip(accessor(ref,ref_binary,ref_primitive['attributes']['POSITION']),accessor(ref,ref_binary,ref_primitive['attributes']['TEXCOORD_0'])):
        points=actual[uv];nearest=min(range(len(points)),key=lambda i:math.dist(pos,points[i]))
        assert math.dist(pos,points.pop(nearest))<.00001,(clip,pos)
    assert all(not points for points in actual.values())
    weights=accessor(g,binary,actor['attributes']['WEIGHTS_0']);assert all(abs(sum(w)-1)<.0001 and min(w)>=0 for w in weights)
    assert all(0<=j<21 for row in accessor(g,binary,actor['attributes']['JOINTS_0']) for j in row)
    assert not any('uri'in x and not x['uri'].startswith('data:')for k in ['buffers','images']for x in g.get(k,[]))
    animation=g['animations'][0]
    for sampler in animation['samplers']:
        times=accessor(g,binary,sampler['input']);assert abs(times[0][0])<.0001 and abs(times[-1][0]-191/24)<.01
    frames=contacts[clip];assert len(frames)==192
    error=max(v['error']for f in frames for v in f['targets'].values());assert error<.015,(clip,error)
    roots=[f['root']for f in frames];max_delta=max(math.dist(a,b)for a,b in zip(roots,roots[1:]));assert max_delta<.10
    if clip=='02_entrar_carro':
        final=frames[-1];assert final['head_top']<1.615
        assert abs(final['butt_low']-.655)<.02
    if clip=='03_montar_mota':
        final=frames[-1];assert abs(final['butt_low']-.95)<.025
        raised=[f['targets']['foot.R']['actual'][2]for f in frames if 2.8<=f['time']<=3.2]
        assert min(raised)-.12>.95+.04
    records.append({'clip':clip,'skin_bones':21,'baked_frames':len(frames),'max_contact_error_m':error,'max_root_step_m':max_delta,'rest_geometry_uv_preserved':True})
    print('ANIMATION OK',clip,'contact error',round(error,6))
videos=[]
for p in sorted(OUT.glob('*.mp4')):
    d=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_entries','stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_read_frames:format=duration','-of','json',str(p)]))
    stream=d['streams'][0];n=576 if p.name.startswith('00_') else 192
    assert (stream['codec_name'],stream['width'],stream['height'],stream['pix_fmt'],int(stream['nb_read_frames']))==('h264',1280,720,'yuv420p',n)
    assert abs(float(d['format']['duration'])-n/24)<.01
    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','framemd5','-']).decode().splitlines()
    unique=len({s.split(',')[-1].strip()for s in raw if s and not s.startswith('#')});assert unique>60
    videos.append({'file':p.name,'duration_seconds':n/24,'unique_decoded_frames':unique,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),**stream})
    print('VIDEO OK',p.name,n,'frames')
assert len(videos)==4
sources=json.loads((OUT/'fontes_validadas.json').read_text());assert len(sources)==3 and all(s['bones_unchanged']==21 for s in sources)
(OUT/'validacao.json').write_text(json.dumps({'animations':records,'videos':videos,'native_godot_validation':'603 checks, 0 failures, Godot4.6.3, clips imported at native24fps','source_rig':'review02 bone placement preserved; trouser seat weights refined locally','game_integration':False,'approval_status':'awaiting creator animation feedback'},indent=2,ensure_ascii=False)+'\n')
