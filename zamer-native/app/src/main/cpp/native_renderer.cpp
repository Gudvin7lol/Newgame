#include "native_renderer.hpp"
#include "scene_picker.hpp"
#include "gizmo_math.hpp"
#include "mesh_edit.hpp"
#include <android/log.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>
namespace zamer {
namespace {
using M=std::array<float,16>;
constexpr float PI=3.14159265358979323846f;
M identity(){return {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};}
M mul(const M&a,const M&b){
 M c{};
 for(int x=0;x<4;x++)for(int y=0;y<4;y++)for(int k=0;k<4;k++)
  c[size_t(x*4+y)]+=a[size_t(k*4+y)]*b[size_t(x*4+k)];
 return c;
}
M perspective(float fov,float aspect){
 M m{};float f=1.f/std::tan(fov*PI/360.f);
 m[0]=f/aspect;m[5]=f;m[10]=-1.002f;m[11]=-1.f;m[14]=-0.2002f;return m;
}
M lookAt(Vec3 eye,Vec3 target){
 Vec3 f=(target-eye).normalized(),s=cross(f,{0,1,0}).normalized(),u=cross(s,f);
 M m=identity();
 m[0]=s.x;m[4]=s.y;m[8]=s.z;
 m[1]=u.x;m[5]=u.y;m[9]=u.z;
 m[2]=-f.x;m[6]=-f.y;m[10]=-f.z;
 m[12]=-dot(s,eye);m[13]=-dot(u,eye);m[14]=dot(f,eye);
 return m;
}
M objectMatrix(const Object&o){
 M m=identity();float c=std::cos(o.yaw),s=std::sin(o.yaw);
 m[0]=c*o.scale.x;m[2]=-s*o.scale.x;m[5]=o.scale.y;
 m[8]=s*o.scale.z;m[10]=c*o.scale.z;
 m[12]=o.position.x;m[13]=o.position.y;m[14]=o.position.z;
 return m;
}

const char* vShader=R"shader(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNormal;
layout(location=2) in vec2 aUV;
uniform mat4 mvp,model;
uniform float markerSize;
out vec3 nWorld,pWorld;
out vec2 texUV;
void main(){
 vec4 w=model*vec4(aPos,1.0);
 pWorld=w.xyz;
 texUV=aUV;
 nWorld=normalize(transpose(inverse(mat3(model)))*aNormal);
 gl_Position=mvp*vec4(aPos,1.0);
 gl_PointSize=markerSize;
})shader";
const char* fShader=R"shader(#version 300 es
precision highp float;
in vec3 nWorld,pWorld;
in vec2 texUV;
uniform vec3 eyePos,baseColor;
uniform float metallic,roughness;
uniform int isSelected,uFlatMode,patternMode;
uniform float uvScale,uvRotation;
uniform vec2 uvOffset;
out vec4 outColor;
const float PI=3.14159265;
void main(){
 if(uFlatMode==1){outColor=vec4(baseColor,1.0);return;}
 vec3 n=normalize(nWorld),v=normalize(eyePos-pWorld);
 vec3 surfaceColor=baseColor;
 float roughLocal=roughness;
 vec2 p=texUV*uvScale;
 float c=cos(uvRotation),s=sin(uvRotation);
 vec2 uv=vec2(p.x*c-p.y*s,p.x*s+p.y*c)+uvOffset;
 if(patternMode==1){
    // Yarn warp/weft: subtle procedural textile, no imported image needed.
    float warp=pow(0.5+0.5*cos(uv.x*100.0),4.0);
    float weft=pow(0.5+0.5*cos(uv.y*100.0),4.0);
    surfaceColor*=0.955+0.032*(warp+weft);
    roughLocal=clamp(roughLocal+0.018*(warp+weft),0.04,1.0);
 }else if(patternMode==2){
    // Directional low-contrast wood fibre. No high-contrast sinusoidal waves.
    float line=uv.y*10.2+0.22*sin(uv.x*3.4+uv.y*0.3)
               +0.09*sin(uv.x*9.7);
    float ring=0.5+0.5*sin(line+0.26*sin(uv.y*2.1));
    float fibre=sin(uv.y*110.0+0.23*sin(uv.x*7.0));
    float tone=0.94+0.055*ring+0.014*fibre;
    surfaceColor*=vec3(tone*1.01,tone,tone*0.98);
    roughLocal=clamp(roughLocal+0.025*ring,0.04,1.0);
 }else if(patternMode==3){
    float pores=sin(uv.x*87.0)*sin(uv.y*96.0);
    surfaceColor*=0.965+0.018*pores;
    roughLocal=clamp(roughLocal+0.020*pores,0.04,1.0);
 }else if(patternMode==4){
    float brushed=0.5+0.5*sin(uv.y*270.0);
    surfaceColor*=0.982+0.018*brushed;
 }
 vec3 l=normalize(vec3(-0.4,0.85,0.44)),h=normalize(v+l);
 float nl=max(dot(n,l),0.0),nv=max(dot(n,v),0.0);
 vec3 a=pow(clamp(surfaceColor,0.0,1.0),vec3(2.2)),f0=mix(vec3(0.04),a,metallic);
 float r=max(roughLocal,0.07),rr=r*r,rr2=rr*rr;
 float nh=max(dot(n,h),0.0),den=nh*nh*(rr2-1.0)+1.0;
 float D=rr2/max(PI*den*den,0.00001);
 float k=pow(r+1.0,2.0)/8.0;
 float G=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
 vec3 F=f0+(1.0-f0)*pow(1.0-max(dot(v,h),0.0),5.0);
 vec3 spec=D*G*F/max(4.0*nv*nl,0.0001);
 vec3 diff=(1.0-F)*(1.0-metallic)*a/PI;
 vec3 fillDir=normalize(vec3(0.65,0.38,-0.65));
 float nf=max(dot(n,fillDir),0.0);
 vec3 x=(diff+spec)*vec3(3.0,3.08,3.18)*nl;
 x+=diff*vec3(0.75,0.88,1.05)*nf;
 x+=a*0.15;
 x=(x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14);
 x=pow(clamp(x,0.0,1.0),vec3(1.0/2.2));
 if(isSelected==1)x=mix(x,vec3(0.18,0.91,0.79),0.16);
 outColor=vec4(x,1.0);
})shader";
}
GLuint Renderer::compile(GLenum kind,const char*source){
 GLuint shader=glCreateShader(kind);glShaderSource(shader,1,&source,nullptr);glCompileShader(shader);
 GLint ok=GL_FALSE;glGetShaderiv(shader,GL_COMPILE_STATUS,&ok);
 if(ok==GL_FALSE){char log[1024]{};glGetShaderInfoLog(shader,1024,nullptr,log);
  __android_log_print(ANDROID_LOG_ERROR,"ZamerEngine","Shader error: %s",log);
  glDeleteShader(shader);return 0;}
 return shader;
}
std::string Renderer::graphicsStatus() const {
 return state+" | "+std::to_string(width)+"x"+std::to_string(height);
}
void Renderer::initGl(){
 const GLubyte* version=glGetString(GL_VERSION);
 if(!version){state="GPU: контекст отсутствует";return;}
 state=std::string("GPU: ")+reinterpret_cast<const char*>(version);
 GLuint vertex=compile(GL_VERTEX_SHADER,vShader),fragment=compile(GL_FRAGMENT_SHADER,fShader);
 if(!vertex||!fragment){state="GPU: ошибка компиляции GLSL";return;}
 program=glCreateProgram();glAttachShader(program,vertex);glAttachShader(program,fragment);
 glLinkProgram(program);glDeleteShader(vertex);glDeleteShader(fragment);
 GLint ok=GL_FALSE;glGetProgramiv(program,GL_LINK_STATUS,&ok);
 if(ok==GL_FALSE){__android_log_print(ANDROID_LOG_ERROR,"ZamerEngine","Program link error");
  state="GPU: ошибка линковки шейдеров";glDeleteProgram(program);program=0;return;}
 mvpLoc=glGetUniformLocation(program,"mvp");modelLoc=glGetUniformLocation(program,"model");
 cameraLoc=glGetUniformLocation(program,"eyePos");colorLoc=glGetUniformLocation(program,"baseColor");
 metalLoc=glGetUniformLocation(program,"metallic");roughLoc=glGetUniformLocation(program,"roughness");
 selectLoc=glGetUniformLocation(program,"isSelected");flatLoc=glGetUniformLocation(program,"uFlatMode");
 markerLoc=glGetUniformLocation(program,"markerSize");
 patternLoc=glGetUniformLocation(program,"patternMode");
 uvScaleLoc=glGetUniformLocation(program,"uvScale");
 uvOffsetLoc=glGetUniformLocation(program,"uvOffset");
 uvRotationLoc=glGetUniformLocation(program,"uvRotation");
 glGenBuffers(1,&gridBuffer);
 glGenBuffers(1,&faceBuffer);
 glGenBuffers(1,&gizmoBuffer);
 for(auto&o:scene.objects){o.gpuBuffer=0;o.dirty=true;}
 glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);glDisable(GL_CULL_FACE);
 const GLubyte* driver=glGetString(GL_RENDERER);
 state=driver?std::string("GPU OK: ")+reinterpret_cast<const char*>(driver):"GPU OK";
}
void Renderer::resize(int w,int h){width=std::max(1,w);height=std::max(1,h);glViewport(0,0,width,height);}
void Renderer::orbit(float dx,float dy){yaw-=dx;pitch=std::clamp(pitch-dy,-1.25f,1.25f);}
void Renderer::zoom(float factor){distance=std::clamp(distance/std::clamp(factor,0.5f,2.f),1.6f,15.f);}
void Renderer::pan(float xPixels,float yPixels){
    if(!std::isfinite(xPixels)||!std::isfinite(yPixels))return;
    const Vec3 forward=Vec3{-std::sin(yaw)*std::cos(pitch),
                            -std::sin(pitch),
                            -std::cos(yaw)*std::cos(pitch)};
    const Vec3 right=cross(forward,{0,1,0}).normalized();
    const Vec3 up=cross(right,forward).normalized();
    const float worldPerPixel=2.f*distance*std::tan(46.f*PI/360.f)/float(std::max(1,height));
    cameraTarget+=right*(-xPixels*worldPerPixel)+up*(yPixels*worldPerPixel);
}
bool Renderer::focusSelected(){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    cameraTarget=scene.objects[size_t(scene.selected)].position;
    return true;
}
void Renderer::drawGrid(const M&p,const M&v,Vec3 eye){
 std::vector<float>points;points.reserve(504);
 for(int i=-10;i<=10;i++){
  float q=0.5f*float(i);
  for(Vec3 a:std::array<Vec3,4>{{{q,-0.018f,-5},{q,-0.018f,5},{-5,-0.018f,q},{5,-0.018f,q}}})
   points.insert(points.end(),{a.x,a.y,a.z,0,1,0});
 }
 glBindBuffer(GL_ARRAY_BUFFER,gridBuffer);glBufferData(GL_ARRAY_BUFFER,GLsizeiptr(points.size()*sizeof(float)),points.data(),GL_DYNAMIC_DRAW);
 glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,6*sizeof(float),nullptr);
 glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,6*sizeof(float),reinterpret_cast<void*>(3*sizeof(float)));
 glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);
 M id=identity(),mvp=mul(p,mul(v,id));
 glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.data());glUniformMatrix4fv(modelLoc,1,GL_FALSE,id.data());
 glUniform3f(cameraLoc,eye.x,eye.y,eye.z);
 glUniform3f(colorLoc,0.16f,0.26f,0.32f);
 glUniform1i(flatLoc,1);glUniform1i(selectLoc,0);
 glDrawArrays(GL_LINES,0,GLsizei(points.size()/6));glUniform1i(flatLoc,0);
}
void Renderer::drawItem(Object&o,int index,const M&p,const M&v,Vec3 eye){
 if(o.gpuBuffer==0){glGenBuffers(1,&o.gpuBuffer);o.dirty=true;}
 glBindBuffer(GL_ARRAY_BUFFER,o.gpuBuffer);
 if(o.dirty){
  auto vertices=o.mesh.interleavedTrianglesUV(o.smoothShading);
  o.gpuVertices=int(vertices.size()/8);
  glBufferData(GL_ARRAY_BUFFER,GLsizeiptr(vertices.size()*sizeof(float)),vertices.data(),GL_DYNAMIC_DRAW);
  o.dirty=false;
 }
 glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,8*sizeof(float),nullptr);
 glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,8*sizeof(float),reinterpret_cast<void*>(3*sizeof(float)));
 glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,8*sizeof(float),reinterpret_cast<void*>(6*sizeof(float)));
 glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);glEnableVertexAttribArray(2);
 M model=objectMatrix(o),mvp=mul(p,mul(v,model));
 glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.data());glUniformMatrix4fv(modelLoc,1,GL_FALSE,model.data());
 glUniform3f(cameraLoc,eye.x,eye.y,eye.z);
 const auto&m=o.pbr;
 glUniform3f(colorLoc,m.color.x,m.color.y,m.color.z);
 glUniform1f(metalLoc,m.metallic);glUniform1f(roughLoc,m.roughness);
 glUniform1i(selectLoc,index==scene.selected?1:0);
 glUniform1i(patternLoc,o.pattern);
 glUniform1f(uvScaleLoc,o.uvScale);
 glUniform2f(uvOffsetLoc,o.uvOffsetX,o.uvOffsetY);
 glUniform1f(uvRotationLoc,o.uvRotation);
 glDrawArrays(GL_TRIANGLES,0,o.gpuVertices);
 glDisableVertexAttribArray(2);
}
int Renderer::pickAt(float x,float y,bool face){
    const float aspect=float(width)/float(std::max(1,height));
    const float yfov=std::tan(46.f*PI/360.f);
    Vec3 target=cameraTarget;
    Vec3 eye=target+Vec3{distance*std::sin(yaw)*std::cos(pitch),
                         distance*std::sin(pitch),
                         distance*std::cos(yaw)*std::cos(pitch)};
    Vec3 forward=(target-eye).normalized();
    Vec3 right=cross(forward,{0,1,0}).normalized();
    Vec3 up=cross(right,forward).normalized();
    float dx=(2.f*x/float(std::max(1,width))-1.f)*aspect*yfov;
    float dy=(1.f-2.f*y/float(std::max(1,height)))*yfov;
    Vec3 direction=(forward+right*dx+up*dy).normalized();
    const SurfaceHit hit=pickSurface(scene,eye,direction);
    if(hit.object>=0){
        scene.selected=hit.object;
        if(face)scene.objects[size_t(hit.object)].selectedFace=hit.face;
    }
    return face?hit.face:hit.object;
}
int Renderer::pick(float x,float y){return pickAt(x,y,false);}
void Renderer::setGizmoMode(int mode){
    gizmoMode=std::clamp(mode,0,3);
    activeAxis=-1;
    dragCheckpointed=false;
}
int Renderer::beginGizmo(float x,float y){
    activeAxis=-1;
    dragCheckpointed=false;
    if((gizmoMode!=1&&gizmoMode!=3)||scene.selected<0||size_t(scene.selected)>=scene.objects.size())return -1;
    const float aspect=float(width)/float(std::max(1,height));
    const float yfov=std::tan(46.f*PI/360.f);
    Vec3 target=cameraTarget;
    Vec3 eye=target+Vec3{distance*std::sin(yaw)*std::cos(pitch),distance*std::sin(pitch),distance*std::cos(yaw)*std::cos(pitch)};
    Vec3 forward=(target-eye).normalized(),right=cross(forward,{0,1,0}).normalized(),up=cross(right,forward).normalized();
    float dx=(2.f*x/float(std::max(1,width))-1.f)*aspect*yfov;
    float dy=(1.f-2.f*y/float(std::max(1,height)))*yfov;
    Vec3 ray=(forward+right*dx+up*dy).normalized();
    const Vec3 center=scene.objects[size_t(scene.selected)].position;
    activeAxis=pickGizmoAxis(eye,ray,center,distance*0.18f,distance*0.017f);
    return activeAxis;
}
bool Renderer::dragGizmo(float dx,float dy){
    if(activeAxis<0||scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    Vec3 target=cameraTarget;
    Vec3 eye=target+Vec3{distance*std::sin(yaw)*std::cos(pitch),distance*std::sin(pitch),distance*std::cos(yaw)*std::cos(pitch)};
    Vec3 forward=(target-eye).normalized(),right=cross(forward,{0,1,0}).normalized(),up=cross(right,forward).normalized();
    Vec3 axis=activeAxis==0?Vec3{1,0,0}:(activeAxis==1?Vec3{0,1,0}:Vec3{0,0,1});
    // Dot gesture with projected axis, normalized against camera angle.
    float sx=dot(axis,right),sy=-dot(axis,up);
    float screenLength=sx*sx+sy*sy;
    if(screenLength<0.02f)return false;
    float metresPerPixel=2.f*distance*std::tan(46.f*PI/360.f)/float(std::max(1,height));
    float delta=(dx*sx+dy*sy)/screenLength*metresPerPixel;
    if(!std::isfinite(delta)||std::fabs(delta)<0.0000001f)return false;
    if(!dragCheckpointed){
        scene.checkpoint();
        dragCheckpointed=true;
    }
    return scene.transform(gizmoMode==1?0:2,activeAxis,delta);
}
bool Renderer::dragRotate(float dx,float dy){
    if(gizmoMode!=2||scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    const float rotation=(dx-dy)*0.008f;
    if(std::fabs(rotation)<0.000001f)return false;
    if(!dragCheckpointed){scene.checkpoint();dragCheckpointed=true;}
    return scene.transform(1,1,rotation);
}
void Renderer::endGizmo(){activeAxis=-1;dragCheckpointed=false;}
void Renderer::discardBuffers(){
    for(auto&o:scene.objects){
        if(o.gpuBuffer!=0)glDeleteBuffers(1,&o.gpuBuffer);
        o.gpuBuffer=0;o.dirty=true;
    }
}
bool Renderer::undoScene(){discardBuffers();return scene.undo();}
bool Renderer::redoScene(){discardBuffers();return scene.redo();}
bool Renderer::restoreScene(const std::string&str){
    // Scene::restore is transactional. Delete current GL buffers only on success.
    Scene temporary;
    if(!temporary.restore(str))return false;
    discardBuffers();
    return scene.restore(str);
}

int Renderer::pickFace(float x,float y){return pickAt(x,y,true);}
void Renderer::drawFaceOutline(const M&p,const M&v,Vec3 eye){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return;
    const Object&o=scene.objects[size_t(scene.selected)];
    if(o.mesh.faces.empty())return;
    const int face=std::clamp(o.selectedFace,0,int(o.mesh.faces.size())-1);
    const auto& ring=o.mesh.faces[size_t(face)];
    if(ring.size()<3)return;
    const Vec3 faceNormal=o.mesh.faceNormal(face);
    std::vector<float>positions;positions.reserve(ring.size()*12);
    for(size_t i=0;i<ring.size();i++){
        for(int id:{ring[i],ring[(i+1)%ring.size()]}){
            const Vec3 pt=o.mesh.vertices[size_t(id)]+faceNormal*0.003f;
            positions.insert(positions.end(),{pt.x,pt.y,pt.z,0.f,1.f,0.f});
        }
    }
    glBindBuffer(GL_ARRAY_BUFFER,faceBuffer);
    glBufferData(GL_ARRAY_BUFFER,GLsizeiptr(positions.size()*sizeof(float)),positions.data(),GL_DYNAMIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,6*sizeof(float),nullptr);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,6*sizeof(float),reinterpret_cast<void*>(3*sizeof(float)));
    glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);
    M world=objectMatrix(o),mvp=mul(p,mul(v,world));
    glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.data());
    glUniformMatrix4fv(modelLoc,1,GL_FALSE,world.data());
    glUniform3f(cameraLoc,eye.x,eye.y,eye.z);
    glUniform3f(colorLoc,0.14f,0.95f,0.79f);
    glUniform1i(flatLoc,1);
    glDisable(GL_DEPTH_TEST);
    glDrawArrays(GL_LINES,0,GLsizei(positions.size()/6));
    glEnable(GL_DEPTH_TEST);
    glUniform1i(flatLoc,0);
}

void Renderer::drawGizmo(const M&p,const M&v,Vec3 eye){
    if(gizmoMode==0||scene.selected<0||size_t(scene.selected)>=scene.objects.size())return;
    const Vec3 c=scene.objects[size_t(scene.selected)].position;
    const float length=distance*0.18f;
    const Vec3 axisDirs[3]={{1,0,0},{0,1,0},{0,0,1}};
    const Vec3 colors[3]={{0.98f,0.32f,0.34f},{0.36f,0.98f,0.49f},{0.30f,0.57f,0.99f}};
    M identityModel=identity(),mvp=mul(p,mul(v,identityModel));
    glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.data());
    glUniformMatrix4fv(modelLoc,1,GL_FALSE,identityModel.data());
    glUniform3f(cameraLoc,eye.x,eye.y,eye.z);
    glUniform1i(selectLoc,0);
    glUniform1i(flatLoc,1);
    glDisable(GL_DEPTH_TEST);
    glBindBuffer(GL_ARRAY_BUFFER,gizmoBuffer);
    glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);
    for(int i=0;i<3;i++){
        if(gizmoMode==2&&i!=1)continue;
        const Vec3 d=axisDirs[i];
        const Vec3 perp=(i==1?Vec3{1,0,0}:Vec3{0,1,0});
        const Vec3 endpoint=c+d*length;
        const Vec3 left=endpoint-d*(length*0.14f)+perp*(length*0.07f);
        const Vec3 right=endpoint-d*(length*0.14f)-perp*(length*0.07f);
        const Vec3 pts[6]={c,endpoint,left,endpoint,right,endpoint};
        std::vector<float> vertices;
        for(const Vec3& pt:pts){
            vertices.insert(vertices.end(),{pt.x,pt.y,pt.z,0.f,1.f,0.f});
        }
        glBufferData(GL_ARRAY_BUFFER,GLsizeiptr(vertices.size()*sizeof(float)),vertices.data(),GL_DYNAMIC_DRAW);
        glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,6*sizeof(float),nullptr);
        glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,6*sizeof(float),reinterpret_cast<void*>(3*sizeof(float)));
        const Vec3 col=colors[i];
        glUniform3f(colorLoc,col.x,col.y,col.z);
        glLineWidth(i==activeAxis?4.f:2.f);
        glDrawArrays(GL_LINES,0,6);
    }
    glLineWidth(1.f);
    glEnable(GL_DEPTH_TEST);
    glUniform1i(flatLoc,0);
}

namespace {
Vec3 transformPoint(const M&m,Vec3 p){
    return {m[0]*p.x+m[4]*p.y+m[8]*p.z+m[12],
            m[1]*p.x+m[5]*p.y+m[9]*p.z+m[13],
            m[2]*p.x+m[6]*p.y+m[10]*p.z+m[14]};
}
bool toScreen(const M&m,Vec3 p,int w,int h,float&x,float&y,float&z){
    const float clipX=m[0]*p.x+m[4]*p.y+m[8]*p.z+m[12];
    const float clipY=m[1]*p.x+m[5]*p.y+m[9]*p.z+m[13];
    const float clipZ=m[2]*p.x+m[6]*p.y+m[10]*p.z+m[14];
    const float clipW=m[3]*p.x+m[7]*p.y+m[11]*p.z+m[15];
    if(clipW<=0.001f)return false;
    z=clipZ/clipW;
    if(z< -1.f || z>1.f)return false;
    x=(clipX/clipW*0.5f+0.5f)*float(w);
    y=(0.5f-clipY/clipW*0.5f)*float(h);
    return true;
}
float segmentDistance(float x,float y,float ax,float ay,float bx,float by){
    const float dx=bx-ax,dy=by-ay;
    float t=((x-ax)*dx+(y-ay)*dy)/std::max(0.00001f,dx*dx+dy*dy);
    t=std::clamp(t,0.f,1.f);
    const float px=ax+dx*t,py=ay+dy*t;
    return std::hypot(x-px,y-py);
}
}
void Renderer::setElementMode(int mode){
    int next=std::clamp(mode,0,2);
    if(next==elementMode)return; // moving between panels must not erase selections
    elementMode=next;
    if(scene.selected<0)return;
    auto&o=scene.objects[size_t(scene.selected)];
    // Leaving edit mode hides points but preserves selection for later editing.
    if(next==1){o.selectedEdgeA=-1;o.selectedEdgeB=-1;}
    if(next==2)o.selectedVertex=-1;
}
int Renderer::pickElement(float x,float y,int mode){
    if((mode!=1&&mode!=2)||scene.selected<0 || size_t(scene.selected)>=scene.objects.size())return -1;
    auto&o=scene.objects[size_t(scene.selected)];
    const float aspect=float(width)/float(std::max(1,height));
    const Vec3 target=cameraTarget;
    const Vec3 eye=target+Vec3{distance*std::sin(yaw)*std::cos(pitch),
                               distance*std::sin(pitch),
                               distance*std::cos(yaw)*std::cos(pitch)};
    const M vp=mul(perspective(46.f,aspect),lookAt(eye,target));
    const M mvp=mul(vp,objectMatrix(o));
    int found=-1;
    float best=mode==1?25.f:20.f;
    float bestDepth=1.f;
    if(mode==1){
        if(o.mesh.vertices.size()>20000)return -1;
        for(size_t i=0;i<o.mesh.vertices.size();i++){
            float sx,sy,depth;
            if(!toScreen(mvp,o.mesh.vertices[i],width,height,sx,sy,depth))continue;
            float dist=std::hypot(x-sx,y-sy);
            if(dist+0.5f<best || (std::fabs(dist-best)<0.5f && depth<bestDepth)){
                found=int(i);best=dist;bestDepth=depth;
            }
        }
        o.selectedVertex=found;o.selectedEdgeA=-1;o.selectedEdgeB=-1;
    }else{
        const auto edges=uniqueEdges(o.mesh);
        if(edges.size()>25000)return -1;
        for(size_t i=0;i<edges.size();i++){
            float ax,ay,az,bx,by,bz;
            if(!toScreen(mvp,o.mesh.vertices[size_t(edges[i].first)],width,height,ax,ay,az)||
               !toScreen(mvp,o.mesh.vertices[size_t(edges[i].second)],width,height,bx,by,bz))continue;
            float dist=segmentDistance(x,y,ax,ay,bx,by);
            float depth=(az+bz)*0.5f;
            if(dist+0.5f<best || (std::fabs(dist-best)<0.5f && depth<bestDepth)){
                found=int(i);best=dist;bestDepth=depth;
            }
        }
        o.selectedVertex=-1;
        o.selectedEdgeA=found>=0?edges[size_t(found)].first:-1;
        o.selectedEdgeB=found>=0?edges[size_t(found)].second:-1;
    }
    return found;
}
bool Renderer::splitSelectedEdge(){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    auto&obj=scene.objects[size_t(scene.selected)];
    Mesh preview=obj.mesh;
    if(splitEdge(preview,obj.selectedEdgeA,obj.selectedEdgeB)<0)return false;
    scene.checkpoint();
    discardBuffers();
    const bool ok=scene.splitSelectedEdge();
    if(ok)elementMode=1;
    return ok;
}
bool Renderer::loopCutSelectedEdge(){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    auto&obj=scene.objects[size_t(scene.selected)];
    Mesh preview=obj.mesh;
    if(loopCut(preview,obj.selectedEdgeA,obj.selectedEdgeB)<0)return false;
    scene.checkpoint();
    discardBuffers();
    const bool ok=scene.loopCutSelectedEdge();
    if(ok)elementMode=1;
    return ok;
}

bool Renderer::bevelSelectedEdge(float metres,int segments){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    const auto&obj=scene.objects[size_t(scene.selected)];
    if(obj.selectedEdgeA<0||obj.selectedEdgeB<0)return false;
    // Dry run before adding an undo checkpoint or deleting GPU buffers.
    Scene preview;
    preview.objects=scene.objects;
    preview.selected=scene.selected;
    if(!preview.bevelSelectedEdge(metres,segments))return false;
    scene.checkpoint();
    discardBuffers();
    const bool result=scene.bevelSelectedEdge(metres,segments);
    if(result){elementMode=0;bridgeFaceA=-1;bridgeObject=-1;}
    return result;
}
bool Renderer::duplicateSelected(){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size()||scene.objects.size()>=64)return false;
    scene.checkpoint();
    if(!scene.duplicateSelected())return false;
    bridgeFaceA=-1;bridgeObject=-1;
    return true;
}
bool Renderer::deleteSelected(){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    scene.checkpoint();
    // Explicitly release every live buffer before erasing the selected object.
    discardBuffers();
    if(!scene.deleteSelected())return false;
    bridgeFaceA=-1;bridgeObject=-1;
    return true;
}
bool Renderer::markBridgeFace(){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size())return false;
    const auto&obj=scene.objects[size_t(scene.selected)];
    if(obj.selectedFace<0||size_t(obj.selectedFace)>=obj.mesh.faces.size()||
        obj.mesh.faces[size_t(obj.selectedFace)].size()!=4)return false;
    bridgeObject=scene.selected;
    bridgeFaceA=obj.selectedFace;
    return true;
}
bool Renderer::bridgeMarkedFaces(){
    if(scene.selected<0||scene.selected!=bridgeObject||bridgeFaceA<0)return false;
    const int faceB=scene.objects[size_t(scene.selected)].selectedFace;
    Scene preview;preview.objects=scene.objects;preview.selected=scene.selected;
    if(!preview.bridgeSelectedFaces(bridgeFaceA,faceB))return false;
    scene.checkpoint();
    discardBuffers();
    const bool result=scene.bridgeSelectedFaces(bridgeFaceA,faceB);
    if(result){
        bridgeFaceA=-1;bridgeObject=-1;elementMode=0;
    }
    return result;
}

bool Renderer::nudgeElement(int axis,float metres){
    if(scene.selected<0||size_t(scene.selected)>=scene.objects.size()||elementMode==0)return false;
    scene.checkpoint();
    return scene.moveComponent(elementMode,axis,metres);
}
void Renderer::drawElementOverlay(const M&p,const M&v,Vec3 eye){
    if(elementMode==0||scene.selected<0||size_t(scene.selected)>=scene.objects.size())return;
    const auto&o=scene.objects[size_t(scene.selected)];
    const M world=objectMatrix(o),mvp=mul(p,mul(v,world));
    glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.data());
    glUniformMatrix4fv(modelLoc,1,GL_FALSE,world.data());
    glUniform3f(cameraLoc,eye.x,eye.y,eye.z);
    glUniform1i(selectLoc,0);glUniform1i(flatLoc,1);
    glDisable(GL_DEPTH_TEST);
    glBindBuffer(GL_ARRAY_BUFFER,faceBuffer);
    glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);
    auto drawMesh=[&](const std::vector<Vec3>&pts,GLenum primitive,Vec3 color,float size){
        if(pts.empty())return;
        std::vector<float>values;
        values.reserve(pts.size()*6);
        for(Vec3 pt:pts)values.insert(values.end(),{pt.x,pt.y,pt.z,0.f,1.f,0.f});
        glBufferData(GL_ARRAY_BUFFER,GLsizeiptr(values.size()*sizeof(float)),values.data(),GL_DYNAMIC_DRAW);
        glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,6*sizeof(float),nullptr);
        glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,6*sizeof(float),reinterpret_cast<void*>(3*sizeof(float)));
        glUniform3f(colorLoc,color.x,color.y,color.z);
        glUniform1f(markerLoc,size);
        glDrawArrays(primitive,0,GLsizei(pts.size()));
    };
    if(elementMode==1){
        if(o.mesh.vertices.size()<3500){
            drawMesh(o.mesh.vertices,GL_POINTS,{0.23f,0.87f,0.98f},5.f);
        }
        if(o.selectedVertex>=0&&size_t(o.selectedVertex)<o.mesh.vertices.size()){
            drawMesh({o.mesh.vertices[size_t(o.selectedVertex)]},GL_POINTS,{1.f,0.69f,0.20f},17.f);
        }
    }else{
        auto edges=uniqueEdges(o.mesh);
        if(edges.size()<1600){
            std::vector<Vec3>lines;
            lines.reserve(edges.size()*2);
            for(auto e:edges){lines.push_back(o.mesh.vertices[size_t(e.first)]);lines.push_back(o.mesh.vertices[size_t(e.second)]);}
            drawMesh(lines,GL_LINES,{0.29f,0.70f,0.78f},1.f);
        }
        if(o.selectedEdgeA>=0&&o.selectedEdgeB>=0){
            drawMesh({o.mesh.vertices[size_t(o.selectedEdgeA)],o.mesh.vertices[size_t(o.selectedEdgeB)]},
                    GL_LINES,{1.f,0.72f,0.19f},1.f);
        }
    }
    glUniform1f(markerLoc,5.f);
    glEnable(GL_DEPTH_TEST);
    glUniform1i(flatLoc,0);
}

void Renderer::draw(){
 glViewport(0,0,width,height);glClearColor(0.11f,0.18f,0.25f,1);
 glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
 if(program==0)return;
 glUseProgram(program);
 glUniform1f(markerLoc,5.f);
 M projection=perspective(46.f,float(width)/float(height));
 Vec3 target=cameraTarget,eye=target+Vec3{
  distance*std::sin(yaw)*std::cos(pitch),
  distance*std::sin(pitch),
  distance*std::cos(yaw)*std::cos(pitch)};
 M view=lookAt(eye,target);
 drawGrid(projection,view,eye);
 for(size_t i=0;i<scene.objects.size();i++)drawItem(scene.objects[i],int(i),projection,view,eye);
 drawFaceOutline(projection,view,eye);
 drawGizmo(projection,view,eye);
 drawElementOverlay(projection,view,eye);
 glBindBuffer(GL_ARRAY_BUFFER,0);
 GLenum glError=glGetError();
 if(glError!=GL_NO_ERROR){
    state="GPU DRAW ERROR: "+std::to_string(int(glError));
 } else {
    state="GPU DRAW OK: "+std::to_string(scene.objects.size())+" objects";
 }
}
} // namespace zamer
