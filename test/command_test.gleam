import command
import gleeunit/should

pub fn from_string_help_test() {
  "`:help col()`"
  |> command.from_string
  |> should.equal(Ok([command.Help("col()")]))

  "look at this: `:help i_<Help>`"
  |> command.from_string
  |> should.equal(Ok([command.Help("i_<Help>")]))

  "you can use `:help :help` to see `:help vim.lsp.buf.hover()`"
  |> command.from_string
  |> should.equal(
    Ok([command.Help(":help"), command.Help("vim.lsp.buf.hover()")]),
  )
}

pub fn from_string_plugin_test() {
  "!plugin bufferline"
  |> command.from_string
  |> should.equal(Ok([command.Plugin("bufferline")]))

  "this plugin is cool !plugin forem.nvim"
  |> command.from_string
  |> should.equal(Ok([command.Plugin("forem.nvim")]))

  "to setup LSP you need !plugin nvim-lspconfig and !plugin nvim-cmp"
  |> command.from_string
  |> should.equal(
    Ok([command.Plugin("nvim-lspconfig"), command.Plugin("nvim-cmp")]),
  )
}

pub fn from_string_mixed_test() {
  "to setup LSP you need !plugin nvim-lspconfig and look at `:help lsp`"
  |> command.from_string
  |> should.equal(Ok([command.Plugin("nvim-lspconfig"), command.Help("lsp")]))
}
