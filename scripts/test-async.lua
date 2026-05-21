#!/usr/bin/env -S nvim -l
-- Standalone regression test for nvim-treesitter.async.
--
-- The async runtime is a hand-written coroutine helper with a few subtle
-- contracts (synchronous callback resume, argc padding, pwait/wait error
-- propagation) that install.lua and scripts/install-parsers.lua depend on.
-- This guards them without needing the plentest toolchain.
--
-- Run:  nvim -l scripts/test-async.lua    (or  make test-async)
-- Exits non-zero if any check fails.
vim.o.rtp = vim.o.rtp .. ',.'

local a = require('nvim-treesitter.async')

local total = 0
local failures = {} ---@type string[]
local function check(name, ok, detail)
  total = total + 1
  if ok then
    print('ok   - ' .. name)
  else
    local line = name .. (detail and (': ' .. detail) or '')
    failures[#failures + 1] = line
    print('FAIL - ' .. line)
  end
end

-- 1. awrap + schedule ordering; Task:wait returns the coroutine's result.
do
  local sleep = a.awrap(2, function(ms, cb)
    local t = assert(vim.uv.new_timer())
    t:start(ms, 0, function()
      t:stop()
      t:close()
      cb('woke')
    end)
  end)
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
  check('wait returns coroutine result', result == 42, 'got ' .. tostring(result))
  check(
    'awrap + schedule resume in order',
    table.concat(log, ',') == 'before,after:woke,scheduled',
    table.concat(log, ',')
  )
end

-- 2. Task:await(cb) fires with (err, ...results).
do
  local got, goterr
  a.async(function()
    return 'hello'
  end)():await(function(err, v)
    goterr = err
    got = v
  end)
  vim.wait(200, function()
    return got ~= nil
  end)
  check('await callback receives (nil, result)', got == 'hello' and goterr == nil, 'got ' .. tostring(got))
end

-- 3. awrap pads argc so the resume callback lands at the right slot even when
--    called with fewer args (e.g. awrap(4, uv.fs_copyfile) called with 2).
do
  local received ---@type table?
  local wrapped = a.awrap(4, function(...)
    received = { n = select('#', ...), ... }
  end)
  a.async(function()
    wrapped('a', 'b')
  end)()
  check(
    'awrap pads argc (callback at position 4)',
    received ~= nil
      and received.n == 4
      and received[1] == 'a'
      and received[2] == 'b'
      and received[3] == nil
      and type(received[4]) == 'function',
    received and ('n=' .. received.n) or 'fn not called'
  )
end

-- 4. error(string) propagates through Task:wait.
do
  local ok, err = pcall(function()
    a.async(function()
      error('boom')
    end)():wait(2000)
  end)
  check('wait raises on task error', not ok and tostring(err):match('boom') ~= nil, tostring(err))
end

-- 5. error(nil) still propagates as a failure (not a silent success).
do
  local ok = pcall(function()
    a.async(function()
      error(nil)
    end)():wait(2000)
  end)
  check('error(nil) propagates as failure', not ok)
end

-- 6. pwait contract relied on by scripts/install-parsers.lua: (ok, result).
do
  local ok1, r1 = a.async(function()
    return true
  end)():pwait(2000)
  local ok2, r2 = a.async(function()
    return false
  end)():pwait(2000)
  local ok3, e3 = a.async(function()
    error('x')
  end)():pwait(2000)
  check('pwait success -> (true, result)', ok1 == true and r1 == true)
  check('pwait incomplete -> (true, false)', ok2 == true and r2 == false)
  check('pwait error -> (false, err)', ok3 == false and e3 ~= nil)
end

if #failures > 0 then
  print(string.format('\n%d/%d async checks FAILED:', #failures, total))
  for _, f in ipairs(failures) do
    print('  - ' .. f)
  end
  vim.cmd.cq()
else
  print(string.format('\nall %d async checks passed', total))
end
