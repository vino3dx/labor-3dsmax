/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ui_about.ms
   module  : ui : 6. about
   desc    : rollout labor_roll_about
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     one rollout (labor_roll_about), loaded by labor.ms,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

rollout labor_roll_about "⑥ 关于 labor"
(
    label lbl_title ("labor " + labor_version + " - 3ds Max Workflow Toolkit") width:300 align:#left
    label lbl_desc "让 3ds Max 到 UE 的流程更轻松：轴心、坐标、贴图、材质、对齐。" width:300 height:28 align:#left

    group "作者"
    (
        label lbl_author "Author: Vino" width:300 align:#left
        hyperlink hl_blog "博客: vinofx.com" address:"https://vinofx.com" width:300 align:#left
        hyperlink hl_git  "GitHub: github.com/vino3dx" address:"https://github.com/vino3dx" width:300 align:#left
        hyperlink hl_bili "哔哩哔哩: Vino 的主页" address:"https://space.bilibili.com/250546761" width:300 align:#left
        label lbl_wechat "微信公众号: Vino自习室" width:300 align:#left
    )

    group "许可"
    (
        label lbl_lic_1 "MIT License" width:300 align:#left
        label lbl_lic_2 "Copyright (c) 2024 Vino. All rights reserved." width:300 align:#left
    )

    button btn_open_repo "打开 GitHub 仓库 (labor-3dsmax)" width:300 height:24 align:#left

    on btn_open_repo pressed do
    (
        try ( shellLaunch "https://github.com/vino3dx/labor-3dsmax" "" ) catch ()
    )
)

--------------------------------------------------------------------------------
-- end of file : labor_ui_about.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ui_about.ms is only a module, please run labor.ms to open the panel.\n"
)
