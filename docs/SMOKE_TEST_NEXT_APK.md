# Zamer — Smoke Test for Next APK

Run this checklist on a real Android device before handing the build to the tester.

- Launch app cold.
- Open existing project.
- Close/reopen app and confirm project persists.
- Add/edit a room dimension.
- Add a door and a window; verify distances to corners.
- Run project control; verify reported issues match project data.
- Open 3D five times in a row without restarting the app.
- Rotate/orbit camera and enter Walk mode.
- Toggle section/hide controls.
- Verify floor and wall finishes remain visible.
- Add furniture from Equipment.
- Move/rotate/delete the added object.
- Verify the object does not sink below floor or disappear.
- Open Unfoldings and switch Wall A/B/C/D.
- Verify openings/electrics positions and wall area.
- Add a photo/note and reopen the project.
- Build documentation PDF, preview it and share/export it.
- Confirm no visible control is a dead button unless clearly disabled.

A build fails the smoke test if any critical step above crashes, loses data, shows fake success state, or silently does nothing.
