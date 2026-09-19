/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file     : labor.ms
   role     : THE ONLY ENTRY FILE  (唯一入口)
   version  : 1.2.0
   author   : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   bilibili : https://space.bilibili.com/250546761
   wechat   : Vino自习室
   license  : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   responsibility of this file
     1. resolve its own folder
     2. load every module with fileIn (library first, then ui rollouts)
     3. register the macro -> Customize User Interface / Category: labor
     4. build the floater and stack the rollouts in it
   it contains NO feature code, every tool lives in ./labor/*.ms or ./labor/ui/*.ms
   ----------------------------------------------------------------------------
   folder layout (all paths are relative to this file)
     labor.ms                        <- this file, the entry
     labor\labor_core.ms             shared helpers
     labor\labor_ue.ms               ue pivot / xform / coordinate / asset check
     labor\labor_fbx.ms              fbx export
     labor\labor_textures.ms         texture relink / pack / viewport toggle
     labor\labor_materials.ms        standard <-> vray, pbr -> standard / vray
     labor\labor_model.ms            align / collapse / normals / smooth / weld
     labor\labor_scene.ms            stats / cleanup helpers / batch rename
     labor\ui\labor_ui_ue.ms         rollout panel 1
     labor\ui\labor_ui_textures.ms   rollout panel 2
     labor\ui\labor_ui_materials.ms  rollout panel 3
     labor\ui\labor_ui_model.ms      rollout panel 4
     labor\ui\labor_ui_scene.ms      rollout panel 5
     labor\ui\labor_ui_about.ms      rollout panel 6
   ----------------------------------------------------------------------------
   adding a new panel later?  3 steps, this entry file stays almost untouched
     1. write  labor\your_lib.ms        (logic)
     2. write  labor\ui\labor_ui_x.ms   (rollout labor_roll_x)
     3. add two fileIn lines below + one addRollout line in labor_open_ui
============================================================================ */

global labor_loading   = false
global labor_root_dir  = ""
global labor_lib_dir   = ""
global labor_ui_dir    = ""
global labor_auto_open = true

--------------------------------------------------------------------------------
-- path resolution
--------------------------------------------------------------------------------

fn labor_resolve_dir =
(
    global labor_root_dir
    global labor_lib_dir
    global labor_ui_dir

    local f = ""
    try ( f = getThisScriptFilename() ) catch ( f = "" )
    if f == undefined do f = ""

    labor_root_dir = if f != "" then ( getFilenamePath f ) else ""
    labor_lib_dir  = labor_root_dir + "labor\\"
    labor_ui_dir   = labor_lib_dir  + "ui\\"
    labor_root_dir
)

--------------------------------------------------------------------------------
-- diagnostics
--------------------------------------------------------------------------------

fn labor_info =
(
    format "[labor] version    %\n" labor_version
    format "[labor] root       %\n" labor_root_dir
    format "[labor] library    %\n" labor_lib_dir
    format "[labor] ui         %\n" labor_ui_dir
    format "[labor] run  labor_open_ui()  to open the panel\n"
    OK
)

--------------------------------------------------------------------------------
-- build the floater : all rollouts come from ./labor/ui/*.ms
--------------------------------------------------------------------------------

fn labor_open_ui =
(
    global labor_floater

    try ( closeRolloutFloater labor_floater ) catch ()
    labor_floater = newRolloutFloater ("labor " + labor_version + "  -  by Vino") 340 760
    addRollout labor_roll_ue    labor_floater rolledup:false
    addRollout labor_roll_tex   labor_floater rolledup:true
    addRollout labor_roll_mat   labor_floater rolledup:true
    addRollout labor_roll_model labor_floater rolledup:true
    addRollout labor_roll_scene labor_floater rolledup:true
    addRollout labor_roll_about labor_floater rolledup:true
    labor_floater
)

--------------------------------------------------------------------------------
-- load modules
-- NOTE : keep these fileIn calls at the top level of the file.
--        wrapping them inside another structure can change the scope the
--        rollouts are defined in.
--------------------------------------------------------------------------------

labor_resolve_dir()

if labor_root_dir == "" do
(
    format "[labor] cannot resolve the script folder, please run labor.ms from disk.\n"
)

labor_loading = true

-- library, order matters: core must be first
fileIn ( labor_lib_dir + "labor_core.ms" )
fileIn ( labor_lib_dir + "labor_ue.ms" )
fileIn ( labor_lib_dir + "labor_fbx.ms" )
fileIn ( labor_lib_dir + "labor_textures.ms" )
fileIn ( labor_lib_dir + "labor_materials.ms" )
fileIn ( labor_lib_dir + "labor_model.ms" )
fileIn ( labor_lib_dir + "labor_scene.ms" )

-- ui rollouts
fileIn ( labor_ui_dir + "labor_ui_ue.ms" )
fileIn ( labor_ui_dir + "labor_ui_textures.ms" )
fileIn ( labor_ui_dir + "labor_ui_materials.ms" )
fileIn ( labor_ui_dir + "labor_ui_model.ms" )
fileIn ( labor_ui_dir + "labor_ui_scene.ms" )
fileIn ( labor_ui_dir + "labor_ui_about.ms" )

labor_loading = false

--------------------------------------------------------------------------------
-- macro : Customize User Interface -> Category: labor -> labor
--------------------------------------------------------------------------------

macroScript labor
    category:"labor"
    buttonText:"labor"
    tooltip:"labor - 3ds Max Workflow Toolkit"
(
    on execute do
    (
        labor_open_ui()
    )
)

--------------------------------------------------------------------------------
-- when this file is dragged into the viewport / run directly, open the panel
-- put  labor_auto_open = false  before the fileIn above if you do not want that
--------------------------------------------------------------------------------

if labor_auto_open do labor_open_ui()

--------------------------------------------------------------------------------
-- end of file : labor.ms
--------------------------------------------------------------------------------
