package main

import "errors"

const defaultPort = 4444 // The default OBS websocket port.

// ConfigFile contains runtime configuration options.
type ConfigFile struct {
	ApiURL      string `yaml:"api_url"`  // Server URL.
	ApiKey      string `yaml:"api_key"`  // Server API key.
	OsuRoot     string `yaml:"osu_root"` // Directory of osu! installation.
	OBSPort     int    `yaml:"obs_port"`
	OBSPassword string `yaml:"obs_password"`
}

// Validate ensures that all required settings are present and fills in default values.
func (c *ConfigFile) Validate() error {
	if c.ApiURL == "" {
		return errors.New("required setting 'api_url' is missing")
	}
	if c.ApiKey == "" {
		return errors.New("required setting 'api_key' is missing")
	}
	if c.OsuRoot == "" {
		return errors.New("required setting 'osu_root' is missing")
	}

	if c.OBSPort == 0 {
		c.OBSPort = defaultPort
	}

	return nil
}
