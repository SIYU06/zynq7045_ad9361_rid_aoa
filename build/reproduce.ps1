param(
    [Parameter(Mandatory=$true)][string]$Workspace,
    [ValidateSet('quick','fpga','kernel')][string]$Mode='quick',
    [ValidateSet('A','B','both')][string]$Station='both',
    [ValidateSet('validate','synth','impl','bitstream')][string]$FpgaPhase='bitstream',
    [ValidateRange(1,10)][int]$Rounds=1,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [string]$PythonExe='python',
    [string]$VivadoBin='',
    [string]$WslDistro='Ubuntu-22.04',
    [switch]$SkipSimulation
)
$ErrorActionPreference='Stop'
$nativeRoot=Join-Path ([IO.Path]::GetFullPath($Workspace)) 'source_code'
$entry=Join-Path $nativeRoot 'reproduce\run_reproduction.ps1'
if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw 'Prepare a fresh workspace with build/prepare_sources.py first.' }
$options=@{Mode=$Mode;Station=$Station;FpgaPhase=$FpgaPhase;Rounds=$Rounds;PythonExe=$PythonExe;OutputRoot=[IO.Path]::GetFullPath($OutputRoot);WslDistro=$WslDistro}
if ($VivadoBin) {$options.VivadoBin=$VivadoBin}
if ($SkipSimulation) {$options.SkipSimulation=$true}
& $entry @options
if ($LASTEXITCODE -ne 0) {throw 'Reproduction failed; preserve output and inspect its logs.'}
