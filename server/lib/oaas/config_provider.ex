defmodule OAAS.ConfigProvider do
  @behaviour Config.Provider

  def init(file), do: file

  def load(config, file) do
    toml =
      "RELEASE_ROOT"
      |> System.get_env("")
      |> Path.join(file)
      |> Toml.decode_file!(keys: :atoms)
      |> Enum.map(fn {k, v} -> {k, Map.to_list(v)} end)

    Config.Reader.merge(config, toml)
  end
end
