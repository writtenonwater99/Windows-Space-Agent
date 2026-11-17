#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Scan')]
param(
    [Parameter(Mandatory)][ValidateRange(0.001,1000000)][double]$TargetFreeGiB,
    [Parameter(Mandatory,ParameterSetName='Scan')][string]$Folder,
    [Parameter(Mandatory,ParameterSetName='Import')][string]$ScanCsv,
    [Parameter(Mandatory,ParameterSetName='Import')][string]$DriveRoot,
    [ValidateRange(1,1000)][int]$Limit=20
)
$ErrorActionPreference = 'Stop'
$skipped = 0
$links = 0
if ($Folder) {
    $dir = Get-Item -LiteralPath $Folder
    if (!$dir.PSIsContainer -or ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Select a local directory without a reparse point.' }
    $DriveRoot = [IO.Path]::GetPathRoot($dir.FullName)
}
$drive = [IO.DriveInfo]::new($DriveRoot)
$available = $drive.AvailableFreeSpace
$gap = [Math]::Max([double]0, [Math]::Ceiling($TargetFreeGiB * 1GB) - $available)
$largest = @()
if ($gap -gt 0 -and $Folder) {
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($dir.FullName)
    while ($pending.Count) {
        $errors = @()
        $children = Get-ChildItem -Force -LiteralPath $pending.Pop() -ErrorAction SilentlyContinue -ErrorVariable errors
        $skipped += $errors.Count
        foreach ($child in $children) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { $links++; continue }
            if ($child.PSIsContainer) { $pending.Push($child.FullName); continue }
            if ($child.Length -gt 0) {
                $largest += [pscustomobject]@{Path=$child.FullName; Bytes=$child.Length}
                if ($largest.Count -ge (2 * $Limit)) { $largest = @($largest | Sort-Object Bytes -Descending | Select-Object -First $Limit) }
            }
        }
    }
} elseif ($gap -gt 0) {
    $seen = @{}
    $largest = @(Import-Csv -LiteralPath $ScanCsv | ForEach-Object {
        $bytes = [long]0
        if (!$_.Path -or ![long]::TryParse($_.Bytes,[ref]$bytes) -or $bytes -lt 0) { throw 'Expected file rows with Path and nonnegative integer Bytes.' }
        $path = [IO.Path]::GetFullPath($_.Path)
        if ($path -ne $_.Path -or [IO.Path]::GetPathRoot($path) -ne $drive.RootDirectory.FullName) { throw 'Each path must be absolute, canonical and on the selected drive.' }
        if ($seen.ContainsKey($path)) { throw 'Duplicate path in input.' }
        $seen[$path] = $true
        [pscustomobject]@{Path=$path; Bytes=$bytes}
    } | Sort-Object Bytes -Descending | Select-Object -First $Limit)
}
$ordered = @($largest | Sort-Object Bytes -Descending | Select-Object -First $Limit)
[pscustomobject]@{Format='space-1'; MeasuredUtc=[datetime]::UtcNow.ToString('o'); AvailableBytes=$available; TargetFreeGiB=$TargetFreeGiB; GapBytes=$gap; InspectionCandidates=$ordered; EnumerationErrors=$skipped; SkippedReparsePoints=$links} | ConvertTo-Json -Depth 4
