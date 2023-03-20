open Import

module File_perm = struct
  type t =
    | Normal
    | Executable

  let suffix = function Normal -> "" | Executable -> "-executable"
  let to_unix_perm = function Normal -> 0o666 | Executable -> 0o777
end

type t =
  | Run of string * string list
  | Copy of Path.t * Path.Build.t
  | Write_file of Path.Build.t * string
  | Rename of Path.Build.t * Path.Build.t
  | Remove_tree of Path.Build.t
  | Mkdir of Path.Build.t
  | Progn of t list
  | System of string
  | Bash of string
