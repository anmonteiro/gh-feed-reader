open Lwt.Infix

let () =
  Ssl_threads.init ();
  Ssl.init ()

let default_ctx = Ssl.create_context Ssl.SSLv23 Ssl.Client_context

let () =
  Ssl.disable_protocols default_ctx [ Ssl.SSLv23 ];
  Ssl.set_context_alpn_protos default_ctx [ "h2" ];
  Ssl.honor_cipher_order default_ctx

(* Ssl.use_bug_workarounds default_ctx; *)

let connect ?(ctx = default_ctx) ?src ?hostname sa fd =
  (match src with
  | None ->
    Lwt.return_unit
  | Some src_sa ->
    Lwt_unix.bind fd src_sa)
  >>= fun () ->
  Lwt_unix.connect fd sa >>= fun () ->
  match hostname with
  | Some host ->
    let s = Lwt_ssl.embed_uninitialized_socket fd ctx in
    let ssl_sock = Lwt_ssl.ssl_socket_of_uninitialized_socket s in
    Ssl.set_client_SNI_hostname ssl_sock host;
    Ssl.set_alpn_protos ssl_sock [ "h2"; "http/1.1" ];
    Lwt_ssl.ssl_perform_handshake s
  | None ->
    Lwt_ssl.ssl_connect fd ctx

type body =
  | Body of string
  | Http1_Response of Httpaf.Response.t * [ `read ] Httpaf.Body.t
  | H2_Response of H2.Response.t * [ `read ] H2.Body.t

let error_handler notify_response_received error =
  let error_str =
    match error with
    | `Malformed_response s ->
      s
    | `Exn exn ->
      Printexc.to_string exn
    | `Protocol_error ->
      "Protocol Error"
    | `Invalid_response_body_length _ ->
      Format.asprintf "invalid response body length"
  in
  Lwt.wakeup notify_response_received (Error error_str)

let h2_request ssl_client fd ?body request_headers =
  let open H2_lwt_unix in
  let response_received, notify_response_received = Lwt.wait () in
  let response_handler response response_body =
    Lwt.wakeup_later
      notify_response_received
      (Ok (H2_Response (response, response_body)))
  in
  let error_received, notify_error_received = Lwt.wait () in
  let error_handler = error_handler notify_error_received in
  Client.SSL.create_connection ~client:ssl_client ~error_handler fd
  >>= fun conn ->
  let request_body =
    Client.SSL.request conn request_headers ~error_handler ~response_handler
  in
  (match body with
  | Some body ->
    H2.Body.write_string request_body body
  | None ->
    ());
  H2.Body.flush request_body (fun () -> H2.Body.close_writer request_body);
  Lwt.return (response_received, error_received)

let http1_request ssl_client fd ?body request_headers =
  let open Httpaf_lwt in
  let response_received, notify_response_received = Lwt.wait () in
  let response_handler response response_body =
    Lwt.wakeup_later
      notify_response_received
      (Ok (Http1_Response (response, response_body)))
  in
  let error_received, notify_error_received = Lwt.wait () in
  let error_handler = error_handler notify_error_received in
  let request_body =
    Client.SSL.request
      ~client:ssl_client
      fd
      request_headers
      ~error_handler
      ~response_handler
  in
  (match body with
  | Some body ->
    Httpaf.Body.write_string request_body body
  | None ->
    ());
  Httpaf.Body.flush request_body (fun () ->
      Httpaf.Body.close_writer request_body);
  Lwt.return (response_received, error_received)

let send_request ~meth ~additional_headers ?body uri =
  let host = Uri.host_with_default uri in
  Lwt_unix.getaddrinfo host "443" [ Unix.(AI_FAMILY PF_INET) ]
  >>= fun addresses ->
  let sa = (List.hd addresses).Unix.ai_addr in
  let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  connect ~hostname:host sa fd >>= fun ssl_client ->
  match Lwt_ssl.ssl_socket ssl_client with
  | None ->
    failwith "handshake not established?"
  | Some ssl_socket ->
    (match Ssl.get_negotiated_alpn_protocol ssl_socket with
    | None
    | Some "http/1.1" ->
      let request_headers =
        Httpaf.Request.create
          meth
          (Uri.path_and_query uri)
          ~headers:
            (Httpaf.Headers.of_list ([ "Host", host ] @ additional_headers))
      in
      http1_request ssl_client fd ?body request_headers
    | Some "h2" ->
      let request_headers =
        H2.Request.create
          meth
          ~scheme:"https"
          (Uri.path_and_query uri)
          ~headers:
            (H2.Headers.of_list ([ ":authority", host ] @ additional_headers))
      in
      h2_request ssl_client fd ?body request_headers
    | Some _ ->
      (* Can't really happen - would mean that TLS negotiated a
       * protocol that we didn't specify. *)
      assert false)

let read_http1_response response_body =
  let open Httpaf in
  let buf = Buffer.create 0x2000 in
  let body_read, notify_body_read = Lwt.wait () in
  let rec read_fn () =
    Body.schedule_read
      response_body
      ~on_eof:(fun () ->
        Body.close_reader response_body;
        Lwt.wakeup_later notify_body_read (Ok (Body (Buffer.contents buf))))
      ~on_read:(fun response_fragment ~off ~len ->
        let response_fragment_bytes = Bytes.create len in
        Lwt_bytes.blit_to_bytes
          response_fragment
          off
          response_fragment_bytes
          0
          len;
        Buffer.add_bytes buf response_fragment_bytes;
        read_fn ())
  in
  read_fn ();
  body_read

let read_h2_response response_body =
  let open H2 in
  let buf = Buffer.create 0x2000 in
  let body_read, notify_body_read = Lwt.wait () in
  let rec read_fn () =
    Body.schedule_read
      response_body
      ~on_eof:(fun () ->
        Body.close_reader response_body;
        Lwt.wakeup_later notify_body_read (Ok (Body (Buffer.contents buf))))
      ~on_read:(fun response_fragment ~off ~len ->
        let response_fragment_bytes = Bytes.create len in
        Lwt_bytes.blit_to_bytes
          response_fragment
          off
          response_fragment_bytes
          0
          len;
        Buffer.add_bytes buf response_fragment_bytes;
        read_fn ())
  in
  read_fn ();
  body_read

let read_body f body err =
  Lwt.pick [ f body; err ] >|= fun x ->
  match x with
  | Ok (Body body_str) ->
    Ok body_str
  | Ok (H2_Response _) | Ok (Http1_Response _) ->
    assert false
  | Error err_str ->
    Error err_str

let send ?(meth = `GET) ?(additional_headers = []) ?body uri =
  send_request ~meth ~additional_headers ?body (Uri.of_string uri)
  >>= fun (resp, err) ->
  Lwt.choose [ resp; err ] >>= fun p ->
  match p with
  | Ok (Http1_Response (_r, body)) ->
    read_body read_http1_response body err
  | Ok (H2_Response (_r, body)) ->
    read_body read_h2_response body err
  | Ok (Body _) ->
    assert false
  | Error msg ->
    Lwt.fail_with msg
