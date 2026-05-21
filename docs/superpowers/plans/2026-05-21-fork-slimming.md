# nvim-treesitter Personal Fork Slimming — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slim the archived-upstream `main`-branch rewrite into a lean, single-user vendored fork: remove indentation, replace the oversized vendored async library with a minimal coroutine helper, and strip community-maintenance metadata — while keeping the upstream-revision-tracking pipeline intact.

**Architecture:** The plugin's job is unchanged (version-locked parser install/update + curated query install + filetype/predicate registration). We delete the one in-plugin feature (indentation), shrink `async.lua` to only what `install.lua` uses plus the documented `Task:wait()` bootstrap contract, and remove `tier`-filtering / `maintainers` / `readme_note` machinery that only ever served the public catalog. The per-entry `tier` field and `scripts/update-parsers.lua` stay, because that script reads `tier` to refresh ~326 pinned parser revisions.

**Tech Stack:** Lua (LuaJIT, Neovim 0.12+), libuv (`vim.uv`), `vim.system`, tree-sitter CLI, tree-sitter query files (`.scm`).

**Decisions locked in (from brainstorming):**
- **Indentation:** remove entirely.
- **`locals` queries:** KEEP (other plugins may read them off `runtimepath`).
- **Maintainer pipeline:** KEEP `scripts/update-parsers.lua` + `scripts/install-parsers.lua` + the per-entry `tier` field. Cut only runtime tier *filtering* and the `maintainers`/`readme_note` metadata.
- **`async.lua`:** rewrite to a minimal helper.

**Constraints:** Neovim ≥ 0.12 only; single-user; no backward-compat concerns; breaking changes are fine.

**Environment notes:**
- Verified local toolchain: `nvim` v0.12.2 on PATH; `stylua` NOT on PATH (formatting steps are optional/guarded).
- Scratch/test files live under `_scratch/` per user convention.
- Work on a branch, one commit per task. Do NOT push unless asked.

**Phase ordering & dependencies:**
1. Task 1 — Strip indentation (independent).
2. Task 2 — Rewrite `async.lua` (independent).
3. Task 3 — Remove `tier`-filtering + `maintainers`/`readme_note` metadata + their sole generator (`update-readme.lua`). MUST run as one commit because `update-readme.lua` is the only consumer of `config.tiers`/`maintainers`/`readme_note`.
4. Task 4 — (Optional) `get_available` autocmd side-effect + minor polish.
5. Task 5 — (Optional, your call) public-audience scaffolding cull.

---

## Task 0: Create the working branch

**Files:** none (git only)

- [ ] **Step 1: Create and switch to a branch**

```bash
cd /Users/kit/Source/nvim-treesitter
git switch -c fork-slimming
```

- [ ] **Step 2: Confirm a clean-ish baseline loads**

Note: the `.github/**` deletions already present in the working tree are unrelated and can be committed or left; this plan does not touch them.

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -c 'lua require("nvim-treesitter")' -c 'qa'
```
Expected: exits 0, no error output. (This is the smoke test reused throughout.)

---

## Task 1: Strip indentation

**Files:**
- Delete: `lua/nvim-treesitter/indent.lua`
- Delete: `tests/indent/` (entire tree, 297 files)
- Delete: `runtime/queries/*/indents.scm` (169 files)
- Delete: `plugin/query_predicates.lua` (the `kind-eq?`/`any-kind-eq?` predicates are used only by `indents.scm`)
- Modify: `lua/nvim-treesitter/init.lua` (remove `indentexpr()` export)
- Modify: `lua/nvim-treesitter/health.lua:125,149,172` (drop the Indents column/legend/bundled query)
- Modify: `README.md` (remove `## Indentation` section)
- Modify: `doc/nvim-treesitter.txt` (remove indent mentions + `indentexpr()` API entry)
- Modify: `scripts/minimal_init.lua:19` (remove `indentexpr` autocmd line)
- Modify: `scripts/update-readme.lua:53` (remove the `I` query glyph)

> **Caveat — `query_predicates.lua`:** verified within this repo that `kind-eq` appears only in 8 `indents.scm` files. If any query in *your personal config* uses `#kind-eq?`/`#any-kind-eq?`, do NOT delete `plugin/query_predicates.lua` — keep that one file and skip Step 4.

- [ ] **Step 1: Delete the indent engine and its tests**

```bash
git rm lua/nvim-treesitter/indent.lua
git rm -r tests/indent
```
Expected: git reports `rm` for `indent.lua` and ~297 files under `tests/indent/`.

- [ ] **Step 2: Delete all `indents.scm` query files**

```bash
git rm runtime/queries/*/indents.scm
```
Expected: git reports `rm` for 169 files. (The glob only matches languages that ship one; that is correct.)

- [ ] **Step 3: Verify the count removed**

Run:
```bash
fd indents.scm runtime/queries | wc -l
```
Expected: `0`

- [ ] **Step 4: Delete the indents-only query predicates** (see caveat above)

```bash
git rm plugin/query_predicates.lua
```
Expected: git reports `rm plugin/query_predicates.lua`.

- [ ] **Step 5: Remove the `indentexpr()` export from `init.lua`**

In `lua/nvim-treesitter/init.lua`, replace:

```lua
end

function M.indentexpr()
  return require('nvim-treesitter.indent').get_indent(vim.v.lnum)
end

return M
```

with:

```lua
end

return M
```

- [ ] **Step 6: Edit `health.lua` — header row (line 125)**

Replace:
```lua
  health.start('Installed languages' .. string.rep(' ', 5) .. 'H L F I J')
```
with:
```lua
  health.start('Installed languages' .. string.rep(' ', 5) .. 'H L F J')
```

- [ ] **Step 7: Edit `health.lua` — legend (line 149)**

Replace:
```lua
  health.start('  Legend: [H]ighlights, [L]ocals, [F]olds, [I]ndents, In[J]ections')
```
with:
```lua
  health.start('  Legend: [H]ighlights, [L]ocals, [F]olds, In[J]ections')
```

- [ ] **Step 8: Edit `health.lua` — bundled queries (line 172)**

Replace:
```lua
M.bundled_queries = { 'highlights', 'locals', 'folds', 'indents', 'injections' }
```
with:
```lua
M.bundled_queries = { 'highlights', 'locals', 'folds', 'injections' }
```
(`locals` stays — see decisions. This also makes `scripts/check-queries.lua` stop checking indents automatically.)

- [ ] **Step 9: Remove the `## Indentation` section from `README.md`**

Replace:
```markdown
## Indentation

Treesitter-based indentation is provided by this plugin but considered **experimental**. To enable it, put the following in your `ftplugin` or `FileType` autocommand:

```lua
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
```

(Note the specific quotes used.)

## Injections
```
with:
```markdown
## Injections
```

- [ ] **Step 10: Edit `doc/nvim-treesitter.txt` — intro feature list (lines 16-18)**

Replace:
```
Nvim-treesitter provides functionalities for managing treesitter parsers and
compatible queries for core features (highlighting, injections, folds,
indents).
```
with:
```
Nvim-treesitter provides functionalities for managing treesitter parsers and
compatible queries for core features (highlighting, injections, folds).
```

- [ ] **Step 11: Edit `doc/nvim-treesitter.txt` — QUICK START autocmd (lines 49-50)**

Replace:
```
      -- folds, provided by Neovim
      vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      vim.wo.foldmethod = 'expr'
      -- indentation, provided by nvim-treesitter
      vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
```
with:
```
      -- folds, provided by Neovim
      vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      vim.wo.foldmethod = 'expr'
    end,
```

- [ ] **Step 12: Edit `doc/nvim-treesitter.txt` — remove the `indentexpr()` API entry (lines 162-166)**

Replace:
```
indentexpr()                                      *nvim-treesitter.indentexpr()*

    Used to enable treesitter indentation for a language via >lua
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
<
get_available([{tier}])                        *nvim-treesitter.get_available()*
```
with:
```
get_available([{tier}])                        *nvim-treesitter.get_available()*
```
(The `[{tier}]` signature is corrected later in Task 3.)

- [ ] **Step 13: Edit `scripts/minimal_init.lua` — remove indent autocmd (line 19)**

Replace:
```lua
  callback = function(args)
    pcall(vim.treesitter.start)
    vim.bo[args.buf].indentexpr = 'v:lua.require"nvim-treesitter".indentexpr()'
  end,
```
with:
```lua
  callback = function(args)
    pcall(vim.treesitter.start)
  end,
```

- [ ] **Step 14: Edit `scripts/update-readme.lua` — remove the `I` glyph (line 53)**

Replace:
```lua
    .. (vim.uv.fs_stat('runtime/queries/' .. v.name .. '/folds.scm') and 'F' or ' ')
    .. (vim.uv.fs_stat('runtime/queries/' .. v.name .. '/indents.scm') and 'I' or ' ')
    .. (vim.uv.fs_stat('runtime/queries/' .. v.name .. '/injections.scm') and 'J' or ' ')
```
with:
```lua
    .. (vim.uv.fs_stat('runtime/queries/' .. v.name .. '/folds.scm') and 'F' or ' ')
    .. (vim.uv.fs_stat('runtime/queries/' .. v.name .. '/injections.scm') and 'J' or ' ')
```

- [ ] **Step 15: Verify no dangling indent references remain in Lua**

Run:
```bash
rg -n 'indent' lua/ plugin/ scripts/ doc/ README.md
```
Expected: no hits referencing `indent.lua`, `indentexpr`, `indents.scm`, or the `I`/`[I]ndents` legend. (Hits inside `tests/` are gone; `runtime/queries` no longer has `indents.scm`.) If anything remains, fix it before continuing.

- [ ] **Step 16: Verify the plugin still loads and health runs**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -c 'lua require("nvim-treesitter")' -c 'qa'
nvim --headless --clean --cmd 'set rtp+=.' -c 'checkhealth nvim-treesitter' -c 'qa' 2>&1 | head -30
```
Expected: first command exits 0 with no errors; checkhealth prints the Requirements/Install sections and the `H L F J` languages grid (no `I` column), no Lua errors.

- [ ] **Step 17: Commit**

```bash
git add -A
git commit -m "refactor: remove experimental treesitter indentation

Delete the in-plugin indent engine, its 169 indents.scm queries, the
indents-only kind-eq query predicates, and the ~297-file indent test tree.
Indentation is experimental and slated for Neovim core; this fork is
single-user on nvim>=0.12 and does not need it."
```

---

## Task 2: Rewrite `async.lua` as a minimal coroutine helper

**Files:**
- Create: `_scratch/async_spec.lua` (characterization test — runs against old AND new module)
- Create: `_scratch/install_smoke.lua` (end-to-end install integration test)
- Modify (full rewrite): `lua/nvim-treesitter/async.lua`

**Approach (characterization-first):** `install.lua` uses only `async`, `await`, `awrap`, `schedule`, plus `Task:await(cb)` (in its local `join`) and the documented `Task:wait(timeout)` bootstrap contract (`README` / `doc`). We write a test that exercises exactly that surface, prove it passes against the *current* 737-line module, then swap in the ~70-line replacement and prove it still passes.

- [ ] **Step 1: Write the characterization test**

Create `_scratch/async_spec.lua`:

```lua
-- Characterization test for nvim-treesitter.async.
-- Exercises only the surface install.lua + the documented Task:wait() use.
-- Run with: nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/async_spec.lua
local a = require('nvim-treesitter.async')

-- A deferred, callback-style op (the awrap shape install.lua relies on).
-- Returns nothing so neither the old nor the new lib tries to auto-close it;
-- we close the timer ourselves.
local sleep = a.awrap(2, function(ms, cb)
  local t = assert(vim.uv.new_timer())
  t:start(ms, 0, function()
    t:stop()
    t:close()
    cb('woke')
  end)
end)

-- Test 1: awrap + schedule ordering, Task:wait returns the function result.
local log = {}
local task = a.async(function()
  log[#log + 1] = 'before'
  local r = sleep(10)
  log[#log + 1] = 'after:' .. r
  a.schedule()
  log[#log + 1] = 'scheduled'
  return 42
end)()
local result = task:wait(2000)
assert(result == 42, 'wait should return 42, got ' .. tostring(result))
assert(
  table.concat(log, ',') == 'before,after:woke,scheduled',
  'ordering wrong: ' .. table.concat(log, ',')
)

-- Test 2: Task:await(cb) fires with (err, result).
local got
a.async(function()
  return 'hello'
end)():await(function(_, v)
  got = v
end)
vim.wait(200, function()
  return got ~= nil
end)
assert(got == 'hello', 'await callback got ' .. tostring(got))

-- Test 3: errors propagate through Task:wait.
local errtask = a.async(function()
  error('boom')
end)()
local ok, err = pcall(function()
  errtask:wait(2000)
end)
assert(not ok, 'wait should raise on task error')
assert(tostring(err):match('boom'), 'error should mention boom, got ' .. tostring(err))

print('async_spec: all tests passed')
```

- [ ] **Step 2: Run the test against the CURRENT module to validate the test**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/async_spec.lua
```
Expected: prints `async_spec: all tests passed`. (If it fails here, the test is wrong — fix the test, not the module.)

- [ ] **Step 3: Replace `async.lua` with the minimal implementation**

Overwrite `lua/nvim-treesitter/async.lua` entirely with:

```lua
--- Minimal coroutine-based async runtime for nvim-treesitter.
---
--- Replaces the larger vendored library. Provides only what install.lua uses
--- (async / await / awrap / schedule, plus Task:await) and the documented
--- Task:wait() bootstrap contract (see :h nvim-treesitter.install()).
local M = {}

--- @param ... any
--- @return { n: integer, [integer]: any }
local function pack(...)
  return { n = select('#', ...), ... }
end

--- @param t? { n: integer, [integer]: any }
--- @return any ...
local function unpack_n(t)
  if t then
    return unpack(t, 1, t.n)
  end
end

--- @class async.Task
--- @field private _thread thread
--- @field private _callbacks fun(err?: any, ...: any)[]
--- @field private _done boolean
--- @field private _err? any
--- @field private _result? { n: integer, [integer]: any }
local Task = {}
Task.__index = Task

--- Register a completion callback, invoked with (err, ...results).
--- If the task already finished, the callback fires immediately.
--- @param callback fun(err?: any, ...: any)
function Task:await(callback)
  if self._done then
    callback(self._err, unpack_n(self._result))
  else
    self._callbacks[#self._callbacks + 1] = callback
  end
end

--- Block until the task finishes, pumping the event loop. Raises on error.
--- @param timeout? integer milliseconds (default: effectively indefinite)
--- @return any ... the task's return values
function Task:wait(timeout)
  local done = vim.wait(timeout or (2 ^ 31 - 1), function()
    return self._done
  end)
  if not done then
    error('nvim-treesitter.async: task timed out')
  elseif self._err ~= nil then
    error(self._err)
  end
  return unpack_n(self._result)
end

--- @private
function Task:_finish(err, result)
  self._err = err
  self._result = result
  self._done = true
  local callbacks = self._callbacks
  self._callbacks = {}
  for _, cb in ipairs(callbacks) do
    cb(err, unpack_n(result))
  end
end

--- @private
--- @param ... any values passed back into the coroutine on resume
function Task:_resume(...)
  local ret = pack(coroutine.resume(self._thread, ...))
  if not ret[1] then
    -- coroutine raised an error
    self:_finish(ret[2])
  elseif coroutine.status(self._thread) == 'dead' then
    -- coroutine returned; ret == { n, true, <returns...> }
    self:_finish(nil, pack(select(2, unpack_n(ret))))
  else
    -- coroutine yielded an await-thunk; drive it, resuming on its callback
    local thunk = ret[2]
    thunk(function(...)
      self:_resume(...)
    end)
  end
end

--- @param func async fun(...): any
--- @return async.Task
local function run(func, ...)
  local task = setmetatable({
    _thread = coroutine.create(func),
    _callbacks = {},
    _done = false,
  }, Task)
  task:_resume(...)
  return task
end

--- Wrap an async function so that calling it starts a Task.
--- @param func async fun(...): any
--- @return fun(...): async.Task
function M.async(func)
  return function(...)
    return run(func, ...)
  end
end

--- Await a callback-style function from within an async context.
--- `fun` is called with the original args plus a resume callback inserted at
--- position `argc`; await returns whatever that callback is invoked with.
--- @async
--- @param argc integer
--- @param fun fun(...): any?
--- @param ... any
--- @return any ...
function M.await(argc, fun, ...)
  local args = pack(...)
  args.n = math.max(args.n, argc)
  return coroutine.yield(function(callback)
    args[argc] = callback
    fun(unpack_n(args))
  end)
end

--- Curry `M.await`: returns an async function that drops the trailing callback.
--- @param argc integer
--- @param fun fun(...): any?
--- @return async fun(...): any
function M.awrap(argc, fun)
  return function(...)
    return M.await(argc, fun, ...)
  end
end

--- Yield to the Neovim scheduler so API calls are allowed after resuming.
--- @async
M.schedule = M.awrap(1, vim.schedule)

return M
```

- [ ] **Step 4: Run the characterization test against the NEW module**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/async_spec.lua
```
Expected: prints `async_spec: all tests passed`.

- [ ] **Step 5: Write the end-to-end install smoke test**

This exercises the full async pipeline (download → build → install → link queries) and the `Task:wait()` contract through `install.lua`. Requires network, `tree-sitter` CLI, and a C compiler (all already required by the project).

Create `_scratch/install_smoke.lua`:

```lua
-- End-to-end install through the rewritten async runtime.
-- Run with: nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/install_smoke.lua
local nts = require('nvim-treesitter')
local dir = vim.fn.fnamemodify('_scratch/ts-smoke', ':p')
vim.fn.delete(dir, 'rf')
nts.setup({ install_dir = dir })

-- 'json' is small, pre-generated, and dependency-free.
nts.install({ 'json' }):wait(180000)

local so = dir .. 'parser/json.so'
local q = dir .. 'queries/json'
assert(vim.uv.fs_stat(so), 'parser .so missing: ' .. so)
assert(vim.uv.fs_stat(q), 'queries dir missing: ' .. q)
print('install_smoke: passed (' .. so .. ')')
```

- [ ] **Step 6: Run the install smoke test**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/install_smoke.lua
```
Expected: prints `install_smoke: passed (...)`. If it fails due to no network/toolchain in this environment, run it manually where those are available before relying on the change.

- [ ] **Step 7: Confirm `async.lua` is the only consumer (no missed API)**

Run:
```bash
rg -n 'require\(.nvim-treesitter\.async.\)' --glob '!_scratch/**'
rg -no 'a\.\w+' lua/nvim-treesitter/install.lua | sort -u
```
Expected: only `lua/nvim-treesitter/install.lua` requires async; the symbols used are exactly `a.async`, `a.await`, `a.awrap`, `a.schedule` (all provided by the new module). `Task:await` is used via the value returned by `a.async(...)()` inside `install.lua`'s local `join`.

- [ ] **Step 8: Commit**

```bash
git add lua/nvim-treesitter/async.lua
git commit -m "refactor(async): replace vendored async lib with minimal helper

install.lua is the only consumer and uses just async/await/awrap/schedule
plus Task:await/Task:wait. Shrinks ~737 lines to ~70, dropping unused
surface (iter/join/joinany/arun/status, Task close/traceback/raise_on_error)
and 5.1/32-bit polyfills (copcall/table.maxn/newproxy). Behavior preserved:
callbacks resume the coroutine synchronously, as install.lua's join requires."
```

> Note: `_scratch/` is gitignored-by-convention scratch space; do not commit the test files unless you want them tracked. If `_scratch` is not in `.gitignore`, the `git add` above (scoped to `async.lua`) keeps them out of the commit regardless.

---

## Task 3: Remove tier-filtering + `maintainers`/`readme_note` metadata + their generator

This is one commit because `scripts/update-readme.lua` is the **sole** consumer of `config.tiers`, `maintainers`, and `readme_note`; removing the metadata without removing the generator would break it, and vice versa.

**Files:**
- Modify: `lua/nvim-treesitter/config.lua` (drop `M.tiers`, `expand_tiers`, `get_available(tier)` filtering, `norm_languages` `skip.unsupported` + dead `skip.installed`)
- Modify: `lua/nvim-treesitter/install.lua:546,558` (drop now-defunct `unsupported = true` flags)
- Modify: `lua/nvim-treesitter/parsers.lua` (strip 313 `maintainers` + 22 `readme_note` lines; keep `tier`)
- Modify: `lua/nvim-treesitter/_meta/parsers.lua` (drop `maintainers` + `readme_note` schema fields; keep `tier`)
- Delete: `scripts/update-readme.lua`, `SUPPORTED_LANGUAGES.md`
- Modify: `doc/nvim-treesitter.txt` (correct `get_available` signature; drop tier-name install mentions)

> **KEEP:** the per-entry `tier` field in `parsers.lua`, `scripts/update-parsers.lua`, and `scripts/install-parsers.lua`. `update-parsers.lua` reads `tier` (stable→latest tag, unstable→HEAD) to refresh pinned revisions.

- [ ] **Step 1: Replace `get_available` in `config.lua` (lines 59-78)**

Replace:
```lua
-- Get a list of all available parsers
---@param tier integer? only get parsers of specified tier
---@return string[]
function M.get_available(tier)
  vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })
  local parsers = require('nvim-treesitter.parsers')
  --- @type string[]
  local languages = vim.tbl_keys(parsers)
  table.sort(languages)
  if tier then
    languages = vim.tbl_filter(
      --- @param p string
      function(p)
        return parsers[p] ~= nil and parsers[p].tier == tier
      end,
      languages
    )
  end
  return languages
end
```
with:
```lua
-- Get a list of all available parsers
---@return string[]
function M.get_available()
  vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })
  local parsers = require('nvim-treesitter.parsers')
  --- @type string[]
  local languages = vim.tbl_keys(parsers)
  table.sort(languages)
  return languages
end
```

- [ ] **Step 2: Delete `expand_tiers` from `config.lua` (lines 80-95)**

Remove the entire function:
```lua
local function expand_tiers(list)
  for i, tier in ipairs(M.tiers) do
    if vim.list_contains(list, tier) then
      list = vim.tbl_filter(
        --- @param l string
        function(l)
          return l ~= tier
        end,
        list
      )
      vim.list_extend(list, M.get_available(i))
    end
  end

  return list
end
```
(Delete the function and the blank line that followed it, so `norm_languages` follows the `get_available` block with a single blank separator.)

- [ ] **Step 3: Replace `norm_languages` in `config.lua` (lines 97-172)**

Replace the whole function:
```lua
---Normalize languages
---@param languages? string[]|string
---@param skip? { missing: boolean?, unsupported: boolean?, installed: boolean?, dependencies: boolean? }
---@return string[]
function M.norm_languages(languages, skip)
  if not languages then
    return {}
  elseif type(languages) == 'string' then
    languages = { languages }
  end

  if vim.list_contains(languages, 'all') then
    if skip and skip.missing then
      return M.get_installed()
    end
    languages = M.get_available()
  end

  languages = expand_tiers(languages)

  if skip and skip.installed then
    local installed = M.get_installed()
    languages = vim.tbl_filter(
      --- @param v string
      function(v)
        return not vim.list_contains(installed, v)
      end,
      languages
    )
  end

  if skip and skip.missing then
    local installed = M.get_installed()
    languages = vim.tbl_filter(
      --- @param v string
      function(v)
        return vim.list_contains(installed, v)
      end,
      languages
    )
  end

  local parsers = require('nvim-treesitter.parsers')
  languages = vim.tbl_filter(
    --- @param v string
    function(v)
      if parsers[v] ~= nil then
        return true
      else
        require('nvim-treesitter.log').warn('skipping unsupported language: ' .. v)
        return false
      end
    end,
    languages
  )

  if skip and skip.unsupported then
    languages = vim.tbl_filter(
      --- @param v string
      function(v)
        return not (parsers[v] and parsers[v].tier and parsers[v].tier == 4)
      end,
      languages
    )
  end

  if not (skip and skip.dependencies) then
    for _, lang in pairs(languages) do
      if parsers[lang] and parsers[lang].requires then
        vim.list_extend(languages, parsers[lang].requires)
      end
    end
  end

  return vim.list.unique(languages)
end
```
with:
```lua
---Normalize languages
---@param languages? string[]|string
---@param skip? { missing: boolean?, dependencies: boolean? }
---@return string[]
function M.norm_languages(languages, skip)
  if not languages then
    return {}
  elseif type(languages) == 'string' then
    languages = { languages }
  end

  if vim.list_contains(languages, 'all') then
    if skip and skip.missing then
      return M.get_installed()
    end
    languages = M.get_available()
  end

  if skip and skip.missing then
    local installed = M.get_installed()
    languages = vim.tbl_filter(
      --- @param v string
      function(v)
        return vim.list_contains(installed, v)
      end,
      languages
    )
  end

  local parsers = require('nvim-treesitter.parsers')
  languages = vim.tbl_filter(
    --- @param v string
    function(v)
      if parsers[v] ~= nil then
        return true
      else
        require('nvim-treesitter.log').warn('skipping unsupported language: ' .. v)
        return false
      end
    end,
    languages
  )

  if not (skip and skip.dependencies) then
    for _, lang in pairs(languages) do
      if parsers[lang] and parsers[lang].requires then
        vim.list_extend(languages, parsers[lang].requires)
      end
    end
  end

  return vim.list.unique(languages)
end
```

- [ ] **Step 4: Delete `M.tiers` from `config.lua` (line 3)**

Remove:
```lua
M.tiers = { 'stable', 'unstable', 'unmaintained', 'unsupported' }
```
(Leave the surrounding blank line tidy: `local M = {}` followed by a blank, then the `TSConfig` annotation.)

- [ ] **Step 5: Drop the defunct `unsupported = true` flags in `install.lua`**

At `install.lua:546`, replace:
```lua
  languages = config.norm_languages(languages, { unsupported = true })
```
with:
```lua
  languages = config.norm_languages(languages)
```

At `install.lua:558`, replace:
```lua
  languages = config.norm_languages(languages, { missing = true, unsupported = true })
```
with:
```lua
  languages = config.norm_languages(languages, { missing = true })
```
(Leave `install.lua:616` `{ missing = true, dependencies = true }` unchanged.)

- [ ] **Step 6: Strip `maintainers` and `readme_note` lines from `parsers.lua`**

Run (whole-line removal; both fields are single-line, verified):
```bash
rg -v '^\s*(maintainers|readme_note) = ' lua/nvim-treesitter/parsers.lua > _scratch/parsers.lua.tmp \
  && mv _scratch/parsers.lua.tmp lua/nvim-treesitter/parsers.lua
```

- [ ] **Step 7: Verify the strip removed exactly the expected lines**

Run:
```bash
rg -c 'maintainers = ' lua/nvim-treesitter/parsers.lua; echo "(expect: no matches / 0)"
rg -c 'readme_note' lua/nvim-treesitter/parsers.lua;   echo "(expect: no matches / 0)"
rg -c '    tier = ' lua/nvim-treesitter/parsers.lua;   echo "(expect: 329 — tier preserved)"
```
Expected: `maintainers`/`readme_note` report no matches; `tier` reports `329`.

- [ ] **Step 8: Verify `parsers.lua` still loads as valid Lua**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' \
  -c '=#vim.tbl_keys(require("nvim-treesitter.parsers"))' -c 'qa'
```
Expected: prints `329` (the parser count), no Lua syntax error.

- [ ] **Step 9: Remove `maintainers` + `readme_note` from the `_meta` schema**

In `lua/nvim-treesitter/_meta/parsers.lua`, replace:
```lua
---@class ParserInfo
---
---Information necessary to build and install the parser (empty for query-only language)
---@field install_info? InstallInfo
---
---List of Github users maintaining the queries for Neovim
---@field maintainers? string[]
---
---List of other languages to install (e.g., if queries inherit from them)
---@field requires? string[]
---
---Language support tier, maps to "stable", "unstable", "unmaintained", "unsupported"
---@field tier integer
---
---Explanatory footnote text to add in SUPPORTED_LANGUAGES.md
---@field readme_note? string
```
with:
```lua
---@class ParserInfo
---
---Information necessary to build and install the parser (empty for query-only language)
---@field install_info? InstallInfo
---
---List of other languages to install (e.g., if queries inherit from them)
---@field requires? string[]
---
---Language support tier; read by scripts/update-parsers.lua (1=stable uses
---latest tag, others track HEAD)
---@field tier integer
```

- [ ] **Step 10: Delete the public catalog generator and its output**

```bash
git rm scripts/update-readme.lua SUPPORTED_LANGUAGES.md
```
Expected: git reports `rm` for both.

- [ ] **Step 11: Confirm the kept update pipeline does not reference removed fields**

Run:
```bash
rg -n 'maintainers|readme_note|\.tiers' scripts/update-parsers.lua scripts/install-parsers.lua
rg -n '\btier\b' scripts/update-parsers.lua
```
Expected: first command — no hits (the kept scripts don't use removed metadata). Second command — hits showing `update-parsers.lua` still reads `tier` (this is intended; the field stays).

- [ ] **Step 12: Fix the `get_available` doc signature in `doc/nvim-treesitter.txt`**

Replace:
```
get_available([{tier}])                        *nvim-treesitter.get_available()*

    Return list of languages available for installation.

    Parameters: ~
    • {tier}  `(integer?)` Only return languages of specified {tier} (`1`:
              stable, `2`: unstable, `3`: unmaintained, `4`: unsupported)
```
with:
```
get_available()                                *nvim-treesitter.get_available()*

    Return list of languages available for installation.
```

- [ ] **Step 13: (Optional doc polish) Drop tier-name install mentions**

`expand_tiers` is gone, so `:TSInstall stable` / `:TSInstall unstable` no longer work. If you keep `doc/`, update these references for accuracy (each is a small prose edit; line numbers approximate after earlier edits):
- `:TSInstall` entry — remove "or tiers (`stable`, `unstable`, or `all` (not recommended))", keep `all`.
- `:TSUpdate` entry — remove "or tier".
- `install()` / `uninstall()` / `update()` API params — remove "or tiers (`stable`, `unstable`)".

Run to locate them:
```bash
rg -n 'tier' doc/nvim-treesitter.txt
```
Fix each hit, or skip this step if you intend to cut `doc/` in Task 5.

- [ ] **Step 14: Verify load, completion, and health**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -c 'lua require("nvim-treesitter")' -c 'qa'
nvim --headless --clean --cmd 'set rtp+=.' \
  -c '=vim.tbl_count(require("nvim-treesitter.config").get_available())' -c 'qa'
nvim --headless --clean --cmd 'set rtp+=.' -c 'checkhealth nvim-treesitter' -c 'qa' 2>&1 | head -30
```
Expected: loads with no error; `get_available()` prints `329`; checkhealth runs with no Lua errors.

- [ ] **Step 15: Verify a real install path still normalizes correctly**

Run (no network — just exercises `norm_languages` + dependency resolution):
```bash
nvim --headless --clean --cmd 'set rtp+=.' \
  -c '=vim.inspect(require("nvim-treesitter.config").norm_languages({"angular"}))' -c 'qa'
```
Expected: a table containing `angular` plus its `requires` deps `html` and `html_tags` (dependency resolution intact).

- [ ] **Step 16: Commit**

```bash
git add -A
git commit -m "refactor: drop tier-filtering and community catalog metadata

Remove runtime tier filtering (config.tiers/expand_tiers/get_available tier
arg/unsupported skip) and the unreachable skip.installed branch; strip the
maintainers (313) and readme_note (22) fields that only fed the public
SUPPORTED_LANGUAGES.md catalog, and delete that generator + output.

Keep the per-entry tier field and scripts/update-parsers.lua: tier still
drives stable-tag-vs-HEAD revision tracking for the parser registry."
```

---

## Task 4 (OPTIONAL): `get_available` autocmd side-effect + minor polish

> Optional and slightly behavior-changing. Do this only if you want the cleanup.

**Files:**
- Modify: `lua/nvim-treesitter/config.lua` (remove `User TSUpdate` autocmd from `get_available`)
- Modify: `lua/nvim-treesitter/install.lua:327-331` (tolerate first-install ENOENT in the hot-swap)

**Context:** `get_available()` fires `nvim_exec_autocmds('User', { pattern = 'TSUpdate' })` (config.lua:63), which runs on *every tab-completion* of `:TSInstall`. That event is the public hook for registering custom parsers, and it still fires at the real mutation points (`install.lua` `reload_parsers` and `uninstall`). Firing it on completion re-runs user callbacks needlessly.

> **Skip this task if** you register custom parsers via `User TSUpdate` and rely on them appearing in `:TSInstall` completion — removing the autocmd from `get_available` means custom parsers only resolve at install time, not in completion.

- [ ] **Step 1: Remove the autocmd from `get_available`**

In `config.lua`, in the `get_available` function, delete the line:
```lua
  vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })
```
so the function reads:
```lua
function M.get_available()
  local parsers = require('nvim-treesitter.parsers')
  --- @type string[]
  local languages = vim.tbl_keys(parsers)
  table.sort(languages)
  return languages
end
```

- [ ] **Step 2: Verify custom-parser registration still works at install time**

Create `_scratch/custom_parser.lua`:
```lua
vim.api.nvim_create_autocmd('User', {
  pattern = 'TSUpdate',
  callback = function()
    require('nvim-treesitter.parsers').zzz_fake = {
      install_info = { url = 'https://example.invalid/tree-sitter-zzz', revision = 'deadbeef' },
      tier = 2,
    }
  end,
})
-- install.update() calls reload_parsers() which fires User TSUpdate, so the
-- custom entry must be present in the registry afterwards.
require('nvim-treesitter.install')
require('nvim-treesitter.config').setup({})
vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })
assert(require('nvim-treesitter.parsers').zzz_fake, 'custom parser not registered')
print('custom_parser: registration hook works')
```
Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/custom_parser.lua
```
Expected: prints `custom_parser: registration hook works`.

- [ ] **Step 3: (Optional) Tolerate ENOENT in the parser hot-swap**

In `install.lua` `do_install` (lines ~327-331), the rename-aside of a not-yet-existing parser returns ENOENT on first install. Replace:
```lua
  local tempfile = target_location .. tostring(uv.hrtime())
  uv_rename(target_location, tempfile) -- parser may be in use: rename...
  uv_unlink(tempfile) -- ...and mark for garbage collection

  local err = uv_copyfile(compile_location, target_location)
```
with:
```lua
  local tempfile = target_location .. tostring(uv.hrtime())
  -- Parser may be loaded/in use: rename it aside, then mark for GC. On a
  -- first install the target does not exist yet (ENOENT) — that is expected.
  if uv.fs_stat(target_location) then
    uv_rename(target_location, tempfile)
    uv_unlink(tempfile)
  end

  local err = uv_copyfile(compile_location, target_location)
```

- [ ] **Step 4: Verify load + re-run the install smoke test (if network available)**

Run:
```bash
nvim --headless --clean --cmd 'set rtp+=.' -c 'lua require("nvim-treesitter")' -c 'qa'
nvim --headless --clean --cmd 'set rtp+=.' -l _scratch/install_smoke.lua
```
Expected: loads clean; smoke test prints `install_smoke: passed (...)` (re-running installs over the existing scratch parser also exercises the hot-swap path).

- [ ] **Step 5: Commit**

```bash
git add lua/nvim-treesitter/config.lua lua/nvim-treesitter/install.lua
git commit -m "refactor: stop firing User TSUpdate on completion; harden parser swap

get_available no longer re-runs user TSUpdate callbacks on every :TSInstall
tab-completion (still fired at install/uninstall). do_install only renames an
existing parser aside, avoiding a spurious ENOENT on first install."
```

---

## Task 5 (OPTIONAL — your call): Public-audience scaffolding cull

> Pure housekeeping for a vendored solo fork. None of this affects runtime behavior. Skip any item you want to keep. The CI that drove these (`.github/**`) is already deleted in your working tree.

**Candidates to delete:**
- `README.md` — public install/quickstart pitch (or trim to a short personal note).
- `CONTRIBUTING.md` — 657-line contributor guide.
- `scripts/ci-install.sh` — downloads a Neovim nightly into a CI runner; orphaned.
- Test harness (needs an external toolchain the deleted CI provisioned — `highlight-assertions` binary, `plentest.nvim`):
  - `tests/query/` (highlights + injections specs, ~105 files)
  - `scripts/minimal_init.lua`
  - the `Makefile` download/test machinery (`Makefile` and `makefile` are the **same inode** on this APFS volume — deleting one removes both)

**Keep (maintainer value):** `scripts/update-parsers.lua`, `scripts/install-parsers.lua`, `lua/nvim-treesitter/health.lua`, `doc/`, `LICENSE`, `.stylua.toml`, `.editorconfig`, `.luarc.json`, and `.tsqueryrc.json` (if you lint queries in your editor).

- [ ] **Step 1: Decide per item, then delete the chosen ones**

Example (adjust to your choices):
```bash
git rm README.md CONTRIBUTING.md scripts/ci-install.sh
git rm -r tests/query
git rm scripts/minimal_init.lua
git rm Makefile   # also removes ./makefile (same inode)
```

- [ ] **Step 2: Verify nothing kept references a deleted file**

Run:
```bash
rg -n 'minimal_init|update-readme|SUPPORTED_LANGUAGES|highlight-assertions|plentest' \
  scripts/ lua/ doc/ Makefile 2>/dev/null
nvim --headless --clean --cmd 'set rtp+=.' -c 'lua require("nvim-treesitter")' -c 'qa'
```
Expected: no dangling references to deleted files in kept code; plugin loads clean.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove public-audience and CI scaffolding for vendored fork"
```

---

## Final verification

- [ ] **Step 1: Full smoke + health**

```bash
nvim --headless --clean --cmd 'set rtp+=.' -c 'lua require("nvim-treesitter")' -c 'qa'
nvim --headless --clean --cmd 'set rtp+=.' -c 'checkhealth nvim-treesitter' -c 'qa' 2>&1 | head -40
```
Expected: loads with no error; checkhealth shows Requirements OK (nvim ≥ 0.12, tree-sitter-cli, tar, curl), the install dir checks, and an `H L F J` query grid for installed languages.

- [ ] **Step 2: Review the branch**

```bash
git log --oneline main..HEAD
git diff --stat main..HEAD
```
Expected: 3–5 focused commits; the diffstat shows the large net deletion (indent tree + indents.scm + async shrink + metadata strip).

- [ ] **Step 3: Clean up scratch**

```bash
rm -rf _scratch/ts-smoke _scratch/async_spec.lua _scratch/install_smoke.lua _scratch/custom_parser.lua _scratch/parsers.lua.tmp
```

---

## Self-review notes (author)

- **Spec coverage:** indentation removal (Task 1) ✓; `locals` kept (no task touches them) ✓; async rewrite (Task 2) ✓; tier-filtering + maintainers/readme_note cut while keeping `tier` field + update pipeline (Task 3) ✓; improvements — async slimming (Task 2), `get_available` autocmd + `do_install` hardening (Task 4), `norm_languages` simplification (Task 3) ✓.
- **API consistency:** the new `async.lua` exposes `async`/`await`/`awrap`/`schedule` and `Task:await`/`Task:wait` — exactly the names `install.lua`, `init.lua`, and the docs use. `M.async(fn)` returns a plain function (the old `TaskFun` table form is unused). `Task:wait` preserved for the documented bootstrap contract.
- **Ordering:** Task 3 deletes `update-readme.lua` in the same commit as removing `config.tiers`/metadata (its only consumer). Task 1's edit to `update-readme.lua:53` precedes that deletion but is harmless. `minimal_init.lua` edited in Task 1, optionally deleted in Task 5.
- **Caveats flagged for the operator:** `query_predicates.lua` deletion (Task 1) assumes no personal-config query uses `#kind-eq?`; `get_available` autocmd removal (Task 4) trades custom-parser completion for cleanliness; the install smoke test needs network + tree-sitter-cli + a C compiler.
