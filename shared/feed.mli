module Author : sig
  type t =
    { name : string
    ; uri : string option
    ; email : string option
    }
  [@@deriving yojson]
end

module Link : sig
  type t =
    { title : string
    ; href : string
    }
  [@@deriving yojson]
end

module Entry : sig
  type t =
    { authors : Author.t * Author.t list
    ; content : string option
    ; id : string
    ; links : Link.t list
    ; published : float option
    ; title : string
    ; updated : float
    }
  [@@deriving yojson]
end

type t =
  { authors : Author.t list
  ; id : string
  ; links : Link.t list
  ; logo : string option
  ; subtitle : string option
  ; title : string
  ; updated : float
  ; entries : Entry.t list
  }
[@@deriving yojson]
