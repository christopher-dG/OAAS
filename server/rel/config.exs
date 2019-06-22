~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file/1)

cookie = System.get_env("COOKIE")
if is_nil(cookie), do: raise "COOKIE environment variable is not set"

use Mix.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()

environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: "COOKIE" |> System.get_env() |> String.to_atom()
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: "COOKIE" |> System.get_env() |> String.to_atom()
  set vm_args: "rel/vm.args"
end

release :oaas do
  set version: current_version(:oaas)
  set applications: [
    :runtime_tools
  ]
  set commands: [
    add_key: "rel/commands/add_key",
    delete_key: "rel/commands/delete_key",
    list_keys: "rel/commands/list_keys"
  ]
  set config_providers: [
    {Toml.Provider, [path: "${RELEASE_ROOT_DIR}/config.toml"]}
  ]
end
