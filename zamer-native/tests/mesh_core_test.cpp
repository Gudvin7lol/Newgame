#include "mesh_core.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace zamer;
int main(){
    Mesh cube=Mesh::cube();
    assert(cube.valid()&&cube.isClosed());
    assert(cube.vertices.size()==8 && cube.faces.size()==6);
    assert(cube.extrude(2,0.05f,0.12f));
    assert(cube.isClosed());
    assert(cube.faces.size()==14); // remove 1, append 4 + 4 + 1
    assert(cube.extrude(int(cube.faces.size())-1,0.08f,0.0f));
    assert(cube.isClosed());
    cube.subdivide();
    assert(cube.isClosed() && cube.faces.size()>50);
    assert(cube.moveVertex(0,{0.01f,0,0}));
    assert(!cube.interleavedTriangles().empty());

    Mesh sphere=Mesh::sphere(),cylinder=Mesh::cylinder();
    assert(sphere.valid()&&sphere.isClosed());
    assert(cylinder.valid()&&cylinder.isClosed());

    Scene scene;
    scene.add(0);
    assert(scene.extrude(0.05f));
    scene.subdivide();
    scene.move(0.10f,0.03f);
    scene.add(1);
    scene.add(2);
    const std::string saved=scene.serialize();
    Scene restore;
    assert(restore.restore(saved));
    assert(restore.objects.size()==3);
    assert(restore.objects[0].mesh.isClosed());
    assert(restore.serialize()==saved);
    assert(!restore.restore("garbage"));
    std::cout<<"NATIVE CORE TESTS OK: watertight topology, face extrude, subdivision, serialize/restore\n";
    return 0;
}
