/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_materials.ms
   module  : materials / 材质工具
   desc    : safe property access / standard <-> vray / pbr metal rough -> standard / -> vray / convert dispatcher / random / wire color
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     material conversion helpers,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_set_prop, labor_get_prop, labor_std_to_vray, labor_vray_to_std, labor_pbr_to_std, labor_pbr_to_vray, labor_convert_materials

fn labor_set_prop obj prop val =
(
    if obj != undefined and (isProperty obj prop) then
    (
        try
        (
            setProperty obj prop val
            return true
        )
        catch ( return false )
    )
    false
)

fn labor_get_prop obj prop =
(
    if obj != undefined and (isProperty obj prop) then
    (
        try
        (
            return (getProperty obj prop)
        )
        catch ( return undefined )
    )
    undefined
)

-- standard -> vray
fn labor_std_to_vray m =
(
    if (classOf VRayMtl) == UndefinedClass do return undefined
    local v = VRayMtl()
    v.name = m.name + "_VRAY"

    labor_set_prop v #diffuse m.diffuse
    if isProperty m #selfIllumColor do labor_set_prop v #selfIllumination m.selfIllumColor
    if isProperty m #selfIllum   do labor_set_prop v #selfIllumination_multiplier (m.selfIllum / 100.0)

    try
    (
        local op = (100.0 - m.opacity) / 100.0
        labor_set_prop v #refraction (color op op op)
    )
    catch ()

    if isProperty m #specular      do labor_set_prop v #reflection m.specular
    if isProperty m #glossiness    do labor_set_prop v #reflection_glossiness (m.glossiness / 100.0)
    if isProperty m #specularLevel do labor_set_prop v #hilight_glossiness (m.specularLevel / 100.0)

    if (labor_get_prop m #diffuseMap) != undefined do labor_set_prop v #texmap_diffuse m.diffuseMap
    if (labor_get_prop m #bumpMap) != undefined do
    (
        labor_set_prop v #texmap_bump m.bumpMap
        local amt = 1.0
        try ( amt = m.bumpMapAmount / 100.0 ) catch ( amt = 1.0 )
        labor_set_prop v #texmap_bump_multiplier amt
    )
    if (labor_get_prop m #opacityMap)    != undefined do labor_set_prop v #texmap_opacity m.opacityMap
    if (labor_get_prop m #selfIllumMap)  != undefined do labor_set_prop v #texmap_self_illumination m.selfIllumMap
    if (labor_get_prop m #reflectionMap) != undefined do labor_set_prop v #texmap_reflection m.reflectionMap
    v
)

-- vray -> standard
fn labor_vray_to_std m =
(
    local s = StandardMaterial()
    s.name = m.name + "_STD"

    local d = labor_get_prop m #diffuse
    if d != undefined do s.diffuse = d

    local si = labor_get_prop m #selfIllumination
    if si != undefined do labor_set_prop s #selfIllumColor si
    local sim = labor_get_prop m #selfIllumination_multiplier
    if sim != undefined do labor_set_prop s #selfIllum (sim * 100.0)

    local rf = labor_get_prop m #refraction
    if rf != undefined and (classOf rf) == Color do
    (
        local avg = (rf.r + rf.g + rf.b) / 3.0
        s.opacity = 100.0 * (1.0 - avg)
    )

    local refl = labor_get_prop m #reflection
    if refl != undefined do s.specular = refl
    local rg = labor_get_prop m #reflection_glossiness
    if rg != undefined do s.glossiness = rg * 100.0
    local hg = labor_get_prop m #hilight_glossiness
    if hg != undefined do s.specularLevel = hg * 100.0

    local td = labor_get_prop m #texmap_diffuse
    if td != undefined do s.diffuseMap = td
    local tb = labor_get_prop m #texmap_bump
    if tb != undefined do
    (
        s.bumpMap = tb
        local amt = labor_get_prop m #texmap_bump_multiplier
        if amt == undefined do amt = 0.3
        s.bumpMapAmount = amt * 100.0
    )
    local to = labor_get_prop m #texmap_opacity
    if to != undefined do s.opacityMap = to
    s
)

-- pbr metal rough (datasmith / gltf / twinmotion) -> standard
fn labor_pbr_to_std m =
(
    local s = StandardMaterial()
    s.name = m.name + "_Scanline"

    local bc = labor_get_prop m #base_color_map
    if bc != undefined then
    (
        s.diffuseMap = bc
        labor_set_prop s #diffuseMapEnable true
    )
    else
    (
        local c = labor_get_prop m #baseColor
        if c != undefined do s.diffuse = c
    )

    local rm = labor_get_prop m #Roughness_Map
    if rm != undefined then
    (
        local cc = Color_Correction()
        cc.map = rm
        cc.invert = true
        s.glossinessMap = cc
        labor_set_prop s #glossinessMapEnable true
    )
    else
    (
        local r = labor_get_prop m #roughness
        if r != undefined do s.glossiness = 100.0 - (r * 100.0)
    )

    local mm = labor_get_prop m #metalness_map
    if mm != undefined then
    (
        s.specularLevelMap = mm
        labor_set_prop s #specularLevelMapEnable true
    )
    else
    (
        local mt = labor_get_prop m #metalness
        if mt != undefined do s.specularLevel = mt * 100.0
    )

    local nm = labor_get_prop m #norm_map
    if nm != undefined then
    (
        local nb = Normal_Bump()
        nb.normal_map = nm
        s.bumpMap = nb
        labor_set_prop s #bumpMapEnable true
        local ba = labor_get_prop m #bump_map_amt
        if ba != undefined do s.bumpMapAmount = ba
    )

    local em = labor_get_prop m #emit_color_map
    if em != undefined then
    (
        s.selfIllumMap = em
        labor_set_prop s #selfIllumMapEnable true
        s.selfIllumAmount = 100.0
    )

    local om = labor_get_prop m #opacity_map
    if om != undefined then
    (
        s.opacityMap = om
        labor_set_prop s #opacityMapEnable true
    )

    if s.specularLevel < 30.0 do s.specularLevel = 30.0
    if s.glossiness    < 20.0 do s.glossiness    = 20.0
    s
)

-- pbr metal rough -> vray
fn labor_pbr_to_vray m =
(
    if (classOf VRayMtl) == UndefinedClass do return undefined
    local v = VRayMtl()
    v.name = m.name + "_VRAY"

    local bc = labor_get_prop m #base_color_map
    if bc != undefined then
        labor_set_prop v #texmap_diffuse bc
    else
    (
        local c = labor_get_prop m #baseColor
        if c != undefined do labor_set_prop v #diffuse c
    )

    local rm = labor_get_prop m #Roughness_Map
    if rm != undefined then
    (
        local cc = Color_Correction()
        cc.map = rm
        cc.invert = true
        labor_set_prop v #texmap_reflectionGlossiness cc
        labor_set_prop v #texmap_reflectionGlossiness_multiplier 100.0
    )
    else
    (
        local r = labor_get_prop m #roughness
        if r != undefined do labor_set_prop v #reflection_glossiness (1.0 - r)
    )

    local mm = labor_get_prop m #metalness_map
    if mm != undefined then
        labor_set_prop v #texmap_metalness mm
    else
    (
        local mt = labor_get_prop m #metalness
        if mt != undefined do labor_set_prop v #metalness mt
    )

    local nm = labor_get_prop m #norm_map
    if nm != undefined then
    (
        local nb = Normal_Bump()
        nb.normal_map = nm
        labor_set_prop v #texmap_bump nb
        local ba = labor_get_prop m #bump_map_amt
        if ba != undefined do labor_set_prop v #texmap_bump_multiplier (ba / 100.0)
    )

    local em = labor_get_prop m #emit_color_map
    if em != undefined then
    (
        labor_set_prop v #texmap_self_illumination em
        labor_set_prop v #selfIllumination_multiplier 1.0
    )

    local om = labor_get_prop m #opacity_map
    if om != undefined do labor_set_prop v #texmap_opacity om

    local refl = labor_get_prop v #reflection
    if refl != undefined and refl == (color 0 0 0) do labor_set_prop v #reflection (color 40 40 40)
    v
)

-- generic converter (handles multi/sub-object materials, caches results)
fn labor_convert_materials objs src_class convert_fn =
(
    local cache_old = #()
    local cache_new = #()
    local count     = 0

    fn apply_conv sm cache_old cache_new convert_fn =
    (
        local idx = findItem cache_old sm
        local nm  = undefined
        if idx > 0 then
            nm = cache_new[idx]
        else
        (
            try ( nm = convert_fn sm ) catch ( nm = undefined )
            append cache_old sm
            append cache_new nm
        )
        nm
    )

    for o in objs where (labor_valid_geom o) do
    (
        local m = o.material
        if m != undefined do
        (
            if (classOf m) == src_class then
            (
                local nm = apply_conv m cache_old cache_new convert_fn
                if nm != undefined do
                (
                    o.material = nm
                    count += 1
                )
            )
            else if (classOf m) == Multimaterial then
            (
                for i = 1 to m.numsubs do
                (
                    local sm = undefined
                    try ( sm = m[i] ) catch ( sm = undefined )
                    if sm != undefined and (classOf sm) == src_class do
                    (
                        local nm = apply_conv sm cache_old cache_new convert_fn
                        if nm != undefined do
                        (
                            try ( m[i] = nm )
                            catch ( try ( m.materialList[i] = nm ) catch () )
                            count += 1
                        )
                    )
                )
            )
        )
    )
    count
)

--------------------------------------------------------------------------------
-- end of file : labor_materials.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_materials.ms is only a module, please run labor.ms to open the panel.\n"
)
