from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
BASE = ROOT / 'build_models_base.py'
source = BASE.read_text()

if len(sys.argv) > 1 and sys.argv[1] == 'sofa':
    start = source.index("if KIND=='sofa':")
    end = source.index("elif KIND=='armchair':")
    replacement = r"""if KIND=='sofa':
 # +107 approved reference: a real 3-seat 2.2 m catalogue sofa, matching the supplied
 # render/top-view instead of the older 2.2 m two-cushion placeholder.
 softbox('upholstered_plinth',(2.09,.87,.19),(0,0,.21),.026,N=20)
 softbox('front_apron',(1.825,.040,.115),(0,-.445,.255),.014,N=14)
 softbox('rear_frame',(2.09,.165,.43),(0,.355,.46),.032,N=22)
 for side in [-1,1]:
  softbox('arm_'+str(side),(.185,.95,.485),(side*1.008,0,.405),.030,.008,N=28)
  piping('arm_upper_welt_'+str(side),.162,.90,.244,(side*1.008,0,.405),plane='xz',rad=.025)
 for i,x in enumerate([-.610,0,.610]):
  softbox('seat_cushion_'+str(i+1),(.590,.77,.197),(x,-.085,.385),.040,.020,N=34)
  piping('seat_welt_'+str(i+1),.568,.735,.008,(x,-.085,.385),rad=.045)
  softbox('back_cushion_'+str(i+1),(.610,.245,.365),(x,.270,.625),.045,.030,rotation=(-.11,0,0),N=34)
  piping('back_welt_'+str(i+1),.580,.335,0,(x,.270,.625),rotation=(-.11,0,0),plane='xz',rad=.040)
 for i,x in enumerate([-.705,.705]):
  softbox('loose_pillow_'+str(i+1),(.390,.105,.385),(x,.105,0),.020,.075,rotation=(-.30,0,.09*(-1 if i==0 else 1)),N=40)
  dz=.475-.006-parts[-1]['v'][:,2].min();parts[-1]['v'][:,2]+=dz
  piping('pillow_welt_'+str(i+1),.378,.372,0,(x,.105,dz),rotation=(-.30,0,.09*(-1 if i==0 else 1)),plane='xz',rad=.024)
 for x in [-.97,.97]:
  for y in [-.36,.36]:
   softbox('walnut_foot',(.058,.058,.128),(x,y,.064),.006,mat=2,N=5)
 dims=np.array([2.20,.95,.85]);LABEL='Диван Sand 3-местный';CATEGORY='Мягкая мебель'
"""
    source = source[:start] + replacement + source[end:]

exec(compile(source, str(BASE), 'exec'), {'__name__': '__main__', '__file__': str(BASE)})
