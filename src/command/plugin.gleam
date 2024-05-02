import gleam/hackney
import gleam/http/request
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub type PluginData {
  PluginData(name: String, link: String, description: String)
}

pub type PluginError {
  NvimShError(hackney.Error)
}

pub fn get(name: String) -> Result(String, PluginError) {
  use plugins <- result.map(
    name
    |> search_in_file
    |> result.try_recover(fn(_) { fetch_from_nvim_sh(name) }),
  )

  case plugins {
    "" -> "No plugins found by the name " <> name
    _ -> plugins
  }
}

fn search_in_file(plugin: String) -> Result(String, Nil) {
  io.println("Reading plugins file...")
  let assert Ok(all_plugins) = simplifile.read("./plugins.md")
  io.println("Read!")

  let plugins = parse_plugins_file(all_plugins, plugin)

  case plugins {
    [] -> Error(Nil)
    _ ->
      plugins
      |> to_html
      |> Ok
  }
}

@internal
pub fn parse_plugins_file(plugins: String, plugin: String) -> List(PluginData) {
  plugins
  |> string.split("\n")
  |> list.filter_map(fn(line) {
    let parts =
      line
      |> string.split(" - ")
    use name <- result.try(list.first(parts))

    case string.contains(name, plugin) {
      True -> {
        use link <- result.try(
          parts
          |> list.drop(1)
          |> list.first,
        )

        use description <- result.map(
          parts
          |> list.drop(2)
          |> list.first,
        )

        PluginData(name: name, link: link, description: description)
      }
      False -> Error(Nil)
    }
  })
}

fn fetch_from_nvim_sh(name: String) -> Result(String, PluginError) {
  let assert Ok(request) = request.to("https://nvim.sh/s/" <> name)

  io.println("Sending request to nvim.sh...")
  use response <- result.map(
    request
    |> hackney.send
    |> result.map_error(NvimShError),
  )
  io.println("Response received. Parsing...")

  response.body
  |> parse_nvim_response(name)
  |> to_html
}

@internal
pub fn parse_nvim_response(plugins: String, name: String) -> List(PluginData) {
  plugins
  |> string.split("\n")
  |> list.drop(1)
  |> list.fold(from: [], with: fn(lines, line) {
    let words = string.split(line, " ")
    let formatted = {
      use name <- result.map(list.first(words))

      let words_not_empty =
        words
        |> list.filter(fn(word) { word != "" })

      let description =
        words_not_empty
        |> list.filter(fn(word) { word != "" })
        |> list.drop(4)
        |> string.join(" ")

      PluginData(
        name: name,
        link: "https://github.com/" <> name,
        description: description,
      )
    }

    case formatted {
      Ok(formatted) -> [formatted, ..lines]
      Error(_) -> lines
    }
  })
  |> list.filter(fn(data) { string.contains(data.name, name) })
}

fn to_html(plugins: List(PluginData)) -> String {
  let formatted = {
    use data <- list.map(plugins)

    let formatted_description = case data.description {
      "" -> "No description"
      d -> d
    }

    "<li><a href=\""
    <> data.link
    <> "\">"
    <> data.name
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
