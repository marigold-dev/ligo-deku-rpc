open Piaf

let ligo_to_tz ~env ~lang ~filename_ligo ~filename_tz () =
  Eio.Switch.run @@ fun sw ->
  Logs.info (fun m -> m "compiling %s with syntax %s" filename_ligo lang);
  let stdout =
    Unix.open_process_args_in "ligo"
      [| "ligo"; "compile"; "contract"; "--syntax"; lang; filename_ligo |]
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

let tz_to_wasm ~env ~storage ~filename_tz ~filename_wasm () =
  Eio.Switch.run @@ fun sw ->
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
    let filename_ligo = Printf.sprintf "%s.%s" hash lang in
    let filename_tz = Printf.sprintf "%s.tz" hash in
    let filename_wasm = Printf.sprintf "%s.wat" hash in
    let ligo_path = Eio.Path.(Eio.Stdenv.cwd env / filename_ligo) in
    let tz_path = Eio.Path.(Eio.Stdenv.cwd env / filename_tz) in
    let wasm_path = Eio.Path.(Eio.Stdenv.cwd env / filename_wasm) in
    let tz_already_exists =
      try Some (Eio.Path.load tz_path) |> Option.is_some with _ -> false
    in

    let wasm =
      match tz_already_exists with
      | false ->
          let () =
            try Eio.Path.save ~create:(`Exclusive 0o600) ligo_path source
            with _ -> ()
          in
          let () = ligo_to_tz ~env ~lang ~filename_ligo ~filename_tz () in
          let () = tz_to_wasm ~env ~storage ~filename_tz ~filename_wasm () in
          let wasm = Eio.Path.load wasm_path in
          Eio.Path.unlink wasm_path;
          wasm
      | true ->
          let () = tz_to_wasm ~env ~storage ~filename_tz ~filename_wasm () in
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
