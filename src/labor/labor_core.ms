/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_core.ms
   module  : core / 公共工具
   desc    : log / path join / safe file name / geometry filter / resolve targets / world bounds / unit convert
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     this file provides the shared helpers used by every other module,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_log, labor_join_path, labor_safe_file_name, labor_valid_geom, labor_get_targets, labor_node_bounds, labor_unit_to_cm, labor_unit_name

global labor_version    = "1.2.0"
global labor_floater    = undefined
global labor_coord_rows = #()
global labor_tex_state  = true

fn labor_log msg =
(
    format "[labor] %\n" (msg as string)
)

fn labor_join_path a b =
(
    local s = if a == undefined then "" else (a as string)
    if s.count > 0 and s[s.count] != "\\" and s[s.count] != "/" do s = s + "\\"
    s + (b as string)
)

fn labor_safe_file_name s =
(
    local out = ""
    local bad = "\\/:*?\"<>|"
    for i = 1 to s.count do
    (
        local c = s[i]
        if (findString bad c) != undefined do c = "_"
        out = out + c
    )
    if out == "" do out = "object"
    out
)

fn labor_valid_geom o =
(
    (isValidNode o) and (superClassOf o == GeometryClass)
)

fn labor_get_targets sel_only =
(
    if sel_only and selection.count > 0 then
        (selection as array)
    else
        (for o in geometry collect o)
)

-- world space bounding box -> #(min, max)
fn labor_node_bounds o =
(
    nodeGetBoundingBox o o.transform
)

-- system unit -> centimeter factor ( ue 1 unit = 1 cm )
fn labor_unit_to_cm =
(
    local t = units.SystemType
    local f = case t of
    (
        #centimeters : 1.0
        #millimeters : 0.1
        #meters      : 100.0
        #kilometers  : 100000.0
        #inches      : 2.54
        #feet        : 30.48
        #miles       : 160934.4
        default      : 1.0
    )
    f
)

fn labor_unit_name =
(
    (units.SystemType as string)
)

--------------------------------------------------------------------------------
-- end of file : labor_core.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_core.ms is only a module, please run labor.ms to open the panel.\n"
)
