open Import
open Fiber.O

type more_deps =
  | Done
  | Need_more_deps of { deps : Path.Build.Set.t }

type execution_context =
  { working_dir : Path.t
  ; build_deps : Path.Build.Set.t -> Path.Build.Set.t Fiber.t (* env? *)
  ; targets : Path.Build.Set.t
  }

let rec exec t ~ectx =
  match (t : Action.t) with
  | Run (prog, args) ->
    let+ () = exec_run ~ectx prog args in
    Done
  | Progn ts -> exec_list ts ~ectx
  | Copy (src, dst) ->
    let dst = Path.build dst in
    Format.eprintf "copy: %s %s@." (Path.to_string src) (Path.to_string dst);
    Io.copy_file ~src ~dst ();
    Fiber.return Done
  | Write_file (fn, s) ->
    Format.eprintf "write: %s @." (Path.Build.to_string fn);
    let perm = Action.File_perm.to_unix_perm Normal in
    Io.write_file (Path.build fn) s ~perm;
    Fiber.return Done
  | Rename (src, dst) ->
    Unix.rename (Path.Build.to_string src) (Path.Build.to_string dst);
    Fiber.return Done
  | Remove_tree path ->
    Path.rm_rf (Path.build path);
    Fiber.return Done
  | Mkdir path ->
    Path.mkdir_p (Path.build path);
    Fiber.return Done
    (* | System cmd -> *)
    (* let path, arg = *)
    (* Utils.system_shell_exn ~needed_to:"interpret (system ...) actions" *)
    (* in *)
    (* let+ () = exec_run ~display ~ectx ~eenv path [ arg; cmd ] in *)
    (* Done *)
  | Bash cmd ->
    let+ () =
      exec_run
        ~ectx
        (bash_exn ~loc:ectx.rule_loc ~needed_to:"interpret (bash ...) actions")
        [ "-e"; "-u"; "-o"; "pipefail"; "-c"; cmd ]
    in
    Done

and exec_run ~ectx prog args =
  (* validate_context_and_prog ectx prog; *)
  let p = Path.of_filename_relative_to_initial_cwd prog in
  Format.eprintf "exec run : %s@." (Path.to_string p);
  let+ (_ : (unit, int) result) =
    Process.run
      (Accept (Predicate.create (Int.equal 0)))
      ~dir:ectx.working_dir
      ~verbose:true
      (* ~env:eenv.env *)
      (* ~stdout_to:eenv.stdout_to *)
      (* ~stderr_to:eenv.stderr_to *)
      (* ~stdin_from:eenv.stdin_from *)
      (* ~metadata:ectx.metadata *)
      (Path.of_filename_relative_to_initial_cwd prog)
      args
  in
  ()

and exec_list ts ~ectx =
  match ts with
  | [] -> Fiber.return Done
  | [ t ] -> exec t ~ectx
  | t :: rest ->
    let* done_or_deps = exec t ~ectx in
    (match done_or_deps with
    | Need_more_deps _ as need -> Fiber.return need
    | Done -> exec_list rest ~ectx)

let exec_until_all_deps_ready ~ectx t =
  let rec loop stages =
    let* result = exec ~ectx t in
    match result with
    | Done -> Fiber.return stages
    | Need_more_deps { deps = deps_to_build } ->
      let* actual_deps = ectx.build_deps deps_to_build in
      let stages = actual_deps :: stages in
      loop stages
  in
  let+ stages = loop [] in
  List.rev stages

let exec ~targets ~root ~build_deps t =
  let ectx = { working_dir = root; targets; build_deps } in
  exec_until_all_deps_ready t ~ectx
