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
 int pick(float x,float y);
 std::string graphicsStatus() const;
 float yaw=0.45f,pitch=0.23f,distance=5.5f;
private:
 int width=1,height=1;
 std::string state="GPU: не инициализирован";
 GLuint program=0,gridBuffer=0;
 GLint mvpLoc=-1,modelLoc=-1,cameraLoc=-1,colorLoc=-1,metalLoc=-1,roughLoc=-1,selectLoc=-1,flatLoc=-1;
 GLuint compile(GLenum kind,const char*src);
 void drawGrid(const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
 void drawItem(Object&obj,int id,const std::array<float,16>&proj,const std::array<float,16>&view,Vec3 eye);
};
}
