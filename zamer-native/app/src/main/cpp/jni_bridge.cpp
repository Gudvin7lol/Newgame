#include "native_renderer.hpp"
#include <jni.h>
#include <string>
using zamer::Renderer;
static Renderer* engine(jlong p){return reinterpret_cast<Renderer*>(p);}
extern "C" {
JNIEXPORT jlong JNICALL Java_com_zamer_studio_Native_create(JNIEnv*,jobject){
 auto* renderer=new Renderer();
 renderer->scene.add(0);
 return reinterpret_cast<jlong>(renderer);
}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_destroy(JNIEnv*,jobject,jlong p){delete engine(p);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_initGl(JNIEnv*,jobject,jlong p){if(p)engine(p)->initGl();}
JNIEXPORT jstring JNICALL Java_com_zamer_studio_Native_graphicsStatus(JNIEnv*e,jobject,jlong p){
 std::string s=p?engine(p)->graphicsStatus():"GPU: нет ядра";
 return e->NewStringUTF(s.c_str());
}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_resize(JNIEnv*,jobject,jlong p,jint w,jint h){if(p)engine(p)->resize(int(w),int(h));}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_draw(JNIEnv*,jobject,jlong p){if(p)engine(p)->draw();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_orbit(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){if(p)engine(p)->orbit(x,y);}
JNIEXPORT jint JNICALL Java_com_zamer_studio_Native_pick(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){return p?engine(p)->pick(x,y):-1;}
JNIEXPORT jint JNICALL Java_com_zamer_studio_Native_pickFace(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){return p?engine(p)->pickFace(x,y):-1;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_transform(JNIEnv*,jobject,jlong p,jint mode,jint axis,jfloat amount){if(!p)return JNI_FALSE;engine(p)->scene.checkpoint();return engine(p)->scene.transform(mode,axis,amount)?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_inset(JNIEnv*,jobject,jlong p,jfloat fraction){if(!p)return JNI_FALSE;engine(p)->scene.checkpoint();return engine(p)->scene.inset(fraction)?JNI_TRUE:JNI_FALSE;}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_setGizmoMode(JNIEnv*,jobject,jlong p,jint mode){if(p)engine(p)->setGizmoMode(mode);}
JNIEXPORT jint JNICALL Java_com_zamer_studio_Native_beginGizmo(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){return p?engine(p)->beginGizmo(x,y):-1;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_dragGizmo(JNIEnv*,jobject,jlong p,jfloat dx,jfloat dy){return p&&engine(p)->dragGizmo(dx,dy)?JNI_TRUE:JNI_FALSE;}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_endGizmo(JNIEnv*,jobject,jlong p){if(p)engine(p)->endGizmo();}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_undo(JNIEnv*,jobject,jlong p){return p&&engine(p)->undoScene()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_redo(JNIEnv*,jobject,jlong p){return p&&engine(p)->redoScene()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_checkpoint(JNIEnv*,jobject,jlong p){if(p)engine(p)->scene.checkpoint();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_zoom(JNIEnv*,jobject,jlong p,jfloat s){if(p)engine(p)->zoom(s);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_add(JNIEnv*,jobject,jlong p,jint type){if(p){engine(p)->scene.checkpoint();engine(p)->scene.add(int(type));}}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_selectNext(JNIEnv*,jobject,jlong p){if(p)engine(p)->scene.selectNext();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_move(JNIEnv*,jobject,jlong p,jfloat x,jfloat z){if(p)engine(p)->scene.move(x,z);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_extrude(JNIEnv*,jobject,jlong p,jfloat m){if(p){engine(p)->scene.checkpoint();engine(p)->scene.extrude(m);}}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_subdivide(JNIEnv*,jobject,jlong p){if(p){engine(p)->scene.checkpoint();engine(p)->scene.subdivide();}}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_material(JNIEnv*,jobject,jlong p,jint id){if(p){engine(p)->scene.checkpoint();engine(p)->scene.setMaterial(int(id));}}
JNIEXPORT jstring JNICALL Java_com_zamer_studio_Native_sceneInfo(JNIEnv*e,jobject,jlong p){
 std::string s=p?engine(p)->scene.describe():"Engine not initialized";return e->NewStringUTF(s.c_str());
}
JNIEXPORT jstring JNICALL Java_com_zamer_studio_Native_serialize(JNIEnv*e,jobject,jlong p){
 std::string s=p?engine(p)->scene.serialize():"";return e->NewStringUTF(s.c_str());
}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_restore(JNIEnv*e,jobject,jlong p,jstring content){
 if(!p||!content)return JNI_FALSE;
 const char*data=e->GetStringUTFChars(content,nullptr);if(!data)return JNI_FALSE;
 bool ok=engine(p)->restoreScene(data);e->ReleaseStringUTFChars(content,data);
 return ok?JNI_TRUE:JNI_FALSE;
}
}
