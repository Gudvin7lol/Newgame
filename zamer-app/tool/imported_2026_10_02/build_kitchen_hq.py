from pathlib import Path
import sys, io, json, math
import numpy as np
from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).resolve().parent
APP_ROOT = SCRIPT_DIR.parent.parent
ROOT = SCRIPT_DIR / 'kitchen'
exec((ROOT/'source/mesh_helpers.py').read_text())

# Reference-driven kitchen models for Zamer. The old +106 path enlarged a
# 256px catalogue swatch and baked that blur into every GLB. +107 synthesises
# a 1024px physically plausible oak surface and keeps normal/roughness detail.
S = 1024
rng = np.random.default_rng(107)
base_path = APP_ROOT / 'assets/textures/imported_2026_10_02/oak_natural_1200mm_basecolor.webp'
if base_path.exists():
    ref = Image.open(base_path).convert('RGB').resize((S,S), Image.Resampling.LANCZOS)
    ref_arr = np.asarray(ref).astype(np.float32)
else:
    ref_arr = np.zeros((S,S,3), dtype=np.float32) + np.array([161,122,78], dtype=np.float32)
y,x = np.mgrid[:S,:S]
u=x/S; v=y/S
from scipy.ndimage import gaussian_filter
warp = .035*np.sin(v*2*np.pi) + .012*np.sin(v*9*np.pi) + .006*np.sin(v*27*np.pi)
bands = 4.2*np.sin((u*7+warp)*2*np.pi) + 1.8*np.sin((u*19+warp)*2*np.pi)
pores = gaussian_filter(rng.normal(0,1,(S,S)), sigma=.55)*4.0
micro = rng.normal(0,1,(S,S))*1.25
color_bias=np.array([5.0,1.5,-3.0],dtype=np.float32)
oak=np.clip(ref_arr*.88 + color_bias + (bands+pores+micro)[:,:,None],0,255).astype(np.uint8)
_oak=Image.fromarray(oak,'RGB')
tex_io=io.BytesIO(); _oak.save(tex_io,format='PNG',optimize=True); tex=tex_io.getvalue()
gray=oak.astype(np.float32).mean(axis=2)/255.0
gy,gx=np.gradient(gaussian_filter(gray,.55))
normal=np.zeros((S,S,3),dtype=np.uint8)
normal[:,:,0]=np.clip(128-gx*1750,0,255).astype(np.uint8)
normal[:,:,1]=np.clip(128-gy*1750,0,255).astype(np.uint8)
normal[:,:,2]=248
rough_val=np.clip(.50 + gaussian_filter(rng.normal(0,.035,(S,S)),1.1) + (gray-gray.mean())*.07,.38,.66)
rough=np.zeros((S,S,3),dtype=np.uint8); rough[:,:,0]=255; rough[:,:,1]=(rough_val*255).astype(np.uint8)
def png(a):
    b=io.BytesIO(); Image.fromarray(a).save(b,format='PNG',optimize=True); return b.getvalue()
ntex=png(normal); rtex=png(rough)
materials=[
 {'name':'Natural oak veneer HQ','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':0,'roughnessFactor':1},'normalTexture':{'index':1,'scale':.22}},
 {'name':'Warm quartz','pbrMetallicRoughness':{'baseColorFactor':[.86,.84,.78,1],'metallicFactor':0,'roughnessFactor':.23}},
 {'name':'Recessed black plinth','pbrMetallicRoughness':{'baseColorFactor':[.018,.017,.016,1],'metallicFactor':0,'roughnessFactor':.55}},
 {'name':'Brushed steel','pbrMetallicRoughness':{'baseColorFactor':[.54,.56,.57,1],'metallicFactor':1,'roughnessFactor':.21}},
 {'name':'Induction glass','pbrMetallicRoughness':{'baseColorFactor':[.005,.007,.009,1],'metallicFactor':0,'roughnessFactor':.09}},
 {'name':'Hob markings','pbrMetallicRoughness':{'baseColorFactor':[.46,.49,.52,1],'metallicFactor':.1,'roughnessFactor':.35}},
 {'name':'Cabinet interior','pbrMetallicRoughness':{'baseColorFactor':[.22,.18,.14,1],'metallicFactor':0,'roughnessFactor':.62}},
 {'name':'Shadow gap','pbrMetallicRoughness':{'baseColorFactor':[.015,.014,.013,1],'metallicFactor':0,'roughnessFactor':.75}},
 {'name':'Sink steel','pbrMetallicRoughness':{'baseColorFactor':[.44,.47,.50,1],'metallicFactor':1,'roughnessFactor':.18}},
]

def box(name,size,pos,mat=0,r=.003,N=8,rotation=(0,0,0)):
    softbox(name,size,pos,min(r,min(size)/3),rotation=rotation,mat=mat,N=N)

def pipe(name,path,r=.006,mat=3,N=20):
    path=np.array(path,float);vs=[];fs=[];uv=[]
    for i,p in enumerate(path):
        t=path[min(i+1,len(path)-1)]-path[max(i-1,0)]
        nt=np.linalg.norm(t)
        if nt < 1e-7:
            prev=path[max(i-2,0)]
            nxt=path[min(i+2,len(path)-1)]
            t=nxt-prev; nt=np.linalg.norm(t)
        if nt < 1e-7:
            t=np.array([1.0,0.0,0.0]); nt=1.0
        t=t/nt
        refs=(np.array([1.,0,0]),np.array([0.,1,0]),np.array([0.,0,1.]))
        ref=min(refs,key=lambda rr: abs(float(np.dot(t,rr))))
        a=np.cross(t,ref); an=np.linalg.norm(a)
        if an<1e-10:
            raise ValueError(f'degenerate pipe tangent in {name} at {i}')
        a/=an; b=np.cross(t,a); b/=max(np.linalg.norm(b),1e-10)
        for k in range(N):
            ang=k*2*np.pi/N
            vs.append(p+r*(a*np.cos(ang)+b*np.sin(ang))); uv.append([k/N,i/max(1,len(path)-1)])
    for i in range(len(path)-1):
        for k in range(N):
            a=i*N+k; b=i*N+(k+1)%N; c=a+N; d=b+N
            fs.extend([[a,b,d],[a,d,c]])
    add(name,vs,fs,uv,mat)

def handle(name,x,z,width=.34,y=-.325):
    pipe(name,[[x-width/2,y,z],[x+width/2,y,z]],.006,3,20)
    for xx in [x-width/2+.025,x+width/2-.025]:
        pipe(name+'_mount',[[xx,y+.012,z],[xx,y-.002,z]],.0045,3,16)

def plinth(w,d):
    box('plinth',(w-.07,d-.09,.10),(0,.018,.05),2,r=.008,N=8)

def carcass(w=.6,d=.624,h=.87):
    plinth(w,d)
    for sx in (-1,1): box('side',(.018,d-.045,h-.11),(sx*(w/2-.009),.012,(h+.09)/2),0,r=.0015,N=5)
    box('bottom',(w-.042,d-.055,.018),(0,.015,.115),6,r=.001,N=4)
    box('back',(w-.042,.012,h-.12),(0,d/2-.030,(h+.09)/2),6,r=.001,N=4)
    box('front_shadow',(w-.018,.008,h-.125),(0,-d/2-.002,(h+.09)/2),7,r=.001,N=4)

def counter(w=.6,d=.624,z=.887):
    box('quartz_counter',(w,d,.035),(0,0,z),1,r=.006,N=12)
    box('counter_edge',(w-.012,.012,.016),(0,-d/2+.007,z-.012),1,r=.003,N=8)

def horizontal_fronts(w,d,h,heights):
    y=-d/2-.012
    z=.105
    for i,hh in enumerate(heights):
        zz=z+hh/2
        box(f'front_{i}',(w-.014,.022,hh-.007),(0,y,zz),0,r=.005,N=10)
        handle(f'handle_{i}',0,zz+hh*.19,width=min(.36,w*.66),y=y-.018)
        z += hh

def double_doors(w,d,h,base=.105):
    y=-d/2-.012
    usable=h-base-.02
    door_w=(w-.020)/2
    for i,x in enumerate((-door_w/2-.002,door_w/2+.002)):
        box(f'door_{i}',(door_w-.005,.022,usable),(x,y,base+usable/2),0,r=.005,N=10)
    handle('handle_l',-.070,base+usable*.56,width=.22,y=y-.018)
    handle('handle_r', .070,base+usable*.56,width=.22,y=y-.018)

def rounded_rect_loop(name,cx,cy,w,d,z,radius=.08,tube_r=.002,mat=5):
    pts=[]
    corners=[(cx+w/2-radius,cy+d/2-radius,0),(cx-w/2+radius,cy+d/2-radius,90),(cx-w/2+radius,cy-d/2+radius,180),(cx+w/2-radius,cy-d/2+radius,270)]
    for ox,oy,start in corners:
        for a in np.linspace(start,start+90,14,endpoint=False):
            aa=np.deg2rad(a); pts.append([ox+radius*np.cos(aa),oy+radius*np.sin(aa),z])
    pts.append(pts[0])
    pipe(name,pts,tube_r,mat,12)

def basin(w=.44,d=.38,cx=0,cy=-.015,top=.904):
    left=(.6-w)/2
    front=(.624-d)/2
    for size,pos in [((.6,front,.035),(0,-.624/2+front/2,top-.0175)),((.6,front,.035),(0,.624/2-front/2,top-.0175)),((left,d,.035),(-.6/2+left/2,cy,top-.0175)),((left,d,.035),(.6/2-left/2,cy,top-.0175))]:
        box('counter_surround',size,pos,1,r=.004,N=10)
    rings=[(w,d,top-.012),(w-.018,d-.018,top-.035),(w-.055,d-.055,.765),(w-.09,d-.09,.735)]
    vs=[];uv=[];fs=[]; ringN=56
    def ring_points(W,D,Z):
        pts=[]; rad=min(.075,W*.18,D*.18)
        corners=[(W/2-rad,D/2-rad,0),(-W/2+rad,D/2-rad,90),(-W/2+rad,-D/2+rad,180),(W/2-rad,-D/2+rad,270)]
        for ox,oy,start in corners:
            for a in np.linspace(start,start+90,ringN//4,endpoint=False):
                aa=np.deg2rad(a); pts.append([cx+ox+rad*np.cos(aa),cy+oy+rad*np.sin(aa),Z])
        return pts
    for W,D,Z in rings:
        rr=ring_points(W,D,Z)
        for p in rr: vs.append(p); uv.append([p[0],p[1]])
    N=len(ring_points(*rings[0]))
    for j in range(len(rings)-1):
        for i in range(N):
            a=j*N+i; b=j*N+(i+1)%N; c=a+N; dd=b+N
            fs.extend([[a,b,dd],[a,dd,c]])
    center_idx=len(vs); vs.append([cx,cy,rings[-1][2]-.002]); uv.append([0,0])
    for i in range(N): fs.append([(len(rings)-1)*N+i,(len(rings)-1)*N+(i+1)%N,center_idx])
    add('sink_bowl',vs,fs,uv,8)
    rounded_rect_loop('sink_rim',cx,cy,w+.008,d+.008,top-.007,.08,.0028,8)
    pipe('drain_ring',[[cx+.027*np.cos(t),cy+.027*np.sin(t),.737] for t in np.linspace(0,2*np.pi,49)],.0022,3,12)

def faucet():
    pts=[]
    pts += [[0,.215,z] for z in np.linspace(.91,1.10,8)]
    for t in np.linspace(0,np.pi,26)[1:]:
        pts.append([0,.145+.070*np.cos(t),1.10+.075*np.sin(t)])
    pts += [[0,.075,z] for z in np.linspace(1.10,1.03,6)[1:]]
    pipe('faucet',pts,.011,3,24)
    pipe('mixer_lever',[[.021,.214,.995],[.068,.214,.995]],.005,3,18)

def hob():
    box('induction_glass',(.555,.505,.008),(0,-.018,.906),4,r=.010,N=12)
    for x,y,rr in [(-.14,-.14,.087),(.14,-.14,.083),(-.14,.11,.078),(.14,.11,.09)]:
        pipe('zone',[[x+rr*np.cos(t),y+rr*np.sin(t),.911] for t in np.linspace(0,2*np.pi,65)],.0014,5,10)
    for x in np.linspace(-.075,.075,4):
        box('touch',(.010,.004,.0012),(x,-.250,.912),5,r=.0004,N=4)

def tall_fronts(w,d,h,fridge=False):
    y=-d/2-.012
    if fridge:
        lower=.62; upper=h-.12-lower-.008
        box('freezer_front',(w-.014,.022,lower),(0,y,.105+lower/2),0,r=.006,N=10)
        box('fridge_front',(w-.014,.022,upper),(0,y,.105+lower+.008+upper/2),0,r=.006,N=10)
        handle('freezer_handle',-.14,.105+lower*.50,width=.22,y=y-.018)
        handle('fridge_handle',-.14,.105+lower+.008+upper*.53,width=.22,y=y-.018)
    else:
        usable=h-.125
        door_w=(w-.020)/2
        for i,x in enumerate((-door_w/2-.002,door_w/2+.002)):
            box(f'tall_door_{i}',(door_w-.005,.022,usable),(x,y,.105+usable/2),0,r=.006,N=10)
        handle('pantry_handle_l',-.07,1.18,width=.25,y=y-.018)
        handle('pantry_handle_r', .07,1.18,width=.25,y=y-.018)

def export(out):
    global P,MODEL_NAME,DETAIL,MATERIAL_NAME,NORMAL_SCALE
    P=str(out.parent); MODEL_NAME=out.stem; DETAIL=1; MATERIAL_NAME='Natural oak veneer HQ'; NORMAL_SCALE=.22
    s=(ROOT/'source/export_template.py').read_text()
    s=s.replace("j=json.dumps(g,separators=(',',':')).encode()","g['materials']=materials\nj=json.dumps(g,separators=(',',':')).encode()")
    exec(s,globals())

def render(path,top=False):
    W=720;H=720; allv=np.concatenate([p['v'] for p in parts]); lo=allv.min(0);hi=allv.max(0);center=(lo+hi)/2
    direction=np.array([0,0,1.]) if top else np.array([-1.5,-2.4,1.55]); direction/=np.linalg.norm(direction)
    right=np.array([1.,0,0]) if top else np.cross(-direction,[0,0,1]); right/=np.linalg.norm(right); up=np.cross(direction,right); B=np.stack([right,up,direction],axis=1)
    Q=(allv-center)@B; scale=600/max(np.ptp(Q[:,0]),np.ptp(Q[:,1])); zb=np.full((H,W),-1e10); img=np.zeros((H,W,4),np.uint8)
    light=np.array([-.45,-.65,.78]); light/=np.linalg.norm(light)
    base=np.asarray(_oak)
    for p in parts:
        q=(p['v']-center)@B; q[:,:2]*=scale; q[:,0]+=W/2; q[:,1]=H/2-q[:,1]
        for f in p['f']:
            a,b,c=q[f]; l=np.maximum(np.floor(np.minimum(np.minimum(a[:2],b[:2]),c[:2])).astype(int),0); h=np.minimum(np.ceil(np.maximum(np.maximum(a[:2],b[:2]),c[:2])).astype(int),[W-1,H-1])
            if (h<l).any(): continue
            den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den)<1e-9: continue
            yy,xx=np.mgrid[l[1]:h[1]+1,l[0]:h[0]+1]; xx=xx+.5; yy=yy+.5
            u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den; vv=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den; w=1-u-vv; z=u*a[2]+vv*b[2]+w*c[2]
            reg=zb[l[1]:h[1]+1,l[0]:h[0]+1]; mask=(u>=0)&(vv>=0)&(w>=0)&(z>reg)
            if not mask.any(): continue
            weights=np.stack([u[mask],vv[mask],w[mask]],1); n=weights@p['n'][f]; n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-9); shade=.62+.38*np.maximum(n@light,0)
            if p['mat']==0:
                uv=weights@p['uv'][f]; col=(base[(uv[:,1]*S).astype(int)%S,(uv[:,0]*S).astype(int)%S]/255.)**2.2
            else:
                fac=materials[p['mat']]['pbrMetallicRoughness']['baseColorFactor'][:3]; col=np.tile(np.array(fac,float),(len(weights),1))
            rgb=np.uint8(np.clip(col*shade[:,None],0,1)**(1/2.2)*255)
            pix=img[l[1]:h[1]+1,l[0]:h[0]+1]; pix[mask]=np.c_[rgb,np.full(len(rgb),255)]; reg[mask]=z[mask]
    Image.fromarray(img).save(path)

OUT=ROOT/'models_hq'; OUT.mkdir(parents=True,exist_ok=True)
TOPVIEW=APP_ROOT/'assets/topview/imported_2026_10_02'; TOPVIEW.mkdir(parents=True,exist_ok=True)
cat=[]
for kind in ['drawers','sink','cooktop','corner','pantry','fridge']:
    parts=[]
    if kind=='drawers':
        carcass(); counter(); horizontal_fronts(.6,.624,.87,[.385,.385])
    elif kind=='sink':
        carcass(); double_doors(.6,.624,.87); basin(); faucet()
    elif kind=='cooktop':
        carcass(); counter(); horizontal_fronts(.6,.624,.87,[.255,.255,.26]); hob()
    elif kind=='corner':
        plinth(.9,.995)
        box('main_side_l',(.018,.58,.76),(-.441,.17,.49),0,r=.002,N=6)
        box('main_side_r',(.018,.58,.76),(.441,.17,.49),0,r=.002,N=6)
        box('main_back',(.87,.018,.76),(0,.452,.49),6,r=.001,N=4)
        box('return_side',(.30,.018,.76),(-.295,-.395,.49),0,r=.002,N=6)
        box('corner_shadow_a',(.60,.008,.76),(.145,-.125,.49),7,r=.001,N=4)
        box('corner_front_a',(.594,.022,.755),(.15,-.143,.49),0,r=.005,N=10)
        box('corner_shadow_b',(.008,.30,.76),(-.155,-.30,.49),7,r=.001,N=4)
        box('corner_front_b',(.022,.294,.755),(-.173,-.30,.49),0,r=.005,N=10)
        box('counter_main',(.9,.62,.035),(0,.18,.887),1,r=.006,N=12)
        box('counter_return',(.30,.395,.035),(-.30,-.3275,.887),1,r=.006,N=12)
        handle('corner_handle_a',.15,.57,width=.29,y=-.161)
        pipe('corner_handle_b',[[-.192,-.30,.44],[-.192,-.30,.69]],.006,3,20)
    else:
        w=.6 if kind=='pantry' else .610; d=.624; h=2.2
        carcass(w,d,h)
        box('top',(w-.040,d-.055,.018),(0,.015,h-.010),6,r=.001,N=4)
        tall_fronts(w,d,h,fridge=(kind=='fridge'))
        for z in [.58,1.08,1.58]: box('shelf',(w-.045,d-.07,.018),(0,.02,z),6,r=.001,N=4)
    out=OUT/f'{kind}.glb'; export(out)
    render(OUT/f'{kind}.png')
    top_png=OUT/f'{kind}_top.png'; render(top_png,top=True)
    Image.open(top_png).save(TOPVIEW/f'kitchen_{kind}.webp','WEBP',quality=92,method=6)
    V=np.concatenate([p['v'] for p in parts]); lo=V.min(0); hi=V.max(0)
    cat.append((kind, sum(len(p['f']) for p in parts), ((hi-lo)*1000).round(1).tolist(), out.stat().st_size))
print(json.dumps(cat,indent=2))
