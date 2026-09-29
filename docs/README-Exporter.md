# Sony BRAVIA API Scan to Home Assistant Exporter

Mit `Export-SonyBraviaHomeAssistant.ps1` lässt sich aus einem zuvor erstellten Sony-BRAVIA-API-Scan automatisch ein Home-Assistant-Package erzeugen. Optional erstellt das Skript zusätzlich ein Basis-Dashboard und eine gerätespezifische Markdown-Dokumentation.

Damit bleibt die Konfiguration reproduzierbar:

```text
Sony BRAVIA
    │
    ▼
Scan-SonyBraviaApi.ps1
    │
    ▼
sony-bravia-api-scan.json
    │
    ▼
Export-SonyBraviaHomeAssistant.ps1
    │
    ├── Home-Assistant-Package
    ├── Basis-Dashboard
    ├── Gerätedokumentation
    ├── secrets.yaml.example
    └── generation-manifest.json
```

## Funktionen

Das Export-Skript liest aus dem Scan unter anderem:

- Modellbezeichnung und API-Generation
- verfügbare Eingänge und deren Bezeichnungen
- installierte Apps und ihre Sony-App-URIs
- IRCC-Fernbedienungsbefehle
- Lautstärkebereich
- Power-, Lautstärke-, Mute- und Audioausgabe-Informationen
- aktuelle Inhalts- und Programminformationen

Es erzeugt daraus:

- REST-Sensoren für Power, Lautstärke, Mute, Audioausgabe und aktuelle Inhalte
- generische Sony-JSON-RPC- und IRCC-Kommandos
- Scripts für Power, Mute, Audioausgabe, Eingänge, Apps und IRCC-Tasten
- ein Number-Entity zur Lautstärkesteuerung
- ein Select-Entity für TV-Lautsprecher bzw. Audiosystem
- optional ein einfaches Home-Assistant-Dashboard
- optional eine Modell-Dokumentation

## Voraussetzungen

### Sony BRAVIA

Am Fernseher müssen aktiviert sein:

- IP-Steuerung
- Authentifizierung über Pre-Shared Key
- Netzwerkzugriff von dem Rechner, auf dem der Scan ausgeführt wird

### PowerShell

Benötigt wird PowerShell 7 oder neuer.

Version prüfen:

```powershell
$PSVersionTable.PSVersion
```

Unter Linux:

```bash
pwsh --version
```

## Dateien

Die beiden Werkzeuge sollten beispielsweise so abgelegt werden:

```text
tools/
├── Scan-SonyBraviaApi.ps1
└── Export-SonyBraviaHomeAssistant.ps1
```

## Schritt 1: Sony BRAVIA scannen

### Windows

```powershell
.\Scan-SonyBraviaApi.ps1 `
  -TvIp "192.168.0.59" `
  -Psk "DEIN_PSK" `
  -OutputFile ".\sony-bravia-api-scan.json"
```

### Linux

```bash
pwsh -File ./Scan-SonyBraviaApi.ps1 \
  -TvIp 192.168.0.59 \
  -Psk 'DEIN_PSK' \
  -OutputFile ./sony-bravia-api-scan.json
```

Der Scan führt nur lesende Inventarisierungsaufrufe aus. Der PSK wird nicht in die JSON-Datei geschrieben. Sensible Werte wie Seriennummer, MAC-Adresse und CID werden vom Scanner redigiert.

## Schritt 2: Home-Assistant-Dateien exportieren

### Windows

```powershell
.\Export-SonyBraviaHomeAssistant.ps1 `
  -ScanFile ".\sony-bravia-api-scan.json" `
  -TvIp "192.168.0.59" `
  -OutputDirectory ".\generated" `
  -IncludeDashboard `
  -IncludeDocumentation
```

### Linux

```bash
pwsh -File ./Export-SonyBraviaHomeAssistant.ps1 \
  -ScanFile ./sony-bravia-api-scan.json \
  -TvIp 192.168.0.59 \
  -OutputDirectory ./generated \
  -IncludeDashboard \
  -IncludeDocumentation
```

## Parameter des Export-Skripts

### `-ScanFile`

Pfad zur JSON-Datei, die mit `Scan-SonyBraviaApi.ps1` erzeugt wurde.

```powershell
-ScanFile ".\sony-bravia-api-scan.json"
```

### `-TvIp`

Aktuelle IP-Adresse des Fernsehers. Sie wird in das erzeugte Home-Assistant-Package übernommen.

```powershell
-TvIp "192.168.0.59"
```

Eine DHCP-Reservierung für den Fernseher wird empfohlen.

### `-OutputDirectory`

Zielverzeichnis für alle erzeugten Dateien.

```powershell
-OutputDirectory ".\generated"
```

### `-SecretName`

Optionaler Name des Home-Assistant-Secrets. Ohne Angabe wird der Name automatisch aus dem Modell erzeugt.

```powershell
-SecretName "sony_bravia_kd70xf8305_psk"
```

### `-IncludeDashboard`

Erzeugt zusätzlich ein einfaches Dashboard als Ausgangspunkt.

```powershell
-IncludeDashboard
```

### `-IncludeDocumentation`

Erzeugt zusätzlich eine gerätespezifische Markdown-Datei.

```powershell
-IncludeDocumentation
```

### `-Force`

Erlaubt die Ausgabe in ein bereits gefülltes Zielverzeichnis.

```powershell
-Force
```

Ohne `-Force` bricht das Skript ab, wenn das Zielverzeichnis bereits Dateien enthält. Dadurch werden bestehende Dateien nicht versehentlich überschrieben.

## Beispiel mit eigenem Secret-Namen

```powershell
.\Export-SonyBraviaHomeAssistant.ps1 `
  -ScanFile ".\sony-bravia-api-scan.json" `
  -TvIp "192.168.0.59" `
  -SecretName "sony_bravia_kd70xf8305_psk" `
  -OutputDirectory ".\generated-kd70" `
  -IncludeDashboard `
  -IncludeDocumentation
```

## Erzeugte Verzeichnisstruktur

```text
generated/
├── packages/
│   └── sony_bravia_<modell>.yaml
├── dashboards/
│   └── dashboard-<modell>.yaml
├── docs/
│   └── <MODELL>.md
├── generation-manifest.json
└── secrets.yaml.example
```

Dashboard und Dokumentation werden nur erzeugt, wenn die entsprechenden Schalter angegeben wurden.

## Home Assistant einrichten

### Packages aktivieren

In `/config/configuration.yaml`:

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Falls bereits ein `homeassistant:`-Block existiert, darf kein zweiter Block angelegt werden. Ergänze nur die Zeile `packages:` im vorhandenen Block.

### Package kopieren

Die generierte Datei aus

```text
generated/packages/
```

nach

```text
/config/packages/
```

kopieren.

### Secret eintragen

Den Eintrag aus

```text
generated/secrets.yaml.example
```

in `/config/secrets.yaml` übernehmen und `CHANGE_ME` durch den echten PSK ersetzen.

Beispiel:

```yaml
sony_bravia_kd70xf8305_psk: "DEIN_PSK"
```

### Konfiguration prüfen

In Home Assistant:

```text
Entwicklerwerkzeuge → YAML → Konfiguration prüfen
```

Erst nach erfolgreicher Prüfung Home Assistant neu starten.

## Generationsmanifest

`generation-manifest.json` dokumentiert unter anderem:

- Zeitpunkt der Generierung
- verwendete Scan-Datei
- Modell und Modell-ID
- API-Generation
- verwendete TV-IP
- Secret-Name
- Anzahl erkannter Eingänge
- Anzahl erkannter Apps
- Anzahl erkannter IRCC-Befehle
- Pfad zum erzeugten Package

Damit lässt sich später nachvollziehen, mit welchen Eingabedaten ein Package erzeugt wurde.

## Empfohlener Git-Workflow

Scans können geräte- und netzwerkspezifische Daten enthalten. Rohscans sollten deshalb nicht automatisch veröffentlicht werden.

Empfohlene `.gitignore`-Einträge:

```gitignore
secrets.yaml
scans/*.json
scans/*.json.txt
generated/
```

Wenn ein Scan für die Unterstützung eines weiteren Modells veröffentlicht werden soll, muss er vorher kontrolliert und gegebenenfalls weiter anonymisiert werden.

## Grenzen des Generators

Das Skript erzeugt ein funktionales Basispaket. Individuelle Anpassungen bleiben sinnvoll, zum Beispiel:

- freundlichere Eingangsnamen
- Auswahl und Reihenfolge der Apps
- reduzierte IRCC-Tastenauswahl
- ein aufwendig gestaltetes Dashboard
- Verknüpfung mit einem AV-Receiver
- angepasste Scanintervalle
- gerätespezifische API-Besonderheiten

Die generierten Dateien sollten daher vor dem produktiven Einsatz geprüft werden.

## Reproduzierbarer Ablauf

Solange folgende Dateien erhalten bleiben, kann die Home-Assistant-Konfiguration jederzeit neu erzeugt werden:

```text
Scan-SonyBraviaApi.ps1
Export-SonyBraviaHomeAssistant.ps1
sony-bravia-api-scan.json
```

Der Chat ist für eine spätere Neuerstellung dann nicht mehr erforderlich.
