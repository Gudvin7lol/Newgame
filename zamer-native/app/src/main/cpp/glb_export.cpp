#include "glb_export.hpp"
#include "texture_bake.hpp"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
#include <vector>
namespace zamer {
namespace {
void word(std::vector<uint8_t>&out,uint32_t x){for(int i=0;i<4;i++)out.push_back(uint8_t(x>>(8*i)));}
void writeFloat(std::vector<uint8_t>&out,float value){
    uint32_t bits=0;std::memcpy(&bits,&value,sizeof(bits));word(out,bits);
}
void align4(std::vector<uint8_t>&out){while(out.size()%4)out.push_back(0);}
std::string vec(Vec3 v){std::ostringstream s;s<<std::setprecision(8)<<'['<<v.x<<','<<v.y<<','<<v.z<<']';return s.str();}
std::string number(float x){std::ostringstream s;s<<std::setprecision(9)<<x;return s.str();}
Vec3 getPos(const std::vector<float>&verts,size_t i){
    return {verts[i*8],verts[i*8+1],verts[i*8+2]};
}
Vec3 getNormal(const std::vector<float>&verts,size_t i){
    return {verts[i*8+3],verts[i*8+4],verts[i*8+5]};
}
Vec3 tangent(const std::vector<float>&v,size_t base){
    const Vec3 a=getPos(v,base),b=getPos(v,base+1),c=getPos(v,base+2);
    const float u1=v[(base+1)*8+6]-v[base*8+6];
    const float v1=v[(base+1)*8+7]-v[base*8+7];
    const float u2=v[(base+2)*8+6]-v[base*8+6];
    const float v2=v[(base+2)*8+7]-v[base*8+7];
    const float determinant=u1*v2-u2*v1;
    if(std::fabs(determinant)>1e-9f)return ((b-a)*v2-(c-a)*v1)/determinant;
    Vec3 n=getNormal(v,base);
    Vec3 t=cross(n,{0,1,0});
    if(t.length()<0.01f)t=cross(n,{1,0,0});
    return t;
}
}
std::vector<uint8_t> exportGLB(const Scene&scene){
    if(scene.objects.empty()||scene.objects.size()>64)return {};
    std::vector<uint8_t>binary;
    std::ostringstream views,accessors,materials,meshes,nodes,roots,images,textures;
    bool first=true;
    for(size_t i=0;i<scene.objects.size();i++){
        const Object&o=scene.objects[i];
        if(!o.mesh.valid()||!std::isfinite(o.uvScale)||o.uvScale<0.1f||o.uvScale>10.f||
           !std::isfinite(o.yaw)||!std::isfinite(o.uvRotation)||
           !std::isfinite(o.uvOffsetX)||!std::isfinite(o.uvOffsetY)||
           !std::isfinite(o.scale.x)||!std::isfinite(o.scale.y)||
           !std::isfinite(o.scale.z)||o.scale.x<=0||o.scale.y<=0||o.scale.z<=0)return {};
        const auto&m=o.pbr;
        if(!std::isfinite(m.color.x)||!std::isfinite(m.color.y)||!std::isfinite(m.color.z)||
           !std::isfinite(m.metallic)||!std::isfinite(m.roughness)||
           m.metallic<0||m.metallic>1||m.roughness<0.04f||m.roughness>1)return {};
        auto v=o.mesh.interleavedTrianglesUV(o.smoothShading);
        const size_t n=v.size()/8;
        if(n==0||n>500000||v.size()%24!=0||binary.size()>26*1024*1024)return {};
        const float cosUV=std::cos(o.uvRotation),sinUV=std::sin(o.uvRotation);
        for(size_t k=0;k<n;k++){
            const float u=v[k*8+6]*o.uvScale;
            const float t=v[k*8+7]*o.uvScale;
            v[k*8+6]=u*cosUV-t*sinUV+o.uvOffsetX;
            v[k*8+7]=u*sinUV+t*cosUV+o.uvOffsetY;
        }
        Vec3 low{std::numeric_limits<float>::max(),std::numeric_limits<float>::max(),std::numeric_limits<float>::max()};
        Vec3 high{-low.x,-low.y,-low.z};
        const size_t offset=binary.size();
        for(size_t k=0;k<n;k+=3){
            Vec3 t=tangent(v,k).normalized();
            for(size_t j=0;j<3;j++){
                const float*p=&v[(k+j)*8];
                for(size_t z=0;z<8;z++)if(!std::isfinite(p[z]))return {};
                Vec3 pos{p[0],p[1],p[2]},normal{p[3],p[4],p[5]};
                low.x=std::min(low.x,pos.x);low.y=std::min(low.y,pos.y);low.z=std::min(low.z,pos.z);
                high.x=std::max(high.x,pos.x);high.y=std::max(high.y,pos.y);high.z=std::max(high.z,pos.z);
                // Gram-Schmidt tangent orthogonalization per face vertex.
                Vec3 ortho=(t-normal*dot(t,normal)).normalized();
                if(ortho.length()<0.01f){
                    ortho=cross(normal,{0,1,0}).normalized();
                    if(ortho.length()<0.01f)ortho=cross(normal,{1,0,0}).normalized();
                }
                const Vec3 edgeA=getPos(v,k+1)-getPos(v,k);
                const Vec3 edgeB=getPos(v,k+2)-getPos(v,k);
                const float du1=v[(k+1)*8+6]-v[k*8+6];
                const float du2=v[(k+2)*8+6]-v[k*8+6];
                const Vec3 bitangent=(edgeB*du1-edgeA*du2);
                const float handedness=dot(cross(normal,ortho),bitangent)<0?-1.f:1.f;
                for(int col=0;col<8;col++)writeFloat(binary,p[col]);
                writeFloat(binary,ortho.x);writeFloat(binary,ortho.y);writeFloat(binary,ortho.z);
                writeFloat(binary,handedness);
            }
        }
        align4(binary);
        const size_t geomLen=binary.size()-offset;
        if(!first){views<<',';accessors<<',';materials<<',';meshes<<',';nodes<<',';roots<<',';}first=false;
        const size_t geomView=4*i;
        views<<"{\"buffer\":0,\"byteOffset\":"<<offset<<",\"byteLength\":"<<geomLen
             <<",\"byteStride\":48,\"target\":34962}";
        const auto maps=bakePbrMaps(o,128);
        for(size_t k=0;k<3;k++){
            if(maps[k].empty())return {};
            const size_t pngOffset=binary.size();
            binary.insert(binary.end(),maps[k].begin(),maps[k].end());
            const size_t pngLength=maps[k].size();
            align4(binary);
            views<<",{\"buffer\":0,\"byteOffset\":"<<pngOffset<<",\"byteLength\":"<<pngLength<<"}";
            if(i>0||k>0){images<<',';textures<<',';}
            images<<"{\"mimeType\":\"image/png\",\"bufferView\":"<<geomView+k+1<<"}";
            textures<<"{\"sampler\":0,\"source\":"<<3*i+k<<"}";
        }
        const size_t a=4*i;
        accessors<<"{\"bufferView\":"<<geomView<<",\"byteOffset\":0,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC3\",\"min\":"<<vec(low)<<",\"max\":"<<vec(high)<<"},";
        accessors<<"{\"bufferView\":"<<geomView<<",\"byteOffset\":12,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC3\"},";
        accessors<<"{\"bufferView\":"<<geomView<<",\"byteOffset\":24,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC2\"},";
        accessors<<"{\"bufferView\":"<<geomView<<",\"byteOffset\":32,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC4\"}";
        materials<<"{\"name\":\"ZAMER PBR "<<i+1<<"\",\"pbrMetallicRoughness\":{"
                 <<"\"baseColorFactor\":["<<number(m.color.x)<<','<<number(m.color.y)<<','<<number(m.color.z)
                 <<",1],\"baseColorTexture\":{\"index\":"<<3*i<<"},\"metallicFactor\":"<<number(m.metallic)
                 <<",\"roughnessFactor\":"<<number(m.roughness)
                 <<",\"metallicRoughnessTexture\":{\"index\":"<<3*i+2<<"}},"
                 <<"\"normalTexture\":{\"index\":"<<3*i+1<<",\"scale\":0.65},\"doubleSided\":true}";
        meshes<<"{\"name\":\"Mesh "<<i+1<<"\",\"primitives\":[{\"attributes\":{\"POSITION\":"
              <<a<<",\"NORMAL\":"<<a+1<<",\"TEXCOORD_0\":"<<a+2<<",\"TANGENT\":"<<a+3
              <<"},\"material\":"<<i<<",\"mode\":4}]}";
        const float q=std::sin(o.yaw*0.5f),qw=std::cos(o.yaw*0.5f);
        nodes<<"{\"name\":\"Object "<<i+1<<"\",\"mesh\":"<<i<<",\"translation\":"
             <<vec(o.position)<<",\"rotation\":[0,"<<number(q)<<",0,"<<number(qw)
             <<"],\"scale\":"<<vec(o.scale)<<"}";
        roots<<i;
    }
    if(binary.size()>32*1024*1024)return {};
    std::ostringstream json;
    json<<"{\"asset\":{\"version\":\"2.0\",\"generator\":\"ZAMER Native Studio 1.2\"},"
        <<"\"scene\":0,\"scenes\":[{\"nodes\":["<<roots.str()<<"]}],"
        <<"\"nodes\":["<<nodes.str()<<"],\"meshes\":["<<meshes.str()<<"],"
        <<"\"materials\":["<<materials.str()<<"],\"buffers\":[{\"byteLength\":"<<binary.size()<<"}],"
        <<"\"bufferViews\":["<<views.str()<<"],\"accessors\":["<<accessors.str()<<"],"
        <<"\"samplers\":[{\"magFilter\":9729,\"minFilter\":9729,\"wrapS\":10497,\"wrapT\":10497}],"
        <<"\"images\":["<<images.str()<<"],\"textures\":["<<textures.str()<<"]}";
    std::string text=json.str();
    while(text.size()%4)text.push_back(' ');
    const uint64_t total=12ull+8ull+text.size()+8ull+binary.size();
    if(total>uint64_t(std::numeric_limits<uint32_t>::max()))return {};
    std::vector<uint8_t>result;result.reserve(size_t(total));
    word(result,0x46546C67u);word(result,2u);word(result,uint32_t(total));
    word(result,uint32_t(text.size()));word(result,0x4E4F534Au);
    result.insert(result.end(),text.begin(),text.end());
    word(result,uint32_t(binary.size()));word(result,0x004E4942u);
    result.insert(result.end(),binary.begin(),binary.end());
    return result;
}
}
