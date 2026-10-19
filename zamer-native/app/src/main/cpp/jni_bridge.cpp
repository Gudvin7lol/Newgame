#include "native_renderer.hpp"
#include "glb_export.hpp"
#include <jni.h>
#include <string>
#include <algorithm>
#include <cmath>
#include <cstdio>
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
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_setElementMode(JNIEnv*,jobject,jlong p,jint mode){if(p)engine(p)->setElementMode(int(mode));}
JNIEXPORT jint JNICALL Java_com_zamer_studio_Native_pickElement(JNIEnv*,jobject,jlong p,jfloat x,jfloat y,jint mode){return p?engine(p)->pickElement(x,y,int(mode)):-1;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_nudgeElement(JNIEnv*,jobject,jlong p,jint axis,jfloat value){return p&&engine(p)->nudgeElement(int(axis),float(value))?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_splitEdge(JNIEnv*,jobject,jlong p){return p&&engine(p)->splitSelectedEdge()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_loopCut(JNIEnv*,jobject,jlong p){return p&&engine(p)->loopCutSelectedEdge()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_bevelEdge(JNIEnv*,jobject,jlong p,jfloat metres,jint segments){return p&&engine(p)->bevelSelectedEdge(float(metres),int(segments))?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_duplicate(JNIEnv*,jobject,jlong p){return p&&engine(p)->duplicateSelected()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_deleteSelected(JNIEnv*,jobject,jlong p){return p&&engine(p)->deleteSelected()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_setPbr(JNIEnv*,jobject,jlong p,jint rgb,jfloat metal,jfloat rough){
    if(!p)return JNI_FALSE;
    auto*r=engine(p);
    if(r->scene.selected<0||size_t(r->scene.selected)>=r->scene.objects.size())return JNI_FALSE;
    const unsigned int raw=static_cast<unsigned int>(rgb);
    const zamer::Vec3 color={float((raw>>16)&255u)/255.f,float((raw>>8)&255u)/255.f,float(raw&255u)/255.f};
    return r->scene.setCustomMaterial(color,float(metal),float(rough))?JNI_TRUE:JNI_FALSE;
}
JNIEXPORT jbyteArray JNICALL Java_com_zamer_studio_Native_exportGlb(JNIEnv*env,jobject,jlong p){
    if(!p)return env->NewByteArray(0);
    auto buffer=zamer::exportGLB(engine(p)->scene);
    if(buffer.empty()||buffer.size()>32u*1024u*1024u)return env->NewByteArray(0);
    jbyteArray result=env->NewByteArray(jsize(buffer.size()));
    if(result)env->SetByteArrayRegion(result,0,jsize(buffer.size()),reinterpret_cast<const jbyte*>(buffer.data()));
    return result;
}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_setPattern(JNIEnv*,jobject,jlong p,jint pattern,jfloat uvScale){
    if(!p)return JNI_FALSE;
    return engine(p)->scene.setPattern(int(pattern),float(uvScale))?JNI_TRUE:JNI_FALSE;
}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_setSmooth(JNIEnv*,jobject,jlong p,jboolean smooth){
    return p&&engine(p)->scene.setSmoothShading(smooth==JNI_TRUE)?JNI_TRUE:JNI_FALSE;
}
JNIEXPORT jstring JNICALL Java_com_zamer_studio_Native_materialState(JNIEnv*env,jobject,jlong p){
    if(!p)return env->NewStringUTF("");
    const auto&r=engine(p)->scene;
    if(r.selected<0||size_t(r.selected)>=r.objects.size())return env->NewStringUTF("");
    const auto&o=r.objects[size_t(r.selected)];
    auto c=[](float f)->unsigned{return unsigned(std::round(std::clamp(f,0.f,1.f)*255.f));};
    char buf[120];
    std::snprintf(buf,sizeof(buf),"%02X%02X%02X|%.4f|%.4f|%d|%d|%d|%.4f",
       c(o.pbr.color.x),c(o.pbr.color.y),c(o.pbr.color.z),
       double(o.pbr.metallic),double(o.pbr.roughness),
       int(o.smoothShading),int(o.customMaterial),int(o.pattern),double(o.uvScale));
    return env->NewStringUTF(buf);
}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_markBridgeFace(JNIEnv*,jobject,jlong p){return p&&engine(p)->markBridgeFace()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_bridgeFaces(JNIEnv*,jobject,jlong p){return p&&engine(p)->bridgeMarkedFaces()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_setGizmoMode(JNIEnv*,jobject,jlong p,jint mode){if(p)engine(p)->setGizmoMode(mode);}
JNIEXPORT jint JNICALL Java_com_zamer_studio_Native_beginGizmo(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){return p?engine(p)->beginGizmo(x,y):-1;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_dragGizmo(JNIEnv*,jobject,jlong p,jfloat dx,jfloat dy){return p&&engine(p)->dragGizmo(dx,dy)?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_dragRotate(JNIEnv*,jobject,jlong p,jfloat dx,jfloat dy){return p&&engine(p)->dragRotate(dx,dy)?JNI_TRUE:JNI_FALSE;}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_endGizmo(JNIEnv*,jobject,jlong p){if(p)engine(p)->endGizmo();}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_undo(JNIEnv*,jobject,jlong p){return p&&engine(p)->undoScene()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_redo(JNIEnv*,jobject,jlong p){return p&&engine(p)->redoScene()?JNI_TRUE:JNI_FALSE;}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_checkpoint(JNIEnv*,jobject,jlong p){if(p)engine(p)->scene.checkpoint();}
JNIEXPORT void JNICALL Java_com_zamer_studio_Native_pan(JNIEnv*,jobject,jlong p,jfloat x,jfloat y){if(p)engine(p)->pan(float(x),float(y));}
JNIEXPORT jboolean JNICALL Java_com_zamer_studio_Native_focusSelected(JNIEnv*,jobject,jlong p){return p&&engine(p)->focusSelected()?JNI_TRUE:JNI_FALSE;}
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
