open Bs_fetch

let request_json endpoint =
  fetchWithInit
    endpoint
    (RequestInit.make
       ~mode:CORS
       ~headers:(HeadersInit.makeWithArray [| "accept", "application/json" |])
       ())
  |> Js.Promise.then_ Response.json
  |> Repromise.Rejectable.fromJsPromise
