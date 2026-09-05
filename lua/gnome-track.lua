local M = {}

---@alias gnome-track.Scheme "prefer-dark" | "prefer-light" | "default"

---@type gnome-track.Scheme
local DEFAULT_SCHEME = "prefer-dark"

---@type fun(scheme: gnome-track.Scheme)[]
local callbacks = {}

---@type integer|nil
local job_id = nil

---@type boolean
local started = false

---@type boolean
local notify_changes = true

---@type gnome-track.Scheme|nil
local last_scheme = nil

---@param command string
---@return string[]
local function get_cmd(command)
    return { "gsettings", command, "org.gnome.desktop.interface", "color-scheme" }
end

---@param line string?
---@return gnome-track.Scheme|nil
local function extract_value(line)
    if not line then
        return nil
    end
    local v = line:match("'([^']+)'")
    if v ~= "prefer-dark" and v ~= "prefer-light" and v ~= "default" then
        return nil
    end
    return v
end

---@param scheme gnome-track.Scheme
local function call_safe(cb, scheme)
    local ok, err = pcall(cb, scheme)
    if not ok then
        vim.notify("[gnome-track] callback error: " .. tostring(err), vim.log.levels.WARN)
    end
end

---@param scheme gnome-track.Scheme
local function emit(scheme)
    last_scheme = scheme
    for _, cb in ipairs(callbacks) do
        call_safe(cb, scheme)
    end
    if notify_changes then
        vim.notify("[gnome-track] color-scheme: " .. scheme, vim.log.levels.INFO)
    end
end

---@return gnome-track.Scheme|nil, boolean
local function read_current_scheme()
    local ok, output = pcall(function()
        return vim.system(get_cmd("get")):wait()
    end)
    if not ok or type(output) ~= "table" or output.code ~= 0 then
        local msg = vim.trim((type(output) == "table" and output.stderr) or tostring(output))
        vim.notify("[gnome-track] failed to read color-scheme: " .. msg, vim.log.levels.ERROR)
        return nil, false
    end
    return extract_value(output.stdout) or DEFAULT_SCHEME, true
end

local function start()
    if started then
        return
    end
    started = true

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("GnomeTrack", { clear = true }),
        callback = function()
            M.stop()
        end,
    })

    local scheme, ok = read_current_scheme()
    if not ok then
        started = false
        return
    end
    emit(scheme)

    job_id = vim.fn.jobstart(get_cmd("monitor"), {
        stdout_buffered = false,
        on_stdout = function(_, data, _)
            if not data then
                return
            end
            for _, line in ipairs(data) do
                local v = extract_value(line)
                if v then
                    vim.schedule(function()
                        emit(v)
                    end)
                end
            end
        end,
        on_exit = function()
            job_id = nil
            started = false
        end,
    })

    if not job_id or job_id <= 0 then
        vim.notify("[gnome-track] failed to start gsettings monitor", vim.log.levels.ERROR)
        job_id = nil
        started = false
    end
end

---@class gnome-track.Config
---@field callback fun(scheme: gnome-track.Scheme)? Callback fired with current scheme on startup and on every change.
---@field notify boolean? Emit an INFO notification on each change. Default: true.

---Accepts either a callback function or a config table.
---@param opts gnome-track.Config|fun(scheme: gnome-track.Scheme)?
function M.setup(opts)
    if type(opts) == "function" then
        return M.track(opts)
    end
    opts = opts or {}
    if opts.notify ~= nil then
        notify_changes = opts.notify
    end
    if opts.callback then
        return M.track(opts.callback)
    end
    return start()
end

---Register a callback and start tracking the GNOME color-scheme.
---@param cb fun(scheme: gnome-track.Scheme)
function M.track(cb)
    if type(cb) ~= "function" then
        error("gnome-track: `track` expects a function", 2)
    end
    table.insert(callbacks, cb)
    if started and last_scheme then
        call_safe(cb, last_scheme)
    end
    return start()
end

---Stop tracking and clear all registered callbacks.
function M.stop()
    if job_id and job_id > 0 then
        local pid_ok, pid = pcall(vim.fn.jobpid, job_id)
        if pid_ok and pid and pid > 0 then
            pcall(vim.uv.kill, pid, "sigterm")
            vim.defer_fn(function()
                pcall(vim.uv.kill, pid, "sigkill")
            end, 200)
        end
        pcall(vim.fn.jobstop, job_id)
        job_id = nil
    end
    callbacks = {}
    started = false
end

return M