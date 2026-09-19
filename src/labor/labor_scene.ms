/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_scene.ms
   module  : scene / 场景工具
   desc    : batch rename / scene statistics / delete empty objects, dummies and layers / orphan materials / quick selection helpers
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     scene level queries and cleanup helpers,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_pad3, labor_clean_name, labor_batch_rename, labor_scene_stats, labor_heavy_objects, labor_delete_empty_objects, labor_delete_empty_dummies, labor_delete_empty_layers, labor_orphan_materials, labor_objects_missing_texture, labor_select_no_material, labor_select_same_material, labor_invert_selection

fn labor_pad3 v =
(
    local s = v as string
    while s.count < 3 do s = "0" + s
    s
)

-- replace characters that are illegal or unfriendly for ue / windows
fn labor_clean_name nm =
(
    local out = ""
    local illegal = " .:;,/'\\\"*?|<>!@#$%^&()+={}[]~`"
    for i = 1 to nm.count do
    (
        local c = nm[i]
        if (findString illegal c) != undefined then
            out = out + "_"
        else
            out = out + c
    )
    if out == "" do out = "object"
    out
)

fn labor_batch_rename objs find_str rep_str prefix suffix use_index =
(
    local n = 0
    local i = 0
    for o in objs do
    (
        local nm = o.name
        if find_str != "" do
        (
            local out = ""
            local pos = findString nm find_str
            while pos != undefined do
            (
                out = out + (substring nm 1 (pos - 1)) + rep_str
                nm  = substring nm (pos + find_str.count) -1
                pos = findString nm find_str
            )
            nm = out + nm
        )
        nm = prefix + nm + suffix
        i += 1
        if use_index do nm = nm + "_" + (labor_pad3 i)
        try
        (
            o.name = nm
            n += 1
        )
        catch ( labor_log ("rename failed: " + o.name) )
    )
    n
)

fn labor_scene_stats =
(
    local obj_count   = 0
    local face_count  = 0
    local vert_count  = 0
    local light_count = 0
    local hidden_cnt  = 0
    local frozen_cnt  = 0

    for o in geometry where (labor_valid_geom o) do
    (
        obj_count += 1
        try
        (
            local pc = getPolygonCount o
            face_count += pc[1]
            vert_count += pc[2]
        )
        catch ()
    )

    try ( for o in lights do light_count += 1 ) catch ()

    for o in objects do
    (
        try ( if o.isHidden do hidden_cnt += 1 ) catch ()
        try ( if o.isFrozen do frozen_cnt += 1 ) catch ()
    )

    local mat_count = 0
    try ( mat_count = sceneMaterials.count ) catch ( mat_count = 0 )

    local tex = labor_tex_stats()
    #(obj_count, face_count, vert_count, light_count, hidden_cnt, frozen_cnt, mat_count, tex[1], tex[2])
)

fn labor_heavy_objects objs limit =
(
    local lst = #()
    for o in objs where (labor_valid_geom o) do
    (
        local nf = 0
        try ( nf = (getPolygonCount o)[1] ) catch ( nf = 0 )
        if nf >= limit do append lst #(o.name, nf)
    )
    lst
)

fn labor_delete_empty_objects =
(
    local del = #()
    for o in geometry where (labor_valid_geom o) do
    (
        local nv = -1
        try
        (
            local cls = classOf o
            if cls == Editable_Poly then
                nv = polyop.getNumVerts o
            else if cls == Editable_Mesh then
                nv = meshop.getNumVerts o
            else
                nv = (getPolygonCount o)[2]
        )
        catch ( nv = -1 )
        if nv == 0 do append del o
    )
    if del.count > 0 do
    (
        try ( delete del ) catch ()
    )
    del.count
)

fn labor_delete_empty_dummies =
(
    local del = #()
    for o in objects do
    (
        try
        (
            if (classOf o) == Dummy and o.children.count == 0 and o.parent == undefined do
                append del o
        )
        catch ()
    )
    if del.count > 0 do
    (
        try ( delete del ) catch ()
    )
    del.count
)

fn labor_delete_empty_layers =
(
    local n = 0
    try
    (
        local lm    = LayerManager
        local total = lm.count
        for i = (total - 1) to 0 by -1 do
        (
            local layer = lm.getLayer i
            if layer != undefined do
            (
                local nodes = #()
                layer.nodes &nodes
                if nodes.count == 0 do
                (
                    local lname = layer.name
                    if lname != "0" do
                    (
                        try
                        (
                            lm.deleteLayerByName lname
                            n += 1
                        )
                        catch ()
                    )
                )
            )
        )
    )
    catch ()
    n
)

fn labor_orphan_materials =
(
    local lst = #()
    try
    (
        for m in sceneMaterials do
        (
            local nodes = #()
            try ( nodes = refs.dependentNodes m ) catch ( nodes = #() )
            if nodes.count == 0 do append lst m
        )
    )
    catch ()
    lst
)

fn labor_objects_missing_texture =
(
    local bms  = labor_collect_bitmaps()
    local done = #()
    for t in bms do
    (
        local p = ""
        try ( p = t.filename as string ) catch ( p = "" )
        if p == "" or not (doesFileExist p) do
        (
            local nodes = #()
            try ( nodes = refs.dependentNodes t ) catch ( nodes = #() )
            for nd in nodes where (findItem done nd == 0) do append done nd
        )
    )
    done
)

fn labor_select_no_material =
(
    local arr = #()
    for o in geometry where (labor_valid_geom o) and (o.material == undefined) do append arr o
    if arr.count > 0 then
    (
        try ( select arr ) catch ()
    )
    else
    (
        try ( clearSelection() ) catch ()
    )
    arr.count
)

fn labor_select_same_material =
(
    if selection.count == 0 do return 0
    local src = selection[1].material
    if src == undefined do return 0
    local arr = #()
    for o in geometry where (labor_valid_geom o) and (o.material == src) do append arr o
    if arr.count > 0 do ( try ( select arr ) catch () )
    arr.count
)

fn labor_invert_selection =
(
    local cur = selection as array
    local inv = for o in objects where (findItem cur o == 0) collect o
    try ( select inv ) catch ()
    inv.count
)

--------------------------------------------------------------------------------
-- end of file : labor_scene.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_scene.ms is only a module, please run labor.ms to open the panel.\n"
)
