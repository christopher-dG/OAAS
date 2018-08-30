package main

// ConfigFile contains runtime configuration options.
type ConfigFile struct {
	ApiURL  string `yaml:"api_url"`  // Server URL.
	ApiKey  string `yaml:"api_key"`  // Server API key.
	OsuRoot string `yaml:"osu_root"` // Directory of osu! installation.
}
