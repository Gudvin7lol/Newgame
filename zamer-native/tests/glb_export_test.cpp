#include "glb_export.hpp"
#include <cassert>
#include <cstdint>
#include <fstream>
#include <iostream>
using namespace zamer;
uint32_t le(const std::vector<uint8_t>&b,size_t x){
    return uint32_t(b[x])|(uint32_t(b[x+1])<<8)|(uint32_t(b[x+2])<<16)|(uint32_t(b[x+3])<<24);
}
int main(){
    Scene empty;assert(exportGLB(empty).empty());
    Scene scene;scene.add(0);scene.add(1);
    assert(scene.setCustomMaterial({0.2f,0.6f,0.9f},0.4f,0.25f));
    assert(scene.setPattern(2,2.f));
    auto bytes=exportGLB(scene);
    assert(bytes.size()>2000);
    assert(le(bytes,0)==0x46546C67u && le(bytes,4)==2);
    assert(le(bytes,8)==bytes.size());
    assert(le(bytes,16)==0x4E4F534Au);
    auto jsonLength=le(bytes,12);
    assert(jsonLength%4==0);
    auto binStart=20+jsonLength;
    assert(le(bytes,binStart+4)==0x004E4942u);
    assert(binStart+8+le(bytes,binStart)==bytes.size());
    std::string json(bytes.begin()+20,bytes.begin()+20+jsonLength);
    assert(json.find("\"TEXCOORD_0\":")!=std::string::npos);
    assert(json.find("\"pbrMetallicRoughness\"")!=std::string::npos);
    assert(json.find("\"byteStride\":32")!=std::string::npos);
    std::ofstream f("/tmp/zamer-1.1-test.glb",std::ios::binary);
    f.write(reinterpret_cast<const char*>(bytes.data()),std::streamsize(bytes.size()));
    assert(bool(f));
    std::cout<<"GLB EXPORT TEST OK: multiple objects, UVs, transforms and PBR materials\n";
}
