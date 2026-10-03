# Zamer — Functional Stability Priority

## Decision

The current visual direction is accepted as the working baseline. From this point, visual polishing is secondary to making every visible control, screen and workflow functional, predictable and stable.

## Priority order

1. **Critical navigation and state**
   - Every visible button, tab, card, back action and settings action must either work or be clearly disabled.
   - Project state must persist across app restarts.
   - Navigation must not reset or lose the current project/context.

2. **Measurement workflow**
   - Create/edit/delete rooms, walls, openings and dimensions.
   - Correct wall geometry, offsets, diagonals and closure checks.
   - Store dimension source, author/date and calculated/manual status.
   - Project validation must point to the exact problem on plan.

3. **3D stability**
   - No crashes entering 3D.
   - No disappearing furniture/materials, flicker or z-fighting.
   - Correct floor/wall materials and object transforms.
   - Stable camera, overview, walk mode, section and hide controls.
   - Objects must stay on floor and remain attached to expected surfaces.

4. **Equipment catalog**
   - Search and filters must work.
   - Add-to-project must insert the selected object into the active room.
   - Move/rotate/delete/duplicate/select objects in 2D/3D.
   - Object dimensions and category metadata must be real, not decorative placeholders.

5. **Materials / finishes**
   - Applying wall/floor/ceiling finish must update the model and persist.
   - Correct scale and UV/tiling.
   - Openings and thresholds must not lose floor material.
   - Material quantities must be calculated from real geometry.

6. **Unfoldings**
   - Wall A/B/C/D switching must correspond to actual room walls.
   - Doors/windows/electrics must appear at measured positions.
   - Wall, floor and ceiling areas must be calculated from geometry.
   - Plinths, outlets and switches must be editable and counted.

7. **Photos and notes**
   - Camera/file import must work.
   - Photos/notes must bind to project, room, wall/object and persist.
   - Filtering by media type and project context must work.

8. **Documentation / PDF**
   - 2D plan, 3D views, unfoldings and specification must be generated from project data.
   - PDF package must actually build, preview and share/export.
   - No placeholder statuses such as “ready” unless the underlying document exists.

9. **Profile / sync / backup**
   - Any sync/backup/device/subscription UI that is not connected to a real backend must not pretend to be live.
   - Until backend functionality exists, show local-only state or an explicit “not connected” state.

## Release gate for next APK

The next APK should only be marked test-ready when:

- app launches and reopens the active project without data loss;
- all primary navigation works;
- measurement editing works end-to-end;
- 3D opens repeatedly without crash and keeps objects/materials visible;
- equipment can be added, selected, moved and removed;
- unfoldings use actual project geometry;
- photo attachment and persistence work;
- project validation reports real data;
- PDF export creates a real file;
- automated tests pass and a manual smoke test checklist is completed.

## Product rule

**No new decorative screens until the visible functionality on the existing screens works end-to-end.**
