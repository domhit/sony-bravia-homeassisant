# Sony BRAVIA Home Assistant Control

Local Home Assistant packages for Sony BRAVIA Android TVs using Sony JSON-RPC and IRCC. No cloud or ADB is required for normal operation.

## Tested models

| Model | API generation | Package |
|---|---:|---|
| KE-75XH9005 | 5.6.0 | `packages/sony_bravia_ke75xh9005.yaml` |
| KD-70XF8305 | 5.4.0 | `packages/sony_bravia_kd70xf8305.yaml` |

## Quick start

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Copy the desired package files to `/config/packages/`, add the PSKs shown in `examples/secrets.yaml.example`, review the package IP addresses, validate Home Assistant and restart. Both packages are namespaced and may coexist.

See `docs/installation.md` for details.

## Generate a package from an API scan

A Home Assistant package can be generated automatically from a Sony BRAVIA API scan.

See:

- [`ols/Scan-SonyBraviaApi.ps1
- [`tools/Export-SonyBraviaHomeAssistant.ps1`](tools/Export-Sony
  
## Features

- Power, volume and mute
- TV speakers / audio system
- Input selection and app launch
- Current content/program information
- IRCC remote-control scripts
- PowerShell API scanner for additional models

## Security

Never publish PSKs or unsanitized scans. Raw scans are ignored by default.

## License

MIT
