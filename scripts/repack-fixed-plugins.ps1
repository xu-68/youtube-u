param(
    [Parameter(Mandatory = $true)][string]$InputIpa,
    [Parameter(Mandatory = $true)][string]$PluginDirectory,
    [Parameter(Mandatory = $true)][string]$OutputIpa
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$libraries = @('iSponsorBlock', 'DontEatMyContent', 'YTVideoOverlay', 'YouQuality', 'YouSpeed', 'YouTubeDislikesReturn')
$inputPath = (Resolve-Path -LiteralPath $InputIpa).Path
$pluginsPath = (Resolve-Path -LiteralPath $PluginDirectory).Path
$outputPath = [System.IO.Path]::GetFullPath($OutputIpa)
if ($outputPath -eq $inputPath) { throw 'Output must be a separate file' }
if (Test-Path -LiteralPath $outputPath) { throw 'Output already exists' }
foreach ($library in $libraries) {
    $path = Join-Path $pluginsPath "$library.dylib"
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing compiled plugin: $library" }
}
New-Item -ItemType Directory -Force ([System.IO.Path]::GetDirectoryName($outputPath)) | Out-Null
Copy-Item -LiteralPath $inputPath -Destination $outputPath
$archive = [System.IO.Compression.ZipFile]::Open($outputPath, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    $roots = @($archive.Entries | Where-Object { $_.FullName -match '^Payload/[^/]+\.app/Info.plist$' })
    if ($roots.Count -ne 1) { throw 'Expected exactly one application' }
    $root = $roots[0].FullName.Substring(0, $roots[0].FullName.Length - 'Info.plist'.Length)
    foreach ($library in $libraries) {
        $entryPath = "${root}Frameworks/$library.dylib"
        $oldEntry = $archive.GetEntry($entryPath)
        if (!$oldEntry) { throw "Original IPA does not contain $library" }
        $attributes = $oldEntry.ExternalAttributes
        $oldEntry.Delete()
        $newEntry = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, (Join-Path $pluginsPath "$library.dylib"), $entryPath,
            [System.IO.Compression.CompressionLevel]::Optimal)
        $newEntry.ExternalAttributes = $attributes
    }
    # A signature manifest from the old application cannot describe new binaries.
    $staleManifests = @($archive.Entries | Where-Object { $_.FullName.StartsWith("${root}_CodeSignature/") })
    foreach ($entry in $staleManifests) { $entry.Delete() }
} finally { $archive.Dispose() }

$archive = [System.IO.Compression.ZipFile]::OpenRead($outputPath)
try {
    foreach ($library in $libraries) {
        $entry = $archive.GetEntry("${root}Frameworks/$library.dylib")
        $stream = $entry.Open()
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try { $actual = [System.BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '') }
        finally { $hasher.Dispose(); $stream.Dispose() }
        $expected = (Get-FileHash -LiteralPath (Join-Path $pluginsPath "$library.dylib") -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw "Packaged plugin differs: $library" }
        Write-Output "Verified packaged library: $library"
    }
} finally { $archive.Dispose() }
$digest = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    (Join-Path ([System.IO.Path]::GetDirectoryName($outputPath)) 'SHA256SUMS.txt'),
    "$digest  $([System.IO.Path]::GetFileName($outputPath))`n",
    [System.Text.UTF8Encoding]::new($false))
Write-Output "Created unsigned IPA: $outputPath"
Write-Output "SHA256: $digest"
