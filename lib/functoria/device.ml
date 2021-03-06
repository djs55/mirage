(*
 * Copyright (c) 2013-2020 Thomas Gazagnaire <thomas@gazagnaire.org>
 * Copyright (c) 2013-2020 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2015-2020 Gabriel Radanne <drupyog@zoho.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Action.Infix
open Astring

type abstract_key = Key.t

type package = Package.t

type info = Info.t

type 'a value = 'a Key.value

type ('a, 'impl) t = {
  id : int;
  module_name : string;
  module_type : 'a Type.t;
  keys : abstract_key list;
  packages : package list value;
  install : info -> Install.t value;
  connect : info -> string -> string list -> string;
  configure : info -> unit Action.t;
  files : info -> [ `Configure | `Build ] -> Fpath.t list;
  build : info -> unit Action.t;
  clean : info -> unit Action.t;
  extra_deps : 'impl list;
}

let pp : type a b. b Fmt.t -> (a, b) t Fmt.t =
 fun pp_impl ppf t ->
  let open Fmt.Dump in
  let fields =
    [
      field "id" (fun t -> t.id) Fmt.int;
      field "module_name" (fun t -> t.module_name) string;
      field "module_type" (fun t -> t.module_type) Type.pp;
      field "keys" (fun t -> t.keys) (list Key.pp);
      field "install" (fun _ -> "<dyn>") Fmt.string;
      field "packages" (fun _ -> "<dyn>") Fmt.string;
      field "extra_deps" (fun t -> t.extra_deps) (list pp_impl);
    ]
  in
  record fields ppf t

let equal x y = x.id = y.id

let hash x = x.id

let default_connect _ _ l =
  Printf.sprintf "return (%s)" (String.concat ~sep:", " l)

let niet _ = Action.ok ()

let nil _ _ = []

type 'a code = string

let merge empty union a b =
  match (a, b) with
  | None, None -> Key.pure empty
  | Some a, None -> Key.pure a
  | None, Some b -> b
  | Some a, Some b -> Key.(pure union $ pure a $ b)

let merge_packages = merge [] List.append

let merge_install = merge Install.empty Install.union

let count =
  let i = ref 0 in
  fun () ->
    incr i;
    !i

let v ?packages ?packages_v ?install ?install_v ?(keys = []) ?(extra_deps = [])
    ?(connect = default_connect) ?(configure = niet) ?(files = nil)
    ?(build = niet) ?(clean = niet) module_name module_type =
  let id = count () in
  let packages = merge_packages packages packages_v in
  let install i =
    let aux = function None -> None | Some f -> Some (f i) in
    merge_install (aux install) (aux install_v)
  in
  {
    module_type;
    id;
    module_name;
    keys;
    connect;
    packages;
    install;
    clean;
    configure;
    files;
    build;
    extra_deps;
  }

let id t = t.id

let module_name t = t.module_name

let module_type t = t.module_type

let packages t = t.packages

let install t = t.install

let connect t = t.connect

let configure t = t.configure

let files t = t.files

let build t = t.build

let clean t = t.clean

let keys t = t.keys

let extra_deps t = t.extra_deps

let start impl_name args =
  Fmt.strf "@[%s.start@ %a@]" impl_name Fmt.(list ~sep:sp string) args

let exec_hook i = function None -> Action.ok () | Some h -> h i

let extend ?packages ?packages_v ?(files = nil) ?pre_configure ?post_configure
    ?pre_build ?post_build ?pre_clean ?post_clean t =
  let files i s = files i s @ t.files i s in
  let packages =
    Key.(pure List.append $ merge_packages packages packages_v $ t.packages)
  in
  let exec pre f post i =
    exec_hook i pre >>= fun () ->
    f i >>= fun () -> exec_hook i post
  in
  let configure = exec pre_configure t.configure post_configure in
  let build = exec pre_build t.build post_build in
  let clean = exec pre_clean t.clean post_clean in
  { t with packages; files; configure; build; clean }
