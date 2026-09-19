/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ui_model.ms
   module  : ui : 4. model
   desc    : rollout labor_roll_model
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     one rollout (labor_roll_model), loaded by labor.ms,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

rollout labor_roll_model "④ 模型工具"
(
    group "顺序对齐"
    (
        radiobuttons rb_axis "对齐轴" labels:#("X", "Y", "Z") columns:3 align:#left
        spinner spn_offset "间距偏移" range:[-100000, 100000, 0] type:#worldunits fieldwidth:70 align:#left
        checkbox chk_bbox "使用边界框 (BBox)" checked:true align:#left
        button btn_align "顺序对齐选中对象" width:300 height:26 align:#left
    )

    group "落地 / 轴心"
    (
        button btn_ground "选中对象吸附地面 (Z=0)" width:300 height:24 align:#left
        button btn_pivot_c "轴心 → 底部中心" width:145 height:24 across:2 align:#left
        button btn_pivot_g "轴心 → 几何中心" width:145 height:24 align:#left
    )

    group "网格处理"
    (
        button btn_collapse "塌陷修改器堆栈" width:145 height:24 across:2 align:#left
        button btn_to_poly  "转为可编辑多边形" width:145 height:24 align:#left
        button btn_flip_norm  "翻转法线" width:145 height:24 across:2 align:#left
        button btn_unify_norm "统一法线" width:145 height:24 align:#left
        button btn_auto_smooth "自动平滑" width:145 height:24 across:2 align:#left
        button btn_clear_sg    "清除平滑组" width:145 height:24 align:#left
        spinner spn_weld "焊接阈值" range:[0, 10000, 0.1] type:#worldunits fieldwidth:70 align:#left
        button btn_weld "焊接顶点" width:145 height:24 across:2 align:#left
        button btn_open_edges "检查开放边" width:145 height:24 align:#left
    )

    label lbl_model_status "状态: 就绪" width:300 align:#left

    on btn_align pressed do
    (
        local objs = selection as array
        if objs.count < 2 do
        (
            messageBox "请至少选择两个对象。" title:"labor"
            return false
        )
        undo "labor_align" on
        (
            labor_align_objects objs rb_axis.state spn_offset.value chk_bbox.checked
        )
        lbl_model_status.text = ("已对齐 " + (objs.count as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_ground pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        undo "labor_ground" on
        (
            for o in objs where (labor_valid_geom o) do
            (
                local bb = labor_node_bounds o
                o.pos = [o.pos.x, o.pos.y, o.pos.z - bb[1].z]
            )
        )
        lbl_model_status.text = ("已落地 " + (objs.count as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_pivot_c pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        undo "labor_pivot_bottom" on ( labor_pivot_process objs 1 false )
        lbl_model_status.text = ("轴心已置底: " + (objs.count as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_pivot_g pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        undo "labor_pivot_center" on ( labor_pivot_process objs 4 false )
        lbl_model_status.text = ("轴心已居中: " + (objs.count as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_collapse pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        if not (queryBox "将塌陷所选对象的修改器堆栈（不可逆，建议先保存）。\n是否继续？" title:"labor") do return false
        local n = 0
        undo "labor_collapse" on
        (
            n = labor_collapse_stack objs false
        )
        lbl_model_status.text = ("已塌陷堆栈: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_to_poly pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_to_poly" on
        (
            n = labor_collapse_stack objs true
        )
        lbl_model_status.text = ("已转为可编辑多边形: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_flip_norm pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_flip_normals" on
        (
            n = labor_normals_fix objs true false
        )
        lbl_model_status.text = ("已翻转法线: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_unify_norm pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_unify_normals" on
        (
            n = labor_normals_fix objs false true
        )
        lbl_model_status.text = ("已统一法线: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_auto_smooth pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_auto_smooth" on
        (
            n = labor_auto_smooth objs 30.0
        )
        lbl_model_status.text = ("已自动平滑(30°): " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_clear_sg pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_clear_smooth" on
        (
            n = labor_clear_smooth_groups objs
        )
        lbl_model_status.text = ("已清除平滑组: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_weld pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        local n = 0
        undo "labor_weld" on
        (
            n = labor_weld_verts objs spn_weld.value
        )
        lbl_model_status.text = ("已焊接顶点: " + (n as string) + " 个对象")
        try ( redrawViews() ) catch ()
    )

    on btn_open_edges pressed do
    (
        local objs = labor_get_targets true
        local lst = labor_open_edges_report objs
        labor_log "---- open edges ----"
        for it in lst do labor_log (it[1] + " : " + (it[2] as string) + " 条开放边")
        lbl_model_status.text = ("发现开放边对象: " + (lst.count as string) + " 个，详见监听器")
    )
)

--------------------------------------------------------------------------------
-- end of file : labor_ui_model.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ui_model.ms is only a module, please run labor.ms to open the panel.\n"
)
