# Checks a copy of the website: HTML structure, links, anchors, canonical URLs, titles, sitemap and release content.
# Usage: pwsh -File tools/check-site.ps1 -Root <folder>. Exit code 1 when anything is wrong.
param([Parameter(Mandatory)][string]$Root)

$Root = (Resolve-Path $Root).Path.TrimEnd('\')
$void = 'meta','link','br','img','input','hr','source','area','base','col','embed','param','track','wbr','path','circle','rect','line','polygon','polyline','ellipse','use','stop'
$problems = [Collections.Generic.List[string]]::new()

$files = Get-ChildItem $Root -Recurse -Filter index.html |
    Where-Object { $_.FullName.Substring($Root.Length) -notmatch '\\(\.git|\.vs|api|tools)\\' }
$pages = @{}
foreach ($file in $files) {
    $relative = $file.DirectoryName.Substring($Root.Length).Replace('\', '/').TrimStart('/')
    $url = if ($relative) { "/$relative/" } else { '/' }
    $pages[$url] = [IO.File]::ReadAllText($file.FullName)
}

$ids = @{}
foreach ($url in $pages.Keys) {
    $ids[$url] = @([regex]::Matches($pages[$url], '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
}

$titles = @{}
foreach ($url in ($pages.Keys | Sort-Object)) {
    $text = $pages[$url]
    $clean = [regex]::Replace($text, '(?s)<!--.*?-->|<script\b.*?</script>|<style\b.*?</style>', '')
    $stack = [Collections.Generic.Stack[string]]::new()
    foreach ($tag in [regex]::Matches($clean, '<(/?)([a-zA-Z][a-zA-Z0-9-]*)((?:[^>"'']|"[^"]*"|''[^'']*'')*?)(/?)>')) {
        $name = $tag.Groups[2].Value.ToLower()
        if ($void -contains $name -or $tag.Groups[4].Value) { continue }
        if ($tag.Groups[1].Value) {
            if ($stack.Count -and $stack.Peek() -eq $name) { [void]$stack.Pop() }
            else { $problems.Add("$url unexpected </$name>") }
        }
        else { $stack.Push($name) }
    }
    if ($stack.Count) { $problems.Add("$url unclosed: $($stack -join ',')") }

    $duplicates = $ids[$url] | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name
    if ($duplicates) { $problems.Add("$url duplicate ids: $duplicates") }

    foreach ($label in [regex]::Matches($text, 'aria-labelledby="([^"]+)"')) {
        foreach ($id in $label.Groups[1].Value -split ' ') {
            if ($ids[$url] -cnotcontains $id) { $problems.Add("$url aria-labelledby without target: $id") }
        }
    }

    $expected = "https://www.offisen.app$url"
    $canonical = [regex]::Match($text, '<link rel="canonical" href="([^"]+)"').Groups[1].Value
    if ($canonical -cne $expected) { $problems.Add("$url canonical '$canonical'") }
    $ogUrl = [regex]::Match($text, 'property="og:url" content="([^"]+)"').Groups[1].Value
    if ($ogUrl -and $ogUrl -cne $expected) { $problems.Add("$url og:url '$ogUrl'") }
    if (([regex]::Matches($text, '<h1[\s>]')).Count -ne 1) { $problems.Add("$url must have one h1") }

    $title = [regex]::Match($text, '<title>(.*?)</title>').Groups[1].Value.Trim()
    if (-not $title) { $problems.Add("$url has no title") } else { $titles[$title] += , $url }

    foreach ($link in [regex]::Matches($text, '<a\b[^>]*href="([^"]+)"')) {
        $href = $link.Groups[1].Value
        if ($href.StartsWith('#')) {
            if ($href.Length -gt 1 -and $ids[$url] -cnotcontains $href.Substring(1)) { $problems.Add("$url anchor $href") }
        }
        elseif ($href.StartsWith('/')) {
            $path, $fragment = $href -split '#', 2
            $withSlash = if ($path.EndsWith('/')) { $path } else { "$path/" }
            if ($pages.ContainsKey($withSlash)) {
                if ($fragment -and $ids[$withSlash] -cnotcontains $fragment) { $problems.Add("$url bad anchor $href") }
            }
            elseif (-not (Test-Path (Join-Path $Root ($path.TrimStart('/') -split '\?')[0]) -PathType Leaf)) { $problems.Add("$url broken link $href") }
        }
    }

    foreach ($asset in [regex]::Matches($text, '(?:src|href)="(/[^"#?]+\.[a-z0-9]+)')) {
        if (-not (Test-Path (Join-Path $Root $asset.Groups[1].Value.TrimStart('/')) -PathType Leaf)) { $problems.Add("$url missing file $($asset.Groups[1].Value)") }
    }

    # Release content
    if ($text -match '(?i)coming in version|upcoming|coming soon') { $problems.Add("$url has pre-release wording") }
    if ($text -match 'cdn-cgi|__cf_email') { $problems.Add("$url has Cloudflare leftovers") }
    if (([regex]::Matches($text, [regex]::Escape('<p>&copy; 2026 Rudolf Mendzezof. All rights reserved.</p>'))).Count -ne 1) { $problems.Add("$url footer wording") }
    if ($text -match 'Designed by') { $problems.Add("$url has Designed by") }
    if ($text -notmatch '<meta name="color-scheme" content="light">') { $problems.Add("$url color-scheme is not light") }
    if ($text -notmatch 'src="/JS/theme-init\.js\?v=\d+"') { $problems.Add("$url lacks theme-init.js") }
}
foreach ($title in $titles.Keys) { if ($titles[$title].Count -gt 1) { $problems.Add("duplicate title '$title': $($titles[$title])") } }

# CSS and web manifest references
$css = [IO.File]::ReadAllText((Join-Path $Root 'CSS\style.css'))
foreach ($ref in [regex]::Matches($css, 'url\(["'']?(/[^"'')?#]+)')) {
    if (-not (Test-Path (Join-Path $Root $ref.Groups[1].Value.TrimStart('/')))) { $problems.Add("style.css missing $($ref.Groups[1].Value)") }
}
if ($css -notmatch ':root \{\s*color-scheme: light;') { $problems.Add('style.css default is not light') }
$manifest = Get-Content (Join-Path $Root 'assets\favicon\site.webmanifest') -Raw | ConvertFrom-Json
foreach ($icon in $manifest.icons) {
    $file = if ($icon.src.StartsWith('/')) { Join-Path $Root $icon.src.TrimStart('/') } else { Join-Path $Root "assets\favicon\$($icon.src)" }
    if (-not (Test-Path $file)) { $problems.Add("webmanifest missing $($icon.src)") }
}

# Sitemap
[xml]$sitemap = [IO.File]::ReadAllText((Join-Path $Root 'sitemap.xml'))
$locations = @($sitemap.urlset.url.loc)
$wanted = @($pages.Keys | ForEach-Object { "https://www.offisen.app$_" })
foreach ($item in $wanted) { if ($locations -notcontains $item) { $problems.Add("not in sitemap: $item") } }
foreach ($item in $locations) { if ($wanted -notcontains $item) { $problems.Add("sitemap without page: $item") } }
if ($locations.Count -ne ($locations | Sort-Object -Unique).Count) { $problems.Add('sitemap has duplicates') }

# Expected content
$codes = @([regex]::Matches($pages['/support/codes/'], '/support/codes/(OFS-\d{4})/') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
if ($codes.Count -ne 26) { $problems.Add("code directory lists $($codes.Count) codes, expected 26") }
foreach ($code in $codes) { if (-not $pages.ContainsKey("/support/codes/$code/")) { $problems.Add("no article for $code") } }
foreach ($chapter in 'editing-sequences', 'merging-sequences', 'text-insertion', 'attached-sequences', 'run-history', 'workday-timer') {
    if (-not $pages.ContainsKey("/guide/$chapter/")) { $problems.Add("missing chapter $chapter") }
    if ($pages['/guide/'] -notmatch "href=`"/guide/$chapter/`"") { $problems.Add("/guide/ does not link $chapter") }
}
if ($pages['/privacy-policy/'] -notmatch 'datetime="2026-11-03">November 3, 2026<') { $problems.Add('privacy policy date') }
if ($pages['/privacy-policy/'] -notmatch 'Cloudflare Web Analytics') { $problems.Add('privacy policy lacks Cloudflare Web Analytics') }
if ($pages['/'] -notmatch 'Offisen gives you time back\.') { $problems.Add('home page promise') }

"Pages: $($pages.Count). Sitemap: $($locations.Count). Codes: $($codes.Count). Sitemap dates: $(($sitemap.urlset.url.lastmod | Sort-Object -Unique) -join ', ')."
if ($problems.Count) {
    $problems | ForEach-Object { "PROBLEM $_" }
    exit 1
}
'No problems found.'
