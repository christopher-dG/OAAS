Sqlitex.Server.start_link("priv/db_#{Mix.env()}.sqlite3", name: OAAS.DB)
OAAS.DB.start_link([])
ExUnit.start()
