/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_model.ms
   module  : model / 模型工具
   desc    : sequential align / collapse stack / convert to poly / flip normals / unify normals / auto smooth / clear smoothing groups / weld vertices / open edge report
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     mesh level operations,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_align_objects, labor_collapse_stack, labor_normals_fix, labor_auto_smooth, labor_clear_smooth_groups, labor_weld_verts, labor_open_edges_report

fn labor_align_objects objs axis offset use_bbox =
(
    if objs.count < 2 do return false
    for i = 2 to objs.count do
    (
        local bb_prev = labor_node_bounds objs[i - 1]
        local bb_cur  = labor_node_bounds objs[i]
        local p = objs[i].pos
        case axis of
        (
            1 : p.x = bb_prev[2].x + offset + (if use_bbox then (objs[i].pos.x - bb_cur[1].x) else 0.0)
            2 : p.y = bb_prev[2].y + offset + (if use_bbox then (objs[i].pos.y - bb_cur[1].y) else 0.0)
            3 : p.z = bb_prev[2].z + offset + (if use_bbox then (objs[i].pos.z - bb_cur[1].z) else 0.0)
        )
        objs[i].pos = p
    )
    true
)

fn labor_collapse_stack objs to_poly =
(
    local n = 0
    for o in objs where (labor_valid_geom o) do
    (
        try
        (
            if to_poly and (classOf o) != Editable_Poly do convertToPoly o
            collapseStack o
            n += 1
        )
        catch ( labor_log ("collapse failed: " + o.name) )
    )
    n
)

fn labor_normals_fix objs do_flip do_unify =
(
    local n = 0
    for o in objs where (labor_valid_geom o) do
    (
        local nm = undefined
        try ( nm = execute "Normal()" ) catch ( nm = undefined )
        if nm == undefined do ( try ( nm = execute "NormalModifier()" ) catch ( nm = undefined ) )

        if nm != undefined then
        (
            if do_flip  do ( try ( nm.flip = true )  catch ( try ( nm.flipNormals = true )  catch () ) )
            if do_unify do ( try ( nm.unify = true ) catch ( try ( nm.unifyNormals = true ) catch () ) )
            try
            (
                addModifier o nm
                n += 1
            )
            catch ()
        )
        else
        (
            try
            (
                local en = execute "Edit_Normals()"
                if en != undefined do
                (
                    addModifier o en
                    local cnt = 0
                    try ( cnt = en.EditNormalsMod.GetNormalCount() ) catch ( cnt = 0 )
                    if cnt > 0 do
                    (
                        en.EditNormalsMod.SetSelection #{1..cnt}
                        try ( en.EditNormalsMod.MakeExplicit() ) catch ()
                        if do_flip  do ( try ( en.EditNormalsMod.Flip() )  catch () )
                        if do_unify do ( try ( en.EditNormalsMod.Unify() ) catch () )
                    )
                    n += 1
                )
            )
            catch ( labor_log ("normals fix failed: " + o.name) )
        )
    )
    n
)

fn labor_auto_smooth objs angle =
(
    local probe = undefined
    try ( probe = execute "Smooth()" ) catch ( probe = undefined )
    if probe == undefined do
    (
        labor_log "smooth modifier is not available on this max version"
        return 0
    )

    local n = 0
    for o in objs where (labor_valid_geom o) do
    (
        try
        (
            local sm = execute "Smooth()"
            try ( sm.autosmooth = true ) catch ( try ( sm.autoSmooth = true ) catch () )
            try ( sm.threshold = angle )  catch ()
            addModifier o sm
            n += 1
        )
        catch ( labor_log ("auto smooth failed: " + o.name) )
    )
    n
)

fn labor_clear_smooth_groups objs =
(
    local n = 0
    for o in objs where (labor_valid_geom o) do
    (
        try
        (
            local cls = classOf o
            if cls == Editable_Poly then
            (
                polyop.setFaceSmoothGroup o #{1..(polyop.getNumFaces o)} 0
                n += 1
            )
            else if cls == Editable_Mesh then
            (
                meshop.setFaceSmoothGroup o #{1..(meshop.getNumFaces o)} 0
                n += 1
            )
        )
        catch ()
    )
    n
)

fn labor_weld_verts objs thr =
(
    local n = 0
    for o in objs where (labor_valid_geom o) do
    (
        local ok = false
        try
        (
            if (classOf o) != Editable_Poly do convertToPoly o
            local nv = polyop.getNumVerts o
            if nv > 0 do
            (
                polyop.weldVertsByThreshold o #{1..nv} thr
                ok = true
            )
        )
        catch ( ok = false )
        if ok do n += 1
    )
    n
)

fn labor_open_edges_report objs =
(
    local lst = #()
    for o in objs where (labor_valid_geom o) do
    (
        local n = -1
        try
        (
            local cls = classOf o
            if cls == Editable_Poly then
                n = (polyop.getOpenEdges o).numberSet
            else if cls == Editable_Mesh then
                n = (meshop.getOpenEdges o).numberSet
        )
        catch ( n = -1 )
        if n > 0 do append lst #(o.name, n)
    )
    lst
)

--------------------------------------------------------------------------------
-- end of file : labor_model.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_model.ms is only a module, please run labor.ms to open the panel.\n"
)
