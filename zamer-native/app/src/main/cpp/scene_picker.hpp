#pragma once
#include "mesh_core.hpp"
namespace zamer {
/// Return nearest mesh hit for a world-space ray, or -1. Pure C++, independently testable.
int pickObject(const Scene& scene, Vec3 origin, Vec3 direction);
}
