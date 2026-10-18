#pragma once
#include "mesh_core.hpp"
namespace zamer {
/// World XYZ manipulator axis index. -1 indicates miss.
int pickGizmoAxis(Vec3 rayOrigin,Vec3 rayDirection,Vec3 center,float length,float radius);
}
