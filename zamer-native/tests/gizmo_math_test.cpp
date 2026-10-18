#include "gizmo_math.hpp"
#include <cassert>
#include <iostream>
using namespace zamer;
int main(){
    Vec3 eye={0.f,1.f,5.f},origin={0.f,1.f,0.f};
    assert(pickGizmoAxis(eye,(Vec3{0.8f,1.f,0.f}-eye),origin,1.f,0.05f)==0);
    assert(pickGizmoAxis(eye,(Vec3{0.f,1.8f,0.f}-eye),origin,1.f,0.05f)==1);
    assert(pickGizmoAxis(eye,(Vec3{0.f,1.f,0.8f}-eye),origin,1.f,0.05f)==2);
    assert(pickGizmoAxis(eye,(Vec3{-4.f,1.f,0.f}-eye),origin,1.f,0.05f)==-1);
    assert(pickGizmoAxis(eye,{0,0,0},origin,1.f,0.05f)==-1);
    std::cout<<"GIZMO HIT TESTS OK\n";
}
