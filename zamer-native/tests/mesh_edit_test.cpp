#include "mesh_core.hpp"
#include "mesh_edit.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace zamer;
int main(){
    Scene scene;scene.add(0);
    Object& o=scene.objects[0];
    auto edges=uniqueEdges(o.mesh);
    assert(edges.size()==12);
    assert(edgeExists(o.mesh,0,1));
    assert(!edgeExists(o.mesh,0,6));
    o.selectedVertex=0;
    const Vec3 old=o.mesh.vertices[0];
    scene.checkpoint();
    assert(scene.moveComponent(1,0,0.025f));
    const Vec3 moved=o.mesh.vertices[0];
    assert(std::fabs(moved.x-old.x-0.025f/o.scale.x)<0.00001f);
    assert(o.dirty);
    assert(scene.undo());
    assert(std::fabs(scene.objects[0].mesh.vertices[0].x-old.x)<0.00001f);
    // Component selection is deliberately ephemeral after restore/undo.
    Object& next=scene.objects[0];
    next.selectedEdgeA=0;next.selectedEdgeB=1;
    const Vec3 va=next.mesh.vertices[0],vb=next.mesh.vertices[1];
    assert(scene.moveComponent(2,1,0.010f));
    assert(std::fabs(next.mesh.vertices[0].y-va.y-0.010f/next.scale.y)<0.00001f);
    assert(std::fabs(next.mesh.vertices[1].y-vb.y-0.010f/next.scale.y)<0.00001f);
    assert(!scene.moveComponent(2,4,0.010f));
    assert(!scene.moveComponent(2,2,10.f));
    next.selectedEdgeB=-1;
    assert(!scene.moveComponent(2,2,0.01f));

    // Full closed quad loop around cuboid, preserving manifold and dimensions.
    Mesh loopMesh=Mesh::cube();
    const int oldFaceCount=int(loopMesh.faces.size());
    const int midpoint=loopCut(loopMesh,0,1);
    assert(midpoint>=8);
    assert(loopMesh.faces.size()==size_t(oldFaceCount+4));
    assert(loopMesh.vertices.size()==12);
    assert(loopMesh.valid()&&loopMesh.isClosed());
    const auto savedFaces=loopMesh.faces;
    assert(loopCut(loopMesh,-1,100)==-1);
    assert(loopMesh.faces==savedFaces); // failing tools never mutate source
    Mesh splitMesh=Mesh::cube();
    const int splitMid=splitEdge(splitMesh,0,1);
    assert(splitMid==8 && splitMesh.isClosed());
    assert(splitMesh.faces.size()==6 && splitMesh.vertices.size()==9);
    // Loop cut cannot pass through an ngon left by an isolated edge split.
    assert(loopCut(splitMesh,0,splitMid)==-1);
    assert(splitMesh.isClosed());
    Scene cutting;cutting.add(0);
    cutting.objects[0].selectedEdgeA=0;cutting.objects[0].selectedEdgeB=1;
    cutting.checkpoint();
    assert(cutting.loopCutSelectedEdge());
    assert(cutting.objects[0].mesh.isClosed());
    assert(cutting.undo());
    assert(cutting.objects[0].mesh.faces.size()==6);
    cutting.objects[0].selectedEdgeA=0;cutting.objects[0].selectedEdgeB=1;
    assert(cutting.splitSelectedEdge());
    assert(cutting.objects[0].mesh.isClosed());
    std::cout<<"MESH EDIT TESTS OK: shared edges, precision vertex/edge moves, undo\n";
}
