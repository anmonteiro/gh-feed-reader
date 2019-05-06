let dayOfWeek = function
  | 0 ->
    "Sunday"
  | 1 ->
    "Monday"
  | 2 ->
    "Tuesday"
  | 3 ->
    "Wednesday"
  | 4 ->
    "Thursday"
  | 5 ->
    "Friday"
  | 6 ->
    "Saturday"
  | _ ->
    assert false

let formatDate d =
  dayOfWeek (Js.Date.getDay d |. int_of_float)
  ^ ", "
  ^ Js.Date.toLocaleString d

module QueryParams = struct
  type t

  external make : string -> t = "URLSearchParams" [@@bs.new]

  external get : t -> string -> string option = ""
    [@@bs.send] [@@bs.return nullable]
end

type window =
  < innerHeight : int ; pageXOffset : int ; pageYOffset : int > Js.t

external window : window = "" [@@bs.val]

external documentElement : < scrollTop : int ; offsetHeight : int > Js.t = ""
  [@@bs.scope "document"] [@@bs.val]

let throttle f ms =
  let last = ref max_float in
  let timer = ref None in
  fun arg ->
    let now = Js.Date.now () in
    if now < !last +. float ms then (
      (match !timer with None -> () | Some id -> Js.Global.clearTimeout id);
      timer :=
        Some
          (Js.Global.setTimeout
             (fun () ->
               last := Js.Date.now ();
               f arg)
             ms))
    else (
      last := Js.Date.now ();
      f arg)

module Scroll = struct
  external onScroll
    :  window
    -> (_[@bs.as "scroll"])
    -> (Dom.event -> unit)
    -> unit
    = "addEventListener"
    [@@bs.send]

  external offScroll
    :  window
    -> (_[@bs.as "scroll"])
    -> (Dom.event -> unit)
    -> unit
    = "removeEventListener"
    [@@bs.send]

  type t =
    { x : int
    ; y : int
    }

  let useScroll () =
    let state, updateState =
      React.useState (fun () ->
          { x = window##pageXOffset; y = window##pageYOffset })
    in
    let handler =
      throttle
        (fun _ ->
          updateState (fun _ ->
              { x = window##pageXOffset; y = window##pageYOffset }))
        200
    in
    React.useEffect0 (fun () ->
        onScroll window handler;
        Some (fun () -> offScroll window handler));
    state
end
