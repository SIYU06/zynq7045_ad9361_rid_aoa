param(
    [Parameter(Mandatory=$true)][string]$Workspace,
    [Parameter(Mandatory=$true)][string]$VivadoBin,
    [Parameter(Mandatory=$true)][string]$OutputRoot
)
$ErrorActionPreference='Stop'
if (Test-Path -LiteralPath $OutputRoot) {throw 'Choose a fresh OutputRoot.'}
$entry=Join-Path ([IO.Path]::GetFullPath($Workspace)) 'source_code\zynq7045_ad9361_rid_aoa\dsss_receiver\sim\run_example.ps1'
if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) {throw 'Prepare sources before running simulation.'}
& $entry -VivadoBin $VivadoBin -WorkDirectory ([IO.Path]::GetFullPath($OutputRoot))
if ($LASTEXITCODE -ne 0) {throw 'Simulation did not pass.'}
