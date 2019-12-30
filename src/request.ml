external js_error_message : Js.Promise.error -> string = "message" [@@bs.get]

let request_json endpoint =
  Bs_fetch.(
    fetchWithInit
      endpoint
      (RequestInit.make
         ~mode:CORS
         ~headers:(HeadersInit.makeWithArray [| "accept", "application/json" |])
         ()))
  |> Js.Promise.then_ Bs_fetch.Response.json
  |. Promise.Js.fromBsPromise
  |. Promise.Js.toResult
  |. Promise.mapError js_error_message
