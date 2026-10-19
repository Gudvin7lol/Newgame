#include "glb_export.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
namespace zamer {
namespace {
void word(std::vector<uint8_t>&out,uint32_t x){
    for(int i=0;i<4;i++)out.push_back(uint8_t(x>>(8*i)));
}
void writeFloat(std::vector<uint8_t>&out,float value){
    uint32_t bits=0;std::memcpy(&bits,&value,sizeof(bits));word(out,bits);
}
void align4(std::vector<uint8_t>&out){while(out.size()%4)out.push_back(0);}
std::string vec(Vec3 v){std::ostringstream s;s<<std::setprecision(8)<<'['<<v.x<<','<<v.y<<','<<v.z<<']';return s.str();}
std::string safeNumber(float x){std::ostringstream s;s<<std::setprecision(9)<<x;return s.str();}
}
std::vector<uint8_t> exportGLB(const Scene&scene){
    if(scene.objects.empty()||scene.objects.size()>64)return {};
    std::vector<uint8_t> binary;
    std::ostringstream views,accessors,materials,meshes,nodes,roots;
    views<<std::setprecision(9);
    bool first=true;
    for(size_t i=0;i<scene.objects.size();i++){
        const Object&o=scene.objects[i];
        if(!o.mesh.valid())return {};
        auto vertices=o.mesh.interleavedTrianglesUV(o.smoothShading);
        const size_t n=vertices.size()/8;
        if(n==0||n>2000000 || vertices.size()%8!=0 || binary.size()>100000000)return {};
        Vec3 low{std::numeric_limits<float>::max(),std::numeric_limits<float>::max(),std::numeric_limits<float>::max()};
        Vec3 high{-low.x,-low.y,-low.z};
        const size_t offset=binary.size();
        for(size_t k=0;k<n;k++){
            const float *p=&vertices[k*8];
            for(int j=0;j<8;j++)if(!std::isfinite(p[j]))return {};
            low.x=std::min(low.x,p[0]);low.y=std::min(low.y,p[1]);low.z=std::min(low.z,p[2]);
            high.x=std::max(high.x,p[0]);high.y=std::max(high.y,p[1]);high.z=std::max(high.z,p[2]);
            for(int j=0;j<8;j++)writeFloat(binary,p[j]);
        }
        align4(binary);
        const size_t len=binary.size()-offset;
        if(!first){views<<',';materials<<',';meshes<<',';nodes<<',';roots<<',';}first=false;
        views<<"{\"buffer\":0,\"byteOffset\":"<<offset<<",\"byteLength\":"<<len<<",\"byteStride\":32,\"target\":34962}";
        const auto m=o.pbr;
        if(!std::isfinite(m.color.x)||!std::isfinite(m.color.y)||!std::isfinite(m.color.z)||
           !std::isfinite(m.metallic)||!std::isfinite(m.roughness)||
           o.scale.x<=0||o.scale.y<=0||o.scale.z<=0)return {};
        materials<<"{\"name\":\"ZAMER material "<<i+1<<"\",\"pbrMetallicRoughness\":{\"baseColorFactor\":["
                 <<safeNumber(m.color.x)<<','<<safeNumber(m.color.y)<<','<<safeNumber(m.color.z)
                 <<",1],\"metallicFactor\":"<<safeNumber(m.metallic)
                 <<",\"roughnessFactor\":"<<safeNumber(m.roughness)<<"},\"doubleSided\":true}";
        meshes<<"{\"name\":\"Mesh "<<i+1<<"\",\"primitives\":[{\"attributes\":{\"POSITION\":"
              <<3*i<<",\"NORMAL\":"<<3*i+1<<",\"TEXCOORD_0\":"<<3*i+2
              <<"},\"material\":"<<i<<",\"mode\":4}]}";
        const float q=std::sin(o.yaw*0.5f),qw=std::cos(o.yaw*0.5f);
        nodes<<"{\"name\":\"Object "<<i+1<<"\",\"mesh\":"<<i<<",\"translation\":"
             <<vec(o.position)<<",\"rotation\":[0,"<<safeNumber(q)<<",0,"<<safeNumber(qw)
             <<"],\"scale\":"<<vec(o.scale)<<"}";
        roots<<i;
        // Create three accessors referencing a single interleaved bufferView.
        if(i)accessors<<',';
        accessors<<"{\"bufferView\":"<<i<<",\"byteOffset\":0,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC3\",\"min\":"<<vec(low)<<",\"max\":"<<vec(high)<<"},";
        accessors<<"{\"bufferView\":"<<i<<",\"byteOffset\":12,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC3\"},";
        accessors<<"{\"bufferView\":"<<i<<",\"byteOffset\":24,\"componentType\":5126,\"count\":"
                 <<n<<",\"type\":\"VEC2\"}";
    }
    std::ostringstream json;
    json<<"{\"asset\":{\"version\":\"2.0\",\"generator\":\"ZAMER Native Studio 1.1\"},"
        <<"\"scene\":0,\"scenes\":[{\"nodes\":["<<roots.str()<<"]}],"
        <<"\"nodes\":["<<nodes.str()<<"],\"meshes\":["<<meshes.str()<<"],"
        <<"\"materials\":["<<materials.str()<<"],\"buffers\":[{\"byteLength\":"<<binary.size()<<"}],"
        <<"\"bufferViews\":["<<views.str()<<"],\"accessors\":["<<accessors.str()<<"]}";
    std::string j=json.str();
    while(j.size()%4)j.push_back(' ');
    const uint64_t total=12ull+8ull+j.size()+8ull+binary.size();
    if(total>std::numeric_limits<uint32_t>::max())return {};
    std::vector<uint8_t>result;
    result.reserve(size_t(total));
    word(result,0x46546C67u);word(result,2u);word(result,uint32_t(total));
    word(result,uint32_t(j.size()));word(result,0x4E4F534Au);
    result.insert(result.end(),j.begin(),j.end());
    word(result,uint32_t(binary.size()));word(result,0x004E4942u);
    result.insert(result.end(),binary.begin(),binary.end());
    return result;
}
}
