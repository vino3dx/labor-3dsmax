/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ui_scene.ms
   module  : ui : 5. scene
   desc    : rollout labor_roll_scene
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     one rollout (labor_roll_scene), loaded by labor.ms,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

rollout labor_roll_scene "⑤ 场景工具"
(
    group "1. 场景体检"
    (
        button btn_stats "一键体检" width:300 height:26 align:#left
        label  lbl_stats "对象 - / 面 - / 顶点 -" width:300 height:44 align:#left
        spinner spn_face_limit "面数预警阈值" range:[1000, 10000000, 200000] type:#integer fieldwidth:70 align:#left
        button btn_heavy "列出超面数对象" width:300 height:22 align:#left
    )

    group "2. 清理"
    (
        button btn_del_empty "删除空对象 (0 顶点)" width:145 height:24 across:2 align:#left
        button btn_del_dummy "删除空 Dummy" width:145 height:24 align:#left
        button btn_del_layer "删除空图层" width:145 height:24 across:2 align:#left
        button btn_orphan_mat "统计孤立材质" width:145 height:24 align:#left
    )

    group "3. 显示 / 性能"
    (
        button btn_unhide "全部取消隐藏" width:145 height:24 across:2 align:#left
        button btn_unfreeze "全部解冻" width:145 height:24 align:#left
        button btn_boxmode "边界盒显示开关" width:145 height:24 across:2 align:#left
        button btn_backcull "背面剔除开关" width:145 height:24 align:#left
        checkbox chk_hide_helper "隐藏 Helper 类" checked:false width:145 height:18 across:2 align:#left
        checkbox chk_hide_shape "隐藏 Shape 类" checked:false width:145 height:18 align:#left
        button btn_isolate "孤立模式开关" width:300 height:24 align:#left
    )

    group "4. 快速选择"
    (
        button btn_sel_nomat "选择无材质对象" width:145 height:24 across:2 align:#left
        button btn_sel_miss  "选择缺贴图对象" width:145 height:24 align:#left
        button btn_sel_same  "选择同材质对象" width:145 height:24 across:2 align:#left
        button btn_sel_inv   "反选" width:145 height:24 align:#left
    )

    group "5. 批量重命名"
    (
        editText edt_find "查找:" text:"" width:300 height:20 align:#left
        editText edt_rep  "替换为:" text:"" width:300 height:20 align:#left
        editText edt_pre  "前缀:" text:"" width:145 height:20 across:2 align:#left
        editText edt_suf  "后缀:" text:"" width:145 height:20 align:#left
        checkbox chk_index "追加序号 (_001)" checked:false align:#left
        checkbox chk_all_obj "处理全部对象 (不限选中)" checked:false align:#left
        button btn_rename "执行重命名" width:300 height:26 align:#left
    )

    label lbl_scene_status "状态: 就绪" width:300 align:#left

    fn scene_objs =
    (
        if chk_all_obj.checked then
            (for o in objects collect o)
        else if selection.count > 0 then
            (selection as array)
        else
            (for o in geometry collect o)
    )

    on btn_stats pressed do
    (
        local st = labor_scene_stats()
        lbl_stats.text = ("对象 " + (st[1] as string) + " / 三角面 " + (st[2] as string) + " / 顶点 " + (st[3] as string) +
                          "\n灯光 " + (st[4] as string) + " / 隐藏 " + (st[5] as string) + " / 冻结 " + (st[6] as string) +
                          "\n材质 " + (st[7] as string) + " / 贴图 " + (st[8] as string) + " / 缺失 " + (st[9] as string))
        labor_log "---- scene report ----"
        labor_log lbl_stats.text
        lbl_scene_status.text = "体检完成，详细数据见监听器"
    )

    on btn_heavy pressed do
    (
        local objs = scene_objs()
        local lst  = labor_heavy_objects objs spn_face_limit.value
        labor_log ("---- faces >= " + (spn_face_limit.value as string) + " ----")
        for it in lst do labor_log (it[1] + " : " + (it[2] as string) + " faces")
        lbl_scene_status.text = ("超面数对象: " + (lst.count as string) + " 个，详见监听器")
    )

    on btn_del_empty pressed do
    (
        if not (queryBox "将删除场景中顶点数为 0 的几何体，是否继续？" title:"labor") do return false
        local n = 0
        undo "labor_delete_empty" on
        (
            n = labor_delete_empty_objects()
        )
        lbl_scene_status.text = ("已删除空对象: " + (n as string) + " 个")
    )

    on btn_del_dummy pressed do
    (
        if not (queryBox "将删除无子级、无父级的 Dummy 对象。\n建议先保存，是否继续？" title:"labor") do return false
        local n = 0
        undo "labor_delete_dummy" on
        (
            n = labor_delete_empty_dummies()
        )
        lbl_scene_status.text = ("已删除空 Dummy: " + (n as string) + " 个")
    )

    on btn_del_layer pressed do
    (
        local n = labor_delete_empty_layers()
        lbl_scene_status.text = ("已删除空图层: " + (n as string) + " 个")
    )

    on btn_orphan_mat pressed do
    (
        local lst = labor_orphan_materials()
        labor_log ("---- orphan materials: " + (lst.count as string) + " ----")
        for m in lst do labor_log m.name
        lbl_scene_status.text = ("孤立材质: " + (lst.count as string) + " 个，详见监听器")
    )

    on btn_unhide pressed do
    (
        try ( unhide objects ) catch ()
        lbl_scene_status.text = "已取消全部隐藏"
        try ( redrawViews() ) catch ()
    )

    on btn_unfreeze pressed do
    (
        try ( unfreeze objects ) catch ()
        lbl_scene_status.text = "已解冻全部对象"
        try ( redrawViews() ) catch ()
    )

    on btn_boxmode pressed do
    (
        local objs   = scene_objs()
        local target = true
        if objs.count > 0 do
        (
            try ( target = not objs[1].boxMode ) catch ( target = true )
        )
        for o in objs do ( try ( o.boxMode = target ) catch () )
        lbl_scene_status.text = ("边界盒显示: " + (if target then "开" else "关"))
        try ( redrawViews() ) catch ()
    )

    on btn_backcull pressed do
    (
        local objs   = scene_objs()
        local target = true
        if objs.count > 0 do
        (
            try ( target = not objs[1].backFaceCull ) catch ( target = true )
        )
        for o in objs do ( try ( o.backFaceCull = target ) catch () )
        lbl_scene_status.text = ("背面剔除: " + (if target then "开" else "关"))
        try ( redrawViews() ) catch ()
    )

    on chk_hide_helper changed state do
    (
        try ( hideByCategory.helpers = state ) catch ()
        try ( redrawViews() ) catch ()
    )

    on chk_hide_shape changed state do
    (
        try ( hideByCategory.shapes = state ) catch ()
        try ( redrawViews() ) catch ()
    )

    on btn_isolate pressed do
    (
        local st = false
        try ( st = IsolateSelection.IsolateNodeState() ) catch ( st = false )
        if st then
        (
            try ( IsolateSelection.ExitIsolateSelectionMode() ) catch ()
            lbl_scene_status.text = "已退出孤立模式"
        )
        else
        (
            if selection.count == 0 then
            (
                messageBox "请先选择要孤立显示的对象。" title:"labor"
                return false
            )
            try ( IsolateSelection.EnterIsolateSelectionMode() ) catch ()
            lbl_scene_status.text = "已进入孤立模式"
        )
    )

    on btn_sel_nomat pressed do
    (
        local n = labor_select_no_material()
        lbl_scene_status.text = ("已选择无材质对象: " + (n as string) + " 个")
    )

    on btn_sel_miss pressed do
    (
        local arr = labor_objects_missing_texture()
        if arr.count > 0 then
        (
            try ( select arr ) catch ()
        )
        else
        (
            try ( clearSelection() ) catch ()
        )
        lbl_scene_status.text = ("已选择缺贴图对象: " + (arr.count as string) + " 个")
    )

    on btn_sel_same pressed do
    (
        local n = labor_select_same_material()
        if n == 0 then
            lbl_scene_status.text = "请先选中一个带材质的对象"
        else
            lbl_scene_status.text = ("已选择同材质对象: " + (n as string) + " 个")
    )

    on btn_sel_inv pressed do
    (
        local n = labor_invert_selection()
        lbl_scene_status.text = ("反选: " + (n as string) + " 个对象")
    )

    on btn_rename pressed do
    (
        local objs = scene_objs()
        if objs.count == 0 do
        (
            messageBox "没有可重命名的对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_rename" on
        (
            n = labor_batch_rename objs edt_find.text edt_rep.text edt_pre.text edt_suf.text chk_index.checked
        )
        lbl_scene_status.text = ("已重命名: " + (n as string) + " 个对象")
    )
)

--------------------------------------------------------------------------------
-- end of file : labor_ui_scene.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ui_scene.ms is only a module, please run labor.ms to open the panel.\n"
)
