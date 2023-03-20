open Import
open Fiber.O

let blocked_signals : Signal.t list = [ Int; Quit; Term ]

module Thread : sig
  val spawn : signal_watcher:[ `Yes | `No ] -> (unit -> 'a) -> unit
  val delay : float -> unit
  val wait_signal : int list -> int
end = struct
  include Thread

  let block_signals =
    lazy
      (let signos = List.map blocked_signals ~f:Signal.to_int in
       ignore (Unix.sigprocmask SIG_BLOCK signos : int list))

  let create ~signal_watcher =
    if Sys.win32
    then Thread.create
    else
      (* On unix, we make sure to block signals globally before starting a
         thread so that only the signal watcher thread can receive signals. *)
      fun f x ->
      let () =
        match signal_watcher with `Yes -> Lazy.force block_signals | `No -> ()
      in
      Thread.create f x

  let spawn ~signal_watcher f =
    let (_ : Thread.t) = create ~signal_watcher f () in
    ()
end

type job = { pid : Pid.t (* ; ivar : Proc.Process_info.t Fiber.Ivar.t *) }

let kill_process_group pid signal =
  match Sys.win32 with
  | false ->
    (* Send to the entire process group so that any child processes created by
       the job are also terminated.

       Here we could consider sending a signal to the job process directly in
       addition to sending it to the process group. This is what GNU [timeout]
       does, for example.

       The upside would be that we deliver the signal to that process even if it
       changes its process group. This upside is small because moving between
       the process groups is a very unusual thing to do (creation of a new
       process group is not a problem for us, unlike for [timeout]).

       The downside is that it's more complicated, but also that by sending the
       signal twice we're greatly increasing the existing race condition where
       we call [wait] in parallel with [kill]. *)
    (try Unix.kill (-Pid.to_int pid) signal with Unix.Unix_error _ -> ())
  | true ->
    (* Process groups are not supported on Windows (or even if they are, [spawn]
       does not know how to use them), so we're only sending the signal to the
       job itself. *)
    (try Unix.kill (Pid.to_int pid) signal with Unix.Unix_error _ -> ())

module Process_watcher : sig
  type t
  (** Initialize the process watcher thread. *)

  val init : signal_watcher:[ `Yes | `No ] -> t

  val register_job : t -> job -> unit
  (** Register a new running job. *)

  val remove : t -> Proc.Process_info.t -> unit
  val is_running : t -> Pid.t -> bool

  val killall : t -> int -> unit
  (** Send the following signal to all running processes. *)
end = struct
  type process_state =
    | Running of job
    | Zombie of Proc.Process_info.t

  (* This mutable table is safe: it does not interact with the state we track in
     the build system. *)
  type t =
    { mutex : Mutex.t
    ; something_is_running : Condition.t
    ; table : (Pid.t, process_state) Table.t
    ; mutable running_count : int
    }

  let is_running t pid =
    Mutex.lock t.mutex;
    let res = Table.mem t.table pid in
    Mutex.unlock t.mutex;
    res

  module Process_table : sig
    val add : t -> job -> unit
    val remove : t -> Proc.Process_info.t -> unit

    (* val running_count : t -> int *)
    val iter : t -> f:(job -> unit) -> unit
  end = struct
    let add t job =
      match Table.find t.table job.pid with
      | None ->
        Table.set t.table job.pid (Running job);
        t.running_count <- t.running_count + 1;
        if t.running_count = 1 then Condition.signal t.something_is_running
      | Some (Zombie _proc_info) -> Table.remove t.table job.pid
      | Some (Running _) -> assert false

    let remove t (proc_info : Proc.Process_info.t) =
      match Table.find t.table proc_info.pid with
      | None -> Table.set t.table proc_info.pid (Zombie proc_info)
      | Some (Running _job) ->
        t.running_count <- t.running_count - 1;
        Table.remove t.table proc_info.pid
      | Some (Zombie _) -> assert false

    let iter t ~f =
      Table.iter t.table ~f:(fun data ->
          match data with Running job -> f job | Zombie _ -> ())

    (* let running_count t = t.running_count *)
  end

  let register_job t job =
    Mutex.lock t.mutex;
    Process_table.add t job;
    Mutex.unlock t.mutex

  let remove t proc_info =
    Mutex.lock t.mutex;
    Process_table.remove t proc_info;
    Mutex.unlock t.mutex

  let killall t signal =
    Mutex.lock t.mutex;
    Process_table.iter t ~f:(fun job -> kill_process_group job.pid signal);
    Mutex.unlock t.mutex

  (* let run t = *)
  (* Mutex.lock t.mutex; *)
  (* while true do *)
  (* while Process_table.running_count t = 0 do *)
  (* Condition.wait t.something_is_running t.mutex *)
  (* done; *)
  (* wait t; *)
  (* Format.eprintf "waited@." *)
  (* done *)

  let init ~signal_watcher:_ =
    let t =
      { mutex = Mutex.create ()
      ; something_is_running = Condition.create ()
      ; table = Table.create (module Pid) 128
      ; running_count = 0
      }
    in
    (* Thread.spawn ~signal_watcher (fun () -> run t); *)
    t
end

module Signal_watcher : sig
  val init : unit -> unit
end = struct
  let signos = List.map blocked_signals ~f:Signal.to_int

  let warning =
    {|

**************************************************************
* Press Control+C again quickly to perform an emergency exit *
**************************************************************

|}

  external sys_exit : int -> _ = "caml_sys_exit"

  let signal_waiter () =
    if Sys.win32
    then (
      let r, w = Unix.pipe ~cloexec:true () in
      let buf = Bytes.create 1 in
      Sys.set_signal
        Sys.sigint
        (Signal_handle (fun _ -> assert (Unix.write w buf 0 1 = 1)));
      Staged.stage (fun () ->
          assert (Unix.read r buf 0 1 = 1);
          Signal.Int))
    else Staged.stage (fun () -> Thread.wait_signal signos |> Signal.of_int)

  let run () =
    let last_exit_signals = Queue.create () in
    let wait_signal = Staged.unstage (signal_waiter ()) in
    while true do
      let signal = wait_signal () in
      match signal with
      | Int | Quit | Term ->
        let now = Unix.gettimeofday () in
        Queue.push last_exit_signals now;
        (* Discard old signals *)
        while
          Queue.length last_exit_signals >= 0
          && now -. Queue.peek_exn last_exit_signals > 1.
        do
          ignore (Queue.pop_exn last_exit_signals : float)
        done;
        let n = Queue.length last_exit_signals in
        if n = 2 then prerr_endline warning;
        if n = 3 then sys_exit 1
      | _ -> (* we only blocked the signals above *) assert false
    done

  let init () = Thread.spawn ~signal_watcher:`Yes (fun () -> run ())
end

type t =
  { job_throttle : Fiber.Throttle.t
  ; cancel : Fiber.Cancel.t
  ; process_watcher : Process_watcher.t
  }

let t : t Fiber.Var.t = Fiber.Var.create ()
let set x f = Fiber.Var.set t x f
let t_opt () = Fiber.Var.get t
let t () = Fiber.Var.get_exn t

exception Build_cancelled

let cancelled () = raise Build_cancelled
let check_cancelled t = if Fiber.Cancel.fired t.cancel then cancelled ()

let with_job_slot f =
  let* t = t () in
  Fiber.Throttle.run t.job_throttle ~f:(fun () ->
      check_cancelled t;
      f t.cancel)

(* We use this version privately in this module whenever we can pass the
   scheduler explicitly *)
let wait_for_process t pid =
  let+ res, outcome =
    Fiber.Cancel.with_handler
      t.cancel
      ~on_cancel:(fun () ->
        Format.eprintf "oncancel@.";
        Process_watcher.killall t.process_watcher Sys.sigkill;
        Fiber.return ())
      (fun () ->
        Process_watcher.register_job t.process_watcher { pid };
        let+ (status : Unix.process_status) =
          Lev_fiber.waitpid ~pid:(Pid.to_int pid)
        in
        let proc_info =
          { Proc.Process_info.pid : Pid.t
          ; status : Unix.process_status
          ; end_time = Unix.gettimeofday ()
          ; resource_usage = None
          }
        in
        Process_watcher.remove t.process_watcher proc_info;
        proc_info)
  in
  match outcome with Cancelled () -> cancelled () | Not_cancelled -> res

let wait_for_process_with_timeout pid ~timeout ~is_process_group_leader =
  let* t = t () in
  let waitpid ~pid wheel =
    let* timeout = Lev_fiber.Timer.Wheel.task wheel in
    Fiber.finalize
      ~finally:(fun () -> Lev_fiber.Timer.Wheel.stop wheel)
      (fun () ->
        let cancelled = ref false in
        Fiber.fork_and_join_unit
          (fun () ->
            Format.eprintf "waitin %d@." (Pid.to_int pid);
            let+ timeout = Lev_fiber.Timer.Wheel.await timeout in
            match timeout with
            | `Ok ->
              Format.eprintf
                "TIMEOUT %B %d@."
                (Process_watcher.is_running t.process_watcher pid)
                (Pid.to_int pid);
              if Process_watcher.is_running t.process_watcher pid
              then (
                if is_process_group_leader
                then kill_process_group pid Sys.sigkill
                else Unix.kill (Pid.to_int pid) Sys.sigkill;
                cancelled := true)
            | `Cancelled ->
              Format.eprintf "toine %d@." (Pid.to_int pid);
              (* Process exited (and canceled this timeout). There's nothing
                 else to do. *)
              ())
          (fun () ->
            let* (proc_info : Proc.Process_info.t) = wait_for_process t pid in
            Format.eprintf "finish %d@." (Pid.to_int pid);
            if !cancelled
            then Fiber.return proc_info
            else
              let+ () = Lev_fiber.Timer.Wheel.cancel timeout in
              proc_info))
  in
  let* wheel = Lev_fiber.Timer.Wheel.create ~delay:timeout in
  let+ ret, _ =
    Fiber.fork_and_join
      (fun () -> waitpid ~pid wheel)
      (fun () -> Lev_fiber.Timer.Wheel.run wheel)
  in
  ret

let wait_for_process ?timeout ?(is_process_group_leader = false) pid =
  let* t = t () in
  match timeout with
  | None -> wait_for_process t pid
  | Some timeout ->
    wait_for_process_with_timeout pid ~timeout ~is_process_group_leader

let sleep duration = Lev_fiber.Timer.sleepf duration

let kill_and_wait_for_all_processes t =
  Process_watcher.killall t.process_watcher Sys.sigkill

let prepare () =
  (* The signal watcher must be initialized first so that signals are blocked in
     all threads. *)
  Signal_watcher.init ();
  let process_watcher = Process_watcher.init ~signal_watcher:`Yes in
  { job_throttle = Fiber.Throttle.create 12
  ; process_watcher
  ; cancel =
      (* This cancellation will never be fired, so this field could instead be
         an [option]. We use a dummy cancellation rather than an option to keep
         the code simpler. *)
      Fiber.Cancel.create ()
  }

module Shutdown = struct
  module Reason = struct
    module T = struct
      type t =
        | Requested
        | Timeout
        | Signal of Signal.t

      let to_dyn t =
        match t with
        | Requested -> Dyn.Variant ("Requested", [])
        | Timeout -> Dyn.Variant ("Timeout", [])
        | Signal signal -> Dyn.Variant ("Signal", [ Signal.to_dyn signal ])

      let compare a b =
        match a, b with
        | Requested, Requested -> Eq
        | Requested, _ -> Lt
        | _, Requested -> Gt
        | Timeout, Timeout -> Eq
        | Timeout, _ -> Lt
        | _, Timeout -> Gt
        | Signal a, Signal b -> Signal.compare a b
    end

    include T
    include Comparable.Make (T)
  end

  exception E of Reason.t

  let () =
    Printexc.register_printer (function
        | E Requested -> Some "shutdown: requested"
        | E Timeout -> Some "shutdown: timeout"
        | E (Signal s) ->
          Some (sprintf "shutdown: signal %s received" (Signal.name s))
        | _ -> None)
end

module Run_once : sig
  type run_error =
    | Already_reported
    | Shutdown_requested of Shutdown.Reason.t
    | Exn of Exn_with_backtrace.t

  val run_and_cleanup : t -> (unit -> 'a Fiber.t) -> ('a, run_error) Result.t
  (** Run the build and clean up after it (kill any stray processes etc). *)
end = struct
  type run_error =
    | Already_reported
    | Shutdown_requested of Shutdown.Reason.t
    | Exn of Exn_with_backtrace.t

  type who_is_responsible_for_the_error =
    | User
    | Developer

  type error =
    { responsible : who_is_responsible_for_the_error
    ; msg : User_message.t
    ; has_embedded_location : bool
    ; needs_stack_trace : bool
    }

  let code_error ~loc ~dyn_without_loc =
    let open Pp.O in
    { responsible = Developer
    ; msg =
        User_message.make
          ?loc
          [ Pp.tag
              User_message.Style.Error
              (Pp.textf
                 "Internal error, please report upstream including the \
                  contents of _build/log.")
          ; Pp.text "Description:"
          ; Pp.box ~indent:2 (Pp.verbatim "  " ++ Dyn.pp dyn_without_loc)
          ]
    ; has_embedded_location = false
    ; needs_stack_trace = false
    }

  let get_error_from_exn = function
    | User_error.E msg ->
      let has_embedded_location = User_message.has_embedded_location msg in
      let needs_stack_trace = User_message.needs_stack_trace msg in
      { responsible = User; msg; has_embedded_location; needs_stack_trace }
    | Code_error.E e ->
      code_error ~loc:e.loc ~dyn_without_loc:(Code_error.to_dyn_without_loc e)
    | Unix.Unix_error (error, syscall, arg) ->
      { responsible = User
      ; msg =
          User_error.make
            [ Unix_error.Detailed.pp
                (Unix_error.Detailed.create error ~syscall ~arg)
            ]
      ; has_embedded_location = false
      ; needs_stack_trace = false
      }
    | Sys_error msg ->
      { responsible = User
      ; msg = User_error.make [ Pp.text msg ]
      ; has_embedded_location = false
      ; needs_stack_trace = false
      }
    | exn ->
      let open Pp.O in
      let s = Printexc.to_string exn in
      let loc, pp =
        match
          Scanf.sscanf s "File %S, line %d, characters %d-%d:" (fun a b c d ->
              a, b, c, d)
        with
        | Error () -> None, User_error.prefix ++ Pp.textf " exception %s" s
        | Ok (fname, line, start, stop) ->
          let start : Lexing.position =
            { pos_fname = fname
            ; pos_lnum = line
            ; pos_cnum = start
            ; pos_bol = 0
            }
          in
          let stop = { start with pos_cnum = stop } in
          Some { Loc.start; stop }, Pp.text s
      in
      { responsible = Developer
      ; msg = User_message.make ?loc [ pp ]
      ; has_embedded_location = Option.is_some loc
      ; needs_stack_trace = false
      }

  let report_backtraces_flag = ref false
  (* let report_backtraces b = report_backtraces_flag := b *)

  (* exception Abort of run_error *)
  let report { Exn_with_backtrace.exn; backtrace } =
    match exn with
    (* | Already_reported -> () *)
    | _ ->
      let { responsible; msg; _ } = get_error_from_exn exn in
      let msg =
        if msg.loc = Some Loc.none then { msg with loc = None } else msg
      in
      let append (msg : User_message.t) pp =
        { msg with paragraphs = msg.paragraphs @ pp }
      in
      let msg =
        if responsible = User && not !report_backtraces_flag
        then msg
        else
          append
            msg
            (List.map
               (Printexc.raw_backtrace_to_string backtrace |> String.split_lines)
               ~f:(fun line -> Pp.box ~indent:2 (Pp.text line)))
      in
      Console.print_user_message msg

  let run t f : _ result =
    let fiber =
      set t (fun () ->
          Fiber.map_reduce_errors
            (module Monoid.Unit)
            f
            ~on_error:(fun e ->
              report e;
              Fiber.return ()))
    in
    match Lev_fiber.run ~sigpipe:`Ignore (fun () -> fiber) with
    | Ok (Ok res) -> Ok res
    | Ok (Error ()) -> Error Already_reported
    | Error _ -> Error Already_reported
    (* | exception Abort err -> Error err *)
    | exception exn -> Error (Exn (Exn_with_backtrace.capture exn))

  let run_and_cleanup t f =
    let res = run t f in
    kill_and_wait_for_all_processes t;
    res
end
