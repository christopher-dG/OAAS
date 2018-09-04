{:ok, _pid} = ReplayFarm.DB.start()

{:ok, _pid} =
  Plug.Adapters.Cowboy2.http(ReplayFarm.Web.Router, [],
    port: Application.get_env(:replay_farm, :port)
  )

ExUnit.start()
