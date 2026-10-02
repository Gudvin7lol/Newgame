binary=bytearray();views=[];access=[]
def bv(data):
 while len(binary)%4:binary.append(0)
 i=len(views);views.append({'buffer':0,'byteOffset':len(binary),'byteLength':len(data)});binary.extend(data);return i
def acc(arr,ctype,typ):
 arr=np.ascontiguousarray(arr);d={'bufferView':bv(arr.tobytes()),'componentType':ctype,'count':len(arr),'type':typ}
 if typ=='VEC3':d.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
 access.append(d);return len(access)-1
meshes=[];nodes=[]
for p in parts:
 v=p['v'][:,[0,2,1]].copy();v[:,2]*=-1
 n=p['n'][:,[0,2,1]].copy();n[:,2]*=-1
 a=acc(v.astype('<f4'),5126,'VEC3');b=acc(n.astype('<f4'),5126,'VEC3');c=acc(p['uv'].astype('<f4'),5126,'VEC2');d=acc(p['f'].reshape(-1).astype('<u4'),5125,'SCALAR')
 meshes.append({'name':p['name'],'primitives':[{'attributes':{'POSITION':a,'NORMAL':b,'TEXCOORD_0':c},'indices':d,'material':p['mat']}]});nodes.append({'name':p['name'],'mesh':len(meshes)-1})
g={'asset':{'version':'2.0','generator':'ZAMER furniture collection'},'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'accessors':access,'bufferViews':views,'images':[{'bufferView':bv(tex),'mimeType':'image/png'},{'bufferView':bv(ntex),'mimeType':'image/png'},{'bufferView':bv(rtex),'mimeType':'image/png'}],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],'textures':[{'source':0,'sampler':0},{'source':1,'sampler':0},{'source':2,'sampler':0}],'materials':[{'name':'Sand woven linen','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':1,'metallicRoughnessTexture':{'index':2}},'normalTexture':{'index':1,'scale':.35}},{'name':'Upholstery piping','pbrMetallicRoughness':{'baseColorFactor':[.54,.47,.38,1],'metallicFactor':0,'roughnessFactor':.94}},{'name':'Dark walnut feet','pbrMetallicRoughness':{'baseColorFactor':[.07,.037,.018,1],'metallicFactor':0,'roughnessFactor':.48}}],'buffers':[{'byteLength':len(binary)}]}
g['materials'][0]['name']=MATERIAL_NAME
g['materials'][0]['normalTexture']['scale']=NORMAL_SCALE
j=json.dumps(g,separators=(',',':')).encode();j+=b' '*((-len(j))%4);binary+=b'\0'*((-len(binary))%4)
with open(P+'/'+MODEL_NAME+('_Mobile' if DETAIL<1 else '')+'.glb','wb') as f:f.write(struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(binary))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binary),0x004e4942)+binary)
