--------------------------------------------------------------------------------
-- Vino Scene Toolkit
-- Module 01 : Scene Scanner
-- file      : vino_scene_toolkit\scene_scanner.ms  (由 ../vino_scene_toolkit.ms 加载，也可单独运行)
-- version   : 0.1.0
-- author    : Vino  |  https://vinofx.com  |  https://github.com/vino3dx
-- license   : MIT
-- target    : 3ds Max 2018+ / MAXScript
--------------------------------------------------------------------------------
-- 目标
--   只读地扫描当前场景，建立统一的场景数据（vino_scene_report），
--   用一个简单 UI 展示统计结果；点击统计项自动选择对应对象。
--
-- 本模块不做（留给后续阶段）
--   自动清理 / 材质合并 / 智能分组 / AI / 程序化建模 / 批处理
--
-- 数据接口（后续 Scene Cleanup 等模块直接消费）
--   global vino_scene_data                  最近一次扫描结果 (vino_scene_report)
--   vino_scan_scene st:<settings>           执行一次扫描，返回 vino_scene_report
--   vino_get_bucket <tag>                   取某个统计项对应的对象数组
--   vino_select_bucket <tag>                选中某个统计项对应对象（可 Undo）
--   vino_get_record <node>                  取单个对象的详细记录 (vino_obj_record)
--   vino_bucket_tags()                      所有可用 tag
--   vino_dump_report rep                    把报告打印到 Listener（调试用）
--   tag 取值
--     #objects #meshes #shapes #groups #cameras #lights #helpers
--     #vertices #faces #triangles #materials #textures #missing_textures
--     #empty #hidden #frozen #bad_scale #missing_tex #high_poly
--
-- 安全约定
--   扫描过程不修改场景：不选择、不创建、不删除、不塌陷、不改名、不塌陷堆栈。
--   逐对象 try/catch 包裹，单个对象异常不影响整体。
--   "选择"动作包在 undo 里，可 Ctrl+Z 回到原选择。
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. settings
--------------------------------------------------------------------------------

struct vino_scan_settings
(
    high_poly_threshold = 20000,   -- 三角面超过此值记为 High Poly
    extreme_scale_high  = 1000.0,  -- 缩放大于此值记为 Extreme
    extreme_scale_low   = 0.001,   -- 缩放小于此值记为 Extreme
    uniform_tolerance   = 0.001,   -- 非统一缩放判定容差（相对）
    zero_epsilon        = 0.000001,-- 缩放为 0 的判定阈值
    collect_details     = true,    -- 采集 UV 通道 / 平滑组（较慢）
    smooth_sample       = 3000,    -- 平滑组采样上限（面数）
    yield_every         = 8        -- 每处理多少个对象让 UI 刷新一次
)

--------------------------------------------------------------------------------
-- 2. data records
--------------------------------------------------------------------------------

struct vino_obj_record
(
    obj              = undefined, -- 节点引用
    name             = "",
    handle           = -1,
    cls              = "",        -- 类名
    super_class      = "",
    kind             = #other,    -- #mesh #shape #camera #light #helper #group #other
    verts            = 0,
    faces            = 0,
    tris             = 0,
    width            = 0.0,       -- 世界 AABB 尺寸
    height           = 0.0,
    depth            = 0.0,
    mat_count        = 0,
    uv_channels      = 0,
    smooth_groups    = 0,
    hidden           = false,
    frozen           = false,
    scale_state      = #ok,       -- #ok #zero #negative #nonuniform #extreme
    scale_x          = 1.0,
    scale_y          = 1.0,
    scale_z          = 1.0,
    tex_count        = 0,
    missing_tex_count= 0,
    empty            = false,
    high_poly        = false,
    mat_list         = #(),
    tex_list         = #(),
    missing_list     = #()
)

struct vino_scene_report
(
    version          = "",
    duration         = 0.0,
    settings         = undefined,

    -- 场景计数
    object_count     = 0,
    mesh_count       = 0,
    shape_count      = 0,
    group_count      = 0,
    camera_count     = 0,
    light_count      = 0,
    helper_count     = 0,
    hidden_count     = 0,
    frozen_count     = 0,

    -- mesh 汇总
    vert_total       = 0,
    face_total       = 0,
    tri_total        = 0,

    -- 资源
    mat_count        = 0,
    tex_count        = 0,
    missing_tex_count= 0,
    mat_list         = #(),
    tex_list         = #(),
    missing_list     = #(),

    -- 明细
    records          = #(),

    -- 问题 / 分类桶（存节点引用，供 UI 与后续模块直接消费）
    all_nodes        = #(),
    mesh_nodes       = #(),
    shape_nodes      = #(),
    group_nodes      = #(),
    camera_nodes     = #(),
    light_nodes      = #(),
    helper_nodes     = #(),
    hidden_nodes     = #(),
    frozen_nodes     = #(),
    mat_nodes        = #(),
    tex_nodes        = #(),
    empty_nodes      = #(),
    bad_scale_nodes  = #(),
    missing_tex_nodes= #(),
    high_poly_nodes  = #()
)

global vino_scanner_version  = "0.1.0"
global vino_scene_data       = undefined
global vino_scanner_settings = undefined
global vino_scan_busy        = false

if vino_scanner_settings == undefined do vino_scanner_settings = vino_scan_settings()

-- 全局读写统一走这两个函数，避免函数体内赋值作用域不明确
fn vino_get_settings =
(
    global vino_scanner_settings
    if vino_scanner_settings == undefined do vino_scanner_settings = vino_scan_settings()
    vino_scanner_settings
)

fn vino_set_busy v =
(
    global vino_scan_busy
    vino_scan_busy = v
)

fn vino_new_record =
(
    local r = vino_obj_record()
    r.mat_list     = #()
    r.tex_list     = #()
    r.missing_list = #()
    r
)

fn vino_new_report =
(
    local r = vino_scene_report()
    r.version          = vino_scanner_version
    r.settings         = vino_get_settings()
    r.mat_list         = #()
    r.tex_list         = #()
    r.missing_list     = #()
    r.records          = #()
    r.all_nodes        = #()
    r.mesh_nodes       = #()
    r.shape_nodes      = #()
    r.group_nodes      = #()
    r.camera_nodes     = #()
    r.light_nodes      = #()
    r.helper_nodes     = #()
    r.hidden_nodes     = #()
    r.frozen_nodes     = #()
    r.mat_nodes        = #()
    r.tex_nodes        = #()
    r.empty_nodes      = #()
    r.bad_scale_nodes  = #()
    r.missing_tex_nodes= #()
    r.high_poly_nodes  = #()
    r
)

--------------------------------------------------------------------------------
-- 3. 底层工具
--------------------------------------------------------------------------------

-- 进度回调：优先刷新 UI，同时驱动 Max 自带进度条并让出消息循环
fn vino_emit_progress pct msg =
(
    try
    (
        vino_roll_scanner.pbar.value = pct
        vino_roll_scanner.lbl_prog.text = msg
    )
    catch ()
    try ( progressUpdate pct ) catch ()
    try ( windows.processPostedMessages() ) catch ()
    true
)

fn vino_pad_str s n =
(
    local r = (if s == undefined then "" else s as string)
    local k = n - r.count
    while k > 0 do
    (
        r = r + " "
        k -= 1
    )
    r
)

-- 是否为"应有网格"的对象
fn vino_is_mesh_obj o =
(
    if o == undefined do return false
    if (isValidNode o) == false do return false
    if (superClassOf o) != GeometryClass do return false
    if (classOf o) == Targetobject do return false
    true
)

-- 隐藏状态（含图层隐藏）
fn vino_get_hidden o =
(
    local h = false
    try ( h = o.isHidden ) catch ( h = false )
    if not h do
    (
        try
        (
            local ln = o.layer
            if ln != undefined do
            (
                local lh = false
                try ( lh = ln.isHidden ) catch ( lh = false )
                if lh do h = true
            )
        )
        catch ()
    )
    h
)

fn vino_get_frozen o =
(
    local f = false
    try ( f = o.isFrozen ) catch ( f = false )
    f
)

-- 顶点 / 面 / 三角面
fn vino_get_counts o =
(
    local v = 0
    local f = 0
    local t = 0
    try ( v = getNumVerts o ) catch ( v = 0 )
    try ( f = getNumFaces o ) catch ( f = 0 )
    try
    (
        local pc = getPolygonCount o
        if classOf pc == Array then
        (
            if pc.count >= 1 do t = pc[1]
        )
        else if classOf pc == Integer then t = pc
    )
    catch ( t = 0 )
    if t < f do t = f
    if (v == 0 and f == 0) do
    (
        -- 少数对象类型上面接口取不到，退回快照（不修改场景）
        try
        (
            local sm = snapshotAsMesh o
            v = sm.numVerts
            f = sm.numFaces
            t = sm.numFaces
            delete sm
        )
        catch ()
    )
    #(v, f, t)
)

-- 世界 AABB 尺寸
fn vino_get_size o =
(
    local w = 0.0
    local h = 0.0
    local d = 0.0
    try
    (
        local bb = nodeGetBoundingBox o o.transform
        local bmin = bb[1]
        local bmax = bb[2]
        w = abs (bmax.x - bmin.x)
        h = abs (bmax.y - bmin.y)
        d = abs (bmax.z - bmin.z)
    )
    catch ()
    #(w, h, d)
)

-- 材质递归收集（多维子材质 / 混合材质展开为叶子材质）
fn vino_collect_materials mat &out depth:0 =
(
    if mat == undefined do return false
    if depth > 8 do return false
    local subs = #()
    try
    (
        local n = getNumSubMtls mat
        for i = 1 to n do
        (
            local sm = getSubMtl mat i
            if sm != undefined and sm != mat do append subs sm
        )
    )
    catch ( subs = #() )
    if subs.count > 0 then
    (
        for sm in subs do vino_collect_materials sm &out depth:(depth + 1)
    )
    else
    (
        appendIfUnique out mat
    )
    true
)

-- 贴图递归收集
fn vino_walk_texmap tx &paths &missing depth:0 =
(
    if tx == undefined do return false
    if depth > 8 do return false
    local f = ""
    try ( f = tx.filename ) catch ( f = "" )
    if f != undefined and classOf f == String and f != "" do
    (
        appendIfUnique paths f
        if not (doesFileExist f) do appendIfUnique missing f
    )
    local n = 0
    try ( n = getNumSubTexmaps tx ) catch ( n = 0 )
    for i = 1 to n do
    (
        local st = undefined
        try ( st = getSubTexmap tx i ) catch ( st = undefined )
        if st != undefined and st != tx do vino_walk_texmap st &paths &missing depth:(depth + 1)
    )
    true
)

fn vino_collect_textures mat &paths &missing depth:0 =
(
    if mat == undefined do return false
    if depth > 8 do return false
    local n = 0
    try ( n = getNumSubTexmaps mat ) catch ( n = 0 )
    for i = 1 to n do
    (
        local tx = undefined
        try ( tx = getSubTexmap mat i ) catch ( tx = undefined )
        if tx != undefined do vino_walk_texmap tx &paths &missing depth:(depth + 1)
    )
    true
)

-- UV 通道数量（1..8）
fn vino_uv_channel_count o =
(
    local n = 0
    for c = 1 to 8 do
    (
        local ok = false
        try ( ok = (polyOp.getMapSupport o c) ) catch ( ok = false )
        if not ok do try ( ok = (meshOp.getMapSupport o c) ) catch ( ok = false )
        if ok do n += 1
    )
    if n == 0 do
    (
        -- 未塌陷的基础体：用快照再试一次
        local sm = undefined
        try
        (
            sm = snapshotAsMesh o
            for c = 1 to 8 do
            (
                local ok2 = false
                try ( ok2 = (meshOp.getMapSupport sm c) ) catch ( ok2 = false )
                if ok2 do n += 1
            )
            if n == 0 and sm.numVerts > 0 do n = 1
            delete sm
            sm = undefined
        )
        catch ( try ( if sm != undefined do delete sm ) catch () )
    )
    n
)

-- 平滑组数量（采样，避免大模型卡死）
fn vino_smooth_group_count o limit =
(
    local bits = #{}
    local fc = 0
    try ( fc = getNumFaces o ) catch ( fc = 0 )
    if fc <= 0 do return 0

    local lim = fc
    if lim > limit do lim = limit
    for i = 1 to lim do
    (
        local g = 0
        try ( g = getFaceSmoothGroup o i ) catch ( g = 0 )
        if g > 0 do
        (
            for b = 1 to 32 do
            (
                if (bit.get g b) do ( bits[b] = true )
            )
        )
    )

    -- Editable Poly 等取不到时，用快照兜底
    if bits.numberSet == 0 do
    (
        local sm = undefined
        try
        (
            sm = snapshotAsMesh o
            local fc2 = sm.numFaces
            local lim2 = fc2
            if lim2 > limit do lim2 = limit
            for i = 1 to lim2 do
            (
                local g = 0
                try ( g = getFaceSmoothGroup sm i ) catch ( g = 0 )
                if g > 0 do
                (
                    for b = 1 to 32 do
                    (
                        if (bit.get g b) do ( bits[b] = true )
                    )
                )
            )
            delete sm
            sm = undefined
        )
        catch ( try ( if sm != undefined do delete sm ) catch () )
    )

    bits.numberSet
)

-- 缩放检查 -> #(state, sx, sy, sz)
fn vino_check_scale o st =
(
    local state = #ok
    local sx = 1.0
    local sy = 1.0
    local sz = 1.0
    try
    (
        local tm = o.transform
        sx = length tm.row1
        sy = length tm.row2
        sz = length tm.row3
        local det = dot (cross tm.row1 tm.row2) tm.row3
        if sx < st.zero_epsilon or sy < st.zero_epsilon or sz < st.zero_epsilon then
            state = #zero
        else if det < 0.0 then
            state = #negative
        else
        (
            local mn = amin sx sy
            mn = amin mn sz
            local mx = amax sx sy
            mx = amax mx sz
            if mn > 0.0 and ((mx / mn) - 1.0) > st.uniform_tolerance then
                state = #nonuniform
            else if mx > st.extreme_scale_high or mx < st.extreme_scale_low then
                state = #extreme
        )
    )
    catch ( state = #ok )
    #(state, sx, sy, sz)
)

--------------------------------------------------------------------------------
-- 4. 扫描主流程（只读）
--------------------------------------------------------------------------------

fn vino_scan_scene st:undefined =
(
    if st == undefined do st = vino_get_settings()

    local t0 = timestamp()
    local rep = vino_new_report()
    rep.settings = st

    -- 收集节点
    local all = #()
    local total = 0
    try
    (
        total = objects.count
        for i = 1 to total do
        (
            local o = objects[i]
            if o != undefined do append all o
        )
    )
    catch ( all = #() )

    total = all.count
    try ( progressStart "Vino Scene Scanner" ) catch ()
    vino_emit_progress 0 ("扫描中 0 / " + (total as string))

    local mats_all = #()
    local tex_all  = #()
    local miss_all = #()

    local idx = 0
    for o in all do
    (
        idx += 1
        if st.yield_every > 0 and (mod idx st.yield_every) == 0 do
        (
            local pct = (100.0 * idx / (amax total 1)) as integer
            vino_emit_progress pct ("扫描中 " + (idx as string) + " / " + (total as string))
        )

        local rec = vino_new_record()
        rec.obj = o

        try ( rec.name = o.name ) catch ( rec.name = "<unknown>" )
        try ( rec.handle = o.inode.handle ) catch ( rec.handle = -1 )
        try ( rec.cls = (classOf o) as string ) catch ( rec.cls = "" )
        try ( rec.super_class = (superClassOf o) as string ) catch ( rec.super_class = "" )

        -- 分类
        local is_head = false
        try ( is_head = isGroupHead o ) catch ( is_head = false )
        local cls_str = rec.cls
        if is_head then
            rec.kind = #group
        else if cls_str == "Targetobject" then
            rec.kind = #other
        else if cls_str == "BoneGeometry" then
            rec.kind = #helper
        else if (vino_is_mesh_obj o) then
            rec.kind = #mesh
        else if (superClassOf o) == Shape then
            rec.kind = #shape
        else if (superClassOf o) == Light then
            rec.kind = #light
        else if (superClassOf o) == Camera then
            rec.kind = #camera
        else if (superClassOf o) == Helper then
            rec.kind = #helper
        else
            rec.kind = #other

        rec.hidden = vino_get_hidden o
        rec.frozen = vino_get_frozen o

        -- 缩放检查（所有对象都做，非 mesh 也常出问题）
        local sc = vino_check_scale o st
        rec.scale_state = sc[1]
        rec.scale_x = sc[2]
        rec.scale_y = sc[3]
        rec.scale_z = sc[4]

        -- mesh 数据
        if rec.kind == #mesh do
        (
            local c = vino_get_counts o
            rec.verts = c[1]
            rec.faces = c[2]
            rec.tris  = c[3]

            local sz = vino_get_size o
            rec.width  = sz[1]
            rec.height = sz[2]
            rec.depth  = sz[3]

            -- 材质
            local mats = #()
            try ( vino_collect_materials o.material &mats ) catch ()
            rec.mat_list = mats
            rec.mat_count = mats.count

            -- 贴图
            local paths = #()
            local miss  = #()
            for m in mats do
            (
                try ( vino_collect_textures m &paths &miss ) catch ()
            )
            rec.tex_list = paths
            rec.missing_list = miss
            rec.tex_count = paths.count
            rec.missing_tex_count = miss.count

            for m in mats    do appendIfUnique mats_all m
            for p in paths   do appendIfUnique tex_all p
            for p in miss    do appendIfUnique miss_all p

            if st.collect_details do
            (
                rec.uv_channels = vino_uv_channel_count o
                rec.smooth_groups = vino_smooth_group_count o st.smooth_sample
            )

            if rec.tris == 0 do rec.empty = true
            if rec.tris >= st.high_poly_threshold do rec.high_poly = true
        )

        -- 汇总
        append rep.all_nodes o
        rep.object_count += 1

        if rec.kind == #mesh then
        (
            append rep.mesh_nodes o
            rep.mesh_count  += 1
            rep.vert_total  += rec.verts
            rep.face_total  += rec.faces
            rep.tri_total   += rec.tris
        )
        else if rec.kind == #shape then
        (
            append rep.shape_nodes o
            rep.shape_count += 1
        )
        else if rec.kind == #group then
        (
            append rep.group_nodes o
            rep.group_count += 1
        )
        else if rec.kind == #camera then
        (
            append rep.camera_nodes o
            rep.camera_count += 1
        )
        else if rec.kind == #light then
        (
            append rep.light_nodes o
            rep.light_count += 1
        )
        else if rec.kind == #helper then
        (
            append rep.helper_nodes o
            rep.helper_count += 1
        )

        if rec.hidden do ( append rep.hidden_nodes o
                           rep.hidden_count += 1 )
        if rec.frozen do ( append rep.frozen_nodes o
                           rep.frozen_count += 1 )

        if rec.kind == #mesh do
        (
            if rec.mat_count > 0 do append rep.mat_nodes o
            if rec.tex_count > 0 do append rep.tex_nodes o
            if rec.empty     do append rep.empty_nodes o
            if rec.high_poly do append rep.high_poly_nodes o
            if rec.missing_tex_count > 0 do append rep.missing_tex_nodes o
        )

        if rec.scale_state != #ok do append rep.bad_scale_nodes o

        append rep.records rec
    )

    rep.mat_list = mats_all
    rep.tex_list = tex_all
    rep.missing_list = miss_all
    rep.mat_count = mats_all.count
    rep.tex_count = tex_all.count
    rep.missing_tex_count = miss_all.count

    rep.duration = ((timestamp() - t0) / 1000.0)

    vino_emit_progress 100 "扫描完成"
    try ( progressEnd() ) catch ()

    global vino_scene_data
    vino_scene_data = rep
    rep
)

--------------------------------------------------------------------------------
-- 5. 对外数据接口
--------------------------------------------------------------------------------

fn vino_bucket_tags =
(
    #(#objects, #meshes, #shapes, #groups, #cameras, #lights, #helpers,
      #vertices, #faces, #triangles, #materials, #textures, #missing_textures,
      #empty, #hidden, #frozen, #bad_scale, #missing_tex, #high_poly)
)

fn vino_get_bucket tag =
(
    local rep = vino_scene_data
    if rep == undefined or tag == undefined do return #()
    local out = #()
    try
    (
        out =
        (
            case tag of
            (
                #objects:          rep.all_nodes
                #meshes:           rep.mesh_nodes
                #shapes:           rep.shape_nodes
                #groups:           rep.group_nodes
                #cameras:          rep.camera_nodes
                #lights:           rep.light_nodes
                #helpers:          rep.helper_nodes
                #vertices:         rep.mesh_nodes
                #faces:            rep.mesh_nodes
                #triangles:        rep.mesh_nodes
                #materials:        rep.mat_nodes
                #textures:         rep.tex_nodes
                #missing_textures: rep.missing_tex_nodes
                #empty:            rep.empty_nodes
                #hidden:           rep.hidden_nodes
                #frozen:           rep.frozen_nodes
                #bad_scale:        rep.bad_scale_nodes
                #missing_tex:      rep.missing_tex_nodes
                #high_poly:        rep.high_poly_nodes
                default:           #()
            )
        )
    )
    catch ( out = #() )
    if out == undefined do out = #()
    out
)

fn vino_get_record o =
(
    local rep = vino_scene_data
    if rep == undefined or o == undefined do return undefined
    local h = -1
    try ( h = o.inode.handle ) catch ( h = -1 )
    for r in rep.records do
    (
        if r.obj == o do return r
        if h >= 0 and r.handle == h do return r
    )
    undefined
)

-- 选中某个统计项对应对象，返回实际选中数量（包在 undo 里）
fn vino_select_bucket tag =
(
    if tag == undefined do return 0
    local nodes = vino_get_bucket tag
    if nodes.count == 0 do return 0
    local alive = #()
    for n in nodes do
    (
        try
        (
            if (isValidNode n) do append alive n
        )
        catch ()
    )
    if alive.count == 0 do return 0
    local cnt = 0
    undo "Vino Scene Scanner: select" on
    (
        if alive.count == 1 then
            select alive[1]
        else
            select alive
        cnt = selection.count
    )
    cnt
)

fn vino_tag_label tag =
(
    case tag of
    (
        #objects:          "Objects"
        #meshes:           "Meshes"
        #shapes:           "Shapes"
        #groups:           "Groups"
        #cameras:          "Cameras"
        #lights:           "Lights"
        #helpers:          "Helpers"
        #vertices:         "Vertices"
        #faces:            "Faces"
        #triangles:        "Triangles"
        #materials:        "Materials"
        #textures:         "Textures"
        #missing_textures: "Missing Textures"
        #empty:            "Empty"
        #hidden:           "Hidden"
        #frozen:           "Frozen"
        #bad_scale:        "Bad Scale"
        #missing_tex:      "Missing Texture"
        #high_poly:        "High Poly"
        default:           (tag as string)
    )
)

fn vino_tag_value rep tag =
(
    if rep == undefined do return 0
    case tag of
    (
        #objects:          rep.object_count
        #meshes:           rep.mesh_count
        #shapes:           rep.shape_count
        #groups:           rep.group_count
        #cameras:          rep.camera_count
        #lights:           rep.light_count
        #helpers:          rep.helper_count
        #vertices:         rep.vert_total
        #faces:            rep.face_total
        #triangles:        rep.tri_total
        #materials:        rep.mat_count
        #textures:         rep.tex_count
        #missing_textures: rep.missing_tex_count
        #empty:            rep.empty_nodes.count
        #hidden:           rep.hidden_count
        #frozen:           rep.frozen_count
        #bad_scale:        rep.bad_scale_nodes.count
        #missing_tex:      rep.missing_tex_nodes.count
        #high_poly:        rep.high_poly_nodes.count
        default:           0
    )
)

-- 某一项的说明文字
fn vino_bucket_detail tag =
(
    local rep = vino_scene_data
    if rep == undefined do return "尚未扫描，请先点击 Refresh。"
    local nodes = vino_get_bucket tag
    local s = (vino_tag_label tag) + " : " + (nodes.count as string) + " 个对象\n"

    if tag == #bad_scale do
    (
        local z = 0
        local ng = 0
        local nu = 0
        local ex = 0
        for r in rep.records where (r.scale_state != #ok) do
        (
            case r.scale_state of
            (
                #zero:       z  += 1
                #negative:   ng += 1
                #nonuniform: nu += 1
                #extreme:    ex += 1
            )
        )
        s += ("  Zero " + (z as string) + " / Negative " + (ng as string) + " / Non-uniform " + (nu as string) + " / Extreme " + (ex as string) + "\n")
    )
    if tag == #missing_tex or tag == #missing_textures do
    (
        s += ("  缺失贴图路径 " + (rep.missing_tex_count as string) + " 个\n")
    )

    -- 名称列表
    local nm = ""
    local k = 0
    for n in nodes do
    (
        if k < 8 do
        (
            local t = ""
            try ( t = n.name ) catch ( t = "<已删除>" )
            if tag == #bad_scale do
            (
                local r = vino_get_record n
                if r != undefined do t = t + " [" + (r.scale_state as string) + "]"
            )
            if k > 0 do nm += ", "
            nm += t
            k += 1
        )
    )
    if nm != "" do s += ("  " + nm + "\n")
    if nodes.count > 8 do s += ("  ... 还有 " + ((nodes.count - 8) as string) + " 个\n")

    if tag == #vertices or tag == #faces or tag == #triangles do
        s += "  说明: 聚合统计项，已选中全部 Mesh 对象。\n"
    if tag == #materials do s += "  说明: 已选中所有带材质的对象。\n"
    if tag == #textures do s += "  说明: 已选中所有带贴图的对象。\n"
    s
)

fn vino_dump_report rep:undefined =
(
    if rep == undefined do rep = vino_scene_data
    if rep == undefined do
    (
        format "Vino Scene Scanner: 没有可输出的报告\n"
        return false
    )
    format "--------------------------------------------------\n"
    format "Vino Scene Scanner  v%\n" rep.version
    format "objects % | meshes % | shapes % | groups % | cameras % | lights % | helpers %\n" rep.object_count rep.mesh_count rep.shape_count rep.group_count rep.camera_count rep.light_count rep.helper_count
    format "verts % | faces % | tris %\n" rep.vert_total rep.face_total rep.tri_total
    format "materials % | textures % | missing %\n" rep.mat_count rep.tex_count rep.missing_tex_count
    format "hidden % | frozen %\n" rep.hidden_count rep.frozen_count
    format "issues: empty % | bad_scale % | missing_tex % | high_poly %\n" rep.empty_nodes.count rep.bad_scale_nodes.count rep.missing_tex_nodes.count rep.high_poly_nodes.count
    format "duration % s\n" (formattedPrint rep.duration format:".2f")
    format "--------------------------------------------------\n"
    true
)

--------------------------------------------------------------------------------
-- 6. ui
--------------------------------------------------------------------------------

rollout vino_roll_scanner "Vino Scene Scanner  v0.1.0"
(
    local row_tags = #()

    button   btn_scan    "Refresh / 扫描场景" width:150 height:30 align:#left
    button   btn_dump    "打印到监听器"       width:100 height:30 align:#right offset:[0,-35]
    checkbox chk_detail  "采集 UV / 平滑组（较慢）" checked:true align:#left
    spinner  spn_highpoly "High Poly 阈值 (三角面):" range:[1, 10000000, 20000] type:#integer fieldWidth:70 align:#left

    progressbar pbar width:290 height:12 color:(color 90 200 130) align:#left
    label    lbl_prog "就绪" width:290 height:16 align:#left

    label    lbl_head "  项目                     数量" width:290 height:16 align:#left
    listBox  lb_stats "" width:290 height:17

    label    lbl_detail "点击上面的统计项即可选中对应对象。" width:290 height:70 align:#left
    button   btn_close  "关闭" width:290 height:22 align:#left

    fn vino_ui_rows =
    (
        local rep = vino_scene_data
        row_tags = #()
        if rep == undefined do
        (
            lb_stats.items = #("(尚未扫描，点击 Refresh)")
            row_tags = #(#none)
            return false
        )
        local tags = #(#objects, #meshes, #shapes, #groups, #cameras, #lights, #helpers,
                       #vertices, #faces, #triangles, #materials, #textures, #missing_textures,
                       #none, #empty, #hidden, #frozen, #bad_scale, #missing_tex, #high_poly)
        local lines = #()
        for tg in tags do
        (
            if tg == #none then
            (
                append lines "---------------------------"
                append row_tags #none
            )
            else
            (
                local txt = (vino_pad_str (vino_tag_label tg) 24) + ((vino_tag_value rep tg) as string)
                append lines txt
                append row_tags tg
            )
        )
        lb_stats.items = lines
        true
    )

    fn vino_ui_pick idx =
    (
        if idx < 1 or idx > row_tags.count do return false
        local tg = row_tags[idx]
        if tg == #none or tg == undefined do
        (
            lbl_detail.text = "点击上面的统计项即可选中对应对象。"
            return false
        )
        local n = vino_select_bucket tg
        local s = vino_bucket_detail tg
        if n == 0 do s += "  (没有可选择的活对象)\n"
        if n > 0 and n < (vino_get_bucket tg).count do
            s += ("  注意: 仅选中 " + (n as string) + " 个，其余可能已被删除或处于冻结/不可选状态。\n")
        lbl_detail.text = s
        try ( redrawViews() ) catch ()
        true
    )

    on vino_roll_scanner open do
    (
        pbar.value = 0
        lbl_prog.text = "就绪"
        vino_ui_rows()
        if vino_scene_data != undefined do
        (
            lbl_prog.text = ("上次扫描: " + (vino_scene_data.object_count as string) + " 个对象")
        )
    )

    on btn_scan pressed do
    (
        if vino_scan_busy do
        (
            lbl_prog.text = "正在扫描中，请稍候..."
            return false
        )
        vino_set_busy true
        btn_scan.enabled = false
        pbar.value = 0
        lbl_prog.text = "开始扫描..."

        local st = vino_get_settings()
        st.collect_details = chk_detail.checked
        st.high_poly_threshold = spn_highpoly.value

        local rep = undefined
        local ok = true
        try
        (
            rep = vino_scan_scene st:st
        )
        catch
        (
            ok = false
            try ( progressEnd() ) catch ()
            format "Vino Scene Scanner 扫描异常: %\n" (getCurrentException())
        )

        vino_set_busy false
        btn_scan.enabled = true

        if ok and rep != undefined then
        (
            vino_ui_rows()
            pbar.value = 100
            lbl_prog.text = ("完成 | " + (rep.object_count as string) + " 对象 | " + (formattedPrint rep.duration format:".2f") + " 秒")
            lbl_detail.text = "点击上面的统计项即可选中对应对象。"
        )
        else
        (
            lbl_prog.text = "扫描失败，详情见 MAXScript Listener"
        )
        true
    )

    on btn_dump pressed do
    (
        vino_dump_report()
        lbl_prog.text = "已打印到 MAXScript Listener"
    )

    on lb_stats selected idx do vino_ui_pick idx
    on lb_stats doubleClicked idx do vino_ui_pick idx

    on btn_close pressed do destroyDialog vino_roll_scanner
)

--------------------------------------------------------------------------------
-- 7. 入口
--------------------------------------------------------------------------------

-- 打开本模块面板（供入口 vino_scene_toolkit.ms 调用）
fn vino_open_scanner =
(
    try ( destroyDialog vino_roll_scanner ) catch ()
    createDialog vino_roll_scanner width:312 height:600
)

macroScript vino_scene_scanner
    category:"Vino Scene Toolkit"
    buttonText:"Scene Scanner"
    tooltip:"Vino Scene Toolkit - Scene Scanner"
(
    on execute do vino_open_scanner()
)

-- 单独运行本文件时自动开面板；被 vino_scene_toolkit.ms 加载时不弹
-- 若放进 scripts\Startup 想完全避免自动弹出，把下面这个 try/catch 块注释掉即可
try
(
    if vino_toolkit_loading != true do vino_open_scanner()
)
catch
(
    vino_open_scanner()
)

--------------------------------------------------------------------------------
-- end of file
--------------------------------------------------------------------------------
