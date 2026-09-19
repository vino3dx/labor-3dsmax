/* ============================================================================
   labor - 3ds Max Workflow Toolkit
   ----------------------------------------------------------------------------
   file    : labor_textures.ms
   module  : textures / 贴图工具
   desc    : collect bitmaps / build file index / relink by recursive search / relink by prefix replace / pack textures / toggle viewport textures
   author  : Vino  |  https://vinofx.com  |  github.com/vino3dx/labor-3dsmax
   license : MIT  |  Copyright (c) 2024 Vino. All rights reserved.
   ----------------------------------------------------------------------------
   NOTE
     texture relink & pack,
     please run  labor.ms  (the workspace entry file) to use it.
============================================================================ */

global labor_collect_bitmaps, labor_tex_stats, labor_build_file_index, labor_relink_by_search, labor_relink_by_prefix, labor_pack_textures, labor_toggle_viewport_textures

fn labor_collect_bitmaps =
(
    local arr   = #()
    local insts = #()
    try ( insts = getClassInstances BitmapTexture ) catch ( insts = #() )
    for t in insts where (findItem arr t == 0) do append arr t
    arr
)

fn labor_tex_stats =
(
    local bms  = labor_collect_bitmaps()
    local miss = 0
    for t in bms do
    (
        local p = ""
        try ( p = t.filename as string ) catch ( p = "" )
        if p == "" or not (doesFileExist p) do miss += 1
    )
    #(bms.count, miss)
)

-- build a filename -> paths index (iterative, safe for deep trees)
fn labor_build_file_index root recursive ignore_case =
(
    local keys  = #()
    local vals  = #()
    local stack = #(root)

    while stack.count > 0 do
    (
        local cur  = stack[stack.count]
        deleteItem stack stack.count
        local cur2 = cur
        if cur2.count > 0 and (cur2[cur2.count] == "\\" or cur2[cur2.count] == "/") do
            cur2 = substring cur2 1 (cur2.count - 1)

        local files = getFiles (cur2 + "\\*.*")
        for f in files do
        (
            if not (doesDirectoryExist f) do
            (
                local ext   = toLower (getFilenameType f)
                local is_img = case ext of
                (
                    ".jpg"  : true
                    ".jpeg" : true
                    ".png"  : true
                    ".tga"  : true
                    ".tif"  : true
                    ".tiff" : true
                    ".bmp"  : true
                    ".exr"  : true
                    ".hdr"  : true
                    ".dds"  : true
                    ".gif"  : true
                    ".webp" : true
                    ".psd"  : true
                    default : false
                )

                if is_img do
                (
                    local key = filenameFromPath f
                    if ignore_case do key = toLower key
                    local idx = findItem keys key
                    if idx == 0 then
                    (
                        append keys key
                        append vals #(f)
                    )
                    else
                    (
                        append vals[idx] f
                    )
                )
            )
        )

        if recursive do
        (
            local dirs = getDirectories (cur2 + "\\*")
            for d in dirs do append stack d
        )
    )
    #(keys, vals)
)

-- relink by searching a root folder
fn labor_relink_by_search root recursive ignore_case use_first =
(
    local bms      = labor_collect_bitmaps()
    local idx_res  = labor_build_file_index root recursive ignore_case
    local keys     = idx_res[1]
    local vals     = idx_res[2]

    local ok_count = 0
    local relinked = 0
    local multi    = 0
    local missing  = 0

    labor_log ("root: " + root)
    labor_log ("indexed files: " + (keys.count as string))

    for t in bms do
    (
        local p = ""
        try ( p = t.filename as string ) catch ( p = "" )

        if p == "" then
        (
            missing += 1
            labor_log ("[no path] " + t.name)
        )
        else if doesFileExist p then
        (
            ok_count += 1
        )
        else
        (
            local key = filenameFromPath p
            if ignore_case do key = toLower key
            local i = findItem keys key

            if i == 0 then
            (
                missing += 1
                labor_log ("[not found] " + p)
            )
            else
            (
                local cands = vals[i]
                if cands.count == 1 or use_first then
                (
                    local np = cands[1]
                    try
                    (
                        t.filename = np
                        try ( t.reload() ) catch ()
                        relinked += 1
                        labor_log ("[relinked] " + p + "  ->  " + np)
                    )
                    catch
                    (
                        missing += 1
                        labor_log ("[relink failed] " + p)
                    )
                )
                else
                (
                    multi += 1
                    labor_log ("[multiple candidates - skipped] " + p + " (" + (cands.count as string) + ")")
                )
            )
        )
    )
    #(bms.count, ok_count, relinked, multi, missing)
)

-- relink by replacing a path prefix
fn labor_relink_by_prefix old_prefix new_prefix =
(
    local bms  = labor_collect_bitmaps()
    local n    = 0
    local miss = 0
    local op   = toLower old_prefix

    for t in bms do
    (
        local p = ""
        try ( p = t.filename as string ) catch ( p = "" )
        if p != "" do
        (
            local np = undefined
            if op != "" and (toLower (substring p 1 op.count)) == op then
                np = new_prefix + (substring p (op.count + 1) -1)
            else if op == "" then
                np = new_prefix + (filenameFromPath p)

            if np != undefined do
            (
                if doesFileExist np then
                (
                    try
                    (
                        t.filename = np
                        try ( t.reload() ) catch ()
                        n += 1
                    )
                    catch ( miss += 1 )
                )
                else ( miss += 1 )
            )
        )
    )
    #(bms.count, n, miss)
)

-- copy every used bitmap into one folder
fn labor_pack_textures dest_folder =
(
    local okc  = 0
    local miss = 0
    if not (doesDirectoryExist dest_folder) do
    (
        try ( makeDir dest_folder ) catch ()
    )
    local bms = labor_collect_bitmaps()
    for t in bms do
    (
        local p = ""
        try ( p = t.filename as string ) catch ( p = "" )
        if p != "" and doesFileExist p then
        (
            local target = labor_join_path dest_folder (filenameFromPath p)
            try
            (
                copyFile p target
                okc += 1
            )
            catch ( miss += 1 )
        )
        else ( miss += 1 )
    )
    #(okc, miss)
)

-- viewport texture display toggle
fn labor_toggle_viewport_textures state =
(
    local mats = #()
    for o in geometry where (isValidNode o) and (o.material != undefined) do
    (
        local m = o.material
        if (classOf m) == Multimaterial then
        (
            for i = 1 to m.numsubs do
            (
                local sm = undefined
                try ( sm = m[i] ) catch ( sm = undefined )
                if sm != undefined and (findItem mats sm == 0) do append mats sm
            )
        )
        else if (findItem mats m == 0) do append mats m
    )
    local n = 0
    for m in mats do
    (
        try
        (
            showTextureMap m state
            n += 1
        )
        catch ()
    )
    try ( redrawViews() ) catch ()
    n
)

--------------------------------------------------------------------------------
-- end of file : labor_textures.ms
--------------------------------------------------------------------------------
if labor_loading == undefined or labor_loading != true do
(
    format "[labor] labor_textures.ms is only a module, please run labor.ms to open the panel.\n"
)
