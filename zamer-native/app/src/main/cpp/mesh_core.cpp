#include "mesh_core.hpp"
#include "mesh_edit.hpp"
#include <algorithm>
#include <iomanip>
#include <limits>
#include <map>
#include <sstream>
#include <unordered_map>

namespace zamer {
float dot(Vec3 a,Vec3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
Vec3 cross(Vec3 a,Vec3 b) {
    return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};
}
Mesh Mesh::cube() {
    Mesh m;
    m.vertices={
        {-0.5f,-0.5f,-0.5f},{0.5f,-0.5f,-0.5f},{0.5f,0.5f,-0.5f},{-0.5f,0.5f,-0.5f},
        {-0.5f,-0.5f,0.5f},{0.5f,-0.5f,0.5f},{0.5f,0.5f,0.5f},{-0.5f,0.5f,0.5f}
    };
    m.faces={{1,2,6,5},{0,4,7,3},{3,7,6,2},{0,1,5,4},{4,5,6,7},{0,3,2,1}};
    return m;
}
Mesh Mesh::sphere(int segments,int rings){
    Mesh m;
    segments=std::clamp(segments,6,96);
    rings=std::clamp(rings,4,48);
    constexpr float PI=3.14159265358979323846f;
    m.vertices.push_back({0,0.5f,0});
    for(int j=1;j<rings;j++){
        float t=PI*float(j)/float(rings);
        for(int i=0;i<segments;i++){
            float p=2.f*PI*float(i)/float(segments);
            m.vertices.push_back({0.5f*std::sin(t)*std::cos(p),0.5f*std::cos(t),0.5f*std::sin(t)*std::sin(p)});
        }
    }
    int bottom=int(m.vertices.size());
    m.vertices.push_back({0,-0.5f,0});
    for(int i=0;i<segments;i++){
        int next=(i+1)%segments;
        m.faces.push_back({0,1+i,1+next});
        for(int j=0;j<rings-2;j++){
            int a=1+j*segments+i,b=1+j*segments+next;
            m.faces.push_back({a,a+segments,b+segments,b});
        }
        int last=1+(rings-2)*segments;
        m.faces.push_back({bottom,last+next,last+i});
    }
    // The generated order depends on latitude traversal, correct each face's winding.
    for(auto &face:m.faces){
        Vec3 n=cross(m.vertices[face[1]]-m.vertices[face[0]],m.vertices[face[2]]-m.vertices[face[0]]);
        Vec3 centre{};
        for(int idx:face)centre+=m.vertices[idx];
        if(dot(n,centre)<0.f)std::reverse(face.begin(),face.end());
    }
    return m;
}
Mesh Mesh::cylinder(int segments){
    Mesh m;
    constexpr float PI=3.14159265358979323846f;
    segments=std::clamp(segments,8,96);
    for(int i=0;i<segments;i++){
        float p=2.f*PI*float(i)/float(segments);
        m.vertices.push_back({0.5f*std::cos(p),-0.5f,0.5f*std::sin(p)});
        m.vertices.push_back({0.5f*std::cos(p),0.5f,0.5f*std::sin(p)});
    }
    int bottom=int(m.vertices.size());m.vertices.push_back({0,-0.5f,0});
    int top=int(m.vertices.size());m.vertices.push_back({0,0.5f,0});
    for(int i=0;i<segments;i++){
        int j=(i+1)%segments;
        m.faces.push_back({2*i,2*i+1,2*j+1,2*j});
        m.faces.push_back({top,2*j+1,2*i+1});
        m.faces.push_back({bottom,2*i,2*j});
    }
    for(auto &face:m.faces){
        Vec3 n=cross(m.vertices[face[1]]-m.vertices[face[0]],m.vertices[face[2]]-m.vertices[face[0]]);
        Vec3 centre{};
        for(int idx:face)centre+=m.vertices[idx];
        centre=centre/float(face.size());
        if(face.size()==4){centre.y=0;}
        if(dot(n,centre)<0.f)std::reverse(face.begin(),face.end());
    }
    return m;
}
Vec3 Mesh::faceNormal(int f) const{
    if(f<0 || size_t(f)>=faces.size() || faces[f].size()<3)return {0,1,0};
    const auto &face=faces[f];
    Vec3 base=vertices[face[0]],n{};
    for(size_t j=1;j+1<face.size();j++)n+=cross(vertices[face[j]]-base,vertices[face[j+1]]-base);
    return n.normalized();
}
bool Mesh::moveVertex(int index,Vec3 delta){
    if(index<0 || size_t(index)>=vertices.size())return false;
    vertices[size_t(index)]+=delta;return true;
}
bool Mesh::extrude(int f,float depth,float inset){
    if(f<0 || size_t(f)>=faces.size() || std::fabs(depth)+inset<1e-6f)return false;
    auto old=faces[size_t(f)];
    if(old.size()<3 || old.size()>128)return false;
    Vec3 n=faceNormal(f),centre{};
    for(int i:old)centre+=vertices[size_t(i)];
    centre=centre/float(old.size());
    inset=std::clamp(inset,0.f,0.42f);
    std::vector<int> ring=old;
    if(inset>1e-6f){
        ring.clear();
        for(int index:old){
            Vec3 p=vertices[size_t(index)]*(1-inset)+centre*inset;
            ring.push_back(int(vertices.size()));vertices.push_back(p);
        }
    }
    // Original face becomes an annulus if inset >0.
    faces.erase(faces.begin()+f);
    if(inset>1e-6f){
        for(size_t i=0;i<old.size();i++){
            size_t j=(i+1)%old.size();
            faces.push_back({old[i],old[j],ring[j],ring[i]});
        }
    }
    std::vector<int>cap=ring;
    if(std::fabs(depth)>1e-6f){
        cap.clear();
        for(int i:ring){
            cap.push_back(int(vertices.size()));
            vertices.push_back(vertices[size_t(i)]+n*depth);
        }
        for(size_t i=0;i<ring.size();i++){
            size_t j=(i+1)%ring.size();
            faces.push_back({ring[i],ring[j],cap[j],cap[i]});
        }
    }
    faces.push_back(std::move(cap));
    return true;
}
void Mesh::subdivide(){
    if(faces.size()>5000)return;
    std::map<std::pair<int,int>,int> edgeMidpoints;
    std::vector<std::vector<int>> newFaces;
    for(const auto &face:faces){
        if(face.size()<3)continue;
        Vec3 centre{};
        for(int i:face)centre+=vertices[size_t(i)];
        centre=centre/float(face.size());
        int c=int(vertices.size());vertices.push_back(centre);
        std::vector<int> mids;
        for(size_t i=0;i<face.size();i++){
            int a=face[i],b=face[(i+1)%face.size()];
            auto key=std::minmax(a,b);
            auto it=edgeMidpoints.find(key);
            if(it==edgeMidpoints.end()){
                int idx=int(vertices.size());
                vertices.push_back((vertices[size_t(a)]+vertices[size_t(b)])*0.5f);
                edgeMidpoints.emplace(key,idx);
                mids.push_back(idx);
            }else mids.push_back(it->second);
        }
        for(size_t i=0;i<face.size();i++){
            size_t previous=(i+face.size()-1)%face.size();
            newFaces.push_back({mids[previous],face[i],mids[i],c});
        }
    }
    faces=std::move(newFaces);
}
bool Mesh::valid() const{
    if(vertices.empty()||faces.empty()||vertices.size()>200000||faces.size()>200000)return false;
    for(const auto &v:vertices)if(!std::isfinite(v.x)||!std::isfinite(v.y)||!std::isfinite(v.z))return false;
    for(const auto &f:faces){
        if(f.size()<3||f.size()>128)return false;
        for(int i:f)if(i<0||size_t(i)>=vertices.size())return false;
    }
    return true;
}
bool Mesh::isClosed() const{
    if(!valid())return false;
    std::map<std::pair<int,int>,int> edgeUse;
    for(const auto& face:faces){
        for(size_t i=0;i<face.size();i++)edgeUse[std::minmax(face[i],face[(i+1)%face.size()])]++;
    }
    for(auto &edge:edgeUse)if(edge.second!=2)return false;
    return true;
}
std::vector<float> Mesh::interleavedTriangles(bool smooth) const{
    std::vector<float>out;
    out.reserve(faces.size()*6*6);
    // Respect sharp edges even when Smooth is enabled. At each face corner,
    // only neighboring faces within 40 degrees contribute to shading.
    // The old unconditional averaging rounded the corners of a cube visually.
    std::vector<Vec3> fn(faces.size());
    std::vector<std::vector<int>> neighbor(vertices.size());
    for(size_t fi=0;fi<faces.size();fi++){
        fn[fi]=faceNormal(int(fi));
        if(smooth)for(int id:faces[fi])neighbor[size_t(id)].push_back(int(fi));
    }
    for(size_t i=0;i<faces.size();i++){
        const auto&face=faces[i];
        const Vec3 n=fn[i];
        for(size_t k=1;k+1<face.size();k++){
            for(int idx:{face[0],face[k],face[k+1]}){
                const Vec3 p=vertices[size_t(idx)];
                Vec3 shadingNormal=n;
                if(smooth){
                    Vec3 total{};
                    for(int adjacent:neighbor[size_t(idx)]){
                        if(dot(n,fn[size_t(adjacent)])>=0.7660f)
                            total+=fn[size_t(adjacent)];
                    }
                    if(total.length()>1e-7f)shadingNormal=total.normalized();
                }
                out.insert(out.end(),{p.x,p.y,p.z,
                                     shadingNormal.x,shadingNormal.y,shadingNormal.z});
            }
        }
    }
    return out;
}
std::vector<float> Mesh::interleavedTrianglesUV(bool smooth) const {
    const auto six=interleavedTriangles(smooth);
    std::vector<float> out;
    out.reserve(six.size()/6*8);
    size_t cursor=0;
    for(size_t fi=0;fi<faces.size();fi++){
        const auto&face=faces[fi];
        const Vec3 n=faceNormal(int(fi));
        const float ax=std::fabs(n.x),ay=std::fabs(n.y),az=std::fabs(n.z);
        for(size_t k=1;k+1<face.size();k++){
            for(int v=0;v<3;v++){
                const Vec3 p={six[cursor],six[cursor+1],six[cursor+2]};
                float u=0.f,t=0.f;
                // Face-aligned planar unwrap (0.5m per UV repeat).
                // Per-corner UV permits hard seams without duplicating topology.
                if(ay>=ax&&ay>=az){u=p.x*2.f;t=p.z*2.f;}
                else if(ax>=az){u=p.z*2.f;t=p.y*2.f;}
                else {u=p.x*2.f;t=p.y*2.f;}
                out.insert(out.end(),six.begin()+static_cast<std::ptrdiff_t>(cursor),
                    six.begin()+static_cast<std::ptrdiff_t>(cursor+6));
                out.push_back(u);out.push_back(t);
                cursor+=6;
            }
        }
    }
    return out;
}
MaterialProperties presetMaterial(int index){
    switch(index){
        case 0:return {{0.62f,0.55f,0.46f},0.0f,0.85f};
        case 1:return {{0.25f,0.34f,0.42f},0.0f,0.67f};
        case 2:return {{0.64f,0.36f,0.21f},0.0f,0.65f};
        case 3:return {{0.68f,0.73f,0.75f},0.82f,0.27f};
        case 4:return {{0.39f,0.50f,0.36f},0.0f,0.77f};
        default:return presetMaterial(0);
    }
}
Scene::Scene()=default;
void Scene::checkpoint(){
    std::string state=serialize();
    if(!undoHistory.empty()&&undoHistory.back()==state)return;
    undoHistory.push_back(std::move(state));
    if(undoHistory.size()>24)undoHistory.erase(undoHistory.begin());
    redoHistory.clear();
}
bool Scene::undo(){
    if(undoHistory.empty())return false;
    const std::string current=serialize();
    const std::string previous=undoHistory.back();
    if(!restore(previous))return false;
    undoHistory.pop_back();
    redoHistory.push_back(current);
    return true;
}
bool Scene::redo(){
    if(redoHistory.empty())return false;
    const std::string current=serialize();
    const std::string next=redoHistory.back();
    if(!restore(next))return false;
    redoHistory.pop_back();
    undoHistory.push_back(current);
    return true;
}
void Scene::add(int type){
    if(objects.size()>63)return;
    Object o;
    o.type=std::clamp(type,0,2);
    o.mesh=(o.type==1?Mesh::sphere():(o.type==2?Mesh::cylinder():Mesh::cube()));
    size_t index=objects.size();
    o.position={float(index%3)*1.5f-1.5f,0.8f,float(index/3)*1.2f};
    if(index==0)o.position.x=0.f;
    o.scale=(o.type==0?Vec3{1.25f,0.75f,0.85f}:Vec3{0.9f,0.9f,0.9f});
    o.material=(type+int(objects.size()))%5;
    o.pbr=presetMaterial(o.material);
    o.smoothShading=o.type==1;
    o.pattern=o.type==0?1:0;
    objects.push_back(std::move(o));
    selected=int(objects.size())-1;
}
bool Scene::duplicateSelected(){
    if(selected<0||size_t(selected)>=objects.size()||objects.size()>=64)return false;
    Object copy=objects[size_t(selected)];
    copy.gpuBuffer=0;copy.gpuVertices=0;copy.dirty=true;
    copy.position.x+=0.20f;
    copy.position.z+=0.20f;
    objects.push_back(std::move(copy));
    selected=int(objects.size())-1;
    return true;
}
bool Scene::deleteSelected(){
    if(selected<0||size_t(selected)>=objects.size())return false;
    objects.erase(objects.begin()+selected);
    selected=objects.empty()?-1:std::min(selected,int(objects.size())-1);
    return true;
}
void Scene::selectNext(){
    if(objects.empty()){selected=-1;return;}
    selected=(selected+1)%int(objects.size());
}
void Scene::move(float x,float z){
    if(selected<0||size_t(selected)>=objects.size())return;
    objects[size_t(selected)].position+=Vec3{x,0.f,z};
}
bool Scene::transform(int mode,int axis,float amount){
    if(selected<0||size_t(selected)>=objects.size()||!std::isfinite(amount))return false;
    if(axis<0||axis>2)return false;
    auto&o=objects[size_t(selected)];
    if(mode==0){
        if(axis==0)o.position.x+=amount;
        else if(axis==1)o.position.y+=amount;
        else o.position.z+=amount;
    }else if(mode==1){
        // First modeling milestone: rotation around vertical (Y) axis only.
        if(axis!=1)return false;
        o.yaw+=amount;
    }else if(mode==2){
        if(axis==0)o.scale.x=std::clamp(o.scale.x+amount,0.05f,100.f);
        else if(axis==1)o.scale.y=std::clamp(o.scale.y+amount,0.05f,100.f);
        else o.scale.z=std::clamp(o.scale.z+amount,0.05f,100.f);
    }else return false;
    return true;
}
bool Scene::inset(float fraction){
    if(selected<0||size_t(selected)>=objects.size())return false;
    auto&o=objects[size_t(selected)];
    if(o.mesh.faces.empty()||o.mesh.faces.size()>30000)return false;
    const int f=std::clamp(o.selectedFace,0,int(o.mesh.faces.size())-1);
    if(!o.mesh.extrude(f,0.f,fraction))return false;
    o.selectedFace=int(o.mesh.faces.size())-1;
    o.dirty=true;
    return true;
}
bool Scene::extrude(float metres){
    if(selected<0||size_t(selected)>=objects.size())return false;
    auto&o=objects[size_t(selected)];
    if(o.mesh.faces.size()>30000)return false;
    int f=std::clamp(o.selectedFace,0,int(o.mesh.faces.size())-1);
    Vec3 n=o.mesh.faceNormal(f);
    float scale=std::fabs(n.x)*o.scale.x+std::fabs(n.y)*o.scale.y+std::fabs(n.z)*o.scale.z;
    if(!o.mesh.extrude(f,metres/std::max(0.001f,scale),0.07f))return false;
    o.selectedFace=int(o.mesh.faces.size())-1;
    o.dirty=true;return true;
}
void Scene::subdivide(){
    if(selected<0||size_t(selected)>=objects.size())return;
    auto&o=objects[size_t(selected)];
    if(o.mesh.faces.size()>1000)return;
    o.mesh.subdivide();o.selectedFace=0;o.dirty=true;
}
bool Scene::moveComponent(int mode,int axis,float metres){
    if(selected<0 || size_t(selected)>=objects.size() || axis<0 || axis>2 ||
       !std::isfinite(metres) || std::fabs(metres)>5.f)return false;
    Object&o=objects[size_t(selected)];
    if(mode!=1&&mode!=2)return false; // vertex or edge only
    int a=(mode==1)?o.selectedVertex:o.selectedEdgeA;
    int b=(mode==2)?o.selectedEdgeB:-1;
    if(a<0 || size_t(a)>=o.mesh.vertices.size())return false;
    if(mode==2 && (b<0 || size_t(b)>=o.mesh.vertices.size() || a==b))return false;
    // Project a WORLD axis motion into mesh-local axes, accounting for object yaw and scale.
    const float c=std::cos(o.yaw),s=std::sin(o.yaw);
    Vec3 delta{};
    if(axis==0)delta={c*metres/o.scale.x,0.f,s*metres/o.scale.z};
    else if(axis==1)delta={0.f,metres/o.scale.y,0.f};
    else delta={-s*metres/o.scale.x,0.f,c*metres/o.scale.z};
    o.mesh.vertices[size_t(a)]+=delta;
    if(mode==2)o.mesh.vertices[size_t(b)]+=delta;
    o.dirty=true;
    return true;
}
bool Scene::splitSelectedEdge(){
    if(selected<0||size_t(selected)>=objects.size())return false;
    Object&obj=objects[size_t(selected)];
    int midpoint=splitEdge(obj.mesh,obj.selectedEdgeA,obj.selectedEdgeB);
    if(midpoint<0)return false;
    obj.selectedVertex=midpoint;
    obj.selectedEdgeA=-1;obj.selectedEdgeB=-1;
    obj.selectedFace=0;obj.dirty=true;
    return true;
}
bool Scene::loopCutSelectedEdge(){
    if(selected<0||size_t(selected)>=objects.size())return false;
    Object&obj=objects[size_t(selected)];
    int midpoint=loopCut(obj.mesh,obj.selectedEdgeA,obj.selectedEdgeB);
    if(midpoint<0)return false;
    obj.selectedVertex=midpoint;
    obj.selectedEdgeA=-1;obj.selectedEdgeB=-1;
    obj.selectedFace=0;obj.dirty=true;
    return true;
}
bool Scene::bevelSelectedEdge(float metres,int segments){
    if(selected<0||size_t(selected)>=objects.size()||!std::isfinite(metres))return false;
    Object&o=objects[size_t(selected)];
    if(o.selectedEdgeA<0||o.selectedEdgeB<0)return false;
    Vec3 n{};
    int count=0;
    for(size_t i=0;i<o.mesh.faces.size();i++){
        const auto&face=o.mesh.faces[i];
        for(size_t k=0;k<face.size();k++){
            int a=face[k],b=face[(k+1)%face.size()];
            if((a==o.selectedEdgeA&&b==o.selectedEdgeB)||
               (a==o.selectedEdgeB&&b==o.selectedEdgeA)){
                n+=o.mesh.faceNormal(int(i));count++;break;
            }
        }
    }
    if(count!=2||n.length()<0.01f)return false;
    n=n.normalized();
    const float inverseScale=std::sqrt(
        (n.x/o.scale.x)*(n.x/o.scale.x)+
        (n.y/o.scale.y)*(n.y/o.scale.y)+
        (n.z/o.scale.z)*(n.z/o.scale.z));
    const int cap=bevelConvexEdge(o.mesh,o.selectedEdgeA,o.selectedEdgeB,metres*inverseScale,segments);
    if(cap<0)return false;
    o.selectedFace=cap;
    o.selectedEdgeA=-1;o.selectedEdgeB=-1;
    o.selectedVertex=-1;
    o.dirty=true;
    return true;
}
bool Scene::bridgeSelectedFaces(int faceA,int faceB){
    if(selected<0||size_t(selected)>=objects.size())return false;
    Object&o=objects[size_t(selected)];
    if(!bridgeOppositeQuads(o.mesh,faceA,faceB,0.24f))return false;
    o.selectedFace=0;
    o.selectedEdgeA=-1;o.selectedEdgeB=-1;o.selectedVertex=-1;
    o.dirty=true;
    return true;
}
void Scene::setMaterial(int id){
    if(selected<0||size_t(selected)>=objects.size())return;
    auto&o=objects[size_t(selected)];
    o.material=(o.material+1)%5;
    if(id>=0&&id<5)o.material=id;
    o.pbr=presetMaterial(o.material);
    o.customMaterial=false;
    o.pattern=id==0?1:(id==1?3:(id==2?2:(id==3?4:0)));
}
bool Scene::setCustomMaterial(Vec3 color,float metallic,float roughness){
    if(selected<0||size_t(selected)>=objects.size())return false;
    auto valid=[](float f){return std::isfinite(f)&&f>=0.f&&f<=1.f;};
    if(!valid(color.x)||!valid(color.y)||!valid(color.z)||!valid(metallic)||
       !valid(roughness))return false;
    auto&o=objects[size_t(selected)];
    o.pbr={color,metallic,std::clamp(roughness,0.04f,1.f)};
    o.customMaterial=true;
    return true;
}
bool Scene::setPattern(int pattern,float uvScale){
    if(selected<0||size_t(selected)>=objects.size()||pattern<0||pattern>4||
       !std::isfinite(uvScale)||uvScale<0.1f||uvScale>10.f)return false;
    auto&o=objects[size_t(selected)];
    o.pattern=pattern;
    o.uvScale=uvScale;
    return true;
}
bool Scene::setUvTransform(float offsetX,float offsetY,float radians){
    if(selected<0||size_t(selected)>=objects.size()||
       !std::isfinite(offsetX)||!std::isfinite(offsetY)||!std::isfinite(radians)||
       std::fabs(offsetX)>20.f||std::fabs(offsetY)>20.f||
       std::fabs(radians)>3.142f)return false;
    auto&o=objects[size_t(selected)];
    o.uvOffsetX=offsetX;
    o.uvOffsetY=offsetY;
    o.uvRotation=radians;
    return true;
}
bool Scene::setSmoothShading(bool enabled){
    if(selected<0||size_t(selected)>=objects.size())return false;
    auto&o=objects[size_t(selected)];
    o.smoothShading=enabled;
    o.dirty=true;
    return true;
}
std::string Scene::describe() const{
    std::ostringstream stream;
    stream<<"C++ MESH ENGINE  •  "<<objects.size()<<" объектов";
    if(selected>=0&&size_t(selected)<objects.size()){
        auto&o=objects[size_t(selected)];
        stream<<"  |  №"<<selected+1<<" • грань "<<o.selectedFace+1<<"/"<<o.mesh.faces.size()<<" • "<<o.mesh.vertices.size()<<" вершин";
        if(o.selectedVertex>=0)stream<<" • вершина "<<o.selectedVertex;
        if(o.selectedEdgeA>=0)stream<<" • ребро "<<o.selectedEdgeA<<"-"<<o.selectedEdgeB;
        stream<<" • Metal "<<int(o.pbr.metallic*100.f)<<"%";
        stream<<" • Rough "<<int(o.pbr.roughness*100.f)<<"%";
        stream<<" • "<<(o.smoothShading?"Smooth":"Flat");
        stream<<" • UV "<<o.uvScale<<"x";
    }
    return stream.str();
}
std::string Scene::serialize() const{
    std::ostringstream f;
    f<<std::setprecision(9)<<"ZAMER_NATIVE_MESH_4\n"<<objects.size()<<" "<<selected<<"\n";
    for(const auto&o:objects){
        f<<o.type<<" "<<o.material<<" "<<o.selectedFace<<" "
         <<o.position.x<<" "<<o.position.y<<" "<<o.position.z<<" "
         <<o.scale.x<<" "<<o.scale.y<<" "<<o.scale.z<<" "<<o.yaw<<"\n";
        f<<int(o.customMaterial)<<" "<<int(o.smoothShading)<<" "
         <<o.pbr.color.x<<" "<<o.pbr.color.y<<" "<<o.pbr.color.z<<" "
         <<o.pbr.metallic<<" "<<o.pbr.roughness<<"\n";
        f<<o.pattern<<" "<<o.uvScale<<" "<<o.uvOffsetX<<" "<<o.uvOffsetY<<" "<<o.uvRotation<<"\n";
        f<<o.mesh.vertices.size()<<" "<<o.mesh.faces.size()<<"\n";
        for(auto v:o.mesh.vertices)f<<v.x<<" "<<v.y<<" "<<v.z<<"\n";
        for(const auto&face:o.mesh.faces){
            f<<face.size();for(int i:face)f<<" "<<i;f<<"\n";
        }
    }
    return f.str();
}
bool Scene::restore(const std::string&source){
    std::istringstream f(source);
    std::string header;
    if(!(f>>header)||(header!="ZAMER_NATIVE_MESH_1"&&header!="ZAMER_NATIVE_MESH_2"&&header!="ZAMER_NATIVE_MESH_3"&&header!="ZAMER_NATIVE_MESH_4"))return false;
    const bool v2=header!="ZAMER_NATIVE_MESH_1";
    const bool v3=(header=="ZAMER_NATIVE_MESH_3"||header=="ZAMER_NATIVE_MESH_4");
    const bool v4=header=="ZAMER_NATIVE_MESH_4";
    int count=0,selection=-1;
    if(!(f>>count>>selection)||count<0||count>64||selection>=count||selection< -1)return false;
    std::vector<Object>loaded;
    for(int i=0;i<count;i++){
        Object o;
        if(!(f>>o.type>>o.material>>o.selectedFace
          >>o.position.x>>o.position.y>>o.position.z
          >>o.scale.x>>o.scale.y>>o.scale.z>>o.yaw))return false;
        o.pbr=presetMaterial(o.material);
        o.smoothShading=o.type==1;
        if(v2){
            int custom=0,smooth=0;
            if(!(f>>custom>>smooth>>o.pbr.color.x>>o.pbr.color.y>>o.pbr.color.z
                  >>o.pbr.metallic>>o.pbr.roughness))return false;
            if((custom!=0&&custom!=1)||(smooth!=0&&smooth!=1))return false;
            auto valid=[](float v){return std::isfinite(v)&&v>=0.f&&v<=1.f;};
            if(!valid(o.pbr.color.x)||!valid(o.pbr.color.y)||!valid(o.pbr.color.z)||
               !valid(o.pbr.metallic)||!valid(o.pbr.roughness)||
               o.pbr.roughness<0.04f)return false;
            o.customMaterial=custom!=0;o.smoothShading=smooth!=0;
        }
        if(v3){
            if(!(f>>o.pattern>>o.uvScale) || o.pattern<0||o.pattern>4||
               !std::isfinite(o.uvScale)||o.uvScale<0.1f||o.uvScale>10.f)return false;
            if(v4){
                if(!(f>>o.uvOffsetX>>o.uvOffsetY>>o.uvRotation)||
                   !std::isfinite(o.uvOffsetX)||!std::isfinite(o.uvOffsetY)||
                   !std::isfinite(o.uvRotation)||std::fabs(o.uvOffsetX)>20.f||
                   std::fabs(o.uvOffsetY)>20.f||std::fabs(o.uvRotation)>3.142f)return false;
            }
        }else{
            o.pattern=o.material==0?1:(o.material==1?3:(o.material==2?2:(o.material==3?4:0)));
        }
        size_t vc=0,fc=0;
        if(!(f>>vc>>fc)||vc>200000||fc>200000||vc<3||fc<1)return false;
        o.mesh.vertices.resize(vc);
        for(auto &v:o.mesh.vertices)if(!(f>>v.x>>v.y>>v.z))return false;
        for(size_t j=0;j<fc;j++){
            int n=0;if(!(f>>n)||n<3||n>128)return false;
            std::vector<int>face(static_cast<size_t>(n));
            for(int &index:face)if(!(f>>index))return false;
            o.mesh.faces.push_back(std::move(face));
        }
        if(!o.mesh.valid()||o.type<0||o.type>2||o.material<0||o.material>=5)return false;
        if(o.scale.x<=0||o.scale.y<=0||o.scale.z<=0)return false;
        o.gpuBuffer=0;o.gpuVertices=0;o.dirty=true;
        loaded.push_back(std::move(o));
    }
    objects=std::move(loaded);selected=selection;
    return true;
}
} // namespace zamer
