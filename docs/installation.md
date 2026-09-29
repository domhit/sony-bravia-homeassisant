# Installation

1. Enable Home Assistant packages with `packages: !include_dir_named packages`.
2. Copy the desired files from `packages/` to `/config/packages/`.
3. Add the matching secrets from `examples/secrets.yaml.example` to `/config/secrets.yaml`.
4. Review the test IPs: KE `192.168.0.58`, KD `192.168.0.59`.
5. Run **Developer Tools > YAML > Check configuration** and restart.

Both packages use model-specific entity, script and command IDs and can be loaded together.
