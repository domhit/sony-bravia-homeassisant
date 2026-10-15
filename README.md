# Sony BRAVIA Home Assistant Control

Local Home Assistant packages for Sony BRAVIA Android TVs using Sony JSON-RPC and IRCC. No cloud or ADB is required for normal operation.

# Dashboard Rework (October 2026)

## Removed

The original custom Sony REST packages were removed from active use:

- `sony_bravia_ke75xh9005.yaml`
- `sony_bravia_kd70xf8305.yaml`

Reason:

- template entities became difficult to maintain
- entity naming was inconsistent
- native Bravia REST API integration already provided most required functionality
- lower maintenance effort with native entities

## New Dashboard Architecture

The dashboards now use native entities from the Bravia REST API integration instead of custom template entities.

## Current Content Sensors
 
Reintroduced custom REST sensors based on:
 
```json
getPlayingContentInfo

KD-70XF8305:

Current source
Program title
Program duration
Media type
Additional TV metadata

KE-75XH9005:

Current source
Program metadata where available
App detection fallback
```

Dashboards are uploaded to examples

# Original v0.1.0
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
