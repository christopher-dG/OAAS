ReplayFarm.DB.start()
Plug.Adapters.Cowboy2.http(ReplayFarm.Router, [], port: Application.get_env(:replay_farm, :port))
ExUnit.start()
