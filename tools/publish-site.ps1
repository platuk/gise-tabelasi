# site/ klasörünü herkese açık github.com/platuk/cuptower deposuna (GitHub Pages) gönderir.
# Ana depo gizli kaldığı için gizlilik ve destek sayfaları bu ayrı depoda yayımlanır.
$ErrorActionPreference = 'Stop'
$site = Join-Path $PSScriptRoot '..\site' | Resolve-Path
$gitDir = Join-Path $env:TEMP 'cuptower-site.git'
$g = @("--git-dir=$gitDir", "--work-tree=$site")
if (-not (Test-Path $gitDir)) {
    git init --bare --initial-branch=main $gitDir | Out-Null
    git --git-dir=$gitDir config core.bare false
    git @g remote add origin https://github.com/platuk/cuptower.git
}
git @g add -A
git @g commit -m "CupTower destek ve gizlilik sayfaları" 2>$null
git @g push -u origin main
Write-Host "Gönderildi."
