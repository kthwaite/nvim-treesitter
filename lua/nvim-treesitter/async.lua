--- Minimal coroutine-based async runtime for nvim-treesitter.
---
--- Replaces the larger vendored library. Provides only what install.lua uses
--- (async / await / awrap / schedule, plus Task:await) and the documented
--- Task:wait() bootstrap contract (see :h nvim-treesitter.install()).
local M = {}

---@param ... any
---@return { n: integer, [integer]: any }
local function pack(...)
  return { n = select('#', ...), ... }
end

---@param t? { n: integer, [integer]: any }
---@return any ...
local function unpack_n(t)
  if t then
    return unpack(t, 1, t.n)
  end
end

---@class async.Task
---@field private _thread thread
---@field private _callbacks fun(err?: any, ...: any)[]
---@field private _done boolean
---@field private _failed boolean
---@field private _err? any
---@field private _result? { n: integer, [integer]: any }
local Task = {}
Task.__index = Task

--- Register a completion callback, invoked with (err, ...results).
--- If the task already finished, the callback fires immediately.
---@param callback fun(err?: any, ...: any)
function Task:await(callback)
  if self._done then
    callback(self._err, unpack_n(self._result))
  else
    self._callbacks[#self._callbacks + 1] = callback
  end
end

--- Block until the task finishes, pumping the event loop (protected variant).
--- Returns `(false, err)` on failure or timeout, `(true, ...results)` on success.
---@param timeout? integer milliseconds (default: effectively indefinite)
---@return boolean ok
---@return any ... results on success, or the error / 'timeout' on failure
function Task:pwait(timeout)
  local done = vim.wait(timeout or (2 ^ 31 - 1), function()
    return self._done
  end)
  if not done then
    return false, 'timeout'
  elseif self._failed then
    return false, self._err
  end
  return true, unpack_n(self._result)
end

--- Block until the task finishes, pumping the event loop. Raises on error.
---@param timeout? integer milliseconds (default: effectively indefinite)
---@return any ... the task's return values
function Task:wait(timeout)
  local res = pack(self:pwait(timeout))
  if not res[1] then
    error(res[2])
  end
  return unpack(res, 2, res.n)
end

---@private
---@param failed boolean
---@param err? any
---@param result? { n: integer, [integer]: any }
function Task:_finish(failed, err, result)
  self._failed = failed
  self._err = err
  self._result = result
  self._done = true
  local callbacks = self._callbacks
  self._callbacks = {}
  for _, cb in ipairs(callbacks) do
    cb(err, unpack_n(result))
  end
end

---@private
---@param ... any values passed back into the coroutine on resume
function Task:_resume(...)
  local ret = pack(coroutine.resume(self._thread, ...))
  if not ret[1] then
    -- coroutine raised an error
    self:_finish(true, ret[2])
  elseif coroutine.status(self._thread) == 'dead' then
    -- coroutine returned; ret == { n, true, <returns...> }
    self:_finish(false, nil, pack(select(2, unpack_n(ret))))
  else
    -- coroutine yielded an await-thunk; drive it, resuming on its callback
    local thunk = ret[2]
    thunk(function(...)
      self:_resume(...)
    end)
  end
end

---@param func async fun(...): any
---@return async.Task
local function run(func, ...)
  local task = setmetatable({
    _thread = coroutine.create(func),
    _callbacks = {},
    _done = false,
    _failed = false,
  }, Task)
  task:_resume(...)
  return task
end

---@alias async.TaskFun fun(): async.Task

--- Wrap an async function so that calling it starts a Task.
---@param func async fun(...): any
---@return fun(...): async.Task
function M.async(func)
  return function(...)
    return run(func, ...)
  end
end

--- Await a callback-style function from within an async context.
--- `fun` is called with the original args plus a resume callback inserted at
--- position `argc`; await returns whatever that callback is invoked with.
---@async
---@param argc integer
---@param fun fun(...): any?
---@param ... any
---@return any ...
function M.await(argc, fun, ...)
  local args = pack(...)
  args.n = math.max(args.n, argc)
  return coroutine.yield(function(callback)
    args[argc] = callback
    fun(unpack_n(args))
  end)
end

--- Curry `M.await`: returns an async function that drops the trailing callback.
---@param argc integer
---@param fun fun(...): any?
---@return async fun(...): any
function M.awrap(argc, fun)
  return function(...)
    return M.await(argc, fun, ...)
  end
end

--- Yield to the Neovim scheduler so API calls are allowed after resuming.
---@async
M.schedule = M.awrap(1, vim.schedule)

return M
