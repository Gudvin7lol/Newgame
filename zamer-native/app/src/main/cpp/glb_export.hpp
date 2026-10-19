#pragma once
#include "mesh_core.hpp"
#include <cstdint>
#include <vector>
namespace zamer {
/// GLB 2.0 geometry + PBR export. Coordinates are metres and Y-up.
std::vector<uint8_t> exportGLB(const Scene& scene);
}
