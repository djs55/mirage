open Ocamlbuild_plugin

let _ = dispatch begin function
  |Before_rules ->
    (* HACK: ocaml doesnt install a str.cmxs by default, it would seem *)
    rule "make str.cmxs from stdlib str.cmxa" ~prod:"str.cmxs"
     (let src = Lazy.force Ocamlbuild_pack.Ocaml_utils.stdlib_dir / "str.cmxa" in
      Ocamlbuild_pack.Ocaml_compiler.native_shared_library_link ~tags:["linkall"] src "str.cmxs"
     )
  |After_rules ->
     (* Required to repack sub-packs (like Pa_css) into Pa_mirage *)
     pflag ["ocaml"; "pack"] "for-repack" (fun param -> S [A "-for-pack"; A param]);
  |_ -> ()
end
