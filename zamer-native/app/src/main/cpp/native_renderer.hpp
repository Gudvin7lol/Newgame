#pragma once
#include "mesh_core.hpp"
#include <GLES3/gl3.h>
#include <array>
#include <string>
namespace zamer {
class Renderer {
public:
 Scene scene;
 void initGl();void resize(int w,int h);void draw();
 void orbit(float x,float y);void zoom(float factor);
 int pickFace(float x,float y);
 void setElementMode(int mode);
 int pickElement(float x,float y,int mode);
 bool nudgeElement(int axis,float metres);
 int pick(float x,float y);
 void setGizmoMode(int mode);
 int beginGizmo(float x,float y);
 bool dragGizmo(float dx,float dy);
 bool dragRotate(float dx,float dy);
 void endGizmo();
 bool undoScene();bool redoScene();bool restoreScene(const std::string&);
 void discardBuffers();
 std::string graphicsStatus() const;
 float yaw=0.45f,pitch=0.23f,distance=5.5f;
private:
 int width=1,height=1;
 std::string state="GPU: не инициализирован";
 GLuint program=0,gridBuffer=0,faceBuffer=0,gizmoBuffer=0;
 int gizmoMode=0,activeAxis=-1;
 int elementMode=0;
 bool dragCheckpointed=false;
 GLint mvpLoc=-1,modelLoc=-1,cameraLoc=-1,colorLoc=-1,metalLoc=-1,roughLoc=-1,selectLoc=-1,flatLoc=-1,markerLoc=-1;
 GLuint compile(GLenum kind,const char*src);
 void drawGrid(const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
 void drawItem(Object&obj,int id,const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
 void drawFaceOutline(const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
 void drawGizmo(const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
 void drawElementOverlay(const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
 int pickAt(float x,float y,bool face);
};
}
