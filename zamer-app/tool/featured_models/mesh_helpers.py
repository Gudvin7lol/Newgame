import numpy as np, math, json, struct, io, os, zipfile
from PIL import Image, ImageFilter, ImageDraw, ImageFont
P=os.path.dirname(__file__)
rng=np.random.default_rng(19)
parts=[]
DETAIL=float(os.environ.get("SOFA_DETAIL","1"))
def rot(rx=0,ry=0,rz=0):
 c,s=np.cos,np.sin
 return np.array([[c(rz),-s(rz),0],[s(rz),c(rz),0],[0,0,1]])@np.array([[c(ry),0,s(ry)],[0,1,0],[-s(ry),0,c(ry)]])@np.array([[1,0,0],[0,c(rx),-s(rx)],[0,s(rx),c(rx)]])
def add(name,v,f,uv,mat=0):
 v=np.array(v);f=np.array(f,dtype=np.uint32);n=np.zeros_like(v)
 cross=np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]])
 for k in range(3):np.add.at(n,f[:,k],cross)
 keys=np.round(v,7); unique, inv=np.unique(keys,axis=0,return_inverse=True); welded=np.zeros((len(unique),3)); np.add.at(welded,inv,n); n=welded[inv]
 n/=np.maximum(np.linalg.norm(n,axis=1)[:,None],1e-10)
 parts.append(dict(name=name,v=v,f=f,n=n,uv=np.array(uv),mat=mat))
def softbox(name,size,pos,r=.05,bulge=0,rotation=(0,0,0),mat=0,N=20):
 N=max(4,round(N*DETAIL))
 h=np.array(size)/2;R=rot(*rotation);vs=[];fs=[];uv=[]
 for axis in range(3):
  a=(axis+1)%3;b=(axis+2)%3
  for sign in [-1,1]:
   start=len(vs)
   for j in range(N+1):
    for i in range(N+1):
     q=np.zeros(3);q[axis]=sign*h[axis];q[a]=(2*i/N-1)*h[a];q[b]=(2*j/N-1)*h[b]
     core=np.clip(q,-h+r,h-r);d=q-core;q=core+r*d/np.linalg.norm(d)
     u=2*i/N-1;w=2*j/N-1
     pillow=name.startswith("loose_pillow")
     active=not pillow or axis==1
     q[axis]+=sign*bulge*active*(max(0,1-u*u)*max(0,1-w*w))**(.48 if pillow else .75)
     if bulge and active and not name.startswith("seat") :
      edge=np.exp(-((abs(w)-.78)/.18)**2)*(1-u*u)
      q[axis]+=sign*(.004 if pillow else .0015)*np.sin(u*14+w*4)*edge*(abs(u)**4 if pillow else 1)
      if pillow:
       q[axis]-=sign*.009*np.exp(-((u-.64*w-.12)/.065)**2)*np.exp(-((w+.61)/.29)**2)
       q[2]-=.018*(1-(q[0]/h[0])**2)*(1-(q[2]/h[2])**2)
     if pillow:
      q[0]*=.91+.09*min(1,abs(q[2]/h[2]))**3
      q[2]-=.030*max(0,1-(q[0]/h[0])**2)*max(0,q[2]/h[2])**4
     vs.append(R@q+pos);uv.append([q[a]/.34,q[b]/.34])
   for j in range(N):
    for i in range(N):
     k=start+j*(N+1)+i
     tris=[[k,k+1,k+N+2],[k,k+N+2,k+N+1]]
     if sign<0:tris=[t[::-1] for t in tris]
     fs.extend(tris)
 add(name,vs,fs,uv,mat)
def tube(name,path,r=.0025,mat=1):
 vs=[];fs=[];uv=[];path=np.array(path);L=len(path)
 for i,p in enumerate(path):
  t=path[(i+1)%L]-path[(i-1)%L];t/=np.linalg.norm(t)
  a=np.cross(t,[0,0,1]);
  if np.linalg.norm(a)<.01:a=np.cross(t,[0,1,0])
  a/=np.linalg.norm(a);b=np.cross(t,a)
  for j in range(6):
   ang=2*math.pi*j/6;vs.append(p+r*(a*math.cos(ang)+b*math.sin(ang)));uv.append([i/L,j/6])
 for i in range(L):
  for j in range(6):
   a=i*6+j;b=i*6+(j+1)%6;c=((i+1)%L)*6+j;d=((i+1)%L)*6+(j+1)%6
   fs.extend([[a,d,c],[a,b,d]])
 add(name,vs,fs,uv,mat)
def piping(name,w,h,depth,pos,rotation=(0,0,0),plane='xy',rad=.05):
 path=[];R=rot(*rotation)
 for cx,cy,ang in [(w/2-rad,h/2-rad,0),(-w/2+rad,h/2-rad,90),(-w/2+rad,-h/2+rad,180),(w/2-rad,-h/2+rad,270)]:
  for t in np.linspace(ang,ang+90,12,endpoint=False):
   a=cx+rad*np.cos(np.deg2rad(t));b=cy+rad*np.sin(np.deg2rad(t))
   q=[a,b,depth] if plane=='xy' else [a,depth,b]
   path.append(R@q+pos)
 tube(name,path)
