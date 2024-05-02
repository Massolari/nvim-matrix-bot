import command/plugin
import gleeunit/should

const nvim_sample = "Name                              Stars  OpenIssues  Updated               Description                                                                                          
Massolari/forem.nvim              18     0           2024-03-15T13:29:47Z  Neovim plugin to read, write and post articles on Forem platforms like dev.to                        
mhartington/formatter.nvim        1282   63          2024-03-18T18:20:51Z                                                                                                       "

const file_sample = "lewis6991/pckr.nvim - https://github.com/lewis6991/pckr.nvim - Spiritual successor of `wbthomason/packer.nvim`.
savq/paq-nvim - https://github.com/savq/paq-nvim - Neovim package manager written in Lua.
NTBBloodbath/cheovim - https://github.com/NTBBloodbath/cheovim - Neovim configuration switcher written in Lua. Inspired by chemacs.
chiyadev/dep]https://github.com/chiyadev/dep) - An alternative to packer.nvim. It was built to be even better and easier to use. Context can be found [here - (https://chiya.dev/posts/2021-11-27-why-package-manager.
folke/lazy.nvim - https://github.com/folke/lazy.nvim - A modern plugin manager, featuring a graphical interface, async execution, a lockfile and more 💤.
roobert/activate.nvim - https://github.com/roobert/activate.nvim - A plugin installation system designed to complement `folke/lazy.nvim`.
nvim-neorocks/rocks.nvim - https://github.com/nvim-neorocks/rocks.nvim - A modern approach to plugin management using Luarocks, inspired by Cargo.
echasnovski/mini.nvim#mini.deps - https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-deps.md - Module of `mini.nvim` for managing other plugins. Uses Git and built-in packages to install, update, clean, and snapshot plugins.
echasnovski/mini.nvim#mini.completion - https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-completion.md - Module of `mini.nvim` for asynchronous two-stage completion. Supports showing completion item info and independent function signature.
neovim/nvim-lspconfig - https://github.com/neovim/nvim-lspconfig - Quickstart configurations for the LSP client.
nvim-lua/lsp-status.nvim - https://github.com/nvim-lua/lsp-status.nvim - This is a plugin/library for generating statusline components from the built-in LSP client."

pub fn parse_nvim_response_test() {
  nvim_sample
  |> plugin.parse_nvim_response("forem")
  |> should.equal([
    plugin.PluginData(
      name: "Massolari/forem.nvim",
      link: "https://github.com/Massolari/forem.nvim",
      description: "Neovim plugin to read, write and post articles on Forem platforms like dev.to",
    ),
  ])
}

pub fn parse_plugins_file_test() {
  file_sample
  |> plugin.parse_plugins_file("mini.completion")
  |> should.equal([
    plugin.PluginData(
      name: "echasnovski/mini.nvim#mini.completion",
      link: "https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-completion.md",
      description: "Module of `mini.nvim` for asynchronous two-stage completion. Supports showing completion item info and independent function signature.",
    ),
  ])
}
