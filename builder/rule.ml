open Import
module Action_builder = Action_builder0

type t =
  { action : Action.t Action_builder.t
  ; targets : Path.Build.Set.t
  ; ivar : Path.Build.Set.t Fiber.Ivar.t
  ; dir : Path.Build.t
  }

let create ~targets ~dir action =
  { dir; action; targets; ivar = Fiber.Ivar.create () }

module L = struct
  (* let filter *)
end
