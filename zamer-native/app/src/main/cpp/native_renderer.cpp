#include "native_renderer.hpp"
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
struct Finish{Vec3 c;float metal,rough;};
const std::array<Finish,5> finishes={{
 {{0.62f,0.55f,0.46f},0.0f,0.85f},
 {{0.25f,0.34f,0.42f},0.0f,0.67f},
 {{0.64f,0.36f,0.21f},0.0f,0.65f},
 {{0.68f,0.73f,0.75f},0.82f,0.27f},
 {{0.39f,0.50f,0.36f},0.0f,0.77f}
}};
const char* vShader=R"shader(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNormal;
uniform mat4 mvp,model;
out vec3 nWorld,pWorld;
void main(){
 vec4 w=model*vec4(aPos,1.0);
 pWorld=w.xyz;
 nWorld=normalize(transpose(inverse(mat3(model)))*aNormal);
 gl_Position=mvp*vec4(aPos,1.0);
})shader";
const char* fShader=R"shader(#version 300 es
precision highp float;
in vec3 nWorld,pWorld;
uniform vec3 eyePos,baseColor;
uniform float metallic,roughness;
uniform int isSelected,flat;
out vec4 outColor;
const float PI=3.14159265;
void main(){
 if(flat==1){outColor=vec4(baseColor,1.0);return;}
 vec3 n=normalize(nWorld),v=normalize(eyePos-pWorld);
 vec3 l=normalize(vec3(-0.4,0.85,0.44)),h=normalize(v+l);
 float nl=max(dot(n,l),0.0),nv=max(dot(n,v),0.0);
 vec3 a=pow(baseColor,vec3(2.2)),f0=mix(vec3(0.04),a,metallic);
 float r=max(roughness,0.07),rr=r*r,rr2=rr*rr;
 float nh=max(dot(n,h),0.0),den=nh*nh*(rr2-1.0)+1.0;
 float D=rr2/max(PI*den*den,0.00001);
 float k=pow(r+1.0,2.0)/8.0;
 float G=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
 vec3 F=f0+(1.0-f0)*pow(1.0-max(dot(v,h),0.0),5.0);
 vec3 spec=D*G*F/max(4.0*nv*nl,0.0001);
 vec3 diff=(1.0-F)*(1.0-metallic)*a/PI;
 vec3 x=(diff+spec)*vec3(3.4,3.5,3.65)*nl+a*0.20;
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
void Renderer::initGl(){
 GLuint vertex=compile(GL_VERTEX_SHADER,vShader),fragment=compile(GL_FRAGMENT_SHADER,fShader);
 if(!vertex||!fragment)return;
 program=glCreateProgram();glAttachShader(program,vertex);glAttachShader(program,fragment);
 glLinkProgram(program);glDeleteShader(vertex);glDeleteShader(fragment);
 GLint ok=GL_FALSE;glGetProgramiv(program,GL_LINK_STATUS,&ok);
 if(ok==GL_FALSE){__android_log_print(ANDROID_LOG_ERROR,"ZamerEngine","Program link error");
  glDeleteProgram(program);program=0;return;}
 mvpLoc=glGetUniformLocation(program,"mvp");modelLoc=glGetUniformLocation(program,"model");
 cameraLoc=glGetUniformLocation(program,"eyePos");colorLoc=glGetUniformLocation(program,"baseColor");
 metalLoc=glGetUniformLocation(program,"metallic");roughLoc=glGetUniformLocation(program,"roughness");
 selectLoc=glGetUniformLocation(program,"isSelected");flatLoc=glGetUniformLocation(program,"flat");
 glGenBuffers(1,&gridBuffer);
 for(auto&o:scene.objects){o.gpuBuffer=0;o.dirty=true;}
 glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);glDisable(GL_CULL_FACE);
}
void Renderer::resize(int w,int h){width=std::max(1,w);height=std::max(1,h);glViewport(0,0,width,height);}
void Renderer::orbit(float dx,float dy){yaw-=dx;pitch=std::clamp(pitch-dy,-1.25f,1.25f);}
void Renderer::zoom(float factor){distance=std::clamp(distance/std::clamp(factor,0.5f,2.f),1.6f,15.f);}
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
  auto vertices=o.mesh.interleavedTriangles();
  o.gpuVertices=int(vertices.size()/6);
  glBufferData(GL_ARRAY_BUFFER,GLsizeiptr(vertices.size()*sizeof(float)),vertices.data(),GL_DYNAMIC_DRAW);
  o.dirty=false;
 }
 glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,6*sizeof(float),nullptr);
 glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,6*sizeof(float),reinterpret_cast<void*>(3*sizeof(float)));
 glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);
 M model=objectMatrix(o),mvp=mul(p,mul(v,model));
 glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.data());glUniformMatrix4fv(modelLoc,1,GL_FALSE,model.data());
 glUniform3f(cameraLoc,eye.x,eye.y,eye.z);
 auto m=finishes[size_t(std::clamp(o.material,0,4))];
 glUniform3f(colorLoc,m.c.x,m.c.y,m.c.z);
 glUniform1f(metalLoc,m.metal);glUniform1f(roughLoc,m.rough);
 glUniform1i(selectLoc,index==scene.selected?1:0);
 glDrawArrays(GL_TRIANGLES,0,o.gpuVertices);
}
void Renderer::draw(){
 glViewport(0,0,width,height);glClearColor(0.045f,0.067f,0.105f,1);
 glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
 if(program==0)return;
 glUseProgram(program);
 M projection=perspective(46.f,float(width)/float(height));
 Vec3 target{0,0.8f,0},eye=target+Vec3{
  distance*std::sin(yaw)*std::cos(pitch),
  distance*std::sin(pitch),
  distance*std::cos(yaw)*std::cos(pitch)};
 M view=lookAt(eye,target);
 drawGrid(projection,view,eye);
 for(size_t i=0;i<scene.objects.size();i++)drawItem(scene.objects[i],int(i),projection,view,eye);
 glBindBuffer(GL_ARRAY_BUFFER,0);
}
} // namespace zamer
