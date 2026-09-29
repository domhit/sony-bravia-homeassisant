[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ScanFile,
    [Parameter(Mandatory=$true)][string]$TvIp,
    [string]$OutputDirectory = ".\generated",
    [string]$SecretName,
    [switch]$IncludeDashboard,
    [switch]$IncludeDocumentation,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SafeId([string]$Text) {
    $id = $Text.ToLowerInvariant() -replace '[^a-z0-9]+','_'
    return $id.Trim('_')
}
function Quote-Yaml([string]$Text) { return '"' + ($Text -replace '"','\"') + '"' }
function Get-Test([object]$Scan,[string]$Method) {
    return @($Scan.readOnlyTests | Where-Object { $_.method -eq $Method -and $_.success }) | Select-Object -First 1
}
function Result-Array([object]$Test) {
    if ($null -eq $Test -or $null -eq $Test.response -or $null -eq $Test.response.result) { return @() }
    $r = @($Test.response.result)
    if ($r.Count -gt 0 -and $r[0] -is [System.Array]) { return @($r[0]) }
    return $r
}
function Add-Line([System.Text.StringBuilder]$Builder,[string]$Line="") { [void]$Builder.AppendLine($Line) }

$scanPath = (Resolve-Path -LiteralPath $ScanFile).Path
$scan = Get-Content -LiteralPath $scanPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
$system = Get-Test $scan "getSystemInformation"
if ($null -eq $system) { throw "The scan does not contain a successful getSystemInformation response." }
$info = @(Result-Array $system)[0]
$model = [string]$info.model
if ([string]::IsNullOrWhiteSpace($model)) { throw "The TV model could not be determined." }
$modelId = Get-SafeId $model
$prefix = "sony_bravia_$modelId"
if ([string]::IsNullOrWhiteSpace($SecretName)) { $SecretName = "${prefix}_psk" }

$inputs = @(Result-Array (Get-Test $scan "getCurrentExternalInputsStatus"))
$apps = @(Result-Array (Get-Test $scan "getApplicationList"))
$remoteTest = Get-Test $scan "getRemoteControllerInfo"
$remote = @()
if ($null -ne $remoteTest) {
    $rr = @($remoteTest.response.result)
    if ($rr.Count -gt 1) { $remote = @($rr[1]) }
}
$volume = @(Result-Array (Get-Test $scan "getVolumeInformation")) | Select-Object -First 1
$minVolume = if ($null -ne $volume.minVolume) { [int]$volume.minVolume } else { 0 }
$maxVolume = if ($null -ne $volume.maxVolume) { [int]$volume.maxVolume } else { 100 }
$generation = if ($null -ne $info.generation) { [string]$info.generation } else { "unknown" }

$out = [IO.Path]::GetFullPath($OutputDirectory)
if ((Test-Path $out) -and -not $Force) {
    $existing = Get-ChildItem $out -Force -ErrorAction SilentlyContinue
    if ($existing) { throw "Output directory is not empty. Use -Force to overwrite generated files: $out" }
}
New-Item -ItemType Directory -Path $out -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $out "packages") -Force | Out-Null
if ($IncludeDashboard) { New-Item -ItemType Directory -Path (Join-Path $out "dashboards") -Force | Out-Null }
if ($IncludeDocumentation) { New-Item -ItemType Directory -Path (Join-Path $out "docs") -Force | Out-Null }

$b = [Text.StringBuilder]::new()
Add-Line $b "###############################################################################"
Add-Line $b "# Generated from a Sony BRAVIA API scan"
Add-Line $b "# Model: $model | API generation: $generation"
Add-Line $b "# Regenerate instead of editing generated sections manually."
Add-Line $b "###############################################################################"
Add-Line $b
Add-Line $b "rest:"
$rests = @(
 @("system","getPowerStatus","[]","1.0","Power Status","value_json.result[0].status","television"),
 @("audio","getVolumeInformation","[]","1.0","Volume","value_json.result[0][0].volume","volume-high"),
 @("audio","getVolumeInformation","[]","1.0","Mute Status","value_json.result[0][0].mute","volume-mute"),
 @("audio","getSoundSettings",'[{"target":""}]',"1.1","Audio Output","value_json.result[0][0].currentValue","speaker-multiple"),
 @("avContent","getPlayingContentInfo","[]","1.0","Current Content","value_json.result[0].title | default(value_json.result[0].source, true) | default('unknown', true)","play-box-outline")
)
foreach ($r in $rests) {
    $sensorId = Get-SafeId $r[4]
    Add-Line $b "  - resource: `"http://$TvIp/sony/$($r[0])`""
    Add-Line $b "    method: POST"
    Add-Line $b "    headers:"
    Add-Line $b "      X-Auth-PSK: !secret $SecretName"
    Add-Line $b "      Content-Type: `"application/json; charset=UTF-8`""
    Add-Line $b "    payload: >-"
    Add-Line $b "      {`"method`":`"$($r[1])`",`"params`":$($r[2]),`"id`":101,`"version`":`"$($r[3])`"}"
    Add-Line $b "    scan_interval: 10"
    Add-Line $b "    timeout: 5"
    Add-Line $b "    sensor:"
    Add-Line $b "      - name: `"Sony BRAVIA $model $($r[4])`""
    Add-Line $b "        unique_id: ${prefix}_${sensorId}"
    Add-Line $b "        value_template: >-"
    Add-Line $b "          {% if value_json.result is defined %}{{ $($r[5]) }}{% else %}unavailable{% endif %}"
    Add-Line $b "        icon: mdi:$($r[6])"
    if ($r[4] -eq "Current Content") {
      Add-Line $b '        json_attributes_path: "$.result[0]"'
      Add-Line $b "        json_attributes: [uri, source, title, programTitle, startDateTime, durationSec, mediaType]"
    }
}
Add-Line $b
Add-Line $b "rest_command:"
Add-Line $b "  ${prefix}_api:"
Add-Line $b '    url: "http://'"$TvIp"'/sony/{{ service }}"'
Add-Line $b "    method: POST"
Add-Line $b "    headers:"
Add-Line $b "      X-Auth-PSK: !secret $SecretName"
Add-Line $b '      Content-Type: "application/json; charset=UTF-8"'
Add-Line $b '    payload: >-'
Add-Line $b '      {"method":{{ method | to_json }},"params":{{ params | to_json }},"id":{{ id | default(200) }},"version":{{ version | default("1.0") | to_json }}}'
Add-Line $b "  ${prefix}_ircc:"
Add-Line $b "    url: `"http://$TvIp/sony/IRCC`""
Add-Line $b "    method: POST"
Add-Line $b "    headers:"
Add-Line $b "      X-Auth-PSK: !secret $SecretName"
Add-Line $b '      SOAPACTION: '"'"'"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC"'"'"''
Add-Line $b '      Content-Type: "text/xml; charset=UTF-8"'
Add-Line $b '    payload: >-'
Add-Line $b '      <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1"><IRCCCode>{{ code }}</IRCCCode></u:X_SendIRCC></s:Body></s:Envelope>'
Add-Line $b
Add-Line $b "script:"
$basic = @(
 @("power_on","Power On","system","setPowerStatus",'[{"status":true}]',"1.0"),
 @("power_off","Power Off","system","setPowerStatus",'[{"status":false}]',"1.0"),
 @("mute_on","Mute On","audio","setAudioMute",'[{"status":true}]',"1.0"),
 @("mute_off","Mute Off","audio","setAudioMute",'[{"status":false}]',"1.0"),
 @("audio_output_tv","TV Speakers","audio","setSoundSettings",'[{"settings":[{"target":"outputTerminal","value":"speaker"}]}]',"1.1"),
 @("audio_output_system","Audio System","audio","setSoundSettings",'[{"settings":[{"target":"outputTerminal","value":"audioSystem"}]}]',"1.1")
)
foreach($x in $basic){
 Add-Line $b "  ${prefix}_$($x[0]):"
 Add-Line $b "    alias: `"Sony BRAVIA $model - $($x[1])`""
 Add-Line $b "    sequence:"
 Add-Line $b "      - action: rest_command.${prefix}_api"
 Add-Line $b "        data:"
 Add-Line $b "          service: $($x[2])"
 Add-Line $b "          method: $($x[3])"
 Add-Line $b "          params: $($x[4])"
 Add-Line $b "          version: `"$($x[5])`""
}
Add-Line $b "  ${prefix}_set_volume:"
Add-Line $b "    alias: `"Sony BRAVIA $model - Set Volume`""
Add-Line $b "    fields: {volume: {required: true}}"
Add-Line $b "    sequence:"
Add-Line $b "      - action: rest_command.${prefix}_api"
Add-Line $b "        data: {service: audio, method: setAudioVolume, params: [{target: speaker, volume: '`{{ volume | int }}`', ui: 'on'}], version: '1.2'}"

foreach($i in $inputs){
 if (-not $i.uri) { continue }
 $label = if ($i.label) { [string]$i.label } elseif ($i.title) { [string]$i.title } else { [string]$i.uri }
 $id = Get-SafeId $label
 Add-Line $b "  ${prefix}_input_${id}:"
 Add-Line $b "    alias: `"Sony BRAVIA $model - Input $label`""
 Add-Line $b "    sequence:"
 Add-Line $b "      - action: rest_command.${prefix}_api"
 Add-Line $b "        data: {service: avContent, method: setPlayContent, params: [{uri: $(Quote-Yaml ([string]$i.uri))}], version: '1.0'}"
}
foreach($a in $apps){
 if (-not $a.uri -or -not $a.title) { continue }
 $id=Get-SafeId ([string]$a.title)
 Add-Line $b "  ${prefix}_app_${id}:"
 Add-Line $b "    alias: `"Sony BRAVIA $model - App $($a.title)`""
 Add-Line $b "    sequence:"
 Add-Line $b "      - action: rest_command.${prefix}_api"
 Add-Line $b "        data: {service: appControl, method: setActiveApp, params: [{uri: $(Quote-Yaml ([string]$a.uri)), data: ''}], version: '1.0'}"
}
foreach($key in $remote){
 if (-not $key.name -or -not $key.value) { continue }
 $id=Get-SafeId ([string]$key.name)
 Add-Line $b "  ${prefix}_remote_${id}:"
 Add-Line $b "    alias: `"Sony BRAVIA $model Remote - $($key.name)`""
 Add-Line $b "    sequence: [{action: rest_command.${prefix}_ircc, data: {code: $(Quote-Yaml ([string]$key.value))}}]"
}

Add-Line $b
Add-Line $b "template:"
Add-Line $b "  - number:"
Add-Line $b "      - name: `"Sony BRAVIA $model Volume Control`""
Add-Line $b "        unique_id: ${prefix}_volume_control"
Add-Line $b "        min: $minVolume"
Add-Line $b "        max: $maxVolume"
Add-Line $b "        step: 1"
Add-Line $b "        state: `"{{ states('sensor.${prefix}_volume') | int(0) }}`""
Add-Line $b "        set_value: [{action: script.${prefix}_set_volume, data: {volume: '`{{ value | int }}`'}}]"
Add-Line $b "  - select:"
Add-Line $b "      - name: `"Sony BRAVIA $model Audio Output Control`""
Add-Line $b "        unique_id: ${prefix}_audio_output_control"
Add-Line $b "        options: ['TV Speakers', 'Audio System']"
Add-Line $b "        state: >-"
Add-Line $b "          {% if is_state('sensor.${prefix}_audio_output', 'audioSystem') %}Audio System{% else %}TV Speakers{% endif %}"
Add-Line $b "        select_option:"
Add-Line $b "          - choose:"
Add-Line $b "              - conditions: `"{{ option == 'Audio System' }}`""
Add-Line $b "                sequence: [{action: script.${prefix}_audio_output_system}]"
Add-Line $b "            default: [{action: script.${prefix}_audio_output_tv}]"

$packagePath = Join-Path (Join-Path $out "packages") "${prefix}.yaml"
[IO.File]::WriteAllText($packagePath,$b.ToString(),[Text.UTF8Encoding]::new($false))

$secretExample = "$SecretName`: `"CHANGE_ME`"`n"
[IO.File]::WriteAllText((Join-Path $out "secrets.yaml.example"),$secretExample,[Text.UTF8Encoding]::new($false))

if ($IncludeDashboard) {
 $d=[Text.StringBuilder]::new(); Add-Line $d "title: Sony BRAVIA $model"; Add-Line $d "views:"; Add-Line $d "  - title: $model"; Add-Line $d "    path: $modelId"; Add-Line $d "    icon: mdi:television"; Add-Line $d "    cards:"; Add-Line $d "      - type: entities"; Add-Line $d "        title: Sony BRAVIA $model"; Add-Line $d "        entities:"; Add-Line $d "          - sensor.${prefix}_power_status"; Add-Line $d "          - number.${prefix}_volume_control"; Add-Line $d "          - select.${prefix}_audio_output_control"; Add-Line $d "          - sensor.${prefix}_current_content"
 [IO.File]::WriteAllText((Join-Path (Join-Path $out "dashboards") "dashboard-${modelId}.yaml"),$d.ToString(),[Text.UTF8Encoding]::new($false))
}
if ($IncludeDocumentation) {
 $doc = "# Sony BRAVIA $model`n`n- API generation: $generation`n- TV IP used during generation: ``$TvIp`` `n- Package: ``packages/${prefix}.yaml```n- Inputs discovered: $($inputs.Count)`n- Apps discovered: $($apps.Count)`n- IRCC commands discovered: $($remote.Count)`n"
 [IO.File]::WriteAllText((Join-Path (Join-Path $out "docs") "$model.md"),$doc,[Text.UTF8Encoding]::new($false))
}
$manifest=[ordered]@{generatedAt=(Get-Date).ToString('o');scanFile=$scanPath;model=$model;modelId=$modelId;generation=$generation;tvIp=$TvIp;secretName=$SecretName;inputs=$inputs.Count;apps=$apps.Count;irccCommands=$remote.Count;package=$packagePath}
$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out "generation-manifest.json") -Encoding UTF8
Write-Host "Generated Home Assistant files for $model" -ForegroundColor Green
Write-Host "Package: $packagePath"
