import gleam/list
import gleam/option.{Some}
import gleam/regex

pub type Command {
  Help(String)
  Plugin(String)
}

pub fn from_string(text: String) -> Result(List(Command), Nil) {
  let help_commands = parse_help_command(text)

  let plugin_commands = parse_plugin_command(text)

  let commands =
    [help_commands, plugin_commands]
    |> list.concat
    |> list.reverse

  case commands {
    [] -> Error(Nil)
    _ -> Ok(commands)
  }
}

fn parse_help_command(text: String) -> List(Command) {
  let assert Ok(help_regex) =
    regex.from_string("`:(?:help|h|he|hel) (((?!`).)*)`")

  let matches =
    help_regex
    |> regex.scan(content: text)

  use commands, match <- list.fold(over: matches, from: [])

  case match.submatches {
    [Some(help), ..] -> [Help(help), ..commands]
    _ -> commands
  }
}

fn parse_plugin_command(text: String) -> List(Command) {
  let assert Ok(plugin_regex) = regex.from_string("!plugin ([\\w.-]+)")

  let matches =
    plugin_regex
    |> regex.scan(content: text)

  use commands, match <- list.fold(over: matches, from: [])

  case match.submatches {
    [Some(plugin), ..] -> [Plugin(plugin), ..commands]
    _ -> commands
  }
}
