/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_ui_materials.ms
   module  : ui : 3. materials
   desc    : rollout labor_roll_mat
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     one rollout (labor_roll_mat), loaded by labor.ms,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

rollout labor_roll_mat "③ 材质工具"
(
    group "材质转换"
    (
        checkbox chk_sel_mat "仅处理选中对象" checked:true align:#left
        button btn_to_vray   "Standard → VRay"  width:145 height:24 across:2 align:#left
        button btn_to_std    "VRay → Standard"  width:145 height:24 align:#left
        button btn_pbr2std   "PBR → Standard"   width:145 height:24 across:2 align:#left
        button btn_pbr2vray  "PBR → VRay"       width:145 height:24 align:#left
    )

    group "快速材质"
    (
        button btn_rnd_mat  "随机材质"   width:145 height:24 across:2 align:#left
        button btn_wire_mat "线框色材质" width:145 height:24 align:#left
        button btn_clear_me "清空材质编辑器" width:300 height:24 align:#left
    )

    label lbl_mat_status "状态: 就绪" width:300 align:#left
    progressbar prg_mat width:300 height:10 align:#left

    fn run_conv src_class convert_fn label_str =
    (
        local objs = labor_get_targets chk_sel_mat.checked
        if objs.count == 0 do
        (
            messageBox "没有可处理的对象。" title:"labor"
            return false
        )

        prg_mat.value = 0
        lbl_mat_status.text = label_str + " 进行中..."
        local n = 0
        undo ("labor_" + label_str) on
        (
            n = labor_convert_materials objs src_class convert_fn
        )
        prg_mat.value = 100
        lbl_mat_status.text = (label_str + " 完成: " + (n as string) + " 个材质")
        try ( completeRedraw() ) catch ()
    )

    on btn_to_vray pressed do
    (
        if (classOf VRayMtl) == UndefinedClass then
            ( messageBox "未检测到 VRay 插件，无法转换。" title:"labor" )
        else run_conv StandardMaterial labor_std_to_vray "转 VRay"
    )

    on btn_to_std pressed do
    (
        if (classOf VRayMtl) == UndefinedClass then
            ( messageBox "未检测到 VRay 插件，无法转换。" title:"labor" )
        else run_conv VRayMtl labor_vray_to_std "转 Standard"
    )

    on btn_pbr2std pressed do
    (
        if (classOf PBRMetalRough) == UndefinedClass then
            ( messageBox "当前 Max 版本没有 PBRMetalRough 材质类。" title:"labor" )
        else run_conv PBRMetalRough labor_pbr_to_std "PBR 转 Standard"
    )

    on btn_pbr2vray pressed do
    (
        if (classOf PBRMetalRough) == UndefinedClass then
            ( messageBox "当前 Max 版本没有 PBRMetalRough 材质类。" title:"labor" )
        else run_conv PBRMetalRough labor_pbr_to_vray "PBR 转 VRay"
    )

    on btn_rnd_mat pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        undo "labor_random_material" on
        (
            for o in objs do
            (
                local m = StandardMaterial()
                m.name = o.name + "_Rnd"
                m.diffuse = color (random 0 255) (random 0 255) (random 0 255)
                o.material = m
            )
        )
        lbl_mat_status.text = ("已生成随机材质: " + (objs.count as string) + " 个")
        try ( redrawViews() ) catch ()
    )

    on btn_wire_mat pressed do
    (
        local objs = labor_get_targets true
        if objs.count == 0 do
        (
            messageBox "请先选择对象。" title:"labor"
            return false
        )
        undo "labor_wire_material" on
        (
            for o in objs do
            (
                local m = StandardMaterial()
                m.name = o.name + "_ID"
                m.diffuse = o.wirecolor
                m.selfIllumAmount = 100.0
                o.material = m
            )
        )
        lbl_mat_status.text = ("已生成线框色材质: " + (objs.count as string) + " 个")
        try ( redrawViews() ) catch ()
    )

    on btn_clear_me pressed do
    (
        if not (queryBox "将把材质编辑器的所有材质球替换为默认标准材质，是否继续？" title:"labor") do return false
        for i = 1 to meditMaterials.count do
        (
            try ( meditMaterials[i] = StandardMaterial() ) catch ()
        )
        lbl_mat_status.text = "材质编辑器已清空"
    )
)

--------------------------------------------------------------------------------
-- end of file : labor_ui_materials.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_ui_materials.ms is only a module, please run labor.ms to open the panel.\n"
)
