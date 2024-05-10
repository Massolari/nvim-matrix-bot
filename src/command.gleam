import gleam/bool
import gleam/list
import gleam/option.{Some}
import gleam/regex
import gleam/string

pub type Command {
  Help(String)
  Plugin(String)
}

pub fn from_string(text: String) -> Result(List(Command), Nil) {
  let text_without_quote =
    text
    |> string.split("\n")
    |> list.filter(fn(line) {
      line
      |> string.trim
      |> string.starts_with(">")
      |> bool.negate
    })
    |> string.join("\n")

  let help_commands = parse_help_command(text_without_quote)

  let plugin_commands = parse_plugin_command(text_without_quote)

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
    regex.from_string("[!:](?:help|h|he|hel) ([^`\\n\\s]+)")

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
