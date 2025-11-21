/*===============================
  Matic 专业工具集 v1.0
  功能：材质转换 / 随机材质 / 模型对齐
  作者：Vino
===============================*/

try (closerolloutfloater MaticFloater) catch()
MaticFloater = newrolloutfloater "Matic 专业工具集 v1.0" 340 420

/*----------------------------------------
  材质操作 Rollout
----------------------------------------*/
rollout materialRollout "材质操作" width:320 height:160
(
    button btnToVray "转 VRay 材质" width:140 height:25 across:2
    button btnToStd "转 标准材质" width:140 height:25
    checkbox chkSelection "仅转换选中对象" checked:true
    
    button btnRandomMat "随机材质" width:100 height:25 across:3
    button btnWireColorMat "线框颜色材质" width:100 height:25
    button btnToggleTextures "切换纹理显示" width:100 height:25
    
    label lblStatus "状态：就绪" width:300
    
    progressbar prgProgress "" width:300 height:12
    
    /*----------------------------------------
      标准材质 -> VRay
    ----------------------------------------*/
    fn ConvertStandardToVray stdMat =
    (
        if not (doesClassExist VRayMtl) then return undefined
        local vrayMat = VRayMtl name:(stdMat.name + "_VRAY")
        vrayMat.diffuse = stdMat.diffuse
        if isProperty stdMat #selfIllumColor do vrayMat.selfIllumination = stdMat.selfIllumColor
        if isProperty stdMat #selfIllum do vrayMat.selfIllumination_multiplier = stdMat.selfIllum/100.0
        if isProperty stdMat #opacity do vrayMat.refraction = color (1-stdMat.opacity/100.0) (1-stdMat.opacity/100.0) (1-stdMat.opacity/100.0)
        if isProperty stdMat #specular do vrayMat.reflection = stdMat.specular
        if isProperty stdMat #glossiness do vrayMat.reflection_glossiness = stdMat.glossiness/100.0
        if isProperty stdMat #specularLevel do vrayMat.hilight_glossiness = stdMat.specularLevel/100.0
        
        if isProperty stdMat #diffuseMap and stdMat.diffuseMap != undefined do vrayMat.texmap_diffuse = stdMat.diffuseMap
        if isProperty stdMat #bumpMap and stdMat.bumpMap != undefined do (
            vrayMat.texmap_bump = stdMat.bumpMap
            if isProperty vrayMat #texmap_bump_multiplier do vrayMat.texmap_bump_multiplier = stdMat.bumpMapAmount/100.0
        )
        vrayMat
    )
    
    /*----------------------------------------
      VRay -> 标准材质
    ----------------------------------------*/
    fn ConvertVrayToStandard vrayMat =
    (
        local stdMat = standardMaterial name:(vrayMat.name + "_STD")
        if isProperty vrayMat #diffuse do stdMat.diffuse = vrayMat.diffuse
        if isProperty vrayMat #selfIllumination do stdMat.selfIllumColor = vrayMat.selfIllumination
        if isProperty vrayMat #selfIllumination_multiplier do stdMat.selfIllum = vrayMat.selfIllumination_multiplier*100.0
        if isProperty vrayMat #refraction do (
            local avg = (vrayMat.refraction.r+vrayMat.refraction.g+vrayMat.refraction.b)/3.0
            stdMat.opacity = 100.0*(1-avg)
        )
        if isProperty vrayMat #reflection do stdMat.specular = vrayMat.reflection
        if isProperty vrayMat #reflection_glossiness do stdMat.glossiness = vrayMat.reflection_glossiness*100.0
        if isProperty vrayMat #hilight_glossiness do stdMat.specularLevel = vrayMat.hilight_glossiness*100.0
        if isProperty vrayMat #texmap_diffuse do stdMat.diffuseMap = vrayMat.texmap_diffuse
        if isProperty vrayMat #texmap_bump do (
            stdMat.bumpMap = vrayMat.texmap_bump
            if isProperty vrayMat #texmap_bump_multiplier do stdMat.bumpMapAmount = vrayMat.texmap_bump_multiplier*100.0
        )
        stdMat
    )
    
    /*----------------------------------------
      执行材质转换
    ----------------------------------------*/
    fn ProcessConversion convertFn srcClass =
    (
        local objs = if chkSelection.checked and selection.count>0 then selection else geometry
        local total = objs.count
        local success = 0
        prgProgress.value = 0
        lblStatus.text = "开始转换..."
        
        for i=1 to total do (
            local o = objs[i]
            if isValidNode o and o.material!=undefined and (classof o.material)==srcClass do (
                local newMat = convertFn o.material
                if newMat != undefined do (
                    o.material = newMat
                    success += 1
                )
            )
            prgProgress.value = (i/total)*100
        )
        lblStatus.text = "完成，成功转换 " + success as string + " 个材质"
    )
    
    /* 按钮事件 */
    on btnToVray pressed do (
        if (doesClassExist VRayMtl) then
            ProcessConversion ConvertStandardToVray StandardMaterial
        else messageBox "未检测到 VRay 插件"
    )
    on btnToStd pressed do ProcessConversion ConvertVrayToStandard VRayMtl
    
    on btnRandomMat pressed do (
        if selection.count==0 then (messageBox "请选择对象") else (
            for o in selection do (
                local m = standardMaterial name:(o.name+"_RandomMat")
                m.diffuse = color (random 0 255) (random 0 255) (random 0 255)
                o.material = m
            )
            lblStatus.text = "已生成随机材质"
        )
    )
    
    on btnWireColorMat pressed do (
        if selection.count==0 then (messageBox "请选择对象") else (
            for o in selection do (
                local m = standardMaterial name:(o.name+"_WireColorMat")
                m.diffuse = o.wirecolor
                o.material = m
            )
            lblStatus.text = "已生成线框材质"
        )
    )
    
    local toggleState = false
    on btnToggleTextures pressed do (
        toggleState = not toggleState
        showTextureMap (getMeditMaterial 1) toggleState
        lblStatus.text = "纹理显示: " + (if toggleState then "开" else "关")
    )
)

/*----------------------------------------
  模型对齐 Rollout
----------------------------------------*/
rollout modelRollout "模型工具" width:320 height:120
(
    radiobuttons rb_axis "对齐轴" labels:#("X","Y","Z") columns:3
    spinner spn_offset "偏移:" range:[-10000,10000,0] type:#worldunits
    checkbox chkBBox "使用边界框" checked:true
    button btnAlign "执行对齐" width:120 height:25
    
    fn alignMultiple objs axis offset useBBox =
    (
        if objs.count<2 then return()
        for i=2 to objs.count do (
            local bbPrev = nodeGetBoundingBox objs[i-1] objs[i-1].transform
            local bbCurr = nodeGetBoundingBox objs[i] objs[i].transform
            local pos = objs[i].pos
            case axis of (
                1: pos.x = bbPrev[2].x + offset + (if useBBox then (objs[i].pos.x - bbCurr[1].x) else 0)
                2: pos.y = bbPrev[2].y + offset + (if useBBox then (objs[i].pos.y - bbCurr[1].y) else 0)
                3: pos.z = bbPrev[2].z + offset + (if useBBox then (objs[i].pos.z - bbCurr[1].z) else 0)
            )
            objs[i].pos = pos
        )
    )
    
    on btnAlign pressed do (
        if selection.count<2 then messageBox "请至少选择两个对象" else (
            undo "对象对齐" on (
                alignMultiple (selection as array) rb_axis.state spn_offset.value chkBBox.checked
            )
        )
    )
)

/*----------------------------------------
  信息 Rollout
----------------------------------------*/
rollout infoRollout "关于 Matic" width:320 height:100
(
    group "作者信息"
    (
        hyperlink myBlog "博客网址: vinofx.com" align:#left
        hyperlink myBili "哔哩哔哩: https://space.bilibili.com/250546761?spm_id_from=333.788.0.0" align:#left
        hyperlink myWeChat "微信公众号: Vino自习室" align:#left
    )

    on myBlog picked do (shellLaunch "https://vinofx.com" "")
    on myBili picked do (shellLaunch "https://b23.tv/xxxx" "")
    on myWeChat picked do (shellLaunch "https://vinceofx.github.io/wei-xin" "")
)

/*----------------------------------------
  添加到 Floater
----------------------------------------*/
addrollout modelRollout MaticFloater
addrollout materialRollout MaticFloater
addrollout infoRollout MaticFloater
