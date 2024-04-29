import dot_env
import dot_env/env
import gleam/result
import gleam/string

pub type Config {
  Config(
    username: String,
    password: String,
    server: String,
    format_link_as_code: Bool,
  )
}

pub type ConfigError {
  UndefinedEnvVar(String)
}

pub fn from_env() -> Result(Config, ConfigError) {
  dot_env.load()

  use username <- result.try(get_env("MATRIX_USERNAME"))
  use password <- result.map(get_env("MATRIX_PASSWORD"))
  let server =
    get_env("MATRIX_SERVER")
    |> result.unwrap("https://matrix.org")
  let format_link_as_code =
    env.get("FORMAT_LINK_AS_CODE")
    |> result.map(fn(value) { string.lowercase(value) == "true" })
    |> result.unwrap(True)

  Config(
    username: username,
    password: password,
    server: server,
    format_link_as_code: format_link_as_code,
  )
}

fn get_env(name: String) -> Result(String, ConfigError) {
  env.get(name)
  |> result.map_error(fn(_) { UndefinedEnvVar(name) })
}

pub fn error_to_string(error: ConfigError) -> String {
  case error {
    UndefinedEnvVar(name) -> "Undefined environment variable: " <> name
  }
}
