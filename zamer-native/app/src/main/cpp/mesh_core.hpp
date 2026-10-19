#pragma once
#include <array>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

namespace zamer {
struct Vec3 {
    float x=0.f,y=0.f,z=0.f;
    Vec3()=default;
    Vec3(float a,float b,float c):x(a),y(b),z(c){}
    Vec3 operator+(const Vec3&v) const{return {x+v.x,y+v.y,z+v.z};}
    Vec3 operator-(const Vec3&v) const{return {x-v.x,y-v.y,z-v.z};}
    Vec3 operator*(float s) const{return {x*s,y*s,z*s};}
    Vec3 operator/(float s) const{return {x/s,y/s,z/s};}
    Vec3& operator+=(const Vec3&v){x+=v.x;y+=v.y;z+=v.z;return *this;}
    float length() const{return std::sqrt(x*x+y*y+z*z);}
    Vec3 normalized() const {float l=length();return l<1e-8f?Vec3{}:(*this)/l;}
};
float dot(Vec3 a,Vec3 b);
Vec3 cross(Vec3 a,Vec3 b);

struct Mesh {
    std::vector<Vec3> vertices;
    std::vector<std::vector<int>> faces;
    static Mesh cube();
    static Mesh sphere(int segments=48,int rings=24);
    static Mesh cylinder(int segments=32);
    Vec3 faceNormal(int face) const;
    bool moveVertex(int index,Vec3 delta);
    bool extrude(int face,float depth,float inset);
    void subdivide();
    bool isClosed() const;
    bool valid() const;
    std::vector<float> interleavedTriangles(bool smooth=false) const; // pos.xyz, normal.xyz
};

struct MaterialProperties {
    Vec3 color={0.62f,0.55f,0.46f}; // sRGB base color in 0..1
    float metallic=0.f;
    float roughness=0.85f;
};
MaterialProperties presetMaterial(int index);

struct Object {
    Mesh mesh;
    Vec3 position={0.f,0.8f,0.f};
    Vec3 scale={1.35f,0.9f,0.8f};
    float yaw=0.f;
    int material=0;
    MaterialProperties pbr{};
    bool customMaterial=false;
    bool smoothShading=false;
    int selectedFace=2;
    int selectedVertex=-1;
    int selectedEdgeA=-1,selectedEdgeB=-1;
    int type=0;
    unsigned int gpuBuffer=0;
    int gpuVertices=0;
    bool dirty=true;
};

class Scene {
public:
    std::vector<Object> objects;
    int selected=-1;
    int activeMaterial=0;
    std::vector<std::string> undoHistory;
    std::vector<std::string> redoHistory;
    void checkpoint();
    bool undo();
    bool redo();
    Scene();
    void add(int type);
    bool duplicateSelected();
    bool deleteSelected();
    void selectNext();
    void move(float x,float z);
    bool transform(int mode,int axis,float amount);
    bool moveComponent(int mode,int axis,float metres);
    bool splitSelectedEdge();
    bool loopCutSelectedEdge();
    bool bevelSelectedEdge(float metres,int segments=1);
    bool bridgeSelectedFaces(int faceA,int faceB);
    bool inset(float fraction);
    bool extrude(float metres);
    void subdivide();
    void setMaterial(int id);
    bool setCustomMaterial(Vec3 color,float metallic,float roughness);
    bool setSmoothShading(bool enabled);
    std::string describe() const;
    std::string serialize() const;
    bool restore(const std::string&);
};
} // namespace zamer
