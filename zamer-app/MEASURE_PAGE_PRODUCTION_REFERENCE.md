# ZAMER — MEASURE PAGE PRODUCTION REFERENCE

Status: mandatory visual/interaction reference for page 2 «Замер».

This document narrows UI KIT 01 to the measurement workspace. It does not replace geometry/business logic.

## 1. Mobile hierarchy

Target portrait reference: 375×812.

1. Project header — 56 px.
   - back action;
   - project name is primary text;
   - floor is secondary text;
   - mode badge `ЗАМЕР 2D`;
   - check / undo / redo / project actions.
2. Measure view strip — 54 px.
   - compact plan status;
   - `2D / 3D / Фото` in one row;
   - 3D and Photo open dedicated work views and must return to Measure without changing the selected master section.
3. Canvas — receives all remaining height.
4. Measure sub-navigation — compact only where it is functionally required.
5. Master project navigation — `Главная / Замер / 3D / Оснащение / Развёртки`.

## 2. Canvas tools

Final target from the approved concept:

- left vertical tool rail: `Стены / Проёмы / Объекты / Размеры / Текст / Слои`;
- minimum touch target 48×48;
- selected tool uses Beige surface + Navy icon/text;
- inactive tools use dark surfaces + Gray300;
- tool rail floats above the canvas and must not reduce the plan viewport width more than necessary;
- zoom/pan/center/snap/layer visibility remain available as compact canvas actions.

The existing PlanEditor geometry code is preserved during migration. UI migration must not remove free partitions, arcs, demolition, node editing, openings, dimensions, snapping or evidence/source records.

## 3. Context controls

The old full-width multi-row tool palette is transitional.

Final context controls should appear only for the active tool:

- Wall: type, thickness, height/material, project layer, snap mode;
- Opening: door/window, width/height, offset from both corners, sill/swing;
- Dimension: source and recorded/calculated state;
- Layer: Existing / Demolition / New;
- Geometry check: contour, mismatches, acute angles, intersections, diagonals.

Context controls use a compact bottom panel/sheet and must not permanently occupy a large fraction of the canvas.

## 4. Visual rules

- background follows UI KIT 01 dark production surfaces;
- Beige is the active/accent state;
- no cyan/blue legacy selected state except semantic Info;
- thin outlines, no heavy Material shadows;
- all pressable controls use tactile press feedback;
- typography follows `ZamerTypography`;
- dimensions remain visually stronger than secondary helper text.

## 5. Navigation contract

- `2D` stays in the Measure page;
- `3D` launched from the view selector is a temporary dedicated preview and returns to Measure;
- `Фото` opens Photo Studio and returns to Measure;
- selecting the master `3D` section is a separate action and may keep the persistent 3D workspace;
- back returns to the previous project/floor screen;
- Home returns to the main app Home.

## 6. Migration order

1. Production shell/header/view selector.
2. Tactile navigation and readable sheets.
3. Left measure tool rail mapped to existing PlanEditor modes.
4. Replace legacy bottom mode palette with contextual properties.
5. Geometry-check presentation.
6. Device pass on 360–430 px widths.

Rule: functionality wins over cosmetic replacement. A new visual control is not considered implemented until it drives the existing geometry operation safely.
