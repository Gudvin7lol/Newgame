from pathlib import Path
import sys,os,json,math
import numpy as np
ROOT=Path(__file__).parent
KIND=sys.argv[1];DETAIL=float(sys.argv[2]) if len(sys.argv)>2 else 1.
OUT=ROOT/KIND/('mobile' if DETAIL<1 else 'high');OUT.mkdir(parents=True,exist_ok=True)
os.environ['SOFA_DETAIL']=str(DETAIL)
exec((ROOT/'mesh_helpers.py').read_text())
P=str(OUT);MODEL_NAME={'sofa':'Zamer_Sofa_v3','armchair':'Zamer_Armchair_Sand','table':'Zamer_Table_Walnut','bed':'Zamer_Bed_Sand','washer':'Zamer_Washer','toilet':'Zamer_Toilet','chandelier':'Zamer_Chandelier_Ring','rug':'Zamer_Rug_2000x1400','sconce':'Zamer_Wall_Sconce_UpDown'}[KIND]
MATERIAL_NAME='Sand fine woven linen';NORMAL_SCALE=.35;MATERIAL_OVERRIDES=None
def cylinder(name,r0,r1,height,pos,rotation=(0,0,0),mat=0,N=72):
 N=max(16,round(N*DETAIL));vs=[];uv=[];fs=[];R=rot(*rotation)
 for j,(r,z) in enumerate([(r0,-height/2),(r1,height/2)]):
  for i in range(N):
   ang=2*math.pi*i/N;q=np.array([r*math.cos(ang),r*math.sin(ang),z]);vs.append(R@q+pos);uv.append([i/N,height*j/.7])
 for i in range(N):
  a=i;b=(i+1)%N;c=i+N;d=(i+1)%N+N;fs.extend([[a,b,d],[a,d,c]])
 # Separate cap vertices provide the physically correct flat cap normals.
 for ring,z,r,sign in [(0,-height/2,r0,-1),(1,height/2,r1,1)]:
  k=len(vs);vs.append(R@np.array([0,0,z])+pos);uv.append([0,0])
  for i in range(N):
   ang=2*math.pi*i/N;q=np.array([r*math.cos(ang),r*math.sin(ang),z]);vs.append(R@q+pos);uv.append([q[0]/.7,q[1]/.7])
  for i in range(N):
   f=[k,k+1+i,k+1+(i+1)%N];fs.append(f if sign>0 else f[::-1])
 add(name,vs,fs,uv,mat)
def turned_top():
 N=max(40,round(128*DETAIL));rings=[(.435,.375),(.443,.377),(.448,.382),(.45,.390),(.45,.405),(.446,.414),(.438,.420)]
 vs=[];uv=[];fs=[]
 for r,z in rings:
  for i in range(N):
   t=2*math.pi*i/N;vs.append([r*math.cos(t),r*math.sin(t),z]);uv.append([r*math.cos(t)/.75,r*math.sin(t)/.75])
 for k in range(len(rings)-1):
  for i in range(N):
   a=k*N+i;b=k*N+(i+1)%N;c=a+N;d=b+N;fs.extend([[a,b,d],[a,d,c]])
 for ring,sign in [(0,-1),(len(rings)-1,1)]:
  k=len(vs);vs.append([0,0,rings[ring][1]]);uv.append([0,0])
  for i in range(N):
   f=[k,ring*N+i,ring*N+(i+1)%N];fs.append(f if sign>0 else f[::-1])
 add('rounded_solid_walnut_top',vs,fs,uv,0)
if KIND=='sofa':
 # Approved Zamer Sofa V3: 2.2m straight sofa, two seat/back cushions,
 # two matching loose pillows and dark walnut feet.
 softbox('upholstered_plinth',(2.09,.87,.19),(0,0,.21),.026,N=18)
 softbox('front_apron',(1.825,.040,.115),(0,-.445,.255),.014,N=12)
 softbox('rear_frame',(2.09,.165,.43),(0,.355,.46),.032,N=20)
 for side in [-1,1]:
  softbox('arm_'+str(side),(.185,.95,.485),(side*1.008,0,.405),.030,.008,N=26)
  piping('arm_upper_welt_'+str(side),.158,.90,.242,(side*1.008,0,.405),plane='xz',rad=.025)
 for i,x in enumerate([-.456,.456]):
  softbox('seat_cushion_'+str(i+1),(.945,.77,.197),(x,-.085,.385),.040,.020,N=32)
  piping('seat_welt_'+str(i+1),.915,.735,.008,(x,-.085,.385),rad=.045)
  softbox('back_cushion_'+str(i+1),(.965,.245,.365),(x,.270,.625),.045,.030,rotation=(-.11,0,0),N=32)
  piping('back_welt_'+str(i+1),.925,.335,0,(x,.270,.625),rotation=(-.11,0,0),plane='xz',rad=.040)
 for i,x in enumerate([-.705,.705]):
  softbox('loose_pillow_'+str(i+1),(.410,.105,.395),(x,.115,0),.020,.075,rotation=(-.30,0,.09*(-1 if i==0 else 1)),N=40)
  dz=.475-.006-parts[-1]['v'][:,2].min();parts[-1]['v'][:,2]+=dz
  piping('pillow_welt_'+str(i+1),.398,.382,0,(x,.115,dz),rotation=(-.30,0,.09*(-1 if i==0 else 1)),plane='xz',rad=.024)
 for x in [-.97,.97]:
  for y in [-.36,.36]:
   softbox('walnut_foot',(.055,.055,.125),(x,y,.0625),.006,mat=2,N=5)
 dims=np.array([2.20,.95,.85]);LABEL='Диван Sand V3';CATEGORY='Мягкая мебель'
elif KIND=='armchair':
 softbox('upholstered_base',(.84,.83,.205),(0,0,.223),.024,N=18)
 softbox('front_apron',(.64,.035,.12),(0,-.424,.271),.015,N=12)
 softbox('back_frame',(.84,.16,.445),(0,.347,.49),.030,N=20)
 for side in [-1,1]:
  softbox('arm_'+str(side),(.16,.88,.49),(side*.38,0,.44),.028,.008,N=26)
  piping('arm_welt_'+str(side),.146,.845,.239,(side*.38,0,.44),rad=.025)
 softbox('seat_cushion',(.615,.688,.175),(0,-.082,.411),.038,.021,N=32)
 piping('seat_welt',.607,.674,.008,(0,-.082,.411),rad=.043)
 softbox('back_cushion',(.623,.182,.343),(0,.248,.663),.045,.033,rotation=(-.12,0,0),N=32)
 piping('back_welt',.602,.321,0,(0,.248,.663),rotation=(-.12,0,0),plane='xz',rad=.039)
 softbox('loose_pillow_1',(.370,.096,.370),(.015,.002,0),.019,.075,rotation=(-.25,0,.08),N=42)
 dz=.508-.006-parts[-1]['v'][:,2].min();parts[-1]['v'][:,2]+=dz
 piping('pillow_welt',.36,.36,0,(.015,.002,dz),rotation=(-.25,0,.08),plane='xz',rad=.023)
 for x in [-.346,.346]:
  for y in [-.331,.331]:softbox('walnut_foot',(.054,.054,.132),(x,y,.066),.006,mat=2,N=5)
 dims=np.array([.92,.90,.86]);LABEL='Кресло Sand';CATEGORY='Мягкая мебель'
elif KIND=='table':
 turned_top()
 for i in range(3):
  a=math.pi/6+2*math.pi*i/3;outward=np.array([math.cos(a),math.sin(a),0.])
  pos=outward*.235+np.array([0,0,.19])
  cylinder('tapered_splayed_leg_'+str(i+1),.027,.043,.388,pos,rotation=(.16*math.sin(a),-.16*math.cos(a),0),N=64)
  cylinder('top_support_'+str(i+1),.054,.054,.035,outward*.199+np.array([0,0,.365]),N=48)
 dims=np.array([.90,.90,.42]);LABEL='Стол Walnut';CATEGORY='Столы и стулья';MATERIAL_NAME='Natural oiled walnut';NORMAL_SCALE=.18
elif KIND=='bed':
 softbox('upholstered_bed_base',(1.70,2.10,.24),(0,-.04,.23),.035,.008,N=24)
 softbox('headboard_frame',(1.77,.14,1.02),(0,.99,.62),.038,N=26)
 for side in [-1,1]:
  softbox('padded_headboard_'+str(side),(.85,.105,.78),(side*.433,.884,.694),.04,.024,N=26)
  piping('headboard_welt_'+str(side),.824,.754,-.019,(side*.433,.884,.694),plane='xz',rad=.044)
 softbox('mattress',(1.60,1.995,.195),(0,-.056,.414),.049,.019,N=32)
 piping('mattress_welt',1.572,1.965,.010,(0,-.056,.414),rad=.052)
 softbox('soft_linen_duvet',(1.65,1.53,.086),(0,-.330,.556),.030,.023,N=48)
 duvet=parts[-1]
 v=duvet['v'];mask=v[:,2]>.559;v[mask,2]+=.004*np.sin(v[mask,0]*7+v[mask,1]*9)*np.exp(-((v[mask,1]+.95)/.26)**2)
 piping('duvet_lower_seam',1.62,1.495,-.006,(0,-.330,.556),rad=.036)
 softbox('folded_duvet_edge',(1.64,.145,.090),(0,.381,.566),.032,.009,N=28)
 for i,x in enumerate([-.397,.397]):
  softbox('loose_pillow_'+str(i+1),(.65,.115,.435),(x,.586,0),.020,.074,rotation=(-1.11,0,0),N=40)
  dz=.526-.007-parts[-1]['v'][:,2].min();parts[-1]['v'][:,2]+=dz
  piping('sleep_pillow_welt_'+str(i+1),.638,.424,0,(x,.586,dz),rotation=(-1.11,0,0),plane='xz',rad=.026)
 for x in [-.726,.726]:
  for y in [-.881,.851]:softbox('dark_walnut_foot',(.074,.074,.128),(x,y,.064),.008,mat=2,N=5)
 dims=np.array([1.80,2.20,1.13]);LABEL='Кровать Sand';CATEGORY='Кровати'
elif KIND=='washer':
 softbox('washer_body',(.60,.60,.85),(0,0,.425),.025,N=10,mat=0)
 softbox('control_panel',(.54,.035,.14),(0,-.304,.735),.008,N=7,mat=0)
 cylinder('door_rim',.225,.225,.036,(0,-.312,.43),rotation=(math.pi/2,0,0),mat=2,N=64)
 cylinder('door_glass',.180,.180,.041,(0,-.334,.43),rotation=(math.pi/2,0,0),mat=1,N=64)
 cylinder('selector',.038,.038,.025,(.14,-.326,.75),rotation=(math.pi/2,0,0),mat=2,N=40)
 dims=np.array([.60,.62,.85]);LABEL='Стиральная машина Pro';CATEGORY='Бытовая техника'
 MATERIAL_OVERRIDES=[
  {'name':'White enamel','pbrMetallicRoughness':{'baseColorFactor':[.84,.87,.88,1],'metallicFactor':.04,'roughnessFactor':.27}},
  {'name':'Dark washer glass','pbrMetallicRoughness':{'baseColorFactor':[.025,.035,.045,1],'metallicFactor':.18,'roughnessFactor':.10}},
  {'name':'Brushed steel','pbrMetallicRoughness':{'baseColorFactor':[.55,.58,.60,1],'metallicFactor':.82,'roughnessFactor':.20}},
 ]
elif KIND=='toilet':
 softbox('toilet_base',(.34,.54,.42),(0,-.04,.21),.09,.015,N=20,mat=0)
 softbox('toilet_bowl',(.39,.68,.30),(0,-.08,.47),.11,.025,N=24,mat=0)
 cylinder('seat',.19,.19,.035,(0,-.12,.625),mat=1,N=64)
 parts[-1]['v'][:,1]=(parts[-1]['v'][:,1]+.12)*1.48-.12
 softbox('cistern',(.37,.19,.43),(0,.235,.555),.035,N=16,mat=0)
 cylinder('flush_button',.032,.032,.012,(0,.235,.78),mat=2,N=36)
 dims=np.array([.39,.70,.76]);LABEL='Унитаз керамический';CATEGORY='Сантехника'
 MATERIAL_OVERRIDES=[
  {'name':'Gloss ceramic','pbrMetallicRoughness':{'baseColorFactor':[.96,.965,.96,1],'metallicFactor':0,'roughnessFactor':.12}},
  {'name':'Seat soft white','pbrMetallicRoughness':{'baseColorFactor':[.90,.91,.90,1],'metallicFactor':0,'roughnessFactor':.24}},
  {'name':'Chrome button','pbrMetallicRoughness':{'baseColorFactor':[.65,.68,.70,1],'metallicFactor':.92,'roughnessFactor':.12}},
 ]
elif KIND=='chandelier':
 circle=[np.array([.43*math.cos(t),.43*math.sin(t),.10]) for t in np.linspace(0,2*math.pi,96,endpoint=False)]
 tube('outer_ring',circle,r=.020,mat=0)
 circle_glow=[np.array([.405*math.cos(t),.405*math.sin(t),.10]) for t in np.linspace(0,2*math.pi,96,endpoint=False)]
 tube('light_ring',circle_glow,r=.010,mat=1)
 cylinder('ceiling_canopy',.09,.09,.045,(0,0,.327),mat=0,N=48)
 for a in [0,2*math.pi/3,4*math.pi/3]:
  cylinder('suspension',.003,.003,.22,(.32*math.cos(a),.32*math.sin(a),.215),mat=2,N=18)
 dims=np.array([.90,.90,.35]);LABEL='Люстра-кольцо Production';CATEGORY='Освещение'
 MATERIAL_OVERRIDES=[
  {'name':'Black anodized metal','pbrMetallicRoughness':{'baseColorFactor':[.035,.04,.045,1],'metallicFactor':.82,'roughnessFactor':.24}},
  {'name':'Warm diffuser','pbrMetallicRoughness':{'baseColorFactor':[1,.78,.48,1],'metallicFactor':0,'roughnessFactor':.20},'emissiveFactor':[1,.48,.18]},
  {'name':'Suspension wire','pbrMetallicRoughness':{'baseColorFactor':[.24,.25,.26,1],'metallicFactor':.74,'roughnessFactor':.28}},
 ]
elif KIND=='sconce':
 softbox('wall_backplate',(.18,.035,.22),(0,.052,.15),.012,N=8,mat=0)
 softbox('sconce_body',(.13,.14,.25),(0,0,.15),.028,N=14,mat=0)
 cylinder('upper_diffuser',.052,.062,.035,(0,0,.282),mat=1,N=52)
 cylinder('lower_diffuser',.062,.052,.035,(0,0,.018),mat=1,N=52)
 softbox('inner_reflector',(.09,.095,.16),(0,-.018,.15),.018,N=9,mat=2)
 dims=np.array([.18,.15,.30]);LABEL='Бра вверх/вниз Production';CATEGORY='Освещение'
 MATERIAL_OVERRIDES=[
  {'name':'Black anodized body','pbrMetallicRoughness':{'baseColorFactor':[.035,.040,.043,1],'metallicFactor':.78,'roughnessFactor':.27}},
  {'name':'Warm diffuser','pbrMetallicRoughness':{'baseColorFactor':[1,.80,.52,1],'metallicFactor':0,'roughnessFactor':.18},'emissiveFactor':[1,.42,.12]},
  {'name':'Inner reflector','pbrMetallicRoughness':{'baseColorFactor':[.66,.60,.50,1],'metallicFactor':.62,'roughnessFactor':.22}},
 ]
elif KIND=='rug':
 softbox('rug_body',(2.0,1.4,.035),(0,0,.0175),.028,.003,N=20,mat=0)
 dims=np.array([2.0,1.4,.035]);LABEL='Ковёр 2000×1400';CATEGORY='Декор';MATERIAL_NAME='Dense woven rug';NORMAL_SCALE=.55
else:raise ValueError(KIND)
# Units and floor origin are exactly consistent across all furniture models.
V=np.concatenate([p['v'] for p in parts]);lo=V.min(0);hi=V.max(0);factor=dims/(hi-lo)
for p in parts:
 p['v']=(p['v']-np.array([(lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]]))*factor
 p['n']/=factor;p['n']/=np.linalg.norm(p['n'],axis=1)[:,None]
exec((ROOT/'linen_texture.py').read_text())
if KIND=='table':
 from scipy.ndimage import gaussian_filter
 xf=xx/S;yf=yy/S
 warp=.28*np.sin(2*np.pi*yf)+.09*np.sin(6*np.pi*yf)+.04*np.sin(2*np.pi*xf)
 phase=xf*43+warp
 grain=np.sin(2*np.pi*phase)+.30*np.sin(2*np.pi*phase*3)
 pores=np.maximum(0,np.sin(2*np.pi*phase*2+.3))**18
 low=np.sin(2*np.pi*xf*3+warp*.25)
 noise=rng.normal(0,.7,(S,S))
 base=np.clip(np.array([135,99,70])[None,None,:]+(grain*2.3-low*4-pores*3+noise)[:,:,None],0,255).astype('uint8')
 buf=io.BytesIO();Image.fromarray(base).save(buf,format='PNG');tex=buf.getvalue()
 height=grain*.06+noise*.003;gy,gx=np.gradient(height);normal=np.dstack((-gx*.20,-gy*.20,np.ones_like(gx)));normal/=np.linalg.norm(normal,axis=2)[:,:,None]
 buf=io.BytesIO();Image.fromarray(np.uint8((normal*.5+.5)*255)).save(buf,format='PNG');ntex=buf.getvalue()
 rough=np.uint8(np.clip(.48+grain*.015+low*.025,.39,.59)*255);roughrgb=np.dstack((np.full_like(rough,255),rough,np.zeros_like(rough)))
 buf=io.BytesIO();Image.fromarray(roughrgb).save(buf,format='PNG');rtex=buf.getvalue()
 Image.fromarray(base).save(P+'/Fabric_basecolor.png');Image.fromarray(np.uint8((normal*.5+.5)*255)).save(P+'/Fabric_normal.png');Image.fromarray(roughrgb).save(P+'/Fabric_roughness.png')
exec((ROOT/'export_glb.py').read_text())
meta={'id':MODEL_NAME.lower(),'name':LABEL,'category':CATEGORY,'units':'metres','up_axis':'Y','front_axis':'+Z','origin':'floor center','dimensions_mm':(dims*1000).astype(int).tolist(),'triangles':sum(len(p['f']) for p in parts),'quality':'mobile' if DETAIL<1 else 'high','materials':3,'texture_resolution':[512,512],'status':'production asset generated for Zamer'}
(OUT/'asset.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
print(json.dumps(meta,ensure_ascii=False),flush=True)
