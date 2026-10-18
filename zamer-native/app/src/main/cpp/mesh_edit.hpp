#pragma once
#include "mesh_core.hpp"
#include <utility>
#include <vector>
namespace zamer {
using Edge = std::pair<int,int>;
/// Unique undirected edges. Shared polygon vertices are retained by topology.
std::vector<Edge> uniqueEdges(const Mesh& mesh);
bool edgeExists(const Mesh& mesh,int a,int b);
// Divide an existing edge in every incident polygon. Result is the new shared
// vertex index; -1 for invalid mesh/edge. Topology remains watertight.
int splitEdge(Mesh& mesh,int a,int b,float fraction=0.5f);
// Inserts a complete closed edge loop through adjacent quad faces.
// Does not mutate on failure or in non-quad regions. Returns seed midpoint ID.
int loopCut(Mesh& mesh,int a,int b);
}
