[CmdletBinding()]param([Parameter(Mandatory=$true)][string]$TvIp,[Parameter(Mandatory=$true)][string]$Psk,[string]$OutputFile=".\sony-bravia-api-scan.json")
$ErrorActionPreference="Stop";$id=1
function Call($service,$method,$params=@(),$version="1.0"){$body=@{method=$method;params=$params;id=$script:id;version=$version};$script:id++;try{$response=Invoke-RestMethod -Uri "http://$TvIp/sony/$service" -Method Post -Headers @{"X-Auth-PSK"=$Psk} -ContentType "application/json; charset=UTF-8" -Body ($body|ConvertTo-Json -Depth 30 -Compress) -TimeoutSec 10;@{success=$true;service=$service;method=$method;version=$version;request=$body;response=$response}}catch{@{success=$false;service=$service;method=$method;version=$version;request=$body;error=$_.Exception.Message}}}
$services=@("system","audio","avContent","appControl","videoScreen","recording","browser","cec","notification","encryption")
$scan=[ordered]@{scanTime=(Get-Date).ToString("o");tvIp="REDACTED";discovery=@();methodTypes=@();readOnlyTests=@()}
$scan.discovery+=Call "guide" "getSupportedApiInfo" @(@{services=@()})
foreach($s in $services){$scan.methodTypes+=Call $s "getMethodTypes" @(" ")}
$tests=@(@("system","getSystemInformation",@(),"1.0"),@("system","getPowerStatus",@(),"1.0"),@("system","getRemoteControllerInfo",@(),"1.0"),@("audio","getVolumeInformation",@(),"1.0"),@("audio","getSoundSettings",@(@{target=""}),"1.1"),@("avContent","getCurrentExternalInputsStatus",@(),"1.1"),@("avContent","getPlayingContentInfo",@(),"1.0"),@("appControl","getApplicationList",@(),"1.0"))
foreach($t in $tests){$scan.readOnlyTests+=Call $t[0] $t[1] $t[2] $t[3]}
$j=$scan|ConvertTo-Json -Depth 60;$j=$j-replace '(?i)("serial"\s*:\s*")[^"]+','$1REDACTED' -replace '(?i)("macAddr"\s*:\s*")[^"]+','$1REDACTED' -replace '(?i)("cid"\s*:\s*")[^"]+','$1REDACTED';$j|Set-Content $OutputFile -Encoding UTF8;Write-Host "Fertig: $OutputFile"
