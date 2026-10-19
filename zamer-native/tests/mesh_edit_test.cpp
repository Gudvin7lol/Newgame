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

    Mesh chamfer=Mesh::cube();
    const int bevelFace=bevelConvexEdge(chamfer,0,1,0.055f);
    assert(bevelFace>=0&&chamfer.isClosed()&&chamfer.valid());
    assert(chamfer.faces.size()==7);
    assert(chamfer.vertices.size()>=12);
    const std::string beforeBadBevel=std::to_string(chamfer.faces.size());
    assert(bevelConvexEdge(chamfer,0,1,-0.01f)==-1);
    assert(std::to_string(chamfer.faces.size())==beforeBadBevel);
    for(int segments=2;segments<=8;segments++){
        Mesh smooth=Mesh::cube();
        const int newFace=bevelConvexEdge(smooth,0,1,0.06f,segments);
        assert(newFace>=0);
        assert(smooth.isClosed()&&smooth.valid());
        assert(smooth.faces.size()==size_t(6+segments));
        assert(smooth.vertices.size()==size_t(12+2*(segments-1)));
    }
    Mesh badSegment=Mesh::cube();
    const auto beforeBad=badSegment.faces;
    assert(bevelConvexEdge(badSegment,0,1,0.06f,0)==-1);
    assert(bevelConvexEdge(badSegment,0,1,0.06f,9)==-1);
    assert(badSegment.faces==beforeBad);
    Mesh tunnel=Mesh::cube();
    assert(bridgeOppositeQuads(tunnel,2,3,0.20f));
    assert(tunnel.valid()&&tunnel.isClosed());
    assert(tunnel.vertices.size()==16&&tunnel.faces.size()==16);
    Mesh wrong=Mesh::cube();
    assert(!bridgeOppositeQuads(wrong,0,2,0.2f));
    assert(wrong.vertices.size()==8&&wrong.faces.size()==6);
    Scene operation;operation.add(0);
    operation.objects[0].selectedEdgeA=0;operation.objects[0].selectedEdgeB=1;
    operation.checkpoint();
    assert(operation.bevelSelectedEdge(0.025f));
    assert(operation.objects[0].mesh.isClosed());
    assert(operation.undo()&&operation.objects[0].mesh.faces.size()==6);
    assert(operation.bridgeSelectedFaces(2,3));
    assert(operation.objects[0].mesh.isClosed());
    assert(operation.objects[0].mesh.valid());
    std::cout<<"MESH EDIT TESTS OK: shared edges, precision vertex/edge moves, undo\n";
}
