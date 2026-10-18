#pragma once
#include "mesh_core.hpp"
#include <utility>
#include <vector>
namespace zamer {
using Edge = std::pair<int,int>;
/// Unique undirected edges. Shared polygon vertices are retained by topology.
std::vector<Edge> uniqueEdges(const Mesh& mesh);
bool edgeExists(const Mesh& mesh,int a,int b);
}
