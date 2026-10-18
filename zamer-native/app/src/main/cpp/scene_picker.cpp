#include "scene_picker.hpp"
#include <algorithm>
#include <cmath>
#include <limits>
namespace zamer {
namespace {
Vec3 toWorld(Vec3 p,const Object& o) {
    const float c=std::cos(o.yaw),s=std::sin(o.yaw);
    const float x=p.x*o.scale.x,z=p.z*o.scale.z;
    return {o.position.x+c*x+s*z,o.position.y+p.y*o.scale.y,o.position.z-s*x+c*z};
}
float rayTriangle(Vec3 ro,Vec3 rd,Vec3 a,Vec3 b,Vec3 c) {
    const Vec3 e1=b-a,e2=c-a;
    const Vec3 p=cross(rd,e2);
    const float det=dot(e1,p);
    if(std::fabs(det)<1e-7f)return std::numeric_limits<float>::infinity();
    const float inv=1.f/det;
    const Vec3 t=ro-a;
    const float u=dot(t,p)*inv;
    if(u<0.f||u>1.f)return std::numeric_limits<float>::infinity();
    const Vec3 q=cross(t,e1);
    const float v=dot(rd,q)*inv;
    if(v<0.f||u+v>1.f)return std::numeric_limits<float>::infinity();
    const float distance=dot(e2,q)*inv;
    return distance>0.0001f?distance:std::numeric_limits<float>::infinity();
}
}
int pickObject(const Scene& scene,Vec3 origin,Vec3 direction) {
    if(direction.length()<1e-6f)return -1;
    direction=direction.normalized();
    float nearest=std::numeric_limits<float>::infinity();
    int found=-1;
    for(size_t objIndex=0;objIndex<scene.objects.size();objIndex++){
        const Object&obj=scene.objects[objIndex];
        for(const auto&face:obj.mesh.faces) {
            if(face.size()<3)continue;
            const Vec3 a=toWorld(obj.mesh.vertices[size_t(face[0])],obj);
            for(size_t i=1;i+1<face.size();i++){
                float distance=rayTriangle(origin,direction,a,
                    toWorld(obj.mesh.vertices[size_t(face[i])],obj),
                    toWorld(obj.mesh.vertices[size_t(face[i+1])],obj));
                if(distance<nearest){nearest=distance;found=int(objIndex);}
            }
        }
    }
    return found;
}
