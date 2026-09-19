# labor-3dsmax

**labor** — a modular 3ds Max workflow toolkit by Vino.
Solves the annoying everyday stuff, especially the **3ds Max → Unreal Engine** pipeline.

**labor** —— 一套模块化的 3ds Max 效率工具集。
解决日常制作痛点，重点是 **3ds Max → Unreal Engine** 的导入流程。

- Author: Vino · <https://vinofx.com> · B站 250546761 · 公众号「Vino自习室」
- License: MIT · Copyright (c) 2024 Vino
- Target: 3ds Max 2018+ / pure MAXScript, no plugin required

---

## Directory structure

Everything MAXScript lives in **`src/`**. Copy the *content* of `src/` into
your 3ds Max `scripts\` folder — the two entries will then sit next to each other.

```
labor-3dsmax/
├─ README.md
├─ LICENSE
├─ CHANGELOG.md
├─ tools/
│  └─ check_mxs.py            optional static check (python 3, no deps)
└─ src/                       <-- copy THIS into  3ds Max\scripts\
   │
   ├─ labor.ms                ★ ENTRY A : labor 工具集入口（唯一入口）
   ├─ labor/                    库 —— 纯逻辑，不建 UI
   │   ├─ labor_core.ms          公共工具：日志/路径/文件名/对象过滤/世界包围盒/单位
   │   ├─ labor_ue.ms            UE 导出准备：轴心/ResetXForm/Max↔UE 坐标/资产检查
   │   ├─ labor_fbx.ms           FBX 导出：预设参数/单文件/逐对象
   │   ├─ labor_textures.ms      贴图：递归重链接/前缀替换/打包/视口开关
   │   ├─ labor_materials.ms     材质：Standard↔VRay / PBR→Standard / PBR→VRay
   │   ├─ labor_model.ms         模型：顺序对齐/塌陷/法线/平滑组/焊接/开放边
   │   ├─ labor_scene.ms         场景：统计/清理/快速选择/批量重命名
   │   └─ ui/                    UI —— 每个文件一个 rollout 面板
   │       ├─ labor_ui_ue.ms
   │       ├─ labor_ui_textures.ms
   │       ├─ labor_ui_materials.ms
   │       ├─ labor_ui_model.ms
   │       ├─ labor_ui_scene.ms
   │       └─ labor_ui_about.ms
   │
   ├─ vino_scene_toolkit.ms   ★ ENTRY B : Vino Scene Toolkit 入口
   └─ vino_scene_toolkit/
       └─ scene_scanner.ms       模块 01 场景扫描（后续 scene_cleanup.ms 直接放这里）
```

### The one rule to remember

> **A suite = one entry `.ms` at the root of `src/` + one folder with the same
> name holding its modules.**
> Entry inside `src/`: `labor.ms`, `vino_scene_toolkit.ms`. Everything else is a
> module and does nothing on its own — dragging a module file just tells you to
> run the entry.

入口规则：**入口在前，模块在同名的文件夹里。** 拖其它 .ms 只会提示你运行入口文件。

---

## Install

**A. Quick / 快速（推荐）**
Drag `src\labor.ms` into the 3ds Max viewport once. It loads every module and
opens the panel. Do the same with `src\vino_scene_toolkit.ms` if you need the
scene toolkit.

**B. Permanent / 常驻**
1. Copy everything inside `src\` into
   `C:\Users\<you>\AppData\Local\Autodesk\3ds Max 20xx\ENU\scripts\`
2. Restart Max.
3. *Customize → Customize User Interface → Category:* `labor`
   → drag **`labor`** to a toolbar or assign a hotkey.
   Category `Vino Scene Toolkit` → **`Vino Toolkit`** for the other suite.

**C. Auto-load without the panel popping up / 静默自启**
Put one line in `scripts\Startup\labor_startup.ms`:
```maxscript
fileIn @"<your scripts dir>\labor.ms"
```
and set `labor_auto_open = false` right before the load section in `labor.ms`
(see the comments at the bottom of that file).

---

## Panels

| # | Panel | Highlights |
|---|---|---|
| ① | UE 导出准备 | 轴心置底 5 种模式、吸附地面、单位检查、ResetXForm、Max↔UE 坐标对照（Location = (X, −Y, Z)）、FBX 导出预设、逐对象导出 |
| ② | 贴图工具 | 目录递归重链接、前缀批量替换、贴图打包、视口贴图开关 |
| ③ | 材质工具 | Standard↔VRay、PBR Metal/Rough → Standard / VRay、随机材质、线框色材质（ID 通道） |
| ④ | 模型工具 | X/Y/Z 顺序对齐（BBox+偏移）、塌陷堆栈、转 Poly、翻转/统一法线、自动平滑、焊接顶点、开放边检查 |
| ⑤ | 场景工具 | 场景体检、空对象/空 Dummy/空图层清理、全部取消隐藏与解冻、Helper/Shape 显隐、快速选择、批量重命名 |
| ⑥ | 关于 | 版本与作者信息 |

*(⑤ 面板里的统计是即时计数；要做结构化数据与后续自动化请用 Vino Scene Toolkit 的 Scene Scanner)*

---

## File types: `.ms` / `.mcr` / `.mse` / `.mzp`

| ext | what it is | use it? |
|---|---|---|
| `.ms` | plain MAXScript source, editable, diffable, version-control friendly | ✅ **yes — this repo's format** |
| `.mcr` | identical syntax to `.ms`, just the convention name for a *macro* file so Max installs it when dropped | optional |
| `.mse` | **encrypted** MAXScript. Max can run it, nobody can read or edit it — meant for selling scripts | ❌ no (contradicts MIT open source) |
| `.mzp` | MAXScript ZIP Package: a `.ms`/`.mcr` plus icons/assets bundled as one installable file | optional, for distribution |

So **not MSE** for this project: once encrypted you lose GitHub diffs, PR review,
issue triage and easy hot-fixing. If you later want a one-click installer for
end users, build a `.mzp` from these `.ms` files — keep the source public.

---

## Adding a module later

1. Write the logic: `src\labor\labor_yourtopic.ms` (functions `labor_*`).
2. Write the panel: `src\labor\ui\labor_ui_yourtopic.ms` with `rollout labor_roll_yourtopic (...)`.
3. Register it in `src\labor.ms` — two lines:
   ```maxscript
   fileIn ( labor_lib_dir + "labor_yourtopic.ms" )
   fileIn ( labor_ui_dir  + "labor_ui_yourtopic.ms" )
   ```
   plus one `addRollout labor_roll_yourtopic labor_floater rolledup:true` in `labor_open_ui`.

Convention: `snake_case` everywhere, every public function declared with a
`global a, b, c` line at the top of its file so the scope is always unambiguous.

---

## Dev check

We cannot run a MAXScript compiler outside Max, so the repo ships a static check:

```bash
python tools/check_mxs.py src
```

It verifies: parenthesis balance outside comments/strings, no `;` multi-statement
lines, no backslash line-continuations, no BOM, and globally unique
`fn` / `rollout` / `macroScript` names.

---

## Roadmap

- [x] Module 01 Scene Scanner
- [ ] Module 02 Scene Cleanup (consumes `vino_scene_data` directly)
- [ ] optionally ship an `.mzp` installer
- [ ] split → separate per-panel hotkeys

---

## License

MIT License · Copyright (c) 2024 Vino. See [LICENSE](LICENSE).
