# Builds the FileZilla package from one commit, so the same commit always gives the same files.
# Usage: pwsh -File tools/build-deploy-package.ps1 -Commit <commit> -Destination <folder outside the repository>
param(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Destination
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$full = git -C $repo rev-parse --verify "$Commit^{commit}"
$destinationFull = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if ($destinationFull.StartsWith($repo, [StringComparison]::OrdinalIgnoreCase)) { throw 'The package must be outside the repository.' }

$public = Join-Path $destinationFull 'public'
if (Test-Path $public) { Remove-Item $public -Recurse -Force }
New-Item -ItemType Directory -Force $public | Out-Null

# Not part of the public website. api/ is never in the repository and stays on the server.
$excluded = @('^\.gitignore$', '^\.gitattributes$', '^README\.md$', '^tools/', '^api/', '^\.vs/', '(^|/)desktop\.ini$')
$tracked = git -C $repo ls-tree -r --name-only $full
$included = @($tracked | Where-Object { $path = $_; -not ($excluded | Where-Object { $path -match $_ }) })

$tarFile = Join-Path $destinationFull 'source.tar'
git -C $repo -c core.autocrlf=false archive --format=tar -o $tarFile $full -- @included
tar -xf $tarFile -C $public
Remove-Item $tarFile -Force

$lines = Get-ChildItem $public -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($public.Length + 1).Replace('\', '/')
    [pscustomobject]@{ Path = $relative; Hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); Size = $_.Length }
} | Sort-Object Path

[IO.File]::WriteAllLines((Join-Path $destinationFull 'SHA256SUMS.txt'), [string[]]($lines | ForEach-Object { "$($_.Hash)  $($_.Path)" }))
[IO.File]::WriteAllLines((Join-Path $destinationFull 'SOURCE-COMMIT.txt'), [string[]]@($full))

$forbidden = Get-ChildItem $public -Recurse -Force | Where-Object { $_.Name -in '.git', '.gitignore', '.vs', 'api', 'tools', 'README.md', 'config.php', 'desktop.ini' -or $_.Extension -in '.sqlite', '.sql', '.md' }
if ($forbidden) { throw "Forbidden files in the package: $($forbidden.FullName -join ', ')" }

"Commit: $full"
"Files: $($lines.Count), bytes: $(($lines | Measure-Object Size -Sum).Sum)"
