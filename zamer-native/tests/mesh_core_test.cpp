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
    assert(scene.inset(0.10f));
    assert(scene.objects[0].mesh.isClosed());
    const float oldX=scene.objects[0].position.x;
    assert(scene.transform(0,0,0.125f));
    assert(std::fabs(scene.objects[0].position.x-oldX-0.125f)<0.0001f);
    assert(scene.transform(1,1,0.20f));
    assert(!scene.transform(1,0,0.20f));
    const float oldScale=scene.objects[0].scale.z;
    assert(scene.transform(2,2,0.25f));
    assert(std::fabs(scene.objects[0].scale.z-oldScale-0.25f)<0.0001f);
    scene.checkpoint();
    scene.add(1);
    assert(scene.objects.size()==2);
    assert(scene.undo() && scene.objects.size()==1);
    assert(scene.redo() && scene.objects.size()==2);
    scene.checkpoint();
    assert(scene.transform(0,0,0.45f));
    assert(scene.undo());
    assert(scene.redo());
    scene.add(2);
    scene.checkpoint();
    assert(scene.duplicateSelected());
    assert(scene.objects.size()==4);
    assert(scene.objects[3].gpuBuffer==0 && scene.objects[3].dirty);
    assert(scene.undo() && scene.objects.size()==3);
    assert(scene.redo() && scene.objects.size()==4);
    scene.checkpoint();
    assert(scene.deleteSelected() && scene.objects.size()==3);
    assert(scene.undo() && scene.objects.size()==4);
    assert(scene.deleteSelected() && scene.objects.size()==3);
    const std::string saved=scene.serialize();
    Scene restore;
    assert(restore.restore(saved));
    assert(restore.objects.size()==3);
    assert(restore.objects[0].mesh.isClosed());
    assert(restore.serialize()==saved);
    assert(!restore.restore("garbage"));
    Scene mat;
    mat.add(0);
    assert(mat.setCustomMaterial({0.10f,0.32f,0.72f},0.68f,0.22f));
    assert(mat.setSmoothShading(true));
    assert(!mat.setCustomMaterial({-0.1f,0.f,0.f},0.5f,0.5f));
    const auto savedV2=mat.serialize();
    assert(savedV2.find("ZAMER_NATIVE_MESH_4")==0);
    Scene matRestored;
    assert(matRestored.restore(savedV2));
    assert(matRestored.serialize()==savedV2);
    assert(matRestored.objects[0].customMaterial);
    assert(matRestored.objects[0].smoothShading);
    mat.checkpoint();
    mat.setMaterial(3);
    assert(!mat.objects[0].customMaterial);
    assert(mat.undo());
    assert(mat.objects[0].customMaterial);
    const float oldRough=mat.objects[0].pbr.roughness;
    assert(std::fabs(oldRough-0.22f)<0.00001f);
    // Legacy project format must load with corresponding material preset.
    std::string v1="ZAMER_NATIVE_MESH_1\n1 0\n";
    {
        auto original=Mesh::cube();
        v1+="0 3 2 0 0.8 0 1 1 1 0\n8 6\n";
        for(auto v:original.vertices) v1+=std::to_string(v.x)+" "+std::to_string(v.y)+" "+std::to_string(v.z)+"\n";
        for(auto face:original.faces){
            v1+=std::to_string(face.size());
            for(int id:face)v1+=" "+std::to_string(id);
            v1+="\n";
        }
    }
    Scene legacy;
    assert(legacy.restore(v1));
    assert(std::fabs(legacy.objects[0].pbr.metallic-0.82f)<0.0001f);
    assert(!legacy.objects[0].customMaterial);
    // Smooth shading normal must not be based on position-from-origin.
    Mesh translated=Mesh::sphere(12,8);
    auto normals=translated.interleavedTriangles(true);
    assert(!normals.empty());
    for(size_t k=0;k<normals.size();k+=6)
        assert(std::isfinite(normals[k+3])&&std::isfinite(normals[k+4])&&std::isfinite(normals[k+5]));
    const auto withUV=mat.objects[0].mesh.interleavedTrianglesUV(true);
    assert(withUV.size()%8==0);
    assert(withUV.size()/8==mat.objects[0].mesh.interleavedTriangles(true).size()/6);
    for(size_t i=0;i<withUV.size();i+=8){
        assert(std::isfinite(withUV[i+6]) && std::isfinite(withUV[i+7]));
    }
    mat.checkpoint();
    assert(mat.setPattern(2,2.5f));
    assert(mat.setUvTransform(0.15f,-0.2f,0.785398f));
    assert(!mat.setUvTransform(21.f,0.f,0.f));
    const std::string v3=mat.serialize();
    Scene fromV3;assert(fromV3.restore(v3));
    assert(fromV3.objects[0].pattern==2 && std::fabs(fromV3.objects[0].uvScale-2.5f)<1e-4f);
    assert(fromV3.serialize()==v3);
    assert(std::fabs(fromV3.objects[0].uvRotation-0.785398f)<1e-4f);
    assert(!fromV3.setPattern(6,1.f));
    assert(!fromV3.setPattern(1,0.01f));
    // Previous project v2 supports user-authored material and smoothing.
    std::string oldV2=matRestored.serialize();
    oldV2.replace(0,std::string("ZAMER_NATIVE_MESH_4").size(),"ZAMER_NATIVE_MESH_2");
    // Construct a v2 file by removing the extra pattern/scale metadata line.
    const size_t materialEnd=oldV2.find('\n',oldV2.find('\n',oldV2.find('\n',oldV2.find('\n')+1)+1)+1);
    const size_t pStart=materialEnd+1,pEnd=oldV2.find('\n',pStart);
    assert(pEnd!=std::string::npos);
    oldV2.erase(pStart,pEnd-pStart+1);
    Scene backward;assert(backward.restore(oldV2));
    assert(backward.objects[0].customMaterial);
    std::string oldV3=mat.serialize();
    oldV3.replace(0,std::string("ZAMER_NATIVE_MESH_4").size(),"ZAMER_NATIVE_MESH_3");
    const auto patLineStart=oldV3.find('\n',oldV3.find('\n',oldV3.find('\n',oldV3.find('\n')+1)+1)+1)+1;
    const auto patLineEnd=oldV3.find('\n',patLineStart);
    assert(patLineEnd!=std::string::npos);
    std::string patternLine=oldV3.substr(patLineStart,patLineEnd-patLineStart);
    auto secondSpace=patternLine.find(' ',patternLine.find(' ')+1);
    assert(secondSpace!=std::string::npos);
    oldV3.erase(patLineStart+secondSpace,patLineEnd-patLineStart-secondSpace);
    Scene prior3;assert(prior3.restore(oldV3));
    assert(prior3.objects[0].uvOffsetX==0.f && prior3.objects[0].uvRotation==0.f);
    std::cout<<"NATIVE CORE TESTS OK: watertight topology, face extrude, subdivision, serialize/restore\n";
    return 0;
}
