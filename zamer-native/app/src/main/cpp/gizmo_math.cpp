#include "gizmo_math.hpp"
#include <algorithm>
#include <limits>
namespace zamer {
int pickGizmoAxis(Vec3 rayOrigin,Vec3 rayDirection,Vec3 center,float length,float radius){
    if(rayDirection.length()<0.00001f || length<0.001f || radius<=0.f)return -1;
    rayDirection=rayDirection.normalized();
    int selected=-1;
    float nearest=radius;
    const Vec3 axes[3]={{1,0,0},{0,1,0},{0,0,1}};
    for(int axis=0;axis<3;axis++){
        const Vec3 direction=axes[axis];
        for(int i=0;i<=24;i++){
            float t=length*(0.27f+0.73f*float(i)/24.f);
            Vec3 point=center+direction*t;
            float along=dot(point-rayOrigin,rayDirection);
            if(along<=0.f)continue;
            float distance=(point-rayOrigin-rayDirection*along).length();
            if(distance<nearest){
                nearest=distance;
                selected=axis;
            }
        }
    }
    return selected;
}
}
