open Import
module Action_builder = Action_builder0

module Exec_result = struct
  type t =
    { produced_targets : Path.Build.Set.t
    ; action_exec_result : Path.Build.Set.t list
    }
end

let t : Global_context.t Fiber.Var.t = Fiber.Var.create ()
let set x f = Fiber.Var.set t x f
let t_opt () = Fiber.Var.get t
let t () = Fiber.Var.get_exn t

module Load_rules = struct
  let get_rule_or_source path =
    let open Fiber.O in
    let* t = t () in
    (* match Path.destruct_build_dir path with *)
    (* | `Outside path -> *)
    (* let+ d = source_or_external_file_digest path in *)
    (* Source d *)
    (* | `Inside path -> *)
    match Path.Build.Map.find t.rules path with
    | Some rule -> Fiber.return (path, rule)
    | None ->
      failwith (Format.asprintf "dep not found? %s" (Path.Build.to_string path))
end

type rule_execution_result =
  { deps : Path.Build.Set.t
  ; targets : Path.Build.Set.t
  }

let rec build_dep path =
  let open Fiber.O in
  let* _path, rule = Load_rules.get_rule_or_source path in
  let+ { deps = _; targets } = Fiber.of_thunk (fun () -> execute_rule rule) in
  match Path.Build.Set.mem targets path with
  | true -> targets
  | false ->
    let target =
      Path.Build.drop_build_context_exn path
      |> Path.Source.to_string_maybe_quoted
    in
    User_error.raise
      ~annots:
        (User_message.Annots.singleton User_message.Annots.needs_stack_trace ())
      [ Pp.textf "XX: %S" target ]

and build_deps deps =
  let open Fiber.O in
  let deps = Path.Build.Set.to_list deps in
  let+ deps = Fiber.parallel_map deps ~f:(fun dep -> build_dep dep) in
  Path.Build.Set.union_all deps

and execute_action_for_rule ~action ~targets : Exec_result.t Fiber.t =
  let open Fiber.O in
  (* Action.chdirs action *)
  (* |> Path.Build.Set.iter ~f:(fun p -> Path.mkdir_p (Path.build p)); *)
  let root =
    Path.Build.root
    (* match context with *)
    (* | None -> Path.Build.root *)
    (* | Some context -> context.build_dir *)
  in
  let root = Path.build root in
  let+ exec_result =
    let+ action_exec_result =
      Action_exec.exec ~root ~targets ~build_deps action
    in
    let produced_targets =
      (* TODO: validate targets are produced. *)
      (* Targets.Produced.produced_after_rule_executed_exn ~loc targets *)
      targets
    in
    { Exec_result.produced_targets; action_exec_result }
  in
  exec_result

and execute_rule (rule : Rule.t) =
  let open Fiber.O in
  let { Rule.targets; action; ivar; dir } = rule in
  let* action, deps = Action_builder.run action Eager in
  Format.eprintf
    "deps for: [%s] -> [%s]@."
    (deps
    |> Path.Build.Set.to_list_map ~f:Path.Build.to_string
    |> String.concat ~sep:"; ")
    (targets
    |> Path.Build.Set.to_list_map ~f:Path.Build.to_string
    |> String.concat ~sep:"; ");
  Fiber.of_thunk (fun () ->
      let open Fiber.O in
      Path.mkdir_p (Path.build dir);
      let+ produced_targets =
        Fiber.Ivar.peek rule.ivar >>= function
        | Some produced_targets ->
          Format.eprintf
            "Actually should [%s]@."
            (String.concat
               ~sep:"; "
               (Path.Build.Set.to_list_map
                  ~f:Path.Build.to_string
                  produced_targets));
          Fiber.return produced_targets
        | None ->
          Path.Build.Set.iter targets ~f:(fun file ->
              (* Cached_digest.remove file; *)
              Format.eprintf "removing %s@." (Path.Build.to_string file);
              Path.Build.unlink_no_err file);
          let* produced_targets =
            let* exec_result = execute_action_for_rule ~action ~targets in
            let produced_targets = exec_result.produced_targets in
            let _dynamic_deps_stages =
              List.map
                exec_result.action_exec_result
                ~f:(fun (deps : Path.Build.Set.t) -> deps)
            in

            let* () = Fiber.Ivar.fill ivar produced_targets in
            Fiber.return produced_targets
          in
          Fiber.return produced_targets
      in
      produced_targets)
  >>| fun produced_targets -> { deps; targets = produced_targets }

let run (gctx : Global_context.t) =
  let open Fiber.O in
  let pending_rules = Path.Build.Map.to_list gctx.rules in
  set gctx (fun () ->
      Fiber.parallel_iter pending_rules ~f:(fun (_, (rule : Rule.t)) ->
          let+ _exec_result = execute_rule rule in
          ()))
