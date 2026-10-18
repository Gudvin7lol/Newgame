#pragma once
#include "mesh_core.hpp"
namespace zamer {
/// Return nearest mesh hit for a world-space ray, or -1. Pure C++, independently testable.
struct SurfaceHit {
    int object=-1;
    int face=-1;
    float distance=0.f;
};
SurfaceHit pickSurface(const Scene& scene,Vec3 origin,Vec3 direction);
int pickObject(const Scene& scene, Vec3 origin, Vec3 direction);
}
