package main

import "errors"

// ConfigFile contains runtime configuration options.
type ConfigFile struct {
	ApiURL      string `yaml:"api_url"`
	ApiKey      string `yaml:"api_key"`
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

	if c.OBSPort == 0 {
		c.OBSPort = obsPort
	}

	return nil
}
