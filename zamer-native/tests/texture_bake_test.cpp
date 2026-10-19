#include "texture_bake.hpp"
#include <cassert>
#include <iostream>
using namespace zamer;
int main(){
    Object o; o.pattern=1;
    const auto a=bakePbrMaps(o,128);
    for(const auto&png:a){
        assert(png.size()>128*128*4);
        const uint8_t magic[8]={137,80,78,71,13,10,26,10};
        for(int i=0;i<8;i++)assert(png[size_t(i)]==magic[i]);
        assert(png[25]==6); // RGBA colour type
    }
    assert(a[0]!=a[1] && a[1]!=a[2]);
    o.pattern=2;
    assert(bakePbrMaps(o,128)[0]!=a[0]);
    assert(bakePbrMaps(o,4)[0].empty());
    std::cout<<"TEXTURE BAKE TEST OK: base color, tangent-space normal, packed metallic/roughness PNG\n";
}
