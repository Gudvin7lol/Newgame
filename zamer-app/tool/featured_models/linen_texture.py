from scipy.ndimage import gaussian_filter
S=512;yy,xx=np.mgrid[:S,:S]
# Small yarn weave with irregular fibre shading; no broad periodic stripes.
period=8.;jitterx=gaussian_filter(rng.normal(0,1,(S,S)),8,mode='wrap')*2
jittery=gaussian_filter(rng.normal(0,1,(S,S)),8,mode='wrap')*2
warp=np.cos(2*np.pi*(xx+jitterx)/period);weft=np.cos(2*np.pi*(yy+jittery)/period)
checker=(-1.)**((xx//8+yy//8)%2)
weave=1.1*warp+.9*weft+.8*checker*warp*weft
noise=rng.normal(0,.75,(S,S));mottle=gaussian_filter(rng.normal(0,1,(S,S)),6,mode='wrap');mottle/=mottle.std()
base=np.clip(np.array([200,189,172])[None,None,:]+(weave+noise+mottle*.35)[:,:,None],0,255).astype('uint8')
buf=io.BytesIO();Image.fromarray(base).save(buf,format='PNG');tex=buf.getvalue()
height=(weave+noise*.3)/20;gy,gx=np.gradient(height);normal=np.dstack((-gx*.38,-gy*.38,np.ones_like(gx)));normal/=np.linalg.norm(normal,axis=2)[:,:,None]
buf=io.BytesIO();Image.fromarray(np.uint8((normal*.5+.5)*255)).save(buf,format='PNG');ntex=buf.getvalue()
rough=np.uint8(np.clip(.89+mottle*.012+weave*.003,.84,.95)*255);roughrgb=np.dstack((np.full_like(rough,255),rough,np.zeros_like(rough)))
buf=io.BytesIO();Image.fromarray(roughrgb).save(buf,format='PNG');rtex=buf.getvalue()
Image.fromarray(base).save(P+'/Fabric_basecolor.png')
Image.fromarray(np.uint8((normal*.5+.5)*255)).save(P+'/Fabric_normal.png')
Image.fromarray(roughrgb).save(P+'/Fabric_roughness.png')
