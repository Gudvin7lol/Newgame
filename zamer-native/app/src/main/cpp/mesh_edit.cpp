#include "mesh_edit.hpp"
#include <algorithm>
#include <set>
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
}
