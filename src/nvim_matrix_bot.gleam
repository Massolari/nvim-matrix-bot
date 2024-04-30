import command
import command/plugin
import config
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
  ReadTagsError(simplifile.FileError)
  PluginError(plugin.PluginError)
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
            handle_plugin_command(client, plugin, room_id, message)
            |> result.map_error(fn(error) {
              error
              |> error_to_string
              |> io.println
            })

          helps
        }
      }
    })

  case help_commands {
    [] -> Nil
    _ -> {
      let _ = handle_help_commands(client, room_id, help_commands, message)

      Nil
    }
  }
}

fn handle_plugin_command(
  client: matrix.Matrix,
  plugin: String,
  room_id: String,
  input_message: matrix.Message,
) -> Result(Nil, AppError) {
  io.println("Handling plugin command for " <> plugin)

  use message <- result.try(
    plugin.get(plugin)
    |> result.map_error(PluginError),
  )

  client
  |> matrix.send_message(room_id, message, replying_to: input_message)
  |> result.map_error(MatrixError)
}

fn handle_help_commands(
  client: matrix.Matrix,
  room_id: String,
  helps: List(String),
  input_message: matrix.Message,
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
  |> matrix.send_message(room_id, formatted_message, replying_to: input_message)
  |> result.map_error(MatrixError)
}

fn error_to_string(error: AppError) {
  case error {
    ConfigError(e) -> config.error_to_string(e)
    MatrixError(e) -> matrix.error_to_string(e)
    PluginError(e) -> plugin.error_to_string(e)
    ReadTagsError(e) -> "Error reading tags file: " <> string.inspect(e)
  }
}
