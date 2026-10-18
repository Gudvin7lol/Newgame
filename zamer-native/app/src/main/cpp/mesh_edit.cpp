#include "mesh_edit.hpp"
#include <algorithm>
#include <set>
#include <map>
#include <array>
namespace zamer {
std::vector<Edge> uniqueEdges(const Mesh& mesh){
    std::set<Edge> edges;
    for(const auto&face:mesh.faces){
        for(size_t i=0;i<face.size();i++){
            const int a=face[i],b=face[(i+1)%face.size()];
            if(a!=b)edges.emplace(std::min(a,b),std::max(a,b));
        }
    }
    return {edges.begin(),edges.end()};
}
bool edgeExists(const Mesh& mesh,int a,int b){
    if(a==b||a<0||b<0||size_t(a)>=mesh.vertices.size()||size_t(b)>=mesh.vertices.size())return false;
    for(const auto&face:mesh.faces){
        for(size_t i=0;i<face.size();i++){
            if((face[i]==a && face[(i+1)%face.size()]==b) ||
               (face[i]==b && face[(i+1)%face.size()]==a))return true;
        }
    }
    return false;
}

namespace {
Edge canonical(int a,int b){return {std::min(a,b),std::max(a,b)};}
bool containsEdge(const std::vector<int>&face,int a,int b,int*edgeIndex=nullptr){
    for(size_t i=0;i<face.size();++i){
        if((face[i]==a&&face[(i+1)%face.size()]==b)||
           (face[i]==b&&face[(i+1)%face.size()]==a)){
            if(edgeIndex)*edgeIndex=int(i);
            return true;
        }
    }
    return false;
}
}
int splitEdge(Mesh& mesh,int a,int b,float fraction){
    if(!mesh.valid()||!mesh.isClosed()||!edgeExists(mesh,a,b)||
       !std::isfinite(fraction)||fraction<=0.f||fraction>=1.f||
       mesh.vertices.size()>=200000)return -1;
    Mesh out=mesh;
    int mid=int(out.vertices.size());
    out.vertices.push_back(mesh.vertices[size_t(a)]*(1.f-fraction)+mesh.vertices[size_t(b)]*fraction);
    bool found=false;
    for(auto&face:out.faces){
        for(size_t i=0;i<face.size();++i){
            if((face[i]==a&&face[(i+1)%face.size()]==b)||
               (face[i]==b&&face[(i+1)%face.size()]==a)){
                if(face.size()>=128)return -1;
                face.insert(face.begin()+int(i)+1,mid);
                found=true;
                break;
            }
        }
    }
    if(!found||!out.valid()||!out.isClosed())return -1;
    mesh=std::move(out);
    return mid;
}
int loopCut(Mesh& mesh,int a,int b){
    if(!mesh.valid()||!mesh.isClosed()||!edgeExists(mesh,a,b)||
       mesh.vertices.size()>=199000||mesh.faces.size()>=99000)return -1;
    std::map<Edge,std::vector<int>> incidence;
    for(size_t fi=0;fi<mesh.faces.size();fi++){
        const auto&face=mesh.faces[fi];
        for(size_t i=0;i<face.size();i++){
            incidence[canonical(face[i],face[(i+1)%face.size()])].push_back(int(fi));
        }
    }
    const Edge seed=canonical(a,b);
    if(incidence[seed].size()!=2)return -1;
    std::map<int,int> entryAtFace;
    std::map<Edge,int> midpoints;
    std::vector<Vec3> generated;
    auto midpoint=[&](Edge e)->int{
        auto it=midpoints.find(e);
        if(it!=midpoints.end())return it->second;
        const int index=int(mesh.vertices.size()+generated.size());
        generated.push_back((mesh.vertices[size_t(e.first)]+mesh.vertices[size_t(e.second)])*0.5f);
        midpoints.emplace(e,index);
        return index;
    };
    const int start=incidence[seed][0];
    int current=start;
    Edge entry=seed;
    bool closed=false;
    while(entryAtFace.size()<=mesh.faces.size()){
        if(entryAtFace.find(current)!=entryAtFace.end()){
            closed=(current==start && entry==seed);
            break;
        }
        const auto&face=mesh.faces[size_t(current)];
        if(face.size()!=4)return -1; // only closed all-quad strips for now
        int i=-1;
        if(!containsEdge(face,entry.first,entry.second,&i))return -1;
        entryAtFace[current]=i;
        midpoint(entry);
        const Edge opposite=canonical(face[size_t((i+2)%4)],face[size_t((i+3)%4)]);
        midpoint(opposite);
        const auto it=incidence.find(opposite);
        if(it==incidence.end()||it->second.size()!=2)return -1;
        const auto&neighbors=it->second;
        const int next=neighbors[0]==current?neighbors[1]:neighbors[0];
        if(next==current)return -1;
        current=next;
        entry=opposite;
    }
    if(!closed||entryAtFace.size()<3)return -1;
    Mesh out=mesh;
    out.vertices.insert(out.vertices.end(),generated.begin(),generated.end());
    out.faces.clear();
    out.faces.reserve(mesh.faces.size()+entryAtFace.size());
    for(size_t fi=0;fi<mesh.faces.size();fi++){
        const auto&face=mesh.faces[fi];
        const auto found=entryAtFace.find(int(fi));
        if(found==entryAtFace.end()){out.faces.push_back(face);continue;}
        const int i=found->second;
        const int cur=midpoints.at(canonical(face[size_t(i)],face[size_t((i+1)%4)]));
        const int opp=midpoints.at(canonical(face[size_t((i+2)%4)],face[size_t((i+3)%4)]));
        out.faces.push_back({face[size_t((i+1)%4)],face[size_t((i+2)%4)],opp,cur});
        out.faces.push_back({face[size_t((i+3)%4)],face[size_t(i)],cur,opp});
    }
    if(!out.valid()||!out.isClosed())return -1;
    mesh=std::move(out);
    return midpoints.at(seed);
}

}
