import command/plugin
import gleeunit/should

const sample = "Name                              Stars  OpenIssues  Updated               Description                                                                                          
Massolari/forem.nvim              18     0           2024-03-15T13:29:47Z  Neovim plugin to read, write and post articles on Forem platforms like dev.to                        
mhartington/formatter.nvim        1282   63          2024-03-18T18:20:51Z                                                                                                       "

pub fn parse_nvim_response_test() {
  sample
  |> plugin.parse_nvim_response("forem")
  |> should.equal([
    #(
      "Massolari/forem.nvim",
      "18",
      "Neovim plugin to read, write and post articles on Forem platforms like dev.to",
    ),
  ])
}
