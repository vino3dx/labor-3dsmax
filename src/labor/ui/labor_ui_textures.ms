/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ui_textures.ms
   module  : ui : 2. textures
   desc    : rollout labor_roll_tex
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     one rollout (labor_roll_tex), loaded by labor.ms,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

rollout labor_roll_tex "② 贴图工具"
(
    group "缺失贴图重链接 (目录搜索)"
    (
        editText edt_root "根目录:" text:"" width:215 height:20 across:2 align:#left
        button  btn_browse "浏览..." width:80 height:22 align:#left
        checkbox chk_recursive "递归子目录" checked:true width:140 height:18 across:2 align:#left
        checkbox chk_case "忽略大小写" checked:true width:140 height:18 align:#left
        checkbox chk_use_first "多候选时取第一个" checked:false align:#left
        button btn_relink "扫描并重链接" width:300 height:26 align:#left
    )

    group "路径前缀替换"
    (
        editText edt_old "旧前缀:" text:"" width:300 height:20 align:#left
        editText edt_new "新前缀:" text:"" width:300 height:20 align:#left
        button btn_prefix "按前缀批量替换" width:300 height:24 align:#left
    )

    group "打包 / 显示"
    (
        button btn_pack "收集贴图到文件夹" width:145 height:24 across:2 align:#left
        button btn_tex_toggle "视口贴图显示开关" width:145 height:24 align:#left
        label lbl_tex_info "贴图总数: -   缺失: -" width:300 align:#left
        button btn_tex_refresh "统计贴图状态" width:145 height:22 across:2 align:#left
        button btn_listener "打开监听器" width:145 height:22 align:#left
    )

    fn refresh_tex_info =
    (
        local st = labor_tex_stats()
        lbl_tex_info.text = ("贴图总数: " + (st[1] as string) + "   缺失: " + (st[2] as string))
    )

    on labor_roll_tex open do refresh_tex_info()

    on btn_browse pressed do
    (
        local d = getSavePath caption:"选择贴图根目录"
        if d != undefined do edt_root.text = d
    )

    on btn_relink pressed do
    (
        local root = edt_root.text
        if root == "" do
        (
            messageBox "请先选择贴图根目录。" title:"labor"
            return false
        )
        if not (doesDirectoryExist root) do
        (
            messageBox "目录不存在，请检查路径。" title:"labor"
            return false
        )

        local st = labor_relink_by_search root chk_recursive.checked chk_case.checked chk_use_first.checked
        refresh_tex_info()
        try ( redrawViews() ) catch ()
        messageBox ("扫描完成\n\n贴图总数: " + (st[1] as string) +
                    "\n路径正常: " + (st[2] as string) +
                    "\n成功重链接: " + (st[3] as string) +
                    "\n多候选跳过: " + (st[4] as string) +
                    "\n仍未找到: " + (st[5] as string)) title:"labor 贴图重链接"
    )

    on btn_prefix pressed do
    (
        local st = labor_relink_by_prefix edt_old.text edt_new.text
        refresh_tex_info()
        try ( redrawViews() ) catch ()
        messageBox ("前缀替换完成\n\n贴图总数: " + (st[1] as string) +
                    "\n成功替换: " + (st[2] as string) +
                    "\n失败/未匹配: " + (st[3] as string)) title:"labor 路径替换"
    )

    on btn_pack pressed do
    (
        local d = getSavePath caption:"选择贴图输出目录"
        if d == undefined do return false
        local st = labor_pack_textures d
        messageBox ("贴图打包完成\n\n成功: " + (st[1] as string) + "\n缺失/失败: " + (st[2] as string)) title:"labor 贴图打包"
    )

    on btn_tex_toggle pressed do
    (
        labor_tex_state = not labor_tex_state
        local n = labor_toggle_viewport_textures labor_tex_state
        lbl_tex_info.text = ("视口贴图显示: " + (if labor_tex_state then "开" else "关") + "  (" + (n as string) + " 个材质)")
    )

    on btn_tex_refresh pressed do refresh_tex_info()

    on btn_listener pressed do
    (
        try ( Listener.show() ) catch ( messageBox "无法打开 MAXScript 监听器。" title:"labor" )
    )
)

--------------------------------------------------------------------------------
-- end of file : labor_ui_textures.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ui_textures.ms is only a module, please run labor.ms to open the panel.\n"
)
