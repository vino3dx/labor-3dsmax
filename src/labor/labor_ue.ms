/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ue.ms
   module  : ue export prepare / UE 导出准备
   desc    : pivot modes / reset xform / max<->ue coordinate / duplicate name check / illegal name check / pivot-on-bottom check
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     everything needed to get a clean Max -> Unreal Engine asset,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_pivot_process, labor_xform_issues, labor_reset_xform_node, labor_max_to_ue, labor_num_str, labor_build_coord_rows, labor_coord_display_lines, labor_rows_to_string, labor_duplicate_names, labor_fix_duplicate_names, labor_bad_names, labor_fix_bad_names, labor_pivot_issues

fn labor_pivot_process objs mode snap_ground =
(
    local cnt = 0
    for o in objs where (labor_valid_geom o) do
    (
        local bb   = labor_node_bounds o
        local bmin = bb[1]
        local bmax = bb[2]
        local np   = case mode of
        (
            1 : [(bmin.x + bmax.x) / 2.0, (bmin.y + bmax.y) / 2.0, bmin.z]
            2 : [o.pos.x, o.pos.y, bmin.z]
            3 : [bmin.x, bmin.y, bmin.z]
            4 : [(bmin.x + bmax.x) / 2.0, (bmin.y + bmax.y) / 2.0, (bmin.z + bmax.z) / 2.0]
            5 : [(bmin.x + bmax.x) / 2.0, (bmin.y + bmax.y) / 2.0, bmin.z]
            default : [(bmin.x + bmax.x) / 2.0, (bmin.y + bmax.y) / 2.0, bmin.z]
        )

        try ( o.pivot = np ) catch ( labor_log ("pivot failed: " + o.name) )

        if mode == 5 then
        (
            try ( o.pos = [0, 0, 0] ) catch ()
        )
        else if snap_ground then
        (
            local bb2 = labor_node_bounds o
            try ( o.pos = [o.pos.x, o.pos.y, o.pos.z - bb2[1].z] ) catch ()
        )
        cnt += 1
    )
    cnt
)

-- scan objects that have rotation or non-uniform scale
fn labor_xform_issues objs =
(
    local lst = #()
    for o in objs where (labor_valid_geom o) do
    (
        local s = o.scale
        local e = (o.rotation as eulerAngles)
        local reason = ""
        if (abs (s.x - s.y) > 0.001) or (abs (s.x - s.z) > 0.001) do reason = reason + "non-uniform scale "
        if (abs e.x > 0.5) or (abs e.y > 0.5) or (abs e.z > 0.5) do reason = reason + "rotated "
        if reason != "" do append lst #(o.name, reason)
    )
    lst
)

-- reset xform (collapses to editable mesh/poly - save your file first)
fn labor_reset_xform_node o =
(
    local ok = false
    try
    (
        ResetXForm o
        ok = true
    )
    catch
    (
        ok = false
    )

    if not ok then
    (
        try
        (
            local cls = classOf o
            local tm  = o.transform
            if cls == Editable_Poly then
            (
                local nv  = polyop.getNumVerts o
                local bak = for v = 1 to nv collect (polyop.getVert o v)
                for v = 1 to nv do polyop.setVert o v (bak[v] * tm)
                o.transform = matrix3 1
                ok = true
            )
            else if cls == Editable_Mesh then
            (
                local nv  = meshop.getNumVerts o
                local bak = for v = 1 to nv collect (meshop.getVert o v)
                for v = 1 to nv do meshop.setVert o v (bak[v] * tm)
                o.transform = matrix3 1
                ok = true
            )
        )
        catch ( ok = false )
    )
    ok
)

-- max position -> ue location ( y flipped by default: right handed -> left handed )
fn labor_max_to_ue p flip_y =
(
    local f = labor_unit_to_cm()
    local x = p.x * f
    local y = p.y * f
    local z = p.z * f
    if flip_y then [x, -y, z] else [x, y, z]
)

fn labor_num_str v =
(
    formattedPrint v format:".2f"
)

fn labor_build_coord_rows objs flip_y =
(
    labor_coord_rows = #()
    for o in objs where (labor_valid_geom o) do
    (
        local ue = labor_max_to_ue o.pos flip_y
        append labor_coord_rows #(o.name, ue.x, ue.y, ue.z)
    )
    labor_coord_rows
)

fn labor_coord_display_lines =
(
    local lines = #()
    for r in labor_coord_rows do
    (
        append lines (r[1] + "   ->   UE (" + (labor_num_str r[2]) + ", " + (labor_num_str r[3]) + ", " + (labor_num_str r[4]) + ")")
    )
    lines
)

fn labor_rows_to_string =
(
    local s = "Name,UE_X,UE_Y,UE_Z\n"
    for r in labor_coord_rows do
    (
        s = s + r[1] + "," + (labor_num_str r[2]) + "," + (labor_num_str r[3]) + "," + (labor_num_str r[4]) + "\n"
    )
    s
)

fn labor_duplicate_names objs =
(
    local seen = #()
    local dups = #()
    for o in objs do
    (
        local nm = o.name
        if (findItem seen nm) == 0 then
            append seen nm
        else if (findItem dups nm) == 0 do
            append dups nm
    )
    dups
)

fn labor_fix_duplicate_names objs =
(
    local seen = #()
    local n = 0
    for o in objs do
    (
        local nm = o.name
        if (findItem seen nm) == 0 then
        (
            append seen nm
        )
        else
        (
            local k    = 1
            local cand = nm + "_" + (labor_pad3 k)
            while (findItem seen cand) != 0 do
            (
                k += 1
                cand = nm + "_" + (labor_pad3 k)
            )
            try
            (
                o.name = cand
                append seen cand
                n += 1
            )
            catch ()
        )
    )
    n
)

fn labor_bad_names objs =
(
    local lst = #()
    for o in objs do
    (
        local cleaned = labor_clean_name o.name
        if cleaned != o.name do append lst #(o.name, cleaned)
    )
    lst
)

fn labor_fix_bad_names objs =
(
    local n = 0
    for o in objs do
    (
        local cleaned = labor_clean_name o.name
        if cleaned != o.name do
        (
            try
            (
                o.name = cleaned
                n += 1
            )
            catch ()
        )
    )
    n
)

-- objects whose pivot is not sitting on the bottom
fn labor_pivot_issues objs tol =
(
    local lst = #()
    for o in objs where (labor_valid_geom o) do
    (
        local bb = labor_node_bounds o
        local d  = abs (o.pos.z - bb[1].z)
        if d > tol do append lst #(o.name, d)
    )
    lst
)

--------------------------------------------------------------------------------
-- end of file : labor_ue.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ue.ms is only a module, please run labor.ms to open the panel.\n"
)
