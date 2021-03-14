open Belt

module Async = struct
  let ( let+ ) = Promise.map

  let ( let* ) = Promise.flatMap

  let ( and* ) a b = Promise.all2 a b
end

module Option = struct
  let ( let+ ) = Option.map

  let ( let* ) = Option.flatMap

  let ( and* ) o1 o2 =
    match o1, o2 with Some x, Some y -> Some (x, y) | _ -> None
end

module Result = struct
  let ( let+ ) = Result.map

  let ( let* ) = Result.flatMap

  let ( and* ) r1 r2 =
    match r1, r2 with
    | Ok x, Ok y ->
      Ok (x, y)
    | Ok _, Error e | Error e, Ok _ | Error e, Error _ ->
      Error e
end

module Bindings = struct
  include Async

  let ( let*? ) = Option.( let* )

  let ( let+? ) = Option.( let+ )

  let ( and*? ) = Option.( and* )

  let ( let*! ) = Result.( let* )

  let ( let+! ) = Result.( let+ )

  let ( and*! ) = Result.( and* )

  let ( let**! ) = Promise.flatMapOk

  let ( let++! ) = Promise.mapOk

  let ( and**! ) lr1 lr2 =
    Promise.all2 lr1 lr2
    |. Promise.map (function
           | Ok x, Ok y ->
             Ok (x, y)
           | Ok _, Error e | Error e, Ok _ | Error e, Error _ ->
             Error e)
end
