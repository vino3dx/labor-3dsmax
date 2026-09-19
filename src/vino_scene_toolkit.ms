--------------------------------------------------------------------------------
-- Vino Scene Toolkit - 入口 / 模块加载器
-- file      : vino_scene_toolkit.ms
-- version   : 0.1.0
-- author    : Vino  |  https://vinofx.com  |  https://github.com/vino3dx
-- license   : MIT
-- target    : 3ds Max 2018+ / MAXScript
--------------------------------------------------------------------------------
-- 作用
--   1. 定位自身目录，fileIn 加载同目录下 vino_scene_toolkit\ 内的各模块
--   2. 注册一个总入口宏，弹出启动面板，列出已加载模块
--   3. 后续新模块只需在 vino_toolkit_module_files 里加一行文件名
--
-- directory convention   (same rule as the labor suite:  entry file + same-name folder)
--   vino_scene_toolkit.ms            本文件（唯一入口）
--   vino_scene_toolkit\scene_scanner.ms   模块 01  场景扫描
--   vino_scene_toolkit\scene_cleanup.ms   模块 02  场景清理（待开发）
--   vino_scene_toolkit\...                后续模块
-- 本文件所在目录就是模块目录，不需要额外一层 modules\
--
-- 每个模块需满足
--   - 自带 rollout，且 rollout 名全局唯一（如 vino_roll_scanner）
--   - 提供一个打开自己面板的函数 vino_open_<module>()
--   - 文件末尾用 vino_toolkit_loading 判断是否自动弹窗（见模块文件末尾示例）
--------------------------------------------------------------------------------

global vino_toolkit_version = "0.1.0"
global vino_toolkit_dir     = ""
global vino_toolkit_modules = #()

-- 模块文件名列表（位于同目录的 vino_scene_toolkit\ 文件夹内）
fn vino_toolkit_module_files =
(
    #("scene_scanner.ms")
)

-- 本文件所在目录
fn vino_toolkit_root =
(
    local d = ""
    try ( d = getFilenamePath (getThisScriptFilename()) ) catch ( d = "" )
    if d == undefined do d = ""
    d
)

-- 加载所有模块，返回 #(#(显示名, 相对路径, 是否成功), ...)
fn vino_toolkit_load_modules =
(
    global vino_toolkit_dir
    global vino_toolkit_modules
    global vino_toolkit_loading

    vino_toolkit_dir = vino_toolkit_root()
    vino_toolkit_modules = #()

    if vino_toolkit_dir == "" do
    (
        format "Vino Scene Toolkit: 无法确定脚本目录，请把本文件与 vino_scene_toolkit 文件夹放一起后重新运行。\n"
        return vino_toolkit_modules
    )

    local files = vino_toolkit_module_files()

    for f in files do
    (
        local full = vino_toolkit_dir + f
        if doesFileExist full then
        (
            -- 置标记，避免模块加载过程中自己弹窗
            vino_toolkit_loading = true
            local ok = true
            try
            (
                fileIn full
            )
            catch
            (
                ok = false
                format "Vino Scene Toolkit: 模块 % 加载失败 - %\n" f (getCurrentException())
            )
            vino_toolkit_loading = false
            append vino_toolkit_modules #(f, f, ok)
        )
        else
        (
            format "Vino Scene Toolkit: 找不到模块 %\n" full
            append vino_toolkit_modules #(f, f, false)
        )
    )
    vino_toolkit_modules
)

-- 已加载模块的中文显示名
fn vino_toolkit_module_name f =
(
    if f == "scene_scanner.ms" then
        "模块 01  场景扫描 Scene Scanner"
    else if f == "scene_cleanup.ms" then
        "模块 02  场景清理 Scene Cleanup"
    else
        f
)

--------------------------------------------------------------------------------
-- 启动面板
--------------------------------------------------------------------------------

rollout vino_roll_launcher "Vino Scene Toolkit"
(
    label lbl_title "Vino Scene Toolkit" width:270 height:20 align:#left
    label lbl_ver   "" width:270 height:16 align:#left
    label lbl_line  "--------------------------------------------" width:270 height:16 align:#left

    button btn_scanner "模块 01  场景扫描 Scene Scanner" width:270 height:32 align:#left
    button btn_reload  "重新加载模块" width:270 height:24 align:#left

    label lbl_status "" width:270 height:60 align:#left
    label lbl_tip    "提示: 各模块也可单独拖拽运行。新模块放进 vino_scene_toolkit\\ 目录即可。" width:270 height:34 align:#left

    fn vino_ui_status =
    (
        local s = "已加载模块:\n"
        if vino_toolkit_modules.count == 0 do s = "尚未加载任何模块。\n"
        for m in vino_toolkit_modules do
        (
            local mark = "[!!]  "
            if m[3] do mark = "[OK]  "
            s += ("  " + mark + (vino_toolkit_module_name m[1]) + "\n")
        )
        lbl_status.text = s
    )

    on vino_roll_launcher open do
    (
        lbl_ver.text = ("version " + vino_toolkit_version + "   |   " + vino_toolkit_dir)
        vino_ui_status()
    )

    on btn_scanner pressed do
    (
        local ready = false
        for m in vino_toolkit_modules do
        (
            if m[1] == "scene_scanner.ms" and m[3] == true do ready = true
        )
        if not ready do
        (
            messageBox "Scene Scanner 未加载成功，请检查 vino_scene_toolkit\\scene_scanner.ms 是否存在。" title:"Vino Scene Toolkit"
            return false
        )
        local opened = true
        try
        (
            vino_open_scanner()
        )
        catch
        (
            opened = false
        )
        if not opened do
        (
            try ( destroyDialog vino_roll_scanner ) catch ()
            createDialog vino_roll_scanner width:312 height:600
        )
    )

    on btn_reload pressed do
    (
        vino_toolkit_load_modules()
        vino_ui_status()
    )
)

--------------------------------------------------------------------------------
-- 宏入口
--------------------------------------------------------------------------------

macroScript vino_scene_toolkit
    category:"Vino Scene Toolkit"
    buttonText:"Vino Toolkit"
    tooltip:"Vino Scene Toolkit - 入口"
(
    on execute do
    (
        try ( destroyDialog vino_roll_launcher ) catch ()
        createDialog vino_roll_launcher width:296 height:280
    )
)

--------------------------------------------------------------------------------
-- 直接运行本文件时：加载模块并打开启动面板
--------------------------------------------------------------------------------

vino_toolkit_load_modules()
try ( destroyDialog vino_roll_launcher ) catch ()
createDialog vino_roll_launcher width:296 height:280

--------------------------------------------------------------------------------
-- end of file
--------------------------------------------------------------------------------
