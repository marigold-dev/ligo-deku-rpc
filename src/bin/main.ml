open Eio.Std
open Piaf

let request_handler ~env req =
  let { Server.ctx = _; request } = req in
  Routes.match' (Ligo_deku_rpc.Router.router ~env ()) ~target:request.target
  |> function
  | Routes.NoMatch -> Piaf.Response.create `Not_found
  | FullMatch handler | MatchWithTrailingSlash handler -> handler req

let main port =
  let config = Server.Config.create port in
  Eio_main.run (fun env ->
      Switch.run (fun sw ->
          let server = Server.create ~config (request_handler ~env) in
          let _command =
            Server.Command.start ~bind_to_address:Eio.Net.Ipaddr.V4.any ~sw env
              server
          in
          ()))

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level (Some level);
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  setup_log Logs.Info;
  let port = ref 8080 in
  Arg.parse
    [ ("-p", Arg.Set_int port, " Listening port number (8080 by default)") ]
    ignore "Echoes POST requests. Runs forever.";
  main !port