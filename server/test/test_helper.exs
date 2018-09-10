Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: ReplayFarm.DB)
ReplayFarm.DB.start_link([])
ExUnit.start()
