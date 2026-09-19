/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_fbx.ms
   module  : fbx export / FBX 导出
   desc    : fbx exporter parameters / export selection to one file / export each object to its own file
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     FBX export helpers,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_fbx_set_param, labor_export_fbx_file, labor_export_each

fn labor_fbx_set_param pname pval =
(
    local ok = false
    try
    (
        FBXExporterSetParam pname pval
        ok = true
    )
    catch
    (
        try
        (
            FbxExporterSetParam pname pval
            ok = true
        )
        catch ( ok = false )
    )
    ok
)

fn labor_export_fbx_file objs file up_axis embed_tex =
(
    local old_sel = getCurrentSelection()
    select objs
    labor_fbx_set_param "Animation" false
    labor_fbx_set_param "BakeAnimation" false
    labor_fbx_set_param "Cameras" false
    labor_fbx_set_param "Lights" false
    labor_fbx_set_param "EmbedTextures" embed_tex
    labor_fbx_set_param "UpAxis" up_axis
    labor_fbx_set_param "ConvertUnit" "cm"
    labor_fbx_set_param "ScaleFactor" 1.0
    labor_fbx_set_param "SmoothingGroups" true
    labor_fbx_set_param "PreserveEdgeOrientation" true
    labor_fbx_set_param "TangentSpaceExport" true
    labor_fbx_set_param "Triangulate" false
    labor_fbx_set_param "Ascii" false

    local res = false
    try ( res = exportFile file #noPrompt selectedOnly:true ) catch ( res = false )
    select old_sel
    res
)

-- export each object separately, temporarily moved to origin with bottom pivot
fn labor_export_each objs dir up_axis embed_tex =
(
    local n = 0
    for o in objs where (labor_valid_geom o) do
    (
        local save_tm    = o.transform
        local save_pivot = o.pivot
        local bb   = labor_node_bounds o
        local bmin = bb[1]
        local bmax = bb[2]

        try ( o.pivot = [(bmin.x + bmax.x) / 2.0, (bmin.y + bmax.y) / 2.0, bmin.z] ) catch ()
        try ( o.pos = [0, 0, 0] ) catch ()

        local f = labor_join_path dir (labor_safe_file_name o.name + ".fbx")
        if labor_export_fbx_file #(o) f up_axis embed_tex do n += 1

        try ( o.transform = save_tm ) catch ()
        try ( o.pivot = save_pivot ) catch ()
    )
    n
)

--------------------------------------------------------------------------------
-- textures

--------------------------------------------------------------------------------
-- end of file : labor_fbx.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_fbx.ms is only a module, please run labor.ms to open the panel.\n"
)
