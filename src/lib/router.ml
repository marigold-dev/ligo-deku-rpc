open Piaf

let ligo_to_tz ~env ~hash ~lang () =
  Eio.Switch.run @@ fun sw ->
  let filename_mligo = Printf.sprintf "%s.mligo" hash in
  let filename_tz = Printf.sprintf "%s.tz" hash in
  Logs.info (fun m -> m "compiling %s with syntax %s" filename_mligo lang);
  let stdout =
    Unix.open_process_args_in "ligo"
      [| "ligo"; "compile"; "contract"; "--syntax"; lang; filename_mligo |]
  in
  let descr = Unix.descr_of_in_channel stdout in
  let source =
    (Eio_unix.FD.as_socket ~sw ~close_unix:true descr :> Eio.Flow.source)
  in
  Eio_unix.await_readable descr;
  let sink =
    Eio.Path.open_out ~sw ~append:false ~create:(`Exclusive 0o600)
      Eio.Path.(Eio.Stdenv.cwd env / filename_tz)
  in
  Eio.Flow.copy source sink

let tz_to_wasm ~env ~hash ~storage () =
  Eio.Switch.run @@ fun sw ->
  let filename_tz = Printf.sprintf "%s.tz" hash in
  let filename_wasm = Printf.sprintf "%s.wat" hash in
  let stdout =
    Unix.open_process_args_in "tunac"
      [| "tunac"; "originate"; filename_tz; storage |]
  in
  let descr = Unix.descr_of_in_channel stdout in
  let source =
    (Eio_unix.FD.as_socket ~sw ~close_unix:true descr :> Eio.Flow.source)
  in
  Eio_unix.await_readable descr;
  let sink =
    Eio.Path.open_out ~sw ~append:false ~create:(`Exclusive 0o600)
      Eio.Path.(Eio.Stdenv.cwd env / filename_wasm)
  in
  Eio.Flow.copy source sink

let to_wasm ~env () =
  let handler { Server.ctx = _; request } =
    let json =
      request.body |> Body.to_string |> Result.map Yojson.Safe.from_string
    in
    let source =
      Result.map
        (fun json -> Yojson.Safe.Util.(member "source" json |> to_string))
        json
      |> Result.get_ok
    in
    let lang =
      Result.map
        (fun json -> Yojson.Safe.Util.(member "lang" json |> to_string))
        json
      |> Result.get_ok
    in
    let storage =
      Result.map
        (fun json -> Yojson.Safe.Util.(member "storage" json |> to_string))
        json
      |> Result.get_ok
    in

    let hash = Hash.make source in
    let filename_mligo = Printf.sprintf "%s.mligo" hash in
    let filename_tz = Printf.sprintf "%s.tz" hash in
    let filename_wasm = Printf.sprintf "%s.wat" hash in
    let mligo_path = Eio.Path.(Eio.Stdenv.cwd env / filename_mligo) in
    let tz_path = Eio.Path.(Eio.Stdenv.cwd env / filename_tz) in
    let wasm_path = Eio.Path.(Eio.Stdenv.cwd env / filename_wasm) in
    let data = try Some (Eio.Path.load tz_path) with _ -> None in

    let wasm =
      match data with
      | None ->
          let () =
            try Eio.Path.save ~create:(`Exclusive 0o600) mligo_path source
            with _ -> ()
          in
          let () = ligo_to_tz ~env ~hash ~lang () in
          let () = tz_to_wasm ~env ~hash ~storage () in
          let wasm = Eio.Path.load wasm_path in
          Eio.Path.unlink wasm_path;
          wasm
      | Some _tz ->
          let () = tz_to_wasm ~env ~hash ~storage () in
          let wasm = Eio.Path.load wasm_path in
          Eio.Path.unlink wasm_path;
          wasm
    in

    let body = Ok (Piaf.Body.of_string wasm) in

    match body with
    | Ok body -> Piaf.Response.create ~body `OK
    | Error e ->
        Piaf.Response.create
          ~body:(Body.of_string @@ Error.to_string e)
          `Bad_request
  in
  Routes.((s "api" / s "v1" / s "ligo" / s "originate" /? nil) @--> handler)

let healthz () =
  let handler _ = Piaf.Response.create ~body:(Piaf.Body.of_string "ok") `OK in
  Routes.((s "health" /? nil) @--> handler)

let router ~env () = Routes.one_of [ to_wasm ~env (); healthz () ]
