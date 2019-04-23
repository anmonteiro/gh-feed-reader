module Promise = struct
  include Js.Promise

  let map : ('a -> 'b) -> 'a Js.Promise.t -> 'b Js.Promise.t =
   fun f p -> then_ (fun a -> resolve (f a)) p
end

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
