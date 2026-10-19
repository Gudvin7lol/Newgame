#include "mesh_edit.hpp"
#include <algorithm>
#include <set>
#include <map>
#include <array>
#include <limits>
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


int bevelConvexEdge(Mesh&mesh,int a,int b,float width,int segments){
    if(!mesh.valid()||!mesh.isClosed()||!edgeExists(mesh,a,b)||
       !std::isfinite(width)||width<=0.00001f||width>0.4f||segments<1||segments>8||
       mesh.vertices.size()>190000||mesh.faces.size()>190000)return -1;
    std::vector<int> adjacent;
    for(size_t i=0;i<mesh.faces.size();++i){
        if(containsEdge(mesh.faces[i],a,b))adjacent.push_back(int(i));
    }
    if(adjacent.size()!=2)return -1;
    const Vec3 n1=mesh.faceNormal(adjacent[0]),n2=mesh.faceNormal(adjacent[1]);
    const Vec3 n=(n1+n2).normalized();
    if(n.length()<0.5f||dot(n1,n2)>0.985f)return -1;
    const float peak=dot(n,mesh.vertices[size_t(a)]);
    if(std::fabs(peak-dot(n,mesh.vertices[size_t(b)]))>0.0002f)return -1;
    const float limit=peak-width;
    // A local convex chamfer must not cut another unrelated vertex.
    for(size_t i=0;i<mesh.vertices.size();i++){
        if(int(i)==a||int(i)==b)continue;
        const float v=dot(n,mesh.vertices[i]);
        if(v>limit-0.00001f)return -1;
    }
    Mesh out=mesh;
    std::map<Edge,int> intersections;
    std::vector<int>cutVertices;
    std::vector<std::vector<int>>clipped;
    for(const auto&face:mesh.faces){
        std::vector<int>ring;
        ring.reserve(face.size()+2);
        for(size_t k=0;k<face.size();k++){
            int i=face[k],j=face[(k+1)%face.size()];
            float di=dot(n,mesh.vertices[size_t(i)])-limit;
            float dj=dot(n,mesh.vertices[size_t(j)])-limit;
            bool inI=di<=0.f,inJ=dj<=0.f;
            if(inI)ring.push_back(i);
            if(inI!=inJ){
                Edge key=canonical(i,j);
                auto it=intersections.find(key);
                int index;
                if(it==intersections.end()){
                    if(out.vertices.size()>=199999)return -1;
                    float fraction=di/(di-dj);
                    const Vec3 p=mesh.vertices[size_t(i)]*(1.f-fraction)+mesh.vertices[size_t(j)]*fraction;
                    index=int(out.vertices.size());
                    out.vertices.push_back(p);
                    cutVertices.push_back(index);
                    intersections.emplace(key,index);
                }else index=it->second;
                ring.push_back(index);
            }
        }
        ring.erase(std::unique(ring.begin(),ring.end()),ring.end());
        if(ring.size()>1 && ring.front()==ring.back())ring.pop_back();
        if(ring.size()>=3 && ring.size()<=128)clipped.push_back(std::move(ring));
        else if(ring.size()>128)return -1;
    }
    if(cutVertices.size()<3 || cutVertices.size()>128)return -1;
    Vec3 center{};
    for(int id:cutVertices)center+=out.vertices[size_t(id)];
    center=center/float(cutVertices.size());
    Vec3 helper=std::fabs(n.y)<0.9f?Vec3{0,1,0}:Vec3{1,0,0};
    const Vec3 u=cross(helper,n).normalized(),v=cross(n,u);
    std::sort(cutVertices.begin(),cutVertices.end(),[&](int l,int r){
        Vec3 pl=out.vertices[size_t(l)]-center,pr=out.vertices[size_t(r)]-center;
        return std::atan2(dot(pl,v),dot(pl,u))<std::atan2(dot(pr,v),dot(pr,u));
    });
    const int capIndex=int(clipped.size());
    if(segments==1){
        clipped.push_back(cutVertices);
    }else{
        // A rounded convex edge is a strip replacing the chamfer's planar
        // quadrilateral. Its boundary uses the same shared vertices as the
        // adjacent clipped faces so no cracks are introduced.
        if(cutVertices.size()!=4 || out.vertices.size()+size_t(2*(segments-1))>=200000)return -1;
        const Vec3 edgeDir=(mesh.vertices[size_t(b)]-mesh.vertices[size_t(a)]).normalized();
        int first=-1;
        float bestParallel=0.96f;
        for(int i=0;i<4;i++){
            Vec3 d=out.vertices[size_t(cutVertices[size_t((i+1)%4)])]-
                   out.vertices[size_t(cutVertices[size_t(i)])];
            float parallel=std::fabs(dot(d.normalized(),edgeDir));
            if(parallel>bestParallel){bestParallel=parallel;first=i;}
        }
        if(first<0)return -1;
        const int v0=cutVertices[size_t(first)];
        const int v1=cutVertices[size_t((first+1)%4)];
        const int v2=cutVertices[size_t((first+2)%4)];
        const int v3=cutVertices[size_t((first+3)%4)];
        int prevLeft=v0,prevRight=v1;
        constexpr float kPi=3.14159265358979323846f;
        for(int step=1;step<=segments;step++){
            int nextLeft=v3,nextRight=v2;
            if(step<segments){
                const float t=float(step)/float(segments);
                // Chord-to-arc approximation at a right-angle bevel. The
                // chamfer boundary is preserved; extra vertices form the arc.
                const Vec3 offset=n*(width*0.41421356f*std::sin(kPi*t));
                nextLeft=int(out.vertices.size());
                out.vertices.push_back(out.vertices[size_t(v0)]*(1.f-t)+out.vertices[size_t(v3)]*t+offset);
                nextRight=int(out.vertices.size());
                out.vertices.push_back(out.vertices[size_t(v1)]*(1.f-t)+out.vertices[size_t(v2)]*t+offset);
            }
            clipped.push_back({prevLeft,prevRight,nextRight,nextLeft});
            prevLeft=nextLeft;prevRight=nextRight;
        }
    }
    out.faces=std::move(clipped);
    if(!out.valid()||!out.isClosed())return -1;
    mesh=std::move(out);
    return capIndex;
}
bool bridgeOppositeQuads(Mesh&mesh,int f1,int f2,float insetFraction){
    if(!mesh.valid()||!mesh.isClosed()||f1==f2||f1<0||f2<0||
       size_t(f1)>=mesh.faces.size()||size_t(f2)>=mesh.faces.size()||
       mesh.faces[size_t(f1)].size()!=4||mesh.faces[size_t(f2)].size()!=4||
       !std::isfinite(insetFraction)||insetFraction<0.05f||insetFraction>0.45f||
       mesh.vertices.size()>199990||mesh.faces.size()>199985)return false;
    const auto&faceA=mesh.faces[size_t(f1)];
    const auto&faceB=mesh.faces[size_t(f2)];
    if(dot(mesh.faceNormal(f1),mesh.faceNormal(f2))>-0.8f)return false;
    for(int i:faceA)for(int j:faceB)if(i==j)return false;
    Mesh out=mesh;
    const int before=int(out.vertices.size());
    std::array<int,4>a{},b{};
    for(int side=0;side<2;side++){
        const auto&face=side==0?faceA:faceB;
        Vec3 centroid{};
        for(int i:face)centroid+=mesh.vertices[size_t(i)];
        centroid=centroid/4.f;
        for(int i=0;i<4;i++){
            const Vec3 p=mesh.vertices[size_t(face[size_t(i)])];
            int v=int(out.vertices.size());
            out.vertices.push_back(p*(1.f-insetFraction)+centroid*insetFraction);
            if(side==0)a[size_t(i)]=v;else b[size_t(i)]=v;
        }
    }
    int offset=0;
    float minCost=std::numeric_limits<float>::infinity();
    for(int shift=0;shift<4;shift++){
        float cost=0.f;
        for(int i=0;i<4;i++){
            const Vec3 delta=out.vertices[size_t(a[size_t(i)])]-
                out.vertices[size_t(b[size_t((shift-i+4)%4)])];
            cost+=dot(delta,delta);
        }
        if(cost<minCost){minCost=cost;offset=shift;}
    }
    out.faces.clear();
    out.faces.reserve(mesh.faces.size()+14);
    for(size_t i=0;i<mesh.faces.size();i++){
        if(int(i)!=f1&&int(i)!=f2)out.faces.push_back(mesh.faces[i]);
    }
    for(int side=0;side<2;side++){
        const auto&face=side==0?faceA:faceB;
        const auto&ring=side==0?a:b;
        for(int i=0;i<4;i++){
            int j=(i+1)%4;
            out.faces.push_back({face[size_t(i)],face[size_t(j)],ring[size_t(j)],ring[size_t(i)]});
        }
    }
    for(int i=0;i<4;i++){
        int j=(i+1)%4;
        int bi=(offset-i+4)%4,bj=(offset-j+4)%4;
        out.faces.push_back({a[size_t(i)],a[size_t(j)],b[size_t(bj)],b[size_t(bi)]});
    }
    if(!out.valid()||!out.isClosed() || int(out.vertices.size())!=before+8)return false;
    mesh=std::move(out);
    return true;
}

}
