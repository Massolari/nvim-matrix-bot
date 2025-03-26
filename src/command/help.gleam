import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import simplifile

pub type HelpError {
  ReadTagsError(simplifile.FileError)
}

pub type Help {
  NoResult
  Found(String)
}

pub fn find(queries: List(String)) -> Result(Help, HelpError) {
  io.println("Reading tags file...")
  use tags <- result.map(
    simplifile.read("./tags")
    |> result.map_error(ReadTagsError),
  )
  io.println("Done! Parsing...")

  let help =
    tags
    |> search(for: queries)
    |> to_html

  case help {
    "" -> NoResult
    _ -> Found(help)
  }
}

@internal
pub fn search(
  on tags: String,
  for queries: List(String),
) -> List(Result(#(String, String), String)) {
  use result, query <- list.fold(over: queries, from: [])

  let match =
    tags
    |> string.split("\n")
    |> list.filter(fn(tag) {
      tag
      |> remove_parentheses
      |> string.contains("*" <> remove_parentheses(query) <> "*")
    })
    |> list.first
    |> result.try(fn(tag) {
      let parts =
        tag
        |> string.split("\t")

      use symbol <- result.try(
        parts
        |> list.first,
      )

      use filename <- result.map(
        parts
        |> list.drop(1)
        |> list.first,
      )

      #(symbol, filename)
    })
    |> result.map_error(fn(_) { query })

  [match, ..result]
}

fn remove_parentheses(str: String) -> String {
  str
  |> string.replace("(", "")
  |> string.replace(")", "")
}

fn to_html(matches: List(Result(#(String, String), String))) -> String {
  matches
  |> list.map(fn(help_file) {
    case help_file {
      Ok(#(help, filename)) -> {
        "<li>Found <code>"
        <> help
        <> "</code> in "
        <> "<a href=\""
        <> get_help_link(help, filename)
        <> "\"><i>"
        <> filename
        <> "</i></a></li>"
      }
      Error(help) ->
        "<li><code>:help</code> for <code>" <> help <> "</code> not found</li>"
    }
  })
  |> string.join("")
  |> fn(content) {
    case content {
      "" -> ""
      _ -> "<ul>" <> content <> "</ul>"
    }
  }
}

fn get_help_link(help: String, filename: String) -> String {
  let file_without_extension =
    filename
    |> string.split(".")
    |> list.first
    |> result.unwrap(filename)

  "https://neovim.io/doc/user/"
  <> file_without_extension
  <> ".html#"
  <> uri.percent_encode(help)
}

pub fn error_to_string(error: HelpError) -> String {
  case error {
    ReadTagsError(file_error) ->
      "Error reading tags file: " <> string.inspect(file_error)
  }
}
