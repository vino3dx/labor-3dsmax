rollout MaterialConverter "材质转换器" width:320 height:260
(
    button btnToVray "转VRay材质" pos:[20,20] width:130 height:30
    button btnToStd "转标准材质" pos:[160,20] width:130 height:30
    checkbox chkSelection "仅转换选中对象" pos:[20,60] checked:true
    progressbar prgProgress "进度" pos:[20,100] width:280 height:15
    label lblStatus "就绪" pos:[20,125] width:280 height:20
    button btnToggleTextures "切换视口显示纹理" pos:[20,150] width:280 height:30
    button btnAlignObjects "多对象对齐" pos:[20,185] width:280 height:30
    
    --------------------------------------------------------------------------------
    -- VRay材质和扫描线standard标准材质相互转换
    --------------------------------------------------------------------------------

    -- 核心转换函数：标准材质转VRay材质
    fn ConvertStandardToVray stdMat = 
    (
        try (
            -- 检查VRayMtl是否可用
            if (classof VRayMtl) == UndefinedClass do return undefined
            
            local vrayMat = VRayMtl()
            
            -- 基础属性
            vrayMat.name = stdMat.name + "_VRAY"
            vrayMat.diffuse = stdMat.diffuse
            
            -- 自发光系统（使用安全属性检查）
            if isProperty stdMat #selfIllumColor then vrayMat.selfIllumination = stdMat.selfIllumColor
            if isProperty stdMat #selfIllum then vrayMat.selfIllumination_multiplier = stdMat.selfIllum / 100.0
            
            -- 透明度系统
            if isProperty stdMat #opacity then (
                local opacityValue = (100.0 - stdMat.opacity) / 100.0
                vrayMat.refraction = color opacityValue opacityValue opacityValue
            )
            
            -- 高光系统
            if isProperty stdMat #specular then vrayMat.reflection = stdMat.specular
            if isProperty stdMat #glossiness then vrayMat.reflection_glossiness = stdMat.glossiness / 100.0
            if isProperty stdMat #specularLevel then vrayMat.hilight_glossiness = stdMat.specularLevel / 100.0
            
            -- 贴图系统
            if isProperty stdMat #diffuseMap and stdMat.diffuseMap != undefined then (
                vrayMat.texmap_diffuse = copy stdMat.diffuseMap
                if classof vrayMat.texmap_diffuse == BitmapTexture then (
                    vrayMat.texmap_diffuse.filename = stdMat.diffuseMap.filename
                    vrayMat.texmap_diffuse.coords = copy stdMat.diffuseMap.coords
                )
            )
            
            if isProperty stdMat #bumpMap and stdMat.bumpMap != undefined then (
                vrayMat.texmap_bump = copy stdMat.bumpMap
                if isProperty vrayMat #texmap_bump_multiplier then (
                    vrayMat.texmap_bump_multiplier = if isProperty stdMat #bumpMapAmount then stdMat.bumpMapAmount / 100.0 else 1.0
                )
            )
            
            return vrayMat
        )
        catch (
            format "转换错误：%\n" (getCurrentException())
            return undefined
        )
    )

    -- 核心转换函数：VRay材质转标准材质
    fn ConvertVrayToStandard vrayMat = 
    (
        try (
            local stdMat = StandardMaterial()
            stdMat.name = vrayMat.name + "_STD"
            
            -- 基础颜色
            if isProperty vrayMat #diffuse then stdMat.diffuse = vrayMat.diffuse
            
            -- 自发光系统（使用更安全的属性检查）
            if isProperty vrayMat #selfIllumination do (
                -- 正确设置自发光颜色
                if isProperty stdMat #selfIllumColor then
                    stdMat.selfIllumColor = vrayMat.selfIllumination
                
                -- 正确设置自发光强度（0-100转换）
                if isProperty vrayMat #selfIllumination_multiplier and
                   isProperty stdMat #selfIllum then
                (
                    stdMat.selfIllum = vrayMat.selfIllumination_multiplier * 100.0
                )
            )
            
            -- 透明系统
            if isProperty vrayMat #refraction and classOf vrayMat.refraction == Color then (
                local avgRefraction = (vrayMat.refraction.r + vrayMat.refraction.g + vrayMat.refraction.b) / 3.0
                stdMat.opacity = 100.0 * (1.0 - avgRefraction)
            )
            
            -- 高光系统
            if isProperty vrayMat #reflection then stdMat.specular = vrayMat.reflection
            if isProperty vrayMat #reflection_glossiness then stdMat.glossiness = vrayMat.reflection_glossiness * 100.0
            if isProperty vrayMat #hilight_glossiness then stdMat.specularLevel = vrayMat.hilight_glossiness * 100.0
            
            -- 贴图系统
            if isProperty vrayMat #texmap_diffuse and vrayMat.texmap_diffuse != undefined then (
                stdMat.diffuseMap = copy vrayMat.texmap_diffuse
                if classof stdMat.diffuseMap == BitmapTexture then (
                    stdMat.diffuseMap.filename = vrayMat.texmap_diffuse.filename
                    stdMat.diffuseMap.coords = copy vrayMat.texmap_diffuse.coords
                )
            )
            
            if isProperty vrayMat #texmap_bump and vrayMat.texmap_bump != undefined then (
                stdMat.bumpMap = copy vrayMat.texmap_bump
                if isProperty stdMat #bumpMapAmount then (
                    stdMat.bumpMapAmount = if isProperty vrayMat #texmap_bump_multiplier then vrayMat.texmap_bump_multiplier * 100.0 else 30.0
                )
            )
            
            return stdMat
        )
        catch (
            format "转换错误：%\n" (getCurrentException())
            return undefined
        )
    )

    -- 转换执行器
    fn ProcessConversion convertFn srcClass = 
    (
        try (
            local targetObjects = if chkSelection.checked and selection.count > 0 then selection else geometry
            local successCount = 0
            local total = targetObjects.count
            
            lblStatus.text = "开始转换..."
            prgProgress.value = 0
            
            for i = 1 to total do (
                local obj = targetObjects[i]
                if not isValidNode obj do continue
                
                if obj.material != undefined and (classof obj.material) == srcClass do (
                    local newMat = convertFn obj.material
                    if newMat != undefined do (
                        obj.material = newMat
                        successCount += 1
                    )
                )
                prgProgress.value = (i / total) * 100
            )
            
            lblStatus.text = "转换完成！成功转换 " + (successCount as string) + " 个材质"
            completeRedraw()
        )
        catch (
            lblStatus.text = "转换过程中发生错误！"
            format "处理错误：%\n" (getCurrentException())
        )
    )

    on btnToVray pressed do
    (
        if (classof VRayMtl) == UndefinedClass then (
            messageBox "未检测到VRay插件，无法执行转换！"
        )
        else (
            ProcessConversion ConvertStandardToVray StandardMaterial
        )
    )

    on btnToStd pressed do
    (
        ProcessConversion ConvertVrayToStandard VRayMtl
    )

    --------------------------------------------------------------------------------
    -- 切换视口显示纹理按钮的功能
    --------------------------------------------------------------------------------
    local toggleTexturesState = false -- 按钮的点击状态

    fn ToggleViewportTextures newState =
    (
        for matClass in material.classes do (
            for m in (getclassinstances matClass processChildren:true) do (
                if (refs.dependentNodes m).count>0 then (
                    if classof m != Multimaterial then (
                        if (classOf m) == FStorm then (
                            if (classOf m.diffuse_tex) == FStormBitmap then showTexturemap m m.diffuse_tex newState
                        ) else (
                            showTexturemap m newState
                        )
                    )
                )
            )
        )
    )

    on btnToggleTextures pressed do
    (
        toggleTexturesState = not toggleTexturesState
        ToggleViewportTextures toggleTexturesState
        if toggleTexturesState then
            btnToggleTextures.text = "关闭视口显示纹理"
        else
            btnToggleTextures.text = "开启视口显示纹理"
    ) 

    -- 多对象对齐功能
    global amo_floater
    global amo_pos = [500,300]

    rollout amo_cont "多对象对齐"
    (
        local axis = "x"
        local offset = 0
        local use_bbox = true
        
        function alignMultiple objArr mainAxis = (
            
            local separations_x = #()
            local separations_y = #()
            local separations_z = #()
        
            if use_bbox==true then (
                for cc=2 to objArr.count do (
                    separations_x[cc-1] = (objArr[cc-1].max.x - objArr[cc-1].pos.x) + (objArr[cc].pos.x - objArr[cc].min.x)
                    separations_y[cc-1] = (objArr[cc-1].max.y - objArr[cc-1].pos.y) + (objArr[cc].pos.y - objArr[cc].min.y)
                    separations_z[cc-1] = (objArr[cc-1].max.z - objArr[cc-1].pos.z) + (objArr[cc].pos.z - objArr[cc].min.z)
                )
            ) else (
                for cc=2 to objArr.count do (
                    separations_x[cc-1] = 0
                    separations_y[cc-1] = 0
                    separations_z[cc-1] = 0
                )
            )
            
            for dd=2 to objArr.count do (
                posx = objArr[1].pos.x
                posy = objArr[1].pos.y
                posz = objArr[1].pos.z            
                
                if mainAxis=="x" then (
                    posx = objArr[dd-1].pos.x + separations_x[dd-1] + offset
                ) else if mainAxis=="y" then (
                    posy = objArr[dd-1].pos.y + separations_y[dd-1] + offset
                ) else (
                    posz = objArr[dd-1].pos.z + separations_z[dd-1] + offset
                )            
                objArr[dd].pos = [posx,posy,posz]
            )
        )
        
        Group "对齐轴心"
        (
            radiobuttons rb_axis columns:3 labels:#("X", "Y", "Z") offsets:#([15,0], [10,0], [10,0]) align:#center default:1
        )
        spinner spn_offset "偏移..........." range:[0,10000,offset] type:#worldunits fieldwidth:50 align:#center offset:[0,6]
        checkbox boundingBox "使用边界框" checked:use_bbox align:#center offset:[0,4]
        button btn_align "-对齐选定对象-" width:140 height:30 align:#center offset:[0,4]
        
        on rb_axis changed state do
        (
            if rb_axis.state==1 then (
                axis = "x"
            ) else if rb_axis.state==2 then (
                axis = "y"
            ) else (
                axis = "z"
            )
        )
        
        on boundingBox changed theState do
        (
            if boundingBox.checked == true then (
                use_bbox = true
            ) else (
                use_bbox = false
            )            
        )
        
        on btn_align pressed do
        (            
            if (selection.count > 0) then
            (
                undo "多对象对齐工具" on (
                    offset = spn_offset.value
                    alignMultiple (selection as array) axis        
                )
            ) else (
                messagebox "请选择对象"
            )    
        )
    ) -- end rollout

    on btnAlignObjects pressed do
    (
        try (
            closerolloutfloater amo_floater
            amo_pos = amo_floater.pos
        ) catch ()
        amo_floater = newrolloutfloater "多对象对齐工具V2.4" 300 180
        amo_floater.pos = amo_pos
        addrollout amo_cont amo_floater rolledup:false
    )
) -- 这是结尾

createDialog MaterialConverter