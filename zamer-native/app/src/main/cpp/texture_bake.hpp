#pragma once
#include "mesh_core.hpp"
#include <array>
#include <cstdint>
#include <vector>
namespace zamer {
// Each 128x128 texture is RGBA8 in standard PNG. Metal-rough map uses the
// glTF 2.0 channel convention: roughness in G, metallic in B.
using BakedMaps=std::array<std::vector<uint8_t>,3>;
BakedMaps bakePbrMaps(const Object& object,int resolution=128);
}
