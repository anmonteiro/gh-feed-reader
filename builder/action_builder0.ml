open Import

type 'a eval_mode =
  | Lazy : unit eval_mode
  | Eager : Path.Build.Set.t eval_mode

type 'a thunk = { f : 'm. 'm eval_mode -> ('a * Path.Build.Set.t) Fiber.t }
[@@unboxed]

type 'a t = 'a thunk

let return x = { f = (fun _mode -> Fiber.return (x, Path.Build.Set.empty)) }
let run t mode = t.f mode

let map t ~f =
  { f =
      (fun mode ->
        let open Fiber.O in
        let+ x, deps = t.f mode in
        f x, deps)
  }

let bind t ~f =
  { f =
      (fun mode ->
        let open Fiber.O in
        let* x, deps1 = t.f mode in
        let+ y, deps2 = (f x).f mode in
        y, Path.Build.Set.union deps1 deps2)
  }

let both x y =
  { f =
      (fun mode ->
        let open Fiber.O in
        let+ x, deps1 = x.f mode
        and+ y, deps2 = y.f mode in
        (x, y), Path.Build.Set.union deps1 deps2)
  }

let all xs =
  { f =
      (fun mode ->
        let open Fiber.O in
        let+ res = Fiber.parallel_map xs ~f:(fun x -> x.f mode) in
        let res, facts = List.split res in
        res, Path.Build.Set.union_all facts)
  }

let of_fiber m =
  { f =
      (fun _mode ->
        let open Fiber.O in
        let+ x = m in
        x, Path.Build.Set.empty)
  }

module O = struct
  let ( >>> ) a b =
    { f =
        (fun mode ->
          let open Fiber.O in
          let+ ((), deps_a), (b, deps_b) =
            Fiber.fork_and_join (fun () -> a.f mode) (fun () -> b.f mode)
          in
          b, Path.Build.Set.union deps_a deps_b)
    }

  let ( >>= ) t f = bind t ~f
  let ( >>| ) t f = map t ~f
  let ( and+ ) = both
  let ( and* ) = both
  let ( let+ ) t f = map t ~f
  let ( let* ) t f = bind t ~f
end

open O

module With_targets = struct
  type nonrec 'a t =
    { build : 'a t
    ; targets : Path.Build.Set.t
    }

  let map_build t ~f = { t with build = f t.build }
  let return x = { build = return x; targets = Path.Build.Set.empty }
  let map { build; targets } ~f = { build = map build ~f; targets }

  let both x y =
    { build = both x.build y.build
    ; targets = Path.Build.Set.union x.targets y.targets
    }

  let seq x y =
    { build = x.build >>> y.build
    ; targets = Path.Build.Set.union x.targets y.targets
    }

  module O = struct
    let ( >>> ) = seq
    let ( >>| ) t f = map t ~f
    let ( and+ ) = both
    let ( let+ ) a f = map ~f a
  end
end
