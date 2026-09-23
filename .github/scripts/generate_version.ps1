Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Find the latest clean semver tag (X.Y.Z only — no suffix)
$allTags = git tag -l | Where-Object { $_ -match '^\d+\.\d+\.\d+$' }

if (-not $allTags) {
    $major = 1; $minor = 0; $patch = 0
    Write-Host "No existing semver tag found, starting at 1.0.0"
}
else {
    $latestTag = $allTags `
        | ForEach-Object { [System.Version]$_ } `
        | Sort-Object `
        | Select-Object -Last 1

    $major = $latestTag.Major
    $minor = $latestTag.Minor
    $patch = $latestTag.Build
    Write-Host "Latest clean tag: $latestTag"
}

$baseVersion = "$major.$minor.$($patch + 1)"

# pull_request events expose the source branch via GITHUB_HEAD_REF;
# push/workflow_dispatch events use GITHUB_REF_NAME directly
$eventName = $env:GITHUB_EVENT_NAME
$branch = if ($eventName -eq "pull_request") { $env:GITHUB_HEAD_REF } else { $env:GITHUB_REF_NAME }

if ($branch -eq "main") {
    $version = $baseVersion
}
else {
    # Sanitize: lowercase, collapse any non-alphanumeric run into a single hyphen, strip leading/trailing hyphens
    $safeBranch = $branch.ToLower() -replace '[^a-z0-9]+', '-' -replace '^-|-$', ''
    $version = "$baseVersion.$safeBranch"
}

Write-Host "Branch  : $branch"
Write-Host "Version : $version"
"version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
