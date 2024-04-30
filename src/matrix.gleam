import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/erlang/process
import gleam/hackney
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import simplifile

pub opaque type Matrix {
  Matrix(server: String, access_token: String)
}

pub type MatrixError {
  LoginError(hackney.Error)
  DecodeAccessTokenError(json.DecodeError)
  SyncError(hackney.Error)
  DecodeMessageError(json.DecodeError)
  SendError(hackney.Error)
  DecodeNextBatchError(json.DecodeError)
  WriteNextBatchError(simplifile.FileError)
}

pub type Message {
  Message(event_id: String, content: String)
}

pub fn new(
  on server: String,
  user user: String,
  password password: String,
) -> Result(Matrix, MatrixError) {
  let assert Ok(request) = request.to(server <> "/_matrix/client/r0/login")

  use response <- result.try(
    request
    |> request.set_method(http.Post)
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("content-type", "application/json")
    |> request.prepend_header("charset", "utf-8")
    |> request.set_body(
      json.object([
        #("type", json.string("m.login.password")),
        #("user", json.string(user)),
        #("password", json.string(password)),
      ])
      |> json.to_string,
    )
    |> hackney.send
    |> result.map_error(LoginError),
  )

  use access_token <- result.map(
    response.body
    |> json.decode(dynamic.field(named: "access_token", of: dynamic.string))
    |> result.map_error(DecodeAccessTokenError),
  )

  Matrix(server, access_token)
}

pub fn error_to_string(error: MatrixError) -> String {
  case error {
    LoginError(hackney_error) ->
      "Login error: " <> string.inspect(hackney_error)
    DecodeAccessTokenError(decode_error) ->
      "Decode access token error: " <> string.inspect(decode_error)
    SyncError(hackney_error) -> "Sync error: " <> string.inspect(hackney_error)
    DecodeMessageError(decode_error) ->
      "Decode message error: " <> string.inspect(decode_error)
    SendError(hackney_error) ->
      "Error sending message: " <> string.inspect(hackney_error)
    DecodeNextBatchError(decode_error) ->
      "Decode next_batch error: " <> string.inspect(decode_error)
    WriteNextBatchError(file_error) ->
      "Failed to write next_batch: " <> string.inspect(file_error)
  }
}

pub fn listen(client: Matrix, handler: fn(Matrix, String, Message) -> a) -> Nil {
  let next_batch =
    simplifile.read("./storage/next_batch.txt")
    |> result.map_error(fn(_) { Nil })

  sync_loop(client, next_batch, handler)
}

fn sync_loop(
  client: Matrix,
  next_batch: Result(String, Nil),
  handler: fn(Matrix, String, Message) -> a,
) -> Nil {
  let status = {
    use sync_response <- result.try(sync(client, next_batch))

    use messages <- result.try(
      sync_response.body
      |> json.decode(using: messages_decoder())
      |> result.map_error(DecodeMessageError),
    )

    let new_next_batch =
      sync_response.body
      |> json.decode(dynamic.field(named: "next_batch", of: dynamic.string))
      |> result.map_error(DecodeNextBatchError)
      |> result.try(fn(next_batch) {
        next_batch
        |> simplifile.write("./storage/next_batch.txt", _)
        |> result.map(fn(_) { next_batch })
        |> result.map_error(WriteNextBatchError)
      })

    messages
    |> option.unwrap(dict.new())
    |> dict.to_list
    |> list.each(fn(room_message) {
      let #(room, messages) = room_message

      list.each(messages, handler(client, room, _))
    })

    new_next_batch
  }

  let new_next_batch = case status {
    Ok(batch) -> Ok(batch)
    Error(error) -> {
      error
      |> error_to_string
      |> io.println

      next_batch
    }
  }

  process.sleep(5000)
  sync_loop(client, new_next_batch, handler)
}

fn sync(
  client: Matrix,
  next_batch: Result(String, Nil),
) -> Result(response.Response(String), MatrixError) {
  let assert Ok(request) =
    request.to(client.server <> "/_matrix/client/r0/sync")

  request
  |> request.prepend_header("accept", "application/json")
  |> request.prepend_header("content-type", "application/json")
  |> request.prepend_header("charset", "utf-8")
  |> request.prepend_header("authorization", "Bearer " <> client.access_token)
  |> fn(req) {
    case next_batch {
      Ok(next_batch) -> request.set_query(req, [#("since", next_batch)])
      Error(_) -> req
    }
  }
  |> hackney.send
  |> result.map_error(SyncError)
}

fn messages_decoder() -> dynamic.Decoder(Option(Dict(String, List(Message)))) {
  dynamic.optional_field(
    named: "rooms",
    of: dynamic.field(
      named: "join",
      of: dynamic.dict(
        dynamic.string,
        dynamic.field(
          named: "timeline",
          of: dynamic.field(named: "events", of: fn(json_events) {
            json_events
            |> dynamic.shallow_list
            |> result.try(list.try_fold(
              _,
              [],
              fn(messages, json_event) {
                use event_id <- result.try(
                  json_event
                  |> dynamic.field(named: "event_id", of: dynamic.string),
                )

                use event_type <- result.map(
                  json_event
                  |> dynamic.field(named: "type", of: dynamic.string),
                )

                case event_type {
                  "m.room.message" -> {
                    let content =
                      json_event
                      |> dynamic.field(
                        named: "content",
                        of: dynamic.field(named: "body", of: dynamic.string),
                      )

                    case content {
                      Ok(content) -> [
                        Message(event_id: event_id, content: content),
                        ..messages
                      ]
                      Error(_) -> messages
                    }
                  }
                  _ -> messages
                }
              },
            ))
          }),
        ),
      ),
    ),
  )
}

pub fn send_message(
  client: Matrix,
  room_id: String,
  message: String,
  replying_to input_message: Message,
) -> Result(Nil, MatrixError) {
  io.println("Sending message to Matrix...")
  let assert Ok(request) =
    request.to(
      client.server
      <> "/_matrix/client/r0/rooms/"
      <> room_id
      <> "/send/m.room.message",
    )

  use response <- result.map(
    request
    |> request.set_method(http.Post)
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header("content-type", "application/json")
    |> request.prepend_header("charset", "utf-8")
    |> request.set_query([#("access_token", client.access_token)])
    |> request.set_body(
      json.object([
        #("msgtype", json.string("m.text")),
        // TODO send unformatted message
        #("body", json.string(message)),
        #("format", json.string("org.matrix.custom.html")),
        #("formatted_body", json.string(message)),
        #(
          "m.relates_to",
          json.object([
            #(
              "m.in_reply_to",
              json.object([#("event_id", json.string(input_message.event_id))]),
            ),
          ]),
        ),
      ])
      |> json.to_string,
    )
    |> hackney.send
    |> result.map_error(SendError),
  )

  io.println("Message sent!")
  io.debug(response)

  Nil
}
