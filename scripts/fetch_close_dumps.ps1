# ==============================================================================
# scripts/fetch_close_dumps.ps1
#
# 49-01 close-out dump fetch (pwsh-native — WSL transport is broken on this
# host; ssh/scp must go through the Windows alias santiago-D330).
#
# Usage:  pwsh -File scripts/fetch_close_dumps.ps1 -Cycle 1
#
# Fetches from the device into docs/dumps/re_kit/:
#   /home/santiago/d330_dsi_capture_close$Cycle/boot_dsi_regs.txt
#       -> close$Cycle_boot_dsi_regs.txt   (required)
#   /home/santiago/d330_dsi_capture_close$Cycle/resume_dsi_regs.txt
#       -> close$Cycle_resume_dsi_regs.txt (required)
#   /home/santiago/d330_dsi_capture_close${Cycle}_lit/boot_dsi_regs.txt
#       -> close$Cycle_lit_dsi_regs.txt    (optional: captured after the
#           reload workaround, later in the session sequence — a PENDING note
#           here is expected when fetching right after the wake arm)
# Prints sha256 per fetched file. Exit 1 only if a required arm is missing.
# ==============================================================================
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 3)]
    [int]$Cycle
)

$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$kit  = Join-Path $repo 'docs\dumps\re_kit'
$dev  = 'santiago-D330'

$arms = @(
    @{ remote = "/home/santiago/d330_dsi_capture_close$Cycle/boot_dsi_regs.txt";      local = "close${Cycle}_boot_dsi_regs.txt";   required = $true }
    @{ remote = "/home/santiago/d330_dsi_capture_close$Cycle/resume_dsi_regs.txt";    local = "close${Cycle}_resume_dsi_regs.txt"; required = $true }
    @{ remote = "/home/santiago/d330_dsi_capture_close${Cycle}_lit/boot_dsi_regs.txt"; local = "close${Cycle}_lit_dsi_regs.txt";   required = $false }
)

$missingRequired = 0
foreach ($arm in $arms) {
    $target = Join-Path $kit $arm.local
    Write-Host "fetch: ${dev}:$($arm.remote) -> $target"
    & scp -o BatchMode=yes "$($dev):$($arm.remote)" $target
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $target)) {
        if ($arm.required) {
            Write-Host "MISSING (required): $($arm.local)"
            $missingRequired++
        }
        else {
            Write-Host "PENDING (optional lit arm not captured yet): $($arm.local)"
        }
        continue
    }
    $h = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower()
    Write-Host "sha256($($arm.local)) = $h"
}

if ($missingRequired -gt 0) { exit 1 } else { exit 0 }
