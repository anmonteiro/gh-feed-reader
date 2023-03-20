open Import
open Fiber.O

type command_result =
  { stdout : string
  ; stderr : string
  ; status : Unix.process_status
  }

let run_command ~cancel ?stdin_value prog args =
  Fiber.of_thunk (fun () ->
      let stdin_i, stdin_o = Unix.pipe ~cloexec:true () in
      let stdout_i, stdout_o = Unix.pipe ~cloexec:true () in
      let stderr_i, stderr_o = Unix.pipe ~cloexec:true () in
      let pid =
        let argv = prog :: args in
        Spawn.spawn
          ~prog
          ~argv
          ~stdin:stdin_i
          ~stdout:stdout_o
          ~stderr:stderr_o
          ()
        |> Stdune.Pid.of_int
      in
      Unix.close stdin_i;
      Unix.close stdout_o;
      Unix.close stderr_o;
      let maybe_cancel =
        match cancel with
        | None ->
          fun f ->
            let+ res = f () in
            res, Fiber.Cancel.Not_cancelled
        | Some token ->
          let on_cancel () =
            Unix.kill (Pid.to_int pid) Sys.sigint;
            Fiber.return ()
          in
          fun f -> Fiber.Cancel.with_handler token ~on_cancel f
      in
      maybe_cancel @@ fun () ->
      let blockity =
        if Sys.win32
        then `Blocking
        else (
          Unix.set_nonblock stdin_o;
          Unix.set_nonblock stdout_i;
          `Non_blocking true)
      in
      let make fd what =
        let fd = Lev_fiber.Fd.create fd blockity in
        Lev_fiber.Io.create fd what
      in
      let* stdin_o = make stdin_o Output in
      let* stdout_i = make stdout_i Input in
      let* stderr_i = make stderr_i Input in
      let stdin () =
        Fiber.finalize
          ~finally:(fun () ->
            Lev_fiber.Io.close stdin_o;
            Fiber.return ())
          (fun () ->
            match stdin_value with
            | None -> Fiber.return ()
            | Some stdin_value ->
              Lev_fiber.Io.with_write stdin_o ~f:(fun w ->
                  Lev_fiber.Io.Writer.add_string w stdin_value;
                  Lev_fiber.Io.Writer.flush w))
      in
      let read from () =
        Fiber.finalize
          ~finally:(fun () ->
            Lev_fiber.Io.close from;
            Fiber.return ())
          (fun () ->
            Lev_fiber.Io.with_read from ~f:Lev_fiber.Io.Reader.to_string)
      in
      let+ status, (stdout, stderr) =
        Fiber.fork_and_join
          (fun () -> Lev_fiber.waitpid ~pid:(Pid.to_int pid))
          (fun () ->
            Fiber.fork_and_join_unit stdin (fun () ->
                Fiber.fork_and_join (read stdout_i) (read stderr_i)))
      in
      { stdout; stderr; status })
