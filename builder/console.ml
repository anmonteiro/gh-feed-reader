open Import

let print_user_message msg =
  Option.iter msg.User_message.loc ~f:(fun loc ->
      Loc.render Format.err_formatter (Loc.pp loc));
  User_message.prerr { msg with loc = None }
