open Util
open Syndic
open Lwt.Infix

let send_response reqd body =
  let open Now in
  let response =
    Response.create
      ~headers:(Headers.of_list [ "content-type", "application/json" ])
      `OK
  in
  Reqd.respond_with_string reqd response (Yojson.Safe.to_string body)

let send_error_response reqd msg =
  let open Now in
  let payload = `Assoc [ "error", `String msg ] in
  let response =
    Response.create
      ~headers:(Headers.of_list [ "content-type", "application/json" ])
      `Bad_request
  in
  Reqd.respond_with_string reqd response (Yojson.Safe.to_string payload)

let replace_hrefs xml_base html_string =
  let tree = Soup.parse html_string in
  let anchors = Soup.select "a" tree in
  Soup.iter
    (fun a ->
      match Soup.attribute "href" a with
      | None ->
        ()
      | Some href ->
        let uri = Uri.resolve "" xml_base (Uri.of_string href) in
        Soup.set_attribute "href" (Uri.to_string uri) a)
    anchors;
  Soup.to_string tree

let text_construct_to_string : Atom.text_construct -> string = function
  | Atom.Text s ->
    s
  | Html (_, s) ->
    s
  | Xhtml (_, _) ->
    assert false

let content_to_string : Atom.content -> string = function
  | Atom.Text s ->
    s
  | Atom.Html (uri, s) ->
    (match uri with Some uri -> replace_hrefs uri s | None -> s)
  | Atom.Src (_, _) | Atom.Xhtml (_, _) ->
    assert false
  | Atom.Mime (_, s) ->
    s

let ptime_to_timestamp t =
  (* Ptime counts seconds, we return milliseconds *)
  Ptime.to_float_s t *. 1000.

let build_link { Atom.href; title; _ } =
  { Feed.Link.href = Uri.to_string href; title }

let build_author { Atom.name; uri; email } =
  { Feed.Author.name; email; uri = Option.map ~f:Uri.to_string uri }

let build_entry
    { Atom.authors = main_author, other_authors
    ; content
    ; id
    ; links
    ; published
    ; title
    ; updated
    ; _
    }
  =
  { Feed.Entry.authors =
      build_author main_author, List.map build_author other_authors
  ; content = Option.map ~f:content_to_string content
  ; id = Uri.to_string id
  ; links = List.map build_link links
  ; published = Option.map ~f:ptime_to_timestamp published
  ; title = text_construct_to_string title
  ; updated = ptime_to_timestamp updated
  }

let handle source =
  let input = Xmlm.make_input source in
  let { Atom.authors; id; links; logo; subtitle; title; updated; entries; _ } =
    Atom.parse ~xmlbase:(Uri.of_string "https://github.com") input
  in
  { Feed.authors = List.map build_author authors
  ; id = Uri.to_string id
  ; links = List.map build_link links
  ; logo = Option.map ~f:Uri.to_string logo
  ; subtitle = Option.map ~f:text_construct_to_string subtitle
  ; title = text_construct_to_string title
  ; updated = ptime_to_timestamp updated
  ; entries = List.map build_entry entries
  }

let get_feed ?page ?token user =
  let base_url = Format.asprintf "https://github.com/%s" user in
  let feed_url, has_query_param =
    match token with
    | Some token ->
      Format.asprintf "%s.private.atom?token=%s" base_url token, true
    | None ->
      Format.asprintf "%s.atom" base_url, false
  in
  let uri =
    match page with
    | Some page ->
      Format.asprintf
        "%s%cpage=%s"
        feed_url
        (if has_query_param then '&' else '?')
        page
    | None ->
      feed_url
  in
  Piaf.Client.Oneshot.get
    ~config:
      { Piaf.Config.default with
        follow_redirects = true
      ; cacert = Some "./cacert.pem"
      }
    ~headers:[ "accept", "text/html,application/xhtml+xml,application/xml" ]
    (Uri.of_string uri)
  >>= function
  | Ok (_, body) ->
    Lwt_result.ok (Piaf.Body.to_string body)
  | Error msg ->
    Lwt_result.fail msg

let handler reqd _ctx =
  let { Httpaf.Request.target; _ } = Now.Reqd.request reqd in
  let usage = "Usage:\n gh-feed.anmonteiro.now.sh/?user=username&page=N" in
  let uri = Uri.of_string target in
  let page = Uri.get_query_param uri "page" in
  let token = Uri.get_query_param uri "token" in
  match Uri.get_query_param uri "user" with
  | Some user ->
    get_feed ?page ?token user >>= ( function
    | Ok feed ->
      let feed_json = handle (`String (0, feed)) |> Feed.to_yojson in
      Lwt.return (send_response reqd feed_json)
    | Error msg ->
      Lwt.return (send_error_response reqd msg) )
  | None ->
    Lwt.return (send_error_response reqd usage)

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level (Some level);
  Logs.set_reporter (Logs_fmt.reporter ())

let () =
  setup_log Logs.Debug;
  (try Lwt_engine.(set (new libev ~backend:Ev_backend.kqueue ())) with
  | _ ->
    Printf.eprintf "Failed setting KQueue libev backend. Falling back.\n%!";
    Lwt_engine.(set (new libev ~backend:Ev_backend.epoll ())));
  Now.io_lambda handler
