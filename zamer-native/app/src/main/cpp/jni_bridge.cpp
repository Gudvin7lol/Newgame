#include "native_renderer.hpp"
#include <jni.h>
#include <string>
using zamer::Renderer;
static Renderer* engine(jlong p){return reinterpret_cast<Renderer*>(p);}
extern "C" {
JNIEXPORT jlong JNICALL Java_com_zamer_studio_Native_create(JNIEnv*,jobject){return reinterpret_cast<jlong>(new Renderer());}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_destroy(JNIEnv*,jobject,jlong p){delete engine(p);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_initGl(JNIEnv*,jobject,jlong p){if(p)engine(p)->initGl();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_resize(JNIEnv*,jobject,jlong p,jint w,jint h){if(p)engine(p)->resize(int(w),int(h));}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_draw(JNIEnv*,jobject,jlong p){if(p)engine(p)->draw();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_orbit(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){if(p)engine(p)->orbit(x,y);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_zoom(JNIEnv*,jobject,jlong p,jfloat s){if(p)engine(p)->zoom(s);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_add(JNIEnv*,jobject,jlong p,jint type){if(p)engine(p)->scene.add(int(type));}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_selectNext(JNIEnv*,jobject,jlong p){if(p)engine(p)->scene.selectNext();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_move(JNIEnv*,jobject,jlong p,jfloat x,jfloat z){if(p)engine(p)->scene.move(x,z);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_extrude(JNIEnv*,jobject,jlong p,jfloat m){if(p)engine(p)->scene.extrude(m);}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_subdivide(JNIEnv*,jobject,jlong p){if(p)engine(p)->scene.subdivide();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_material(JNIEnv*,jobject,jlong p,jint id){if(p)engine(p)->scene.setMaterial(int(id));}
JNIEXPORT jstring JNICALL Java_com_zamer_studio_Native_sceneInfo(JNIEnv*e,jobject,jlong p){
 std::string s=p?engine(p)->scene.describe():"Engine not initialized";return e->NewStringUTF(s.c_str());
}
JNIEXPORT jstring JNICALL Java_com_zamer_studio_Native_serialize(JNIEnv*e,jobject,jlong p){
 std::string s=p?engine(p)->scene.serialize():"";return e->NewStringUTF(s.c_str());
}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_restore(JNIEnv*e,jobject,jlong p,jstring content){
 if(!p||!content)return JNI_FALSE;
 const char*data=e->GetStringUTFChars(content,nullptr);if(!data)return JNI_FALSE;
 bool ok=engine(p)->scene.restore(data);e->ReleaseStringUTFChars(content,data);
 return ok?JNI_TRUE:JNI_FALSE;
}
}
