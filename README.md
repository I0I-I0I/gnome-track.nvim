# gnome-track

Simple NeoVim plugin for tracking preferred color style.

Tracks the GNOME desktop color-scheme setting (`gsettings org.gnome.desktop.interface color-scheme`) and fires a callback on startup and whenever it changes.

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
return {
    "I0I-I0I/gnome-track.nvim",
    lazy = false,
    config = function()
        require("gnome-track").setup({ callback = ... })
    end,
}
```

</details>

<details>
<summary>Native (with vim.pack)</summary>

```lua
vim.pack.add({ "https://github.com/I0I-I0I/gnome-track.nvim" })
```

</details>

## Usage

Via `track`:

```lua
vim.pack.add({ "https://github.com/I0I-I0I/stille.nvim" })

---@param scheme "prefer-dark" | "prefer-light" | "default"
require("gnome-track").track(function(scheme)
    if scheme == "prefer-dark" then
        require("stille").setup({ transparent = true, terminal_colors = false })
        vim.g.neovide_opacity = 0.7

        vim.cmd.colo("stille-leere")
        vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#000000" })
    else
        require("stille").setup({ transparent = false, terminal_colors = false })
        vim.g.neovide_opacity = 1

        vim.cmd.colo("stille-hell")
    end
end)
```

Or you can use `setup`, it accepts a config table with a `callback` field, or a callback function directly.

```lua
require("gnome-track").setup({
    notify = false, -- hide INFO notifications on scheme change
    ---@param scheme "prefer-dark" | "prefer-light" | "default"
    callback = function(scheme) ... end,
})
```

The scheme is one of `"prefer-dark"`, `"prefer-light"`, `"default"`.

**Note:** GNOME may emit a short-lived transient `"default"` event right after switching to `"prefer-light"`. If that flashes your theme, debounce or ignore it in your callback (e.g. re-apply only when the value is stable).
