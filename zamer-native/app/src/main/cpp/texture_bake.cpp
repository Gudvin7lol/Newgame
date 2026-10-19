#include "texture_bake.hpp"
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>
namespace zamer {
namespace {
constexpr float kPi=3.14159265358979323846f;
float clamp01(float a){return std::clamp(a,0.f,1.f);}
uint8_t byte(float a){return uint8_t(std::round(clamp01(a)*255.f));}
struct Sample {
    float r=1.f,g=1.f,b=1.f,rough=1.f,height=0.f;
};
Sample shade(int pattern,float u,float v){
    Sample s;
    if(pattern==1){
        float warp=std::pow(0.5f+0.5f*std::cos(u*100.f),4.f);
        float weft=std::pow(0.5f+0.5f*std::cos(v*100.f),4.f);
        s.r=s.g=s.b=std::min(1.f,0.78f+0.17f*(warp+weft));
        s.rough=1.f+0.06f*(warp+weft);
        s.height=0.04f*(warp+weft);
    }else if(pattern==2){
        float grain=std::sin((u+0.04f*std::sin(v*9.f))*52.f+std::sin(v*2.7f)*3.f);
        float streak=0.5f+0.5f*grain;
        s.r=0.73f+0.25f*streak;
        s.g=0.75f+0.21f*streak;
        s.b=0.79f+0.15f*streak;
        s.height=0.018f*grain;
    }else if(pattern==3){
        float pores=std::sin(u*87.f)*std::sin(v*96.f);
        s.r=s.g=s.b=0.91f+0.065f*pores;
        s.rough=1.f+0.045f*pores;
        s.height=0.015f*pores;
    }else if(pattern==4){
        float brushed=0.5f+0.5f*std::sin(v*270.f);
        s.r=s.g=s.b=0.96f+0.04f*brushed;
        s.height=0.005f*std::sin(v*270.f);
    }
    return s;
}
void be32(std::vector<uint8_t>&out,uint32_t x){
    for(int i=3;i>=0;i--)out.push_back(uint8_t(x>>(8*i)));
}
uint32_t crc(const uint8_t*data,size_t n){
    uint32_t value=0xFFFFFFFFu;
    for(size_t i=0;i<n;i++){
        value^=data[i];
        for(int b=0;b<8;b++)value=(value>>1)^((value&1u)?0xEDB88320u:0u);
    }
    return value^0xFFFFFFFFu;
}
void chunk(std::vector<uint8_t>&png,const char kind[4],const std::vector<uint8_t>&body){
    be32(png,uint32_t(body.size()));
    size_t start=png.size();
    for(int i=0;i<4;i++)png.push_back(uint8_t(kind[i]));
    png.insert(png.end(),body.begin(),body.end());
    be32(png,crc(png.data()+start,png.size()-start));
}
std::vector<uint8_t> pngRGBA(const std::vector<uint8_t>&pixels,int w,int h){
    if(w<=0||h<=0||pixels.size()!=size_t(w)*size_t(h)*4u)return {};
    const uint8_t signature[8]={137,80,78,71,13,10,26,10};
    std::vector<uint8_t> png(signature,signature+8);
    std::vector<uint8_t> ihdr;
    be32(ihdr,uint32_t(w));be32(ihdr,uint32_t(h));
    ihdr.insert(ihdr.end(),{8,6,0,0,0}); // RGBA8, lossless
    chunk(png,"IHDR",ihdr);
    std::vector<uint8_t> raw;
    raw.reserve(size_t(h)*(size_t(w)*4+1));
    for(int y=0;y<h;y++){
        raw.push_back(0); // PNG filter "none"
        raw.insert(raw.end(),pixels.begin()+size_t(y)*size_t(w)*4,
                   pixels.begin()+size_t(y+1)*size_t(w)*4);
    }
    // Zlib/DEFLATE stored blocks avoid a heavy compression dependency.
    std::vector<uint8_t> z{0x78,0x01};
    size_t offset=0;
    while(offset<raw.size()){
        const size_t count=std::min<size_t>(65535,raw.size()-offset);
        z.push_back(offset+count==raw.size()?1:0);
        const uint16_t n=uint16_t(count);
        z.push_back(uint8_t(n));z.push_back(uint8_t(n>>8));
        const uint16_t complement=uint16_t(~n);
        z.push_back(uint8_t(complement));z.push_back(uint8_t(complement>>8));
        z.insert(z.end(),raw.begin()+std::ptrdiff_t(offset),raw.begin()+std::ptrdiff_t(offset+count));
        offset+=count;
    }
    uint32_t a=1,b=0;
    for(uint8_t c:raw){a=(a+c)%65521u;b=(b+a)%65521u;}
    be32(z,(b<<16)|a);
    chunk(png,"IDAT",z);
    chunk(png,"IEND",{});
    return png;
}
}
BakedMaps bakePbrMaps(const Object&o,int resolution){
    if(resolution<16||resolution>512 || o.pattern<0||o.pattern>4)return {};
    const size_t count=size_t(resolution)*size_t(resolution)*4;
    std::array<std::vector<uint8_t>,3> pixels;
    for(auto&v:pixels)v.resize(count);
    const float du=1.f/float(resolution);
    for(int y=0;y<resolution;y++){
        for(int x=0;x<resolution;x++){
            const float u=(float(x)+0.5f)*du,v=(float(y)+0.5f)*du;
            const Sample s=shade(o.pattern,u,v);
            const Sample ux=shade(o.pattern,u+du,v);
            const Sample vx=shade(o.pattern,u,v+du);
            // Bump strength is intentionally restrained for furniture materials.
            const float nx=(s.height-ux.height)*5.f,ny=(s.height-vx.height)*5.f;
            const float length=std::sqrt(nx*nx+ny*ny+1.f);
            const size_t j=(size_t(y)*size_t(resolution)+size_t(x))*4u;
            auto&color=pixels[0],&normal=pixels[1],&mr=pixels[2];
            color[j]=byte(s.r);color[j+1]=byte(s.g);color[j+2]=byte(s.b);color[j+3]=255;
            normal[j]=byte(0.5f+0.5f*nx/length);
            normal[j+1]=byte(0.5f+0.5f*ny/length);
            normal[j+2]=byte(0.5f+0.5f/length);normal[j+3]=255;
            mr[j]=255; // occlusion channel unused
            mr[j+1]=byte(std::min(1.f,s.rough));
            mr[j+2]=255; // material.metallicFactor controls absolute metalness
            mr[j+3]=255;
        }
    }
    BakedMaps baked;
    for(size_t i=0;i<3;i++)baked[i]=pngRGBA(pixels[i],resolution,resolution);
    return baked;
}
}
