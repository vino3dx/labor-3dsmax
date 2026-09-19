/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ui_ue.ms
   module  : ui : 1. ue export
   desc    : rollout labor_roll_ue
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     one rollout (labor_roll_ue), loaded by labor.ms,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

rollout labor_roll_ue "① UE 导出准备"
(
    local last_issues = #()

    group "1. 单位 / 变换检查"
    (
        label  lbl_unit   "系统单位: -" width:300 align:#left
        button btn_unit_cm  "设为厘米" width:145 height:22 across:2 align:#left
        button btn_unit_chk "重新检测" width:145 height:22 align:#left
        label  lbl_bad    "变换异常对象: -" width:300 align:#left
        button btn_scan_xf "扫描变换问题" width:145 height:22 across:2 align:#left
        button btn_fix_xf  "Reset XForm"  width:145 height:22 align:#left
    )

    group "2. 轴心 / 落地"
    (
        checkbox chk_sel_only "仅处理选中对象" checked:true align:#left
        dropdownList ddl_pivot "轴心位置" items:#("底部中心 (推荐 UE)", "底部 + 保持当前 XY", "底部最小角", "几何中心", "归世界原点 + 底部") selection:1 width:300 align:#left
        checkbox chk_snap_ground "同时吸附地面 (最低点 Z=0)" checked:false align:#left
        button btn_pivot  "轴心 / 落地处理" width:300 height:26 align:#left
        button btn_one_key "★ 一键 UE 预处理" width:300 height:30 align:#left
    )

    group "3. FBX 导出"
    (
        checkbox chk_embed_tex "嵌入贴图 (建议关闭)" checked:false align:#left
        dropdownList ddl_up "上轴" items:#("Y 轴向上 (FBX 默认)", "Z 轴向上") selection:1 width:300 align:#left
        checkbox chk_exp_sel "只导出选中对象" checked:true align:#left
        button btn_export_one  "导出为单个 FBX (保留世界坐标)" width:300 height:26 align:#left
        button btn_export_each "逐对象导出 (各自归原点)" width:300 height:26 align:#left
    )

    group "4. 坐标对照 (Max → UE)"
    (
        checkbox chk_flip_y "Y 轴取反 (右手系 → 左手系)" checked:true align:#left
        button btn_coord_refresh "刷新对照" width:145 height:22 across:2 align:#left
        button btn_coord_copy    "复制剪贴板" width:145 height:22 align:#left
        listBox lb_coord "对象 → UE Location" height:7 width:300 align:#left
        button btn_coord_csv "导出 CSV" width:300 height:22 align:#left
    )

    group "5. UE 资产检查"
    (
        button btn_chk_dup   "检查重名对象" width:145 height:22 across:2 align:#left
        button btn_fix_dup   "自动修复重名" width:145 height:22 align:#left
        button btn_chk_name  "检查非法命名" width:145 height:22 across:2 align:#left
        button btn_fix_name  "清理非法字符" width:145 height:22 align:#left
        button btn_chk_pivot "检查未落地轴心" width:145 height:22 across:2 align:#left
        button btn_ue_name   "加 SM_ 前缀" width:145 height:22 align:#left
        label  lbl_chk "检查结果: -" width:300 align:#left
    )

    label lbl_status "状态: 就绪" width:300 align:#left
    label lbl_tip "提示: UE 1 单位 = 1 厘米; 底部中心轴心 + 世界坐标导出 = UE 中位置与 Max 对应。" width:300 height:32 align:#left

    fn refresh_units =
    (
        local f = labor_unit_to_cm()
        lbl_unit.text = ("系统单位: " + (labor_unit_name()) + "   (1 单位 = " + (f as string) + " cm)")
    )

    fn refresh_coord =
    (
        local objs = labor_get_targets chk_sel_only.checked
        labor_build_coord_rows objs chk_flip_y.checked
        lb_coord.items = labor_coord_display_lines()
    )

    on labor_roll_ue open do
    (
        refresh_units()
        lbl_bad.text = "变换异常对象: 未扫描"
    )

    on btn_unit_chk pressed do refresh_units()

    on btn_unit_cm pressed do
    (
        try
        (
            units.SystemType  = #centimeters
            units.DisplayType = #metric
            units.MetricType  = #centimeters
            lbl_status.text = "系统单位已设为厘米"
        )
        catch ( lbl_status.text = "单位设置失败，请到 Customize > Units Setup 手动设置" )
        refresh_units()
    )

    on btn_scan_xf pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        last_issues = labor_xform_issues objs
        lbl_bad.text = ("变换异常对象: " + (last_issues.count as string) + " / " + (objs.count as string))
        labor_log "---- transform scan ----"
        for it in last_issues do labor_log (it[1] + "  :  " + it[2])
        if last_issues.count == 0 then
            lbl_status.text = "未发现旋转 / 非等比缩放问题"
        else
            lbl_status.text = ("发现 " + (last_issues.count as string) + " 个问题对象，详见监听器")
    )

    on btn_fix_xf pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        if objs.count == 0 do
        (
            messageBox "没有可处理的对象。" title:"labor"
            return false
        )
        if not (queryBox "Reset XForm 会把对象塌陷为可编辑网格/多边形，修改器堆栈将丢失。\n\n建议先保存文件，是否继续？" title:"labor") do return false

        local n = 0
        undo "labor_reset_xform" on
        (
            for o in objs where (labor_valid_geom o) do
                if labor_reset_xform_node o do n += 1
        )
        lbl_status.text = ("Reset XForm 完成: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_pivot pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        if objs.count == 0 do
        (
            messageBox "没有可处理的对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_pivot" on
        (
            n = labor_pivot_process objs ddl_pivot.selection chk_snap_ground.checked
        )
        lbl_status.text = ("轴心处理完成: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_one_key pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        if objs.count == 0 do
        (
            messageBox "没有可处理的对象。" title:"labor"
            return false
        )

        local msg = ""
        undo "labor_ue_prep" on
        (
            if (labor_unit_to_cm()) != 1.0 do
                msg = "警告: 系统单位不是厘米，导入 UE 后大小可能不一致。 "

            local issues = labor_xform_issues objs
            if issues.count > 0 do
                msg = msg + ("发现 " + (issues.count as string) + " 个对象有旋转/非等比缩放(未自动修复)。 ")

            local n = labor_pivot_process objs ddl_pivot.selection chk_snap_ground.checked
            msg = msg + ("轴心处理 " + (n as string) + " 个对象。")
        )

        lbl_status.text = msg
        lbl_bad.text = ("变换异常对象: " + ((labor_xform_issues objs).count as string))
        refresh_coord()
        try ( redrawViews() ) catch ()
        labor_log msg
    )

    on btn_export_one pressed do
    (
        local objs = labor_get_targets chk_exp_sel.checked
        if objs.count == 0 do
        (
            messageBox "没有可导出的对象。" title:"labor"
            return false
        )
        local f = getSaveFileName caption:"导出 FBX (保留世界坐标)" types:"FBX (*.fbx)|*.fbx|All Files (*.*)|*.*"
        if f == undefined do return false
        if (getFilenameType f) == "" do f = f + ".fbx"

        local up = if ddl_up.selection == 1 then "Y" else "Z"
        local ok = labor_export_fbx_file objs f up chk_embed_tex.checked
        lbl_status.text = if ok then ("已导出: " + f) else "导出失败，请查看监听器"
    )

    on btn_export_each pressed do
    (
        local objs = labor_get_targets chk_exp_sel.checked
        if objs.count == 0 do
        (
            messageBox "没有可导出的对象。" title:"labor"
            return false
        )
        local dir = getSavePath caption:"选择逐对象导出目录"
        if dir == undefined do return false

        local up = if ddl_up.selection == 1 then "Y" else "Z"
        local n  = 0
        undo "labor_export_each" on
        (
            n = labor_export_each objs dir up chk_embed_tex.checked
        )
        lbl_status.text = ("已导出 " + (n as string) + " 个 FBX 到: " + dir)
    )

    on btn_coord_refresh pressed do
    (
        refresh_coord()
        lbl_status.text = ("坐标对照: " + (labor_coord_rows.count as string) + " 个对象")
    )

    on btn_coord_copy pressed do
    (
        if labor_coord_rows.count == 0 do refresh_coord()
        try
        (
            setClipBoardText (labor_rows_to_string())
            lbl_status.text = "坐标已复制到剪贴板 (CSV 格式)"
        )
        catch ( lbl_status.text = "复制失败，请手动记录" )
    )

    on btn_coord_csv pressed do
    (
        if labor_coord_rows.count == 0 do refresh_coord()
        local f = getSaveFileName caption:"导出坐标 CSV" types:"CSV (*.csv)|*.csv|All Files (*.*)|*.*"
        if f == undefined do return false
        if (getFilenameType f) == "" do f = f + ".csv"

        local fs = createFile f
        if fs != undefined then
        (
            format "Name,UE_X,UE_Y,UE_Z\n" to:fs
            for r in labor_coord_rows do
                format "%,%,%,%\n" r[1] (labor_num_str r[2]) (labor_num_str r[3]) (labor_num_str r[4]) to:fs
            close fs
            lbl_status.text = ("CSV 已保存: " + f)
        )
        else ( lbl_status.text = "CSV 保存失败" )
    )

    on btn_chk_dup pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        local dups = labor_duplicate_names objs
        labor_log ("duplicate names: " + dups.count as string)
        for d in dups do labor_log d
        lbl_chk.text = ("重名对象组: " + dups.count as string)
        if dups.count > 0 do
            messageBox ("发现 " + dups.count as string + " 组重名对象。\nUE 导入时会报重名错误，建议点「自动修复重名」。") title:"labor"
    )

    on btn_fix_dup pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        local n = 0
        undo "labor_fix_dup" on
        (
            n = labor_fix_duplicate_names objs
        )
        lbl_chk.text = ("已修复重名: " + n as string + " 个")
    )

    on btn_chk_name pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        local lst = labor_bad_names objs
        labor_log "---- illegal names ----"
        for it in lst do labor_log (it[1] + "  ->  " + it[2])
        lbl_chk.text = ("非法命名: " + lst.count as string + " 个")
    )

    on btn_fix_name pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        local n = 0
        undo "labor_fix_name" on
        (
            n = labor_fix_bad_names objs
        )
        lbl_chk.text = ("已清理命名: " + n as string + " 个")
    )

    on btn_chk_pivot pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        local lst = labor_pivot_issues objs 0.001
        labor_log "---- pivot not on bottom ----"
        for it in lst do labor_log (it[1] + "  距底部: " + (labor_num_str it[2]))
        lbl_chk.text = ("未落地轴心: " + lst.count as string + " 个")
    )

    on btn_ue_name pressed do
    (
        local objs = labor_get_targets chk_sel_only.checked
        local n = 0
        undo "labor_ue_name" on
        (
            n = labor_batch_rename objs "" "" "SM_" "" false
        )
        lbl_chk.text = ("已加 SM_ 前缀: " + n as string + " 个")
    )
)

--------------------------------------------------------------------------------
-- end of file : labor_ui_ue.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ui_ue.ms is only a module, please run labor.ms to open the panel.\n"
)
