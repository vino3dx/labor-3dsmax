/* =========================================================
   脚本名称：
       PBRMetalRough → Scanline Standard 材质转换工具

   功能说明：
       将 Datasmith / Twinmotion / glTF 等导入的
       PBRMetalRough（金属度 / 粗糙度）材质
       转换为 3ds Max 传统 Scanline 渲染器可用的
       Standard（标准）材质。

   转换规则：
       - Base Color      → Diffuse
       - Roughness       → Glossiness（自动反转）
       - Metalness       → Specular Level
       - Normal Map      → Normal Bump
       - Emission        → Self-Illumination
       - Opacity         → Opacity

   使用方法：
       1. 在场景中选中一个或多个模型
       2. 运行本脚本
       3. 脚本会自动将其材质替换为 Scanline 标准材质

   适用版本：
       3ds Max 2025（理论上 2022+ 均可）

   注意事项：
       - 仅处理材质类型为 PBRMetalRough 的物体
       - 不影响原贴图资源，仅转换材质结构
       - 会直接覆盖物体当前材质（不可逆，建议先保存）

   作者用途：
       技术美术 / 资产整理 / 引擎导入资产兼容
========================================================= */

(
    /* =====================================================
       函数：PBRMetalRough_To_Scanline
       作用：
           将单个 PBRMetalRough 材质转换为
           Scanline Standard 材质
    ===================================================== */
    fn PBRMetalRough_To_Scanline oldMat =
    (
        -- 安全检查
        if oldMat == undefined then return undefined
        if classOf oldMat != PBRMetalRough then return undefined
        
        -- 创建新的 Scanline 标准材质
        local newMat = StandardMaterial()
        newMat.name = oldMat.name + "_Scanline"
        
        /* ---------------------------------
           1. Base Color → Diffuse
        --------------------------------- */
        if oldMat.base_color_map != undefined then
        (
            -- 如果有 Base Color 贴图，直接接入 Diffuse
            newMat.diffuseMap = oldMat.base_color_map
            newMat.diffuseMapEnable = true
        )
        else
        (
            -- 否则使用纯色
            newMat.diffuse = oldMat.baseColor
        )
        
        /* ---------------------------------
           2. Roughness → Glossiness（反转）
        --------------------------------- */
        if oldMat.Roughness_Map != undefined then
        (
            -- Roughness 需要反转成 Glossiness
            local cc = Color_Correction()
            cc.map = oldMat.Roughness_Map
            cc.invert = true
            
            newMat.glossinessMap = cc
            newMat.glossinessMapEnable = true
        )
        else
        (
            -- 数值模式下同样进行反转
            newMat.glossiness = 100 - (oldMat.roughness * 100)
        )
        
        /* ---------------------------------
           3. Metalness → Specular Level
        --------------------------------- */
        if oldMat.metalness_map != undefined then
        (
            newMat.specularLevelMap = oldMat.metalness_map
            newMat.specularLevelMapEnable = true
        )
        else
        (
            newMat.specularLevel = oldMat.metalness * 100
        )
        
        /* ---------------------------------
           4. Normal Map → Normal Bump
        --------------------------------- */
        if oldMat.norm_map != undefined then
        (
            local nb = Normal_Bump()
            nb.normal_map = oldMat.norm_map
            
            newMat.bumpMap = nb
            newMat.bumpMapEnable = true
            newMat.bumpMapAmount = oldMat.bump_map_amt
        )
        
        /* ---------------------------------
           5. Emission → Self-Illumination
        --------------------------------- */
        if oldMat.emit_color_map != undefined then
        (
            newMat.selfIllumMap = oldMat.emit_color_map
            newMat.selfIllumMapEnable = true
            newMat.selfIllumAmount = 100
        )
        
        /* ---------------------------------
           6. Opacity（透明贴图）
        --------------------------------- */
        if oldMat.opacity_map != undefined then
        (
            newMat.opacityMap = oldMat.opacity_map
            newMat.opacityMapEnable = true
        )
        
        /* ---------------------------------
           7. 防止材质过暗的兜底设置
        --------------------------------- */
        newMat.specularLevel = amax newMat.specularLevel 30
        newMat.glossiness    = amax newMat.glossiness 20
        
        -- 返回新材质
        newMat
    )
    
    
    /* =====================================================
       主执行逻辑
    ===================================================== */
    if selection.count == 0 then
    (
        messageBox "请先选中需要转换材质的模型！"
    )
    else
    (
        local count = 0
        
        -- 遍历选中物体
        for obj in selection do
        (
            if obj.material != undefined and classOf obj.material == PBRMetalRough then
            (
                -- 强制替换物体材质
                obj.material = PBRMetalRough_To_Scanline obj.material
                count += 1
            )
        )
        
        format "转换完成：% 个 PBRMetalRough 材质已成功转为 Scanline 标准材质。\n" count
        redrawViews()
    )
)
