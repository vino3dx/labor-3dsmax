# Changelog

All notable changes to this project.

## [1.2.1] - 2026-09-20  (repository move)

### Changed
- Repository moved to `D:\Workspace\Code\labor-3dsmax`, remote
  `git@github.com:vino3dx/labor-3dsmax.git`.
- All references updated from `vinceofx/3dsmax-labor` to `vino3dx/labor-3dsmax`
  (script headers, README, about panel, changelog).

## [1.2.0] - 2026-09-20  (structure refactor, no functional change)

### Changed
- **Single monolithic `labor.ms` (2506 lines) split into 13 module files.**
  - `src/labor.ms` is now the only entry: resolve path → `fileIn` modules → build floater.
  - `src/labor/*.ms` — pure logic, no UI.
  - `src/labor/ui/*.ms` — one rollout per file.
- Repo re-organised around `src/`, which maps 1:1 onto 3ds Max `scripts\`.
- `vino_scene_toolkit` moved into `src/` and follows the same convention
  (`vino_scene_toolkit.ms` + `vino_scene_toolkit\`); the extra `modules\`
  level was removed.
- Naming rule unified with labor: entry file + same-name folder.
- Added `README.md`, `LICENSE`, `tools/check_mxs.py`.

### Notes
- All public functions now carry an explicit `global` declaration line, so
  including modules from any scope keeps them global.
- Feature code is byte-identical to 1.1.0: 58 functions, all verified moved.

## [1.1.0] - 2026-09-19

### Added
- Panel ⑤ Scene tools: scene report, cleanup (empty objects / dummies / layers /
  orphan materials), display & viewport performance, quick selection, batch rename.
- Model tools: collapse stack, convert to poly, flip/unify normals, auto smooth,
  clear smoothing groups, weld vertices, open edge report.
- UE asset check: duplicate names, illegal names, pivot-on-bottom, `SM_` prefix.

## [1.0.0] - 2026-09-19

### Added
- First release, renamed from MaxKit to `labor`, all identifiers `snake_case`.
- UE export prepare, textures, materials, model tool modules.
- Merged the old `max-flow`, `PBRMetalRoughMtl_To_StandardMtl`,
  `Vino Missing Texture Relinker` scripts into one tool set.

## [0.1.0] - 2026-09-19

### Added
- Vino Scene Toolkit module 01 Scene Scanner (read-only scene scan + data API + UI).
