open Import
open Fiber.O
include Action_builder0

let register_action_deps :
    type a. a eval_mode -> Path.Build.Set.t -> Path.Build.Set.t Fiber.t
  =
 fun mode deps ->
  match mode with
  | Eager -> Build_system.build_deps deps
  | Lazy -> Fiber.return deps

let dyn_deps deps =
  { f =
      (fun mode ->
        let* deps, paths = deps in
        let+ deps = register_action_deps mode deps in
        paths, deps)
  }

let deps d = dyn_deps (Fiber.return (d, ()))
let dep d = deps (Path.Build.Set.singleton d)

let with_targets ~targets build =
  { With_targets.build; targets = Path.Build.Set.of_list targets }

let write_file ~dst contents =
  let action = return (Action.Write_file (dst, contents)) in
  with_targets ~targets:[ dst ] action

let copy ~src ~dst =
  let action = return (Action.Copy (src, dst)) in
  with_targets ~targets:[ dst ] action
