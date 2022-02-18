open Let_syntax.Bindings

external js_error_message : Js.Promise.error -> string = "message" [@@bs.get]

let request_json endpoint =
  let+ response =
    Bs_fetch.(
      fetchWithInit
        endpoint
        (RequestInit.make
           ~mode:CORS
           ~headers:
             (HeadersInit.makeWithArray [| "accept", "application/json" |])
           ()))
    |> Js.Promise.then_ Bs_fetch.Response.json
    |. Promise.Js.fromBsPromise
    |. Promise.Js.toResult
  in
  match response with Ok r -> Ok r | Error msg -> Error (js_error_message msg)
