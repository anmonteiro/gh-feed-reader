open Import

module Primitive = struct
  (* type t = *)
  (* | Static_files *)
  (* | Serverless_functions *)
  (* | Edge_functions *)
  (* | Prerender_functions *)

  module Serverless_function = struct
    module Name : sig
      type t

      val of_string : string -> t
      val to_string : t -> string
      val to_output : t -> Path.Local.t
    end = struct
      type t = string

      let of_string t = t
      let to_string t = t
      let to_output t = Path.Local.of_string (t ^ ".func")
    end

    type t =
      { name : Name.t
      ; handler : Path.t
      ; runtime : string
      ; files : Path.Set.t
      ; routes : string list (* write one as a directory, symlink the rest *)
      ; memory : int option
      ; max_duration : int option
      ; environment : string String.Map.t
      ; regions : string list (* TODO: Region.t *)
      }

    let create
        ?memory
        ?max_duration
        ?(environment = String.Map.empty)
        ~name
        ~routes
        ~regions
        ~runtime
        ~files
        handler
      =
      { name
      ; handler
      ; routes
      ; regions
      ; runtime
      ; files
      ; memory
      ; max_duration
      ; environment
      }

    let to_dyn t =
      let open Dyn in
      record
        [ "name", string (Name.to_string t.name)
        ; "routes", list string t.routes
        ]
  end
end

module Configuration = struct
  (* module Static_files = struct *)
  (* end *)

  type t =
    { static_files : Path.Set.t
    ; serverless_functions : Primitive.Serverless_function.t String.Map.t
    }

  let to_dyn t =
    let open Dyn in
    record
      [ "static_files", Path.Set.to_dyn t.static_files
      ; ( "serverless_functions"
        , String.Map.to_dyn
            Primitive.Serverless_function.to_dyn
            t.serverless_functions )
      ]

  let example () =
    { static_files = Path.Set.empty
    ; serverless_functions =
        (let files =
           let set = Path.Set.singleton (Path.of_string "cacert.pem") in
           Path.Set.add set (Path.of_string "bsconfig.json")
         in
         String.Map.singleton
           "feed-reader"
           Primitive.Serverless_function.(
             create
               (Path.of_string "api/bootstrap")
               ~name:(Name.of_string "feed-reader")
               ~routes:[ "/bootstrap" ]
               ~regions:[ "sfo1" ]
               ~runtime:"provided"
               ~files))
    }
end

module Function_rules = struct
  let functions_dir = "functions"

  let setup_vc_config_json ~runtime ?memory ?max_duration ~regions handler :
      Yojson.Safe.t
    =
    (* TODO: environment *)
    `Assoc
      (Option.to_list
         (Option.map memory ~f:(fun memory -> "memory", `Int memory))
      @ Option.to_list
          (Option.map max_duration ~f:(fun max_duration ->
               "maxDuration", `Int max_duration))
      @ [ "handler", `String (Path.to_string handler)
        ; "runtime", `String runtime
        ; "regions", `List (List.map ~f:(fun x -> `String x) regions)
        ])

  let setup_function_rules
      (gctx : Global_context.t)
      (sfn : Primitive.Serverless_function.t)
    =
    let { Primitive.Serverless_function.name
        ; handler
        ; runtime
        ; files
        ; routes = _
        ; regions
        ; memory
        ; max_duration
        ; _
        }
      =
      sfn
    in
    let output_dir =
      let function_output_dir =
        Primitive.Serverless_function.Name.to_output name
        |> Path.Local.to_string
      in
      Path.Build.L.relative
        gctx.build_dir
        [ functions_dir; function_output_dir ]
    in
    let () =
      let vc_config_json =
        setup_vc_config_json ~runtime ?memory ?max_duration ~regions handler
      in
      let action =
        Action_builder.write_file
          ~dst:(Path.Build.relative output_dir ".vc-config.json")
          (Yojson.Safe.pretty_to_string vc_config_json)
      in
      Global_context.add_rule ~dir:output_dir gctx action
    in
    let copy_file src =
      let action =
        let dst = Path.Build.relative output_dir (Path.basename src) in
        Action_builder.copy ~src ~dst
      in
      Global_context.add_rule ~dir:output_dir gctx action
    in
    List.iter (Path.Set.to_list files) ~f:copy_file;

    let copy_handler src =
      let action =
        let dst = Path.Build.relative output_dir (Path.basename src) in
        let action =
          let open Action_builder.O in
          Action_builder.dep (Path.Build.relative output_dir "bsconfig.json")
          >>> Action_builder.return (Action.Copy (src, dst))
        in
        Action_builder.with_targets ~targets:[ dst ] action
      in
      Global_context.add_rule ~dir:output_dir gctx action
    in
    copy_handler handler;
    let example_action src =
      let action =
        let dst = Path.Build.relative output_dir "foo.tony.txt" in
        let action =
          let open Action_builder.O in
          Action_builder.return (Action.Copy (src, dst))
        in
        Action_builder.with_targets ~targets:[ dst ] action
      in
      Global_context.add_rule ~dir:output_dir gctx action
    in
    ()
end

let () =
  let root = Path.External.cwd () in
  let gctx = Global_context.create ~root in
  let config = Configuration.example () in
  let setup_function_rules = Function_rules.setup_function_rules gctx in
  Format.eprintf "config: %s@." (Dyn.to_string (Configuration.to_dyn config));
  String.Map.iter config.serverless_functions ~f:setup_function_rules;
  let t = Scheduler.prepare () in
  match
    Scheduler.Run_once.run_and_cleanup t (fun () -> Build_system.run gctx)
  with
  | Ok () -> ()
  | Error _ -> ()

(* let run_two_processes () = *)
(* (* let open Fiber.O in *) *)
(* let sh = Path.of_string "/bin/sh" in *)
(* Fiber.all_concurrently_unit *)
(* [ Process.run ~verbose:true Strict sh [ "-c"; "sleep 6; echo hi" ] *)
(* ; Process.run *)
(* ~verbose:true *)
(* ~stdout_to:Process.Io.stdout *)
(* (* (Accept (Predicate.create (Int.equal 0))) *) *)
(* Strict *)
(* (* Return *) *)
(* sh *)
(* [ "-c"; "exit 2" ] *)
(* ; Process.run *)
(* ~verbose:true *)
(* Strict *)
(* sh *)
(* [ "-c"; "echo HELLO; sleep 4; echo DONE" ] *)
(* ; Process.run *)
(* ~verbose:true *)
(* ~stdout_to:Process.Io.stdout *)
(* Strict *)
(* sh *)
(* [ "-c"; "sleep 4; echo four; sleep 2; echo two; sleep 2; echo twomore" ] *)
(* ] *)
(* (* Format.eprintf *) *)
(* (* "p1: %s; p2: %.2f %.2f %d %d@." *) *)
(* (* p1 *) *)
(* (* p2.elapsed_time *) *)
(* (* p3.elapsed_time *) *)
(* (* ret1 *) *)
(* (* 2 *) *)
(* (* ret4 *) *)

(* let run_two_processes () = *)
(* let open Fiber.O in *)
(* let+ ret = Fiber.collect_errors run_two_processes in *)
(* match ret with *)
(* | Ok () -> () *)
(* | Error exns -> *)
(* Format.eprintf *)
(* "XX: %a@." *)
(* (Format.pp_print_list Exn_with_backtrace.pp_uncaught) *)
(* exns *)

(* let () = *)
(* let t = Scheduler.prepare () in *)
(* match *)
(* Scheduler.Run_once.run_and_cleanup t (fun () -> run_two_processes ()) *)
(* with *)
(* | Ok () -> () *)
(* | Error _ -> () *)

(* let fiber () = *)
(* let open Fiber.O in *)
(* let do_work wheel = *)
(* let* timeout = Lev_fiber.Timer.Wheel.task wheel in *)
(* Fiber.finalize *)
(* ~finally:(fun () -> Lev_fiber.Timer.Wheel.stop wheel) *)
(* (fun () -> *)
(* Fiber.fork_and_join_unit *)
(* (fun () -> *)
(* Format.eprintf "waitin@."; *)
(* let+ timeout = Lev_fiber.Timer.Wheel.await timeout in *)
(* match timeout with *)
(* | `Ok -> Format.eprintf "TIMEOUT@." *)
(* | `Cancelled -> ()) *)
(* (fun () -> *)
(* let* () = Lev_fiber.Timer.sleepf 5. in *)
(* let+ x = Lev_fiber.Timer.Wheel.cancel timeout in *)
(* Format.eprintf "yup@."; *)
(* x)) *)
(* in *)
(* let* wheel = Lev_fiber.Timer.Wheel.create ~delay:2. in *)
(* Fiber.fork_and_join_unit *)
(* (fun () -> do_work wheel) *)
(* (fun () -> Lev_fiber.Timer.Wheel.run wheel) *)

(* let () = Lev_fiber.run ~sigpipe:`Ignore fiber |> Lev_fiber.Error.ok_exn *)
