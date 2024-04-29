import command
import config
import gleam/hackney
import gleam/http/request
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import matrix
import simplifile

type AppError {
  ConfigError(config.ConfigError)
  MatrixError(matrix.MatrixError)
  NvimShError(hackney.Error)
  ReadTagsError(simplifile.FileError)
}

pub fn main() {
  let status = run()

  case status {
    Ok(_) -> Nil
    Error(e) ->
      e
      |> error_to_string
      |> io.println
  }
}

fn run() -> Result(Nil, AppError) {
  io.println("Loading configuration...")
  use config <- result.try(
    config.from_env()
    |> result.map_error(ConfigError),
  )
  io.println("Loaded configuration")

  io.println("Logging in to Matrix...")
  use client <- result.map(
    matrix.new(
      on: config.server,
      user: config.username,
      password: config.password,
    )
    |> result.map_error(MatrixError),
  )
  io.println("Logged in.")

  client
  |> matrix.listen(handle_message)
}

fn handle_message(
  client: matrix.Matrix,
  room_id: String,
  message: matrix.Message,
) {
  io.println("Got new message!")
  use commands <- result.map(
    message.content
    |> command.from_string,
  )
  io.println("Message parsed as commands.")

  let help_commands =
    list.fold(over: commands, from: [], with: fn(helps, command) {
      case command {
        command.Help(help) -> [help, ..helps]
        command.Plugin(plugin) -> {
          let _ =
            handle_plugin_command(client, plugin, room_id)
            |> result.map_error(fn(error) {
              error
              |> error_to_string
              |> io.println
            })

          helps
        }
      }
    })

  let _ = handle_help_commands(client, room_id, help_commands)
}

fn handle_plugin_command(
  client: matrix.Matrix,
  plugin: String,
  room_id: String,
) -> Result(Nil, AppError) {
  io.println("Handling plugin command for " <> plugin)
  let assert Ok(request) = request.to("https://nvim.sh/s/" <> plugin)

  io.println("Sending request to nvim.sh...")
  use response <- result.try(
    request
    |> hackney.send
    |> result.map_error(NvimShError),
  )
  io.println("Response received. Parsing...")

  let plugins =
    response.body
    |> string.split("\n")
    |> list.drop(1)
    |> list.fold(from: [], with: fn(lines, line) {
      let words = string.split(line, " ")
      let formatted = {
        use name <- result.map(list.first(words))

        let formatted_name =
          "<a href=\"https://github.com/" <> name <> "\">" <> name <> "</a>"
        let description =
          words
          |> list.filter(fn(word) { word != "" })
          |> list.drop(3)
          |> string.join(" ")

        let formatted_description = case description {
          "" -> "No description"
          d -> d
        }

        #(formatted_name, formatted_description)
      }

      case formatted {
        Ok(formatted) -> [formatted, ..lines]
        Error(_) -> lines
      }
    })
    |> list.filter(fn(name_description) {
      string.contains(name_description.0, plugin)
    })
    |> list.map(fn(name_description) {
      "<li>" <> name_description.0 <> " - " <> name_description.1 <> "</li>"
    })

  let message = case plugins {
    [] -> "No plugins found by the name " <> plugin
    _ -> "<ol>" <> string.join(plugins, "") <> "</ol>"
  }

  client
  |> matrix.send_message(room_id, message)
  |> result.map_error(MatrixError)
}

fn handle_help_commands(
  client: matrix.Matrix,
  room_id: String,
  helps: List(String),
) {
  io.println("Handling help commands...")
  io.println("Reading tags file...")
  use tags <- result.try(
    simplifile.read("./tags")
    |> result.map_error(ReadTagsError),
  )
  io.println("Done! Parsing...")

  let help_files = {
    use result, help <- list.fold(over: helps, from: [])
    let filename =
      tags
      |> string.split("\n")
      |> list.filter(fn(tag) { string.contains(tag, "*" <> help <> "*") })
      |> list.first
      |> result.try(fn(tag) {
        tag
        |> string.split("\t")
        |> list.drop(1)
        |> list.first
      })
      |> result.map(fn(filename) { #(help, filename) })
      |> result.map_error(fn(_) { help })

    [filename, ..result]
  }

  let message =
    help_files
    |> list.map(fn(help_file) {
      case help_file {
        Ok(#(help, filename)) -> {
          let file_without_extension =
            filename
            |> string.split(".")
            |> list.first
            |> result.unwrap(filename)

          "<li><a href=\"https://neovim.io/doc/user/"
          <> file_without_extension
          <> ".html#"
          <> uri.percent_encode(help)
          <> "\">"
          <> help
          <> "</a> in "
          <> filename
          <> " <i></i></li>"
        }
        Error(help) -> "<li>" <> help <> " not found</li>"
      }
    })
    |> string.join("")

  let formatted_message = case message {
    "" -> "No help found for any of the inputs: " <> string.join(helps, ", ")
    _ -> "<ul>" <> message <> "</ul>"
  }
  client
  |> matrix.send_message(room_id, formatted_message)
  |> result.map_error(MatrixError)
}

fn error_to_string(error: AppError) {
  case error {
    ConfigError(e) -> config.error_to_string(e)
    MatrixError(e) -> matrix.error_to_string(e)
    NvimShError(e) -> "Error connecting to nvim.sh: " <> string.inspect(e)
    ReadTagsError(e) -> "Error reading tags file: " <> string.inspect(e)
  }
}
