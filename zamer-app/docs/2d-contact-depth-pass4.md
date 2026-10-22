# Contact depth in the 2D plan

The 2D painter now grounds floor furniture with soft contact shading derived
from each sprite's alpha. Furniture artwork, saved dimensions, rotations and
the living-room arrangement stay unchanged. Rugs use a much tighter and weaker
contact mask. Elevated objects do not receive floor contact shading.

Masks are generated once when the top-view assets load, at a maximum physical
footprint edge of 256 pixels, with an 8 MiB decoded cache limit. The eight
detailed furniture sprites have priority. Their existing 16 MiB foreground
texture budget remains unchanged. Masks are isolated from shared atlases before
filtering, so neighboring catalog sprites cannot bleed into a shadow. Pan and
zoom only draw the cached images.

Wall contact shading is clipped to room interiors and cut at doors and windows.
A narrow fixed-direction bevel gives the graphite wall cuts a readable edge.
The effect respects wall and project-layer visibility. The painter's optional
`showDepth` parameter permits comparison against the flat rendering without
changing project data. No lighting controls or floor-material changes are added.

Validation covers alpha silhouettes and atlas isolation, the weaker rug mask,
clear doorways, unchanged exterior and distant floor pixels, hidden walls,
decoded-memory limits, physical dimensions at 0 and 90 degrees, wall joins,
stacking, and CAD geometry. The focused preview workflow renders the same
living room through `CadPlanPainterV3` for visual review.
