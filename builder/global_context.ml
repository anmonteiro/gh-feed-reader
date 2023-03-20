open Import
module Action_builder = Action_builder0

type t =
  { root : Path.External.t
  ; build_dir : Path.Build.t
  ; mutable rules : Rule.t Path.Build.Map.t
  }

let create ~root =
  Path.set_root root;
  (* let build_dir = Path.External.relative root "_build" in *)
  Path.Build.set_build_dir (Path.Outside_build_dir.of_string "_build");
  let build_dir = Path.Build.root in
  { root; build_dir; rules = Path.Build.Map.empty }

let add_rule
    t
    ~dir
    ({ build; targets } : Action.t Action_builder.With_targets.t)
  =
  Format.eprintf
    "targets: [%s]@."
    (String.concat
       ~sep:"; "
       (Path.Build.Set.to_list_map targets ~f:Path.Build.to_string));
  t.rules <-
    Path.Build.Set.fold targets ~init:t.rules ~f:(fun target acc ->
        let rule = Rule.create build ~dir ~targets in
        match Path.Build.Map.add acc target rule with
        | Ok acc -> acc
        | Error _ ->
          User_error.raise
            [ Pp.textf
                "Multiple rules generated for %s"
                (Path.to_string (Path.build target))
            ])
