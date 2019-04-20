module D = Decoders_bs.Decode
open Feed
open D.Infix

let x = D.( >>= )

let decode_author =
  D.(field "name" string) >>= fun name ->
  D.(maybe (field "uri" string)) >>= fun uri ->
  D.(maybe (field "email" string)) >>= fun email ->
  D.succeed { Author.name; email; uri }

let decode_link =
  D.(field "title" string) >>= fun title ->
  D.(field "href" string) >>= fun href -> D.succeed { Link.title; href }

let decode_entry =
  let decode_authors_field : (Author.t * Author.t list) D.decoder =
    D.index 0 decode_author >>= fun author ->
    D.(index 1 (list decode_author)) >>= fun authors ->
    D.succeed (author, authors)
  in
  D.(field "authors" decode_authors_field) >>= fun authors ->
  D.(maybe (field "content" string)) >>= fun content ->
  D.(field "id" string) >>= fun id ->
  D.(field "links" (list decode_link)) >>= fun links ->
  D.(maybe (field "published" float)) >>= fun published ->
  D.(field "title" string) >>= fun title ->
  D.(field "updated" float) >>= fun updated ->
  D.succeed { Entry.authors; content; id; links; published; title; updated }

let decode_feed =
  D.(field "authors" (list decode_author)) >>= fun authors ->
  D.(field "id" string) >>= fun id ->
  D.(field "links" (list decode_link)) >>= fun links ->
  D.(maybe (field "logo" string)) >>= fun logo ->
  D.(maybe (field "subtitle" string)) >>= fun subtitle ->
  D.(field "title" string) >>= fun title ->
  D.(field "updated" float) >>= fun updated ->
  D.(field "entries" (list decode_entry)) >>= fun entries ->
  D.succeed { authors; id; links; logo; subtitle; title; updated; entries }
