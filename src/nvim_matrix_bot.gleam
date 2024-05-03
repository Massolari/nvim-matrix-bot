import command
import command/help
import command/plugin
import config
import gleam/io
import gleam/list
import gleam/result
import matrix

type AppError {
  ConfigError(config.ConfigError)
  MatrixError(matrix.MatrixError)
  HelpError(help.HelpError)
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

  use message <- result.try(
    help.find(helps)
    |> result.map_error(HelpError),
  )

  case message {
    help.NoResult -> Ok(Nil)
    help.Found(help) -> {
      client
      |> matrix.send_message(room_id, help, replying_to: input_message)
      |> result.map_error(MatrixError)
    }
  }
}

fn error_to_string(error: AppError) {
  case error {
    ConfigError(e) -> config.error_to_string(e)
    MatrixError(e) -> matrix.error_to_string(e)
    HelpError(e) -> help.error_to_string(e)
    PluginError(e) -> plugin.error_to_string(e)
  }
}
