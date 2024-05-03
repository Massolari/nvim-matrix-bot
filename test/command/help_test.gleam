import command/help
import gleeunit/should

const sample = "vim.lsp.Client	lsp.txt	/*vim.lsp.Client*
vim.lsp.Client.Progress	lsp.txt	/*vim.lsp.Client.Progress*
vim.lsp.ClientConfig	lsp.txt	/*vim.lsp.ClientConfig*
vim.lsp.ListOpts	lsp.txt	/*vim.lsp.ListOpts*
vim.lsp.LocationOpts	lsp.txt	/*vim.lsp.LocationOpts*
vim.lsp.LocationOpts.OnList	lsp.txt	/*vim.lsp.LocationOpts.OnList*
vim.lsp.buf.add_workspace_folder()	lsp.txt	/*vim.lsp.buf.add_workspace_folder()*
vim.lsp.buf.clear_references()	lsp.txt	/*vim.lsp.buf.clear_references()*
vim.lsp.buf.code_action()	lsp.txt	/*vim.lsp.buf.code_action()*"

pub fn search_simple_test() {
  sample
  |> help.search(for: ["vim.lsp.Client"])
  |> should.equal([Ok(#("vim.lsp.Client", "lsp.txt"))])
}

pub fn search_parenthesis_test() {
  sample
  |> help.search(for: ["vim.lsp.buf.code_action()"])
  |> should.equal([Ok(#("vim.lsp.buf.code_action()", "lsp.txt"))])
}

pub fn search_parenthesis_omitting_test() {
  sample
  |> help.search(for: ["vim.lsp.buf.code_action"])
  |> should.equal([Ok(#("vim.lsp.buf.code_action()", "lsp.txt"))])
}
