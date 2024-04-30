import gleam/hackney
import gleam/http/request
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub type PluginError {
  NvimShError(hackney.Error)
}

pub fn get(name: String) -> Result(String, PluginError) {
  let assert Ok(request) = request.to("https://nvim.sh/s/" <> name)

  io.println("Sending request to nvim.sh...")
  use response <- result.map(
    request
    |> hackney.send
    |> result.map_error(NvimShError),
  )
  io.println("Response received. Parsing...")

  let plugins =
    response.body
    |> parse_nvim_response(name)
    |> to_html

  case plugins {
    "" -> "No plugins found by the name " <> name
    _ -> plugins
  }
}

@internal
pub fn parse_nvim_response(response: String, name: String) -> List(
  #(String, String),
) {
  response
  |> string.split("\n")
  |> list.drop(1)
  |> list.fold(from: [], with: fn(lines, line) {
    let words = string.split(line, " ")
    let formatted = {
      use name <- result.map(list.first(words))

      let description =
        words
        |> list.filter(fn(word) { word != "" })
        |> list.drop(4)
        |> string.join(" ")

      #(name, description)
    }

    case formatted {
      Ok(formatted) -> [formatted, ..lines]
      Error(_) -> lines
    }
  })
  |> list.filter(fn(name_description) {
    string.contains(name_description.0, name)
  })
}

fn to_html(plugins: List(#(String, String))) -> String {
  let formatted = {
    use plugin_description <- list.map(plugins)

    let #(name, description) = plugin_description

    let formatted_description = case description {
      "" -> "No description"
      d -> d
    }

    "<li><a href=\"https://github.com/"
    <> name
    <> "\">"
    <> name
    <> "</a> - "
    <> formatted_description
    <> "</li>"
  }

  case formatted {
    [] -> ""
    _ -> "<ol>" <> string.join(formatted, "") <> "</ol>"
  }
}

pub fn error_to_string(error: PluginError) -> String {
  case error {
    NvimShError(e) -> "Error connecting to nvim.sh: " <> string.inspect(e)
  }
}
