from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parent.parent
exec((ROOT/'source/mesh_helpers.py').read_text())
from scipy.ndimage import gaussian_filter
S=512
Y,X=np.mgrid[:S,:S];rng=np.random.default_rng(91)
# Native material maps: subdued natural oak with fine pores and restrained growth bands.
u=X/S;v=Y/S
warp=.035*np.sin(v*2*np.pi)+.012*np.sin(v*11*np.pi)
bands=np.sin((u*7+warp)*2*np.pi)*2.2 + np.sin((u*21+warp)*2*np.pi)*0.9
pores=gaussian_filter(rng.normal(0,1,(S,S)),sigma=.45)*3.0
base=np.uint8(np.clip(np.array([156,119,78])+bands[:,:,None]+pores[:,:,None],0,255))
normal=np.zeros((S,S,3),dtype=np.uint8);normal[:]=[128,128,255]
grad=np.gradient(bands);normal[:,:,0]=np.uint8(np.clip(128-grad[1]*9,0,255));normal[:,:,1]=np.uint8(np.clip(128-grad[0]*9,0,255))
rough=np.zeros((S,S,3),dtype=np.uint8);rough[:]=[255,175,0]
def png(a):
 b=io.BytesIO();Image.fromarray(a).save(b,format='PNG');return b.getvalue()

# Use the generated seamless oak scan for the cabinet fronts; keep procedural maps for normal/roughness.
_oak_path=Path(__file__).resolve().parent/'oak_veneer.png'
_oak=Image.open(_oak_path).convert('RGB').resize((S,S),Image.Resampling.LANCZOS) if _oak_path.exists() else Image.fromarray(base)
tex=io.BytesIO(); _oak.save(tex,format='PNG'); tex=tex.getvalue()
ntex=png(normal);rtex=png(rough)
materials=[{'name':'Natural oak veneer','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':0,'roughnessFactor':1},'normalTexture':{'index':1,'scale':.12}}]
for name,col,metal,r in [('Warm quartz',[.72,.68,.59],0,.28),('Recessed plinth',[.018,.016,.014],0,.7),('Brushed steel',[.42,.45,.47],1,.24),('Induction glass',[.006,.009,.012],0,.12),('Hob markings',[.42,.44,.46],0,.48),('Cabinet interior',[.42,.37,.30],0,.62),('Matte black profile',[.025,.027,.029],0,.32)]:
 materials.append({'name':name,'pbrMetallicRoughness':{'baseColorFactor':col+[1],'metallicFactor':metal,'roughnessFactor':r}})

def box(name,size,pos,mat=0,r=.002):softbox(name,size,pos,min(r,min(size)/3),mat=mat,N=4)
def pipe(name,path,r,mat=3):
 path=np.array(path,float);vs=[];fs=[];uv=[];N=16
 for i,p in enumerate(path):
  t=path[min(i+1,len(path)-1)]-path[max(i-1,0)];t/=np.linalg.norm(t)
  a=np.cross(t,[0,1,0]);
  if np.linalg.norm(a)<1e-8: a=np.cross(t,[1,0,0])
  a/=np.linalg.norm(a);b=np.cross(t,a)
  for k in range(N):vs.append(p+r*(a*np.cos(k*2*np.pi/N)+b*np.sin(k*2*np.pi/N)));uv.append([k/N,i/len(path)])
 for i in range(len(path)-1):
  for k in range(N):
   a=i*N+k;b=i*N+(k+1)%N;c=a+N;d=b+N;fs.extend([[a,b,d],[a,d,c]])
 add(name,vs,fs,uv,mat)
def carcass(w=.6,d=.6,h=.87,x=0,y=0):
 box('plinth',(w-.05,d-.09,.10),(x,y+.015,.05),2)
 for sx in [-1,1]:box('side',( .018,d,h-.1),(x+sx*(w/2-.009),y,(h+.1)/2))
 box('back',(w-.036,.012,h-.1),(x,y+d/2-.006,(h+.1)/2),6)
 box('bottom',(w-.036,d-.018,.018),(x,y,.109),6)
 box('top_rail',(w-.036,.09,.04),(x,y-.2,h-.02),6)
def fronts(w=.6,h=.87,count=2,vertical=False,x=0,y=-.3):
 for i in range(count):
  if vertical:box('door_'+str(i),(w/count-.004,.02,h-.105),(x-w/2+w/count*(i+.5),y-.01,(h+.1)/2))
  else:
   step=(h-.1)/count;box('drawer_'+str(i),(w-.004,.02,step-.008),(x,y-.01,.1+step*(i+.5)))
   box('integrated_pull',(min(.42,w*.7),.012,.018),(x,y-.018,.1+step*(i+.5)),6,r=.004)
def counter(w=.6,d=.62,x=0,y=-.01):
 box('quartz_counter',(w,d,.035),(x,y,.885),1,r=.004)
 box('counter_front_edge',(w-.012,.012,.018),(x,y-d/2+.008,.873),1,r=.002)
def basin():
 # Open metal bowl, tapered sides, rim and floor. Counter pieces surround real opening.
 for size,pos in [((.6,.105,.03),(0,-.2675,.885)),((.6,.145,.03),(0,.2275,.885)),((.085,.37,.03),(-.2575,-.03,.885)),((.085,.37,.03),(.2575,-.03,.885))]:box('counter_surround',size,pos,1)
 rings=[(.216,.186,.90),(.207,.177,.888),(.17,.14,.72)]
 vs=[];uv=[];fs=[]
 for w,d,z in rings:
  for a,b in [(-w,-d),(w,-d),(w,d),(-w,d)]:vs.append([a,b-.03,z]);uv.append([a,b])
 for j in range(2):
  for i in range(4):
   a=j*4+i;b=j*4+(i+1)%4;fs.extend([[a,b,b+4],[a,b+4,a+4]])
 fs.extend([[8,9,10],[8,10,11]]);add('sink_bowl',vs,fs,uv,3)
 box('drain',(.052,.052,.003),(0,-.03,.724),4)
 path=[[0,.245,z] for z in np.linspace(.90,1.11,8)]
 for t in np.linspace(0,np.pi,18)[1:]:path.append([0,.165+.08*np.cos(t),1.11+.08*np.sin(t)])
 path.append([0,.085,1.065]);pipe('faucet',path,.012)
 pipe('mixer_lever',[[.023,.245,.98],[.065,.245,.98]],.006)
def hob():
 box('induction',(.55,.49,.006),(0,-.02,.903),4)
 for x in [-.135,.135]:
  for y in [-.14,.10]:
   pts=[[x+.09*np.cos(t),y+.09*np.sin(t),.907] for t in np.linspace(0,2*np.pi,65)]
   pipe('cooking_zone',pts,.0007,5)
 for x in [-.07,0,.07]:box('touch_control',(.012,.003,.0008),(x,-.239,.907),5,r=.0001)

def export(out):
 global P,MODEL_NAME,DETAIL,MATERIAL_NAME,NORMAL_SCALE
 P=str(out.parent);MODEL_NAME=out.stem;DETAIL=1;MATERIAL_NAME='Natural oak veneer';NORMAL_SCALE=.22
 s=(ROOT/'source/export_template.py').read_text();s=s.replace("j=json.dumps(g,separators=(',',':')).encode()","g['materials']=materials\nj=json.dumps(g,separators=(',',':')).encode()")
 exec(s,globals())

def render(path,top=False):
 W=600;H=600;allv=np.concatenate([p['v'] for p in parts]);lo=allv.min(0);hi=allv.max(0);center=(lo+hi)/2
 direction=np.array([0,0,1.]) if top else np.array([-1.4,-2.3,1.55]);direction/=np.linalg.norm(direction)
 right=np.array([1.,0,0]) if top else np.cross(-direction,[0,0,1]);right/=np.linalg.norm(right);up=np.cross(direction,right);B=np.stack([right,up,direction],axis=1)
 Q=(allv-center)@B;scale=490/max(np.ptp(Q[:,0]),np.ptp(Q[:,1]));zb=np.full((H,W),-1e10);img=np.zeros((H,W,4),np.uint8)
 light=np.array([-.5,-.6,.8]);light/=np.linalg.norm(light)
 for p in parts:
  q=(p['v']-center)@B;q[:,:2]*=scale;q[:,0]+=W/2;q[:,1]=H/2-q[:,1]
  for f in p['f']:
   a,b,c=q[f];l=np.maximum(np.floor(np.minimum(np.minimum(a[:2],b[:2]),c[:2])).astype(int),0);h=np.minimum(np.ceil(np.maximum(np.maximum(a[:2],b[:2]),c[:2])).astype(int),[W-1,H-1])
   if (h<l).any():continue
   den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
   if abs(den)<1e-9:continue
   yy,xx=np.mgrid[l[1]:h[1]+1,l[0]:h[0]+1];xx=xx+.5;yy=yy+.5
   u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den;v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;w=1-u-v;z=u*a[2]+v*b[2]+w*c[2]
   reg=zb[l[1]:h[1]+1,l[0]:h[0]+1];mask=(u>=0)&(v>=0)&(w>=0)&(z>reg)
   if not mask.any():continue
   weights=np.stack([u[mask],v[mask],w[mask]],1);n=weights@p['n'][f];n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-9);shade=.58+.42*np.maximum(n@light,0)
   if p['mat']==0:
    uv=weights@p['uv'][f];col=(base[(uv[:,1]*S).astype(int)%S,(uv[:,0]*S).astype(int)%S]/255)**2.2
   else:col=np.array(materials[p['mat']]['pbrMetallicRoughness']['baseColorFactor'][:3])
   rgb=np.uint8(np.clip(col*shade[:,None],0,1)**(1/2.2)*255)
   img[l[1]:h[1]+1,l[0]:h[0]+1][mask]=np.c_[rgb,np.full(len(rgb),255)];reg[mask]=z[mask]
 Image.fromarray(img).save(path)

(ROOT/'models').mkdir(exist_ok=True);(ROOT/'previews').mkdir(exist_ok=True)
catalog=[]
for kind in ['drawers','sink','cooktop','corner','pantry','fridge']:
 parts=[]
 if kind in ['drawers','sink','cooktop']:
  carcass();fronts(count=2 if kind!='cooktop' else 3,vertical=kind=='sink')
  if kind=='sink':basin()
  else:counter()
  if kind=='cooktop':hob()
 elif kind=='corner':
  # True L footprint: two carcasses; rear overlap excluded.
  carcass(.9,.6,x=0,y=.15);carcass(.3,.3,x=-.3,y=-.3)
  counter(.9,.6,x=0,y=.15);counter(.3,.3,x=-.3,y=-.3)
  box('front_a',(.594,.02,.762),(.15,-.16,.485));box('front_b',(.02,.294,.762),(-.14,-.3,.485))
 else:
  carcass(h=2.2);box('top',(.564,.58,.018),(0,0,2.191))
  if kind=='pantry':
   fronts(h=2.2,vertical=True)
   box('integrated_pull',(.32,.012,.018),(0,-.318,1.12),6,r=.004)
  else:
   box('freezer_door',(.596,.02,.60),(0,-.31,.402));box('fridge_door',(.596,.02,1.49),(0,-.31,1.452))
   box('integrated_pull_lower',(.18,.012,.018),(-.22,-.318,.402),6,r=.004)
   box('integrated_pull_upper',(.18,.012,.018),(-.22,-.318,1.45),6,r=.004)
  for z in [.6,1.1,1.6]:box('shelf',(.564,.55,.018),(0,0,z),6)
 export(ROOT/'models'/f'{kind}.glb')
 V=np.concatenate([p['v'] for p in parts]);lo=V.min(0);hi=V.max(0)
 assert np.isfinite(V).all() and abs(lo[2])<1e-6
 catalog.append({'id':kind,'glb':f'models/{kind}.glb','bounds_mm':{'min':(lo[[0,2,1]]*[1,1,-1]*1000).tolist(),'size_xyz':((hi-lo)[[0,2,1]]*1000).round(2).tolist()},'triangles':sum(len(p['f']) for p in parts),'topview':f'previews/{kind}_top.png','origin':'floor center of nominal footprint','anchors_local_m':{'left':[-.3,0,0],'right':[.3,0,0]} if kind!='corner' else {}})
 render(ROOT/'previews'/f'{kind}.png');render(ROOT/'previews'/f'{kind}_top.png',True)
 print(kind,catalog[-1]['triangles'],flush=True)
(ROOT/'catalog.json').write_text(json.dumps({'units':'metres','up_axis':'Y','front_axis':'+Z','objects':catalog},ensure_ascii=False,indent=2))
board=Image.new('RGB',(1500,1080),(232,228,220));draw=ImageDraw.Draw(board)
for i,e in enumerate(catalog):
 im=Image.open(ROOT/'previews'/f"{e['id']}.png");im.thumbnail((490,490));x=(i%3)*500;y=(i//3)*540;board.paste(im,(x,y),im);draw.text((x+22,y+498),e['id'],fill=(40,40,40))
board.save(ROOT/'Kitchen_3D_Preview.png')
