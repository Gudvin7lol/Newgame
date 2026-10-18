#include "scene_picker.hpp"
#include <cassert>
#include <iostream>
using namespace zamer;
int main(){
    Scene scene;
    assert(pickObject(scene,{0,1,4},{0,-0.2f,-1})==-1);
    scene.add(0);
    assert(pickObject(scene,{0,0.85f,4},{0,0,-1})==0);
    assert(pickObject(scene,{5,5,4},{0,0,-1})==-1);
    scene.add(1);
    // Last-added sphere may overlap the front ray, but nearest object must be selected.
    auto surface=pickSurface(scene,{0,0.85f,4},{0,0,-1});
    assert(surface.object>=0 && surface.face>=0);
    assert(scene.objects[size_t(surface.object)].mesh.faces.size()>size_t(surface.face));
    assert(pickSurface(scene,{5,5,4},{0,0,-1}).face==-1);
    const int picked=pickObject(scene,{0,0.85f,4},{0,0,-1});
    assert(picked>=0 && picked<2);
    assert(pickObject(scene,{0,0.85f,4},{0,0,0})==-1);
    std::cout<<"PICK TESTS OK: no-hit, mesh hit, offscreen, overlapping objects\n";
}
