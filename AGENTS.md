# AGENTS.md

Neovim plugin that previews PlantUML diagrams in a vsplit via image.nvim. Pure Lua (LuaJIT), no build step, no linter config in the repo. There IS a plenary/busted test suite in `tests/` and a GitHub Actions workflow (`.github/workflows/ci.yml`) that runs it on every push/PR to `main` — treat it as the merge gate.

## Architecture

- `plugin/plantuml.lua` is the side-effect entrypoint: maps user commands (`:PlantumlPreviewToggle`, `Open`, `Close`, `Next`, `Prev`, `ZoomIn`, `ZoomOut`, `ZoomReset`) to methods on `require("plantuml")`. Adding a command requires editing the `commands` table here **and** implementing the method in `lua/plantuml/init.lua`.
- `lua/plantuml/` modules:
  - `init.lua` — public API (`setup`, `open`, `close`, `toggle`, `next_diagram`, `prev_diagram`, `zoom_in`, `zoom_out`, `zoom_reset`); gate on PlantUML filetypes (`puml`, `plantuml`, `pu`).
  - `config.lua` — module-global `M.options` (deepcopy of defaults); `setup()` mutates it via `vim.tbl_deep_extend("force", ...)`. Note `setup()` **accumulates** across calls; it never resets.
  - `paths.lua` — builds temp source path `<temp_dir>/<bufnr>.puml`.
  - `renderer.lua` — async render via `jobstart`; results delivered through callbacks wrapped in `vim.schedule`. Never do nvim API work synchronously in the `on_exit` handler.
  - `watcher.lua` — per-buffer augroup + `uv.new_timer` debounce on `TextChanged`/`TextChangedI`/`BufWritePost`.
  - `preview.lua` — owns preview state keyed by source bufnr (`state.previews[bufnr]`); all window/buffer cleanup must go through `M.close`/`clear_current_image`.

## Gotchas

- Rendering requires the `image.nvim` plugin (pcall-required as `image`) and a `plantuml` CLI on PATH. Both are missing by default; handle gracefully.
- **Each render writes to its own directory** `<temp_dir>/<bufnr>_<hrtime>/`, producing `<bufnr>.png` / `<bufnr>_<n>.png` inside (multi-diagram files). `renderer.find_output_files` matches on the `<bufnr>` prefix *within that render dir*. Render dirs are only deleted on `preview.close` (`renderer.cleanup`); never delete them while a preview is open, or image.nvim will fail with "unable to open image" when it re-identifies a deleted file.
- **Stale render callbacks**: `renderer.render` bumps a per-bufnr generation counter; `on_exit` drops callbacks whose generation is no longer current. `renderer.invalidate(bufnr)` (called from `preview.close`) makes in-flight callbacks no-ops. Callbacks may still be invoked repeatedly and after `close` — guard accordingly.
- Filter empty lines in `on_stderr` (`data` arrives as `{""}` at stream close) or you'll spam empty `plantuml.nvim:` notifications that trigger "Press ENTER".
- Zoom only re-renders the image geometry (via image.nvim's `render(geometry)`, with `ignore_global_max_size` set so the pane is never resized). **zoom=1 means "fit the whole diagram inside the preview window"** (aspect preserved); zoom < 1 shrinks, zoom > 1 overflows the pane on purpose. Zoom config lives in `config.zoom`.

## Verification

- Run `./tests/run.sh` (or `make test`) — plenary/busted, headless. Renderer specs use `plantuml -tutxt` text output so no image.nvim/terminal is needed; preview specs stub the `image` module via `package.preload`.
- The test harness needs the `plenary.nvim` runtime and a `plantuml` CLI on PATH. Plenary is found in `~/.local/share/nvim/site/pack/core/opt/plenary.nvim` by default; override with the `PLENARY_PATH` env var.
- CI runs `./tests/run.sh` on every push/PR to `main` (installs nvim >= 0.10, plantuml, plenary). `vim.uv` usage means nvim >= 0.10 is required.
- LuaLS config lives at `.lua_ls/config.json` (LuaJIT runtime, nvim runtime library) if a language server is available; `stylua`/`lua-language-server` are not installed here.
