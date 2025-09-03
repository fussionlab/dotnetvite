# Prompt for project name 
Write-Host "Enter your project name:" -ForegroundColor Cyan
$projectName = Read-Host 
$color = @("Black", "Gray", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow")
# Create ASP.NET MVC project
dotnet new mvc -n $projectName
Set-Location $projectName
New-Item -ItemType Directory -Name "Helpers"


#Add Data or replace content to the file Function
function Get-AddToFileContent {
    param (
        [string]$FilePath,
        [string]$FileName,
        [string]$AddContent,
        [string]$FindContent,
        [ValidateSet("above", "below", "replace")]
        [string]$Action = "below"
    )

    # Find the file
    $file = Get-ChildItem -Path $FilePath -Recurse -Filter $FileName | Select-Object -First 1

    if (-not $file) {
        Write-Error "File '$FileName' not found in path '$FilePath'"
        return
    }

    # Read file content
    $content = Get-Content $file.FullName
    $newContent = @()

    foreach ($line in $content) {
        if ($line -match $FindContent) {
            switch ($Action) {
                "above" { $newContent += $AddContent; $newContent += $line }
                "below" { $newContent += $line; $newContent += $AddContent }
                "replace" { $newContent += $AddContent }
            }
        }
        else {
            $newContent += $line
        }
    }

    # Write back the content
    $newContent | Set-Content $file.FullName

}
# Add ViteManifest helper class
Set-Content -Path ".\Helpers\ViteManifest.cs" -Value @"
using System.Text.Json;
namespace $projectName.Helpers;

public class ViteManifest
{
    private readonly string _manifestPath;

    public ViteManifest(IWebHostEnvironment env)
    {
        _manifestPath = Path.Combine(env.WebRootPath, "manifest.json");
    }

    public (List<string> jsFiles, List<string> cssFiles) GetAllAssets()
    {
        if (!File.Exists(_manifestPath))
            return (new(), new());

        var json = File.ReadAllText(_manifestPath);
        var manifest = JsonSerializer.Deserialize<Dictionary<string, ManifestEntry>>(json);

        var jsFiles = new List<string>();
        var cssFiles = new List<string>();

        if (manifest != null)
        {
            foreach (var entry in manifest.Values)
            {
                if (!string.IsNullOrEmpty(entry.file) && entry.file.EndsWith(".js"))
                    jsFiles.Add("/" + entry.file);

                if (entry.css != null)
                {
                    foreach (var css in entry.css)
                        cssFiles.Add("/" + css);
                }
            }
        }

        return (jsFiles.Distinct().ToList(), cssFiles.Distinct().ToList());
    }

    private class ManifestEntry
    {
        public string file { get; set; } = string.Empty;
        public List<string>? css { get; set; }
    }
}

"@

# Update Program.cs with required DI and fallback route
$filePath = ".\Program.cs"
$fileContent = Get-Content $filePath
$newContent = @()
$insertedUsing = $false

foreach ($line in $fileContent) {
    # Insert using before the 'var builder' line
    if (-not $insertedUsing -and $line -like "var builder*") {
        $newContent += "using $projectName.Helpers;"
        $insertedUsing = $true
    }

    $newContent += $line

    # Inject singleton service registration
    if ($line -like "*builder.Services.AddControllersWithViews();*") {
        $newContent += 'builder.Services.AddSingleton<ViteManifest>();'
    }

    # Inject fallback mapping for production
    if ($line -like "*.WithStaticAssets();") {
        $newContent += @'
			if (!app.Environment.IsDevelopment())
			{
				app.MapFallbackToFile("index.html");
			}
'@
    }
	
}
$file = Get-Content $filePath
foreach ($line in $file) {
    if ($line -like "*.WithStaticAssets();*") {
        $line = $line -replace ".WithStaticAssets();", ";"
    }
}

Set-Content -Path $filePath -Value $newContent

Set-Content -Path ".\Views\Shared\_Layout.cshtml" -Value $null
Get-ChildItem -Path ".\Views\Home" -File | Where-Object { $_.Name -ne "Index.cshtml" } | Remove-Item -Force
Get-ChildItem -Path ".\Views\Shared" -File | Where-Object { $_.Name -ne "_Layout.cshtml" } | Remove-Item -Force

# Modify Index.cshtml to use _Layout #
 
Set-Content -Path ".\Views\Home\Index.cshtml" -Value @"
@{
	Layout = "_Layout";
}
"@

Set-Content -Path ".\Controllers\HomeController.cs" -Value @"
using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using $projectName.Models;

namespace $projectName.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;

    public HomeController(ILogger<HomeController> logger)
    {
        _logger = logger;
    }

    [HttpGet("{*url}", Order = int.MaxValue)]
    public IActionResult Index()
    {
        return View();
    }

}

"@

Set-Content -Path ".\Controllers\WeatherForecastController.cs" -Value @"
using Microsoft.AspNetCore.Mvc;
using $projectName.Controllers;
using $projectName.Models;

[ApiController]
[Route("api/[controller]")]
public class WeatherForecastController : ControllerBase
{
    private static readonly string[] Summaries = new[]
    {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    private readonly ILogger<WeatherForecastController> _logger;

    public WeatherForecastController(ILogger<WeatherForecastController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IEnumerable<WeatherForecast> Get()
    {
        var rng = new Random();
        return Enumerable.Range(1, 5).Select(index => new WeatherForecast
        {
            Date = DateTime.Now.AddDays(index),
            TemperatureC = rng.Next(-20, 55),
            Summary = Summaries[rng.Next(Summaries.Length)]
        })
        .ToArray();
    }
}

"@
Set-Content -Path ".\Models\WeatherForecast.cs" -Value @"
using System;
namespace $projectName.Models;
public class WeatherForecast
{
    public DateTime Date { get; set; }
    public int TemperatureC { get; set; }
    public string? Summary { get; set; }

    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
"@

# Framework options
$frameworks = @("", "vanilla", "vue", "react", "preact", "lit", "svelte", "solid", "qwik", "angular", "marko")
$color = @("White", "Green", "Yellow", "Cyan", "Magenta", "Blue", "Gray", "DarkCyan", "DarkGreen", "DarkYellow", "DarkMagenta", "DarkRed")

Write-Host "Select a framework:" -ForegroundColor Cyan
for ($i = 1; $i -lt $frameworks.Count; $i++) {
    Write-Host "$i. $($frameworks[$i])" -ForegroundColor $color[$i % $color.Count]
}
Write-Host "Enter the number of your selected framework:" -ForegroundColor Yellow
$frameworkIndex = [int](Read-Host)
$framework = $frameworks[$frameworkIndex]

$template = ""
$variantLanguage = ""

if ($framework -eq "react") {
    Write-Host "`nSelect a React variant:" -ForegroundColor Cyan
    $reactVariants = @(
        @{ label = "Empty"; template = ""; lang = "" },
        @{ label = "TypeScript"; template = "react-ts"; lang = "tsx" },
        @{ label = "TypeScript + SWC"; template = "react-swc"; lang = "tsx" },
        @{ label = "JavaScript"; template = "react"; lang = "jsx" },
        @{ label = "JavaScript + SWC"; template = "react-swc-js"; lang = "jsx" }
    )
    for ($i = 1; $i -lt $reactVariants.Count; $i++) {
        Write-Host "$i. $($reactVariants[$i].label)" -ForegroundColor $color[$i % $color.Count]
    }
    Write-Host "Enter the number of your selected variant:" -ForegroundColor Yellow
    $variantIndex = [int](Read-Host)
    $template = $reactVariants[$variantIndex].template
    $variantLanguage = $reactVariants[$variantIndex].lang
}
elseif ($framework -eq "preact") {
    Write-Host "`nSelect a Preact variant:" -ForegroundColor Cyan

    $preactVariants = @(
        @{ label = "Empty"; template = ""; lang = "" },
        @{ label = "TypeScript"; template = "preact-ts"; lang = "tsx" },
        @{ label = "JavaScript"; template = "preact"; lang = "jsx" }
    )
    for ($i = 1; $i -lt $preactVariants.Count; $i++) {
        Write-Host "$i. $($preactVariants[$i].label)" -ForegroundColor $color[$i % $color.Count]
    }
    Write-Host "Enter the number of your selected variant:" -ForegroundColor Yellow
    $variantIndex = [int](Read-Host)
    $template = $preactVariants[$variantIndex].template
    $variantLanguage = $preactVariants[$variantIndex].lang
}
elseif ($framework -eq "solid") {
    Write-Host "`nSelect a Solid variant:" -ForegroundColor Cyan

    $solidVariants = @(
        @{ label = "Empty"; template = ""; lang = "" },
        @{ label = "TypeScript"; template = "solid-ts"; lang = "tsx" },
        @{ label = "JavaScript"; template = "solid"; lang = "jsx" }
    )
    for ($i = 1; $i -lt $solidVariants.Count; $i++) {
        Write-Host "$i. $($solidVariants[$i].label)" -ForegroundColor $color[$i % $color.Count]
    }
    Write-Host "Enter the number of your selected variant:" -ForegroundColor Yellow
    $variantIndex = [int](Read-Host)
    $template = $solidVariants[$variantIndex].template
    $variantLanguage = $solidVariants[$variantIndex].lang
}
elseif ($framework -eq "qwik") {
    Write-Host "`nSelect a Qwik variant:" -ForegroundColor Cyan

    $qwikVariants = @(
        @{ label = "Empty"; template = ""; lang = "" },
        @{ label = "TypeScript"; template = "qwik-ts"; lang = "tsx" },
        @{ label = "JavaScript"; template = "qwik"; lang = "jsx" }
    )
    for ($i = 1; $i -lt $qwikVariants.Count; $i++) {
        Write-Host "$i. $($qwikVariants[$i].label)" -ForegroundColor $color[$i % $color.Count]
    }
    Write-Host "Enter the number of your selected variant:" -ForegroundColor Yellow
    $variantIndex = [int](Read-Host)
    $template = $qwikVariants[$variantIndex].template
    $variantLanguage = $qwikVariants[$variantIndex].lang
}
elseif ($framework -eq "angular") {
    Write-Host "`nAngular does not have variants, using default template." -ForegroundColor Green
    $template = "angular"
    $variantLanguage = "ts"
}
else {
    Write-Host "`nSelect a variant:" -ForegroundColor Cyan
    $variants = @(
        @{ label = "Empty"; suffix = ""; lang = "" },
        @{ label = "TypeScript"; suffix = "-ts"; lang = "ts" },
        @{ label = "JavaScript"; suffix = ""; lang = "js" }
    )
    for ($i = 1; $i -lt $variants.Count; $i++) {
        Write-Host "$i. $($variants[$i].label)" -ForegroundColor $color[$i % $color.Count]
    }
    Write-Host "Enter the number of your selected variant:" -ForegroundColor Yellow
    $variantIndex = [int](Read-Host)
    
    # FIX: assign just the suffix string, not the whole hashtable
    $suffix = $variants[$variantIndex].suffix
    $template = "$framework$suffix"
    $variantLanguage = $variants[$variantIndex].lang
}

Write-Host "`nSelected framework: $framework"
Write-Host "Template: $template"
Write-Host "Language extension: $variantLanguage"


$_IWeatherInterface = @"
interface IWeatherData {
    date: string;
    temperatureC: number;
    temperatureF: number;
    summary: string;
}
"@

$reactRefresh = @()

if ($variantLanguage -eq "tsx" -and $framework -eq "react" -or $variantLanguage -eq "jsx" -and $framework -eq "react") {
    $reactRefresh += @'
	<script type="module">
		import { injectIntoGlobalHook } from "http://localhost:5173/@@react-refresh";
		injectIntoGlobalHook(window);
		window.$RefreshReg$ = () => {};
		window.$RefreshSig$ = () => (type) => type;
    </script>
'@
}
else {
    $reactRefresh += ""
}

# Define framework metadata and configuration
$pluginImport = ""
$pluginUsage = ""
$frameworkLink = ""
$rootId = ""
$extension = ""

switch ($framework) {
    "vue" { $pluginImport = "import vue from '@vitejs/plugin-vue'"; $pluginUsage = "plugins: [vue()]"; $frameworkLink = "https://vuejs.org/"; $rootId = "app"; $extension = "vue" }
    "react" { $pluginImport = "import react from '@vitejs/plugin-react'"; $pluginUsage = "plugins: [react()]"; $frameworkLink = "https://react.dev/"; $rootId = "root"; $extension = $variantLanguage }
    "svelte" { $pluginImport = "import { svelte } from '@sveltejs/vite-plugin-svelte'"; $pluginUsage = "plugins: [svelte()]"; $frameworkLink = "https://svelte.dev/"; $rootId = "app"; $extension = "svelte" }
    "lit" { $pluginImport = "import lit from 'vite-plugin-lit'"; $pluginUsage = "plugins: [lit()]"; $frameworkLink = "https://lit.dev/"; $rootId = "app"; $extension = $variantLanguage }
    "solid" { $pluginImport = "import solid from 'vite-plugin-solid'"; $pluginUsage = "plugins: [solid()]"; $frameworkLink = "https://www.solidjs.com/"; $rootId = "root"; $extension = $variantLanguage }
    "qwik" { $pluginImport = "import { qwikVite } from '@builder.io/qwik/optimizer'"; $pluginUsage = "plugins: [ qwikVite({ csr: true, }), ]"; $frameworkLink = "https://qwik.builder.io/"; $rootId = "app"; $extension = $variantLanguage }
    "marko" { $pluginImport = "import marko from '@marko/vite'"; $pluginUsage = "plugins: [marko()]"; $frameworkLink = "https://markojs.com/"; $rootId = "app"; $extension = "marko" }
    "preact" { $pluginImport = "import preact from '@preact/preset-vite'"; $pluginUsage = "plugins: [preact()]"; $frameworkLink = "https://preactjs.com/"; $rootId = "app"; $extension = $variantLanguage }
    "vanilla" { $pluginImport = "// No plugin needed for vanilla"; $pluginUsage = "plugins: []"; $frameworkLink = "https://developer.mozilla.org/en-US/docs/Web/JavaScript"; $rootId = "app"; $extension = $variantLanguage }
    "angular" { $frameworkLink = "https://angular.dev/"; $extension = $variantLanguage }
    default { $pluginImport = "// Plugin not defined for selected framework"; $pluginUsage = "plugins: []"; $frameworkLink = ""; $rootId = "app"; $extension = $variantLanguage }
}

# Setup class attribute
if ($variantLanguage -eq "tsx" -or $variantLanguage -eq "jsx") {
    $className = "className"
}
else {
    $className = "class"
}

# Set up directories
$componentsPath = "$clientPath/components"
$pagesPath = "$clientPath/pages"
New-Item -ItemType Directory -Force -Path $componentsPath, $pagesPath | Out-Null

# Content templates
# (navbarContent, footerContent, homeContent, counterContent, fetchDataContent)
# Provided from your environment as-is
$port = "5173"
$mainEmement = ""
$mainSrc = "src/main.$variantLanguage"
if ($framework -eq "lit") {
    $mainEmement = "<main-element></main-element>"

}
elseif ($framework -eq "angular") {
    $mainEmement = "<app-root></app-root>"
    $port = "4200"
    $mainSrc = "main.js"
}
else {
    $mainEmement = @"
    <div id="$rootId"></div>
"@
}
# Create Views and Controllers folders

Add-Content -Path ".\Views\Shared\_Layout.cshtml" -Value @"
@using $projectName.Helpers
@inject ViteManifest viteManifest

@{
    var (jsChunks, cssChunks) = viteManifest.GetAllAssets();
}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] | $projectName</title>
    <link rel="stylesheet" href="/lib/dist/bootstrap.min.css" />
    @if (Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Production")
    {
      @foreach (var css in cssChunks)
		{
			<link rel="stylesheet" href="@css" />
		}
    }
    else
    {
		$reactRefresh
        <script type="module" src="http://localhost:$port/@@vite/client"></script>
    }
</head>
<body>
    $mainEmement
    @RenderBody()
    @if (Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Production")
    {
       @foreach (var js in jsChunks)
		{
			<script type="module" src="@js" fetchpriority="low"></script>
		}
    }
    else
    {
        <script type="module" src="http://localhost:$port/$mainSrc"></script>
    }
    @await RenderSectionAsync("Scripts", required: false)
</body>
</html>
"@


# Update .csproj to copy Vite build output to wwwroot
# Define the XML block to insert
$vitePublishTarget = @"
  <Target Name="PublishRunWebpack" AfterTargets="ComputeFilesToPublish">
    <ItemGroup>
      <DistFiles Include="ClientApp\build\**" />
      <ResolvedFileToPublish Include="@(DistFiles->'%(FullPath)')" Exclude="@(ResolvedFileToPublish)">
        <RelativePath>wwwroot\%(RecursiveDir)%(FileName)%(Extension)</RelativePath>
        <CopyToPublishDirectory>PreserveNewest</CopyToPublishDirectory>
        <ExcludeFromSingleFile>true</ExcludeFromSingleFile>
      </ResolvedFileToPublish>
    </ItemGroup>
  </Target>
"@
$angularPublicFiles = @"
<Target Name="CopyAngularPublic" BeforeTargets="Build">
  <Copy SourceFiles="@(AngularPublicFiles)" DestinationFolder="wwwroot" SkipUnchangedFiles="true" />
</Target>

<ItemGroup>
  <AngularPublicFiles Include="ClientApp/public/**/*.*" />
</ItemGroup>
"@
# Insert just before </Project>
$csprojPath = "$projectName.csproj"
$csprojContent = Get-Content $csprojPath
if ($framework -eq "angular") {
    $vitePublishTarget += $angularPublicFiles
}
$modifiedContent = @()
foreach ($line in $csprojContent) {
    if ($line -match "</Project>") {
        $modifiedContent += $vitePublishTarget
    }
    $modifiedContent += $line
}

Set-Content -Path $csprojPath -Value $modifiedContent
Write-Host "Mvc project '$projectName' created successfully with Vite setup." -ForegroundColor Green
# Run Vite scaffolding
Write-Host "`nRunning: npm create vite@latest clientapp --template $template" -ForegroundColor Green

if ($framework -eq "angular") {
    # Check if ng is installed
    try {
        # This command will throw an error if 'ng' is not found
    $ngcheck = Get-Command ng -ErrorAction Stop
    if($null -ne $ngcheck)
    {
        Write-Host "Starting.." -ForegroundColor Green
    }
    }
    catch {
        Write-Host "Angular CLI not found. Installing..."
        
        # Set the execution policy to allow scripts to run
        # This is often required for npm global packages on Windows
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        
        # Install the Angular CLI globally
        npm install -g @angular/cli
        
        # Check if the installation was successful
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Angular CLI installed successfully. You may need to restart PowerShell or open a new terminal window for the 'ng' command to be recognized."
            Start-Process -FilePath "powershell" -ArgumentList "ng version"
            Write-Host "Angular CLI installed open new terminal and start process once again" -ForegroundColor Green
        }
        else {
            Write-Host "Failed to install Angular CLI. Please check your npm and network configuration."
        }
    }

    # Ask about Zone.js
    Write-Host "Do you want to include Zone.js? (y/n):" -ForegroundColor Cyan
    $useZoneJs = Read-Host 
    if ($useZoneJs -eq "y") {
        # If 'y', we'll let it be. Angular's default includes it.
        # We might even want to ensure it's there if a user previously removed it
        # but for a new app, default is fine.
        $polyfillsOption = "" # No special action needed for 'y' as default includes it
        Write-Host "Zone.js will be included."
    }
    else {
        # If 'n', we'll mark it for removal from polyfills later
        $polyfillsOption = "--zoneless"
        Write-Host "Zone.js will be excluded (requires careful consideration for browser compatibility)."
    }

    # Ask about CSS Preprocessor
    Write-Host "Which CSS preprocessor do you want to use? (css/scss/less):" -ForegroundColor Cyan
    $cssPreprocessor = Read-Host 
    if ($cssPreprocessor -eq "scss") {
        $styleOption = "--style=scss"
        Write-Host "SCSS selected." -ForegroundColor Gray
    }
    elseif ($cssPreprocessor -eq "less") {
        $styleOption = "--style=less"
        Write-Host "CSS selected." -ForegroundColor Blue
    }
    else {
        $styleOption = "--style=css" # Default to CSS
        Write-Host "CSS selected." -ForegroundColor Green
    }

    # Ask about SSR/SSG
    Write-Host "Do you want to enable SSR/SSG? (y/n):" -ForegroundColor Cyan
    $enableSsr = Read-Host 
    if ($enableSsr -eq "y") {
        $ssrOption = "--ssr"
        Write-Host "SSR/SSG will be enabled." -ForegroundColor Green
    }
    else {
        $ssrOption = "" # No SSR/SSG
        Write-Host "SSR/SSG will NOT be enabled." -ForegroundColor Yellow
    }

    # Construct the ng new command
    $ngNewCommand = "ng n clientapp $styleOption $ssrOption $polyfillsOption"
    Write-Host "Executing: $ngNewCommand"
    Invoke-Expression $ngNewCommand

    
}
elseif($framework -eq "marko"){
    # Marko does not have a specific template, so we use the default
    New-Item -ItemType Directory -Force -Path "ClientApp"

    Set-Content -Path ".\ClientApp\package.json" -Value @"
{
  "name": "clientapp",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
  },
  "devDependencies": {
  }
}
"@

 npm i marko@next page
 npm i -D vite @marko/vite bootstrap
 if($variantLanguage -eq "ts"){
Set-Content -Path ".\ClientApp\tsconfig.json" -Value @"
{
  "include": ["src/**/*"],
  "compilerOptions": {
    "allowSyntheticDefaultImports": true,
    "lib": ["dom", "ESNext"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "noEmit": true,
    "noImplicitOverride": true,
    "noUnusedLocals": true,
    "outDir": "dist",
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "strict": true,
    "target": "ESNext",
    "verbatimModuleSyntax": true,
    "types": ["vite/client"]
  }
}
"@
$typeAny = ":any"
$typeHTMLElement = ":HTMLElement"
$typeVoid = ":void"
$typeRecord ="?: Record<string, any>"
}
Set-Content -Path ".\clientapp\src\router.$variantLanguage" @"
import page from "page";
import Home from "./pages/Home.marko";
import Counter from "./pages/Counter.marko";
import WeatherForecast from "./pages/WeatherForecast.marko";
import Layout from "./pages/index.marko";

let layoutInstance$typeHTMLElement;
let routeContainer$typeHTMLElement;
let currentView$typeHTMLElement;

export function initRouter(mountPoint) {
layoutInstance = Layout.mount({}, mountPoint);
routeContainer = mountPoint.querySelector("#router-view");

page("/", () => loadView(Home, { name: "Client" }));
page("/counter", () => loadView(Counter));
page("/fetch-data", () => loadView(WeatherForecast, {}));
page();
}

function loadView(ViewComponent$typeAny, props$typeRecord)$typeVoid {
if (currentView) {
    currentView.destroy && currentView.destroy();
    routeContainer.innerHTML = "";
}

currentView = ViewComponent.mount(props, routeContainer);
}
"@
}

else {
    # Original Vite logic remains
    npx create-vite@latest clientapp --template $template
}

if ($framework -eq "lit") {
    Get-AddToFileContent -FilePath "./Views/Shared" -FileName "_Layout.cshtml" -AddContent @"
        <link rel="stylesheet" href="http://localhost:5173/src/index.css" />
"@ -FindContent "\@\@vite\/client\`"><\/script>" -Action "above"
}
if($framework -ne "marko"){
Rename-Item clientapp app
Rename-Item app ClientApp
}
Set-Location ClientApp
Start-Process -WorkingDirectory ".\" -NoNewWindow -FilePath "powershell" -ArgumentList "npm i"
Set-Location ..

$clientPath = "ClientApp"
$componentsPath = "$clientPath/src/components"
$pagesPath = "$clientPath/src/pages"
$tagsPath = "$clientPath/src/tags"
if($framework -eq "marko"){
   New-Item -ItemType Directory -Force "$clientPath/public",  $pagesPath, "$clientPath/src/tags"
}
# Create folders
if ($framework -ne "angular" -and $framework -ne "marko") {
    New-Item -ItemType Directory -Force -Path $componentsPath, $pagesPath
}

# Move assets to public
if (Test-Path "$clientPath/src/assets") {
    Move-Item "$clientPath/src/assets" "$clientPath/public" -Force
}

if ($framework -eq "angular") {
    # creating angular svg
    Set-Content -Path "$clientPath/public/angular.svg" -Value @"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" fill="none" viewBox="0 0 223 236" width="32" class="angular-logo"><g  clip-path="url(#a)"><path  fill="url(#b)" d="m222.077 39.192-8.019 125.923L137.387 0l84.69 39.192Zm-53.105 162.825-57.933 33.056-57.934-33.056 11.783-28.556h92.301l11.783 28.556ZM111.039 62.675l30.357 73.803H80.681l30.358-73.803ZM7.937 165.115 0 39.192 84.69 0 7.937 165.115Z"></path><path  fill="url(#c)" d="m222.077 39.192-8.019 125.923L137.387 0l84.69 39.192Zm-53.105 162.825-57.933 33.056-57.934-33.056 11.783-28.556h92.301l11.783 28.556ZM111.039 62.675l30.357 73.803H80.681l30.358-73.803ZM7.937 165.115 0 39.192 84.69 0 7.937 165.115Z"></path></g><defs ><linearGradient  id="b" x1="49.009" x2="225.829" y1="213.75" y2="129.722" gradientUnits="userSpaceOnUse"><stop  stop-color="#E40035"></stop><stop  offset=".24" stop-color="#F60A48"></stop><stop  offset=".352" stop-color="#F20755"></stop><stop  offset=".494" stop-color="#DC087D"></stop><stop  offset=".745" stop-color="#9717E7"></stop><stop  offset="1" stop-color="#6C00F5"></stop></linearGradient><linearGradient  id="c" x1="41.025" x2="156.741" y1="28.344" y2="160.344" gradientUnits="userSpaceOnUse"><stop  stop-color="#FF31D9"></stop><stop  offset="1" stop-color="#FF5BE1" stop-opacity="0"></stop></linearGradient><clipPath  id="a"><path  fill="#fff" d="M0 0h223v236H0z"></path></clipPath></defs></svg>
"@
    Set-Content -Path "$clientPath/public/vite.svg" -Value @"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFEA83"></stop><stop offset="8.333%" stop-color="#FFDD35"></stop><stop offset="100%" stop-color="#FFA800"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
"@
}

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dotnet/brand/refs/heads/main/logo/dotnet-logo.svg" -OutFile "$clientPath/public/dotnet.svg"

if ($variantLanguage -eq "tsx") {
    $extention = "ts"
}
elseif ($variantLanguage -eq "jsx") {
    $extention = "js"
}
else {
    $extention = $variantLanguage
}
# Create vite.config.js
if ($framework -ne "angular" -or $framework -ne "lit"){
    Set-Content -Path "ClientApp\vite.config.$extention" -Value @"
import { defineConfig } from 'vite';
$pluginImport
export default defineConfig({
 $pluginUsage,
 server: {
        port: 5173,
        strictPort: true,
        hmr: {
        host: 'localhost',
        port: 5173
        }
    },
  build: {
    outDir: 'build',
    emptyOutDir: true,
    manifest: true,
    rollupOptions: {
      input: '/index.html',
      output: {
        entryFileNames: 'assets/[name].[hash].js',
        chunkFileNames: 'assets/[name].[hash].js',
        assetFileNames: 'assets/[name].[hash][extname]'
      }
    }
  },
  base: '/'
});
"@
}
if ($framework -in @("vue", "react", "preact", "svelte", "qwik", "lit", "vanilla")) {
    switch ($variantLanguage) {
        "tsx" { $variant = "ts" }
        "jsx" { $variant = "js" }
        default { $variant = $variantLanguage }
    }
    Set-Content -Path "$clientPath/src/router.config.$variant" -Value @"
// routes.config.js
export const routes = [
  {
    path: '/',
    name: 'Home',
    componentPath: './pages/Home',
    meta: {
      title: 'Home Page',
      requiresAuth: false
    }
  },
  {
    path: '/counter',
    name: 'Counter',
    componentPath: './pages/Counter',
    meta: {
      title: 'Counter Page',
      requiresAuth: false
    }
  },
  {
    path: '/fetch-data',
    name: 'WeatherForecast',
    componentPath: './pages/WeatherForecast',
    meta: {
      title: 'Weather Forecast',
      requiresAuth: true
    }
  }
];
export default routes;
"@
}
elseif ($framework -eq "solid") {
    Set-Content -Path "$clientPath/src/router.config.$variantLanguage" -Value @"
// routes.config.$variantLanguage
import { lazy } from "solid-js";

export const routes = [
  {
    path: '/',
    name: 'Home',
    component: lazy(() => import('./pages/Home')),
    meta: {
      title: 'Home Page',
      requiresAuth: false
    }
  },
  {
    path: '/counter',
    name: 'Counter',
    component: lazy(() => import('./pages/Counter')),
    meta: {
      title: 'Counter Page',
      requiresAuth: false
    }
  },
  {
    path: '/fetch-data',
    name: 'WeatherForecast',
    component: lazy(() => import('./pages/WeatherForecast')),
    meta: {
      title: 'Weather Forecast',
      requiresAuth: true
    }
  }
];
export default routes;
"@
}

$_frameworkBasedSvg = $null
if ($framework -eq "svelte" -or $framework -eq "solid") {
    $_frameworkBasedSvg = "import $($framework)Logo from '/assets/$framework.svg';"
}
elseif ($framework -eq "vanilla") {
    if ($variantLanguage -eq "ts") {
        $_frameworkBasedSvg = "import typescriptLogo from '/typescript.svg';"
    }
    elseif ($variantLanguage -eq "js") {
        $_frameworkBasedSvg = "import javascriptLogo from '/javascript.svg';"
    }
}
else {
    $_frameworkBasedSvg = "import $($framework)Logo from '/$framework.svg';"
}

$svgImports = @"
import viteLogo from '/vite.svg';
$_frameworkBasedSvg
import dotnetLogo from '/dotnet.svg';
"@

$mainStyle = @" 
.logo {
  height: 6em;
  padding: 1.5em;
}
.logo:hover {
  filter: drop-shadow(0 0 2em #646cffaa);
}
"@

if ($variantLanguage -in @("tsx", "jsx") -and $framework -notin @("preact", "lit", "vanilla", "solid", "qwik")) {
    $className = "className"
}
else {
    $className = "class"
}

$navbarContent = @"
<header $className="bg-white w-100" >
        <nav $className="navbar navbar-expand-sm navbar-light bg-light border-bottom shadow-sm mb-3">
            <div $className="container">
            <a  $className="navbar-brand text-uppercase" href="/">$projectName</a>
            <button
                $className="navbar-toggler"
                type="button"
                data-bs-toggle="collapse"
                data-bs-target="#navbarNav"
                aria-controls="navbarNav"
                aria-expanded="false"
                aria-label="Toggle navigation"
            >
                <span $className="navbar-toggler-icon"></span>
            </button>
            <div $className="collapse navbar-collapse" id="navbarNav">
                <ul $className="navbar-nav ms-auto">
                <li $className="nav-item">
                <a  $className="nav-link text-dark" href="/">Home</a>
                </li>
                <li $className="nav-item">
                    <a  $className="nav-link text-dark" href="/counter">Counter</a>
                </li>
                <li $className="nav-item">
                    <a  $className="nav-link text-dark" href="/fetch-data">Weather Forecast</a>
                </li>
                </ul>
            </div>
            </div>
        </nav>
</header>
"@
$CaptlizeTitle = $projectName.ToUpper()
$footerContent = 
@" 
<footer $className="w-full bg-light text-center text-lg-start mt-5 py-4">
    <div $className="container d-flex justify-content-between align-items-center px-3">
        <p $className="mb-0 text-start">$CaptlizeTitle &copy; $(Get-Date -Format yyyy)</p>
        <p $className="mb-0 text-center">Built with <a href="https://dotnet.microsoft.com" target="_blank">.NET</a> and
            <a href="https://vitejs.dev" target="_blank">Vite.js</a></p>
        <p $className="mb-0 text-end">
           <a $className="link-text" href="https://github.com/fussionlab/dotnetvite" target="_blank">
                <span>
                    <svg height="24" aria-hidden="true" viewBox="0 0 24 24" width="24" data-view-component="true" $className="octicon octicon-mark-github v-align-middle">
                            <path
                                d="M12 1C5.923 1 1 5.923 1 12c0 4.867 3.149 8.979 7.521 10.436.55.096.756-.233.756-.522 0-.262-.013-1.128-.013-2.049-2.764.509-3.479-.674-3.699-1.292-.124-.317-.66-1.293-1.127-1.554-.385-.207-.936-.715-.014-.729.866-.014 1.485.797 1.691 1.128.99 1.663 2.571 1.196 3.204.907.096-.715.385-1.196.701-1.471-2.448-.275-5.005-1.224-5.005-5.432 0-1.196.426-2.186 1.128-2.956-.111-.275-.496-1.402.11-2.915 0 0 .921-.288 3.024 1.128a10.193 10.193 0 0 1 2.75-.371c.936 0 1.871.123 2.75.371 2.104-1.43 3.025-1.128 3.025-1.128.605 1.513.221 2.64.111 2.915.701.77 1.127 1.747 1.127 2.956 0 4.222-2.571 5.157-5.019 5.432.399.344.743 1.004.743 2.035 0 1.471-.014 2.654-.014 3.025 0 .289.206.632.756.522C19.851 20.979 23 16.854 23 12c0-6.077-4.922-11-11-11Z">
                            </path>
                        </svg>
                </span>
                <span>Dotnetvite</span>
            </a>
        </p>
    </div>
</footer>
"@

function Get-HomeContent {
    param (
        [string]$MainFramework,       # main framework
        [string]$Mode = "html",   # or "import"
        [string]$Links,
        [string]$Class
    )

    $title = (Get-Culture).TextInfo.ToTitleCase($MainFramework)

    # Pick the logo based on framework/language
    if ($framework -eq "vanilla" -and $variantLanguage -eq "js") {
        $_image = "javascriptLogo"
    }
    elseif ($framework -eq "vanilla" -and $variantLanguage -eq "ts") {
        $_image = "typescriptLogo"
    }
    else {
        $_image = "$($Framework)Logo"
    }

    if ($framework -eq "angular" -and $Mode -eq "import") {
        $content = @"
    <div $Class='d-flex justify-content-center gap-4 py-4'>
        <a href="https://dotnet.microsoft.com" target="_blank">
        <img [src]="dotnetLogo" $Class="logo" alt=".NET logo" />
        </a>
        <a href="https://vitejs.dev" target="_blank">
        <img [src]="viteLogo" $Class="logo" alt="Vite logo" />
        </a>
        <a href="$Links" target="_blank">
        <img [src]="angularLogo" $Class="logo" alt="$title logo" />
        </a>
    </div>
"@
    }
    elseif (($framework -eq "lit" -or $framework -eq "vanilla" -or $framework -eq "marko") -and $Mode -eq "import") {
        $content = @"
    <div class="d-flex justify-content-center gap-4 py-4">
        <a href="https://dotnet.microsoft.com" target="_blank">
            <img src=``$`{dotnetLogo}`` class="logo" alt=".NET logo" />
        </a>
        <a href="https://vitejs.dev" target="_blank">
            <img src=``$`{viteLogo}`` class="logo" alt="Vite logo" />
        </a>
        <a href="$Links" target="_blank">
            <img src=``$`{$_image}`` class="logo" alt="$framework logo" />
        </a>
    </div>
"@
    }
    elseif ($Mode -eq "import") {
        $content = @"
    <div $Class='d-flex justify-content-center gap-4 py-4'>
      <a href="https://dotnet.microsoft.com" target="_blank">
        <img src={dotnetLogo} $Class="logo" alt=".NET logo" />
      </a>
      <a href="https://vitejs.dev" target="_blank">
        <img src={viteLogo} $Class="logo" alt="Vite logo" />
      </a>
      <a href="$Links" target="_blank">
        <img src={$($_image)} $Class="logo" alt="$title logo" />
      </a>
    </div>
"@
    }
    else {
        $content = @"
    <div $Class='d-flex justify-content-center gap-4 py-4'>
        <a href="https://dotnet.microsoft.com" target="_blank">
            <img src="/dotnet.svg" $Class="logo" alt=".NET logo" />
        </a>
        <a href="https://vitejs.dev" target="_blank">
            <img src="/vite.svg" $Class="logo" alt="Vite logo" />
        </a>
        <a href="$Links" target="_blank">
            <img src="/$($framework).svg" $Class="logo" alt="$title logo" />
        </a>
    </div>
"@
    }

return @"
<section $Class='container px-4 py-5 text-center'>
    $content
    <h1 $Class='display-1 fw-bold text-secondary'>Dotnet + Vite + $title</h1>
    <p $Class='lead'>This is a simple ASP.NET MVC application with Vite.js setup.</p>
</section>
"@
}

function Get-FetchContent {
    param(
        [bool]$Content = $false
    )
    $LitContent = ""
    if ($Content -eq $true) {
        if ($framework -eq "lit") {
            $LitContent = @"
            <tbody>
                `$`{this.weatherData.map(item => html``
                    <tr>
                        <td>`$`{new Date(item.date).toLocaleDateString()}</td>
                        <td>`$`{item.temperatureC} &deg;C</td>
                        <td>`$`{item.temperatureF} &deg;F</td>
                        <td>`$`{item.summary}</td>
                    </tr>
                ``)}
            </tbody>
"@
        }
        elseif ($framework -eq "svelte") {
            $LitContent = @"
            <tbody>
                {#each weatherData as forecast}
                    <tr>
                        <td>{new Date(forecast.date).toLocaleDateString()}</td>
                        <td>{forecast.temperatureC} &deg;C</td>
                        <td>{forecast.temperatureF} &deg;F</td>
                        <td>{forecast.summary}</td>
                    </tr>
                {/each}
            </tbody>
"@
        }
        elseif ($framework -eq "marko") {
$LitContent = @"
            <tbody>
                <for |item| of=weatherData>
                    <tr>
                        <td>`$`{new Date(item.date).toLocaleDateString()}</td>
                        <td>`$`{item.temperatureC} &deg;C</td>
                        <td>`$`{item.temperatureF} &deg;F</td>
                        <td>`$`{item.summary}</td>
                    </tr>
                </for>
            </tbody>
"@
        }
        elseif ($framework -eq "angular") {
$LitContent = @"
<tbody>
    @for (forecast of weatherData(); track forecast.date) {
        <tr class="forecast-item">
            <td>{{ formatDate(forecast.date) }}</td>
            <td>{{ forecast.temperatureC }} &deg;C</td>
            <td>{{ forecast.temperatureF }} &deg;F</td>
            <td>{{ forecast.summary }}</td>
        </tr>
    }
</tbody>
"@
        }
        elseif ($framework -eq "solid" -or $framework -eq "react" -or $framework -eq "preact" -or $framework -eq "qwik") {
            $_functionNameImplement = ""
            if ($framework -eq "solid") {
                $_functionNameImplement = "weatherData()"
            }
            elseif($framework -eq "qwik") {
                $_functionNameImplement = "weatherData.value"
            }
            else {
                $_functionNameImplement = "weatherData"
            }
            $LitContent = @"
            <tbody>
                {$_functionNameImplement.map((item, key) => (
                    <tr key={key}>
                        <td>{new Date(item.date).toLocaleDateString()}</td>
                        <td>{item.temperatureC} &deg;C</td>
                        <td>{item.temperatureF} &deg;F</td>
                        <td>{item.summary}</td>
                    </tr>
                ))}
            </tbody>
"@
        }
    }
    else {
        $LitContent = @"
<tbody id="weatherData">
</tbody>

"@            
    }

@"
<section $className="container px-4 py-5">
    <h1 $className="display-2 text-secondary text-center">Fetch Weather Forecast Data</h1>
    <p $className="lead text-center">This section fetches data from the ASP.NET WeatherForeCastController API. To view the API <a $className="linklink-underline-info" target="_blank" href="/api/weatherforecast">Click Here</a></p>
    <table $className="mt-2 table table-striped table-bordered">
        <thead>
            <tr>
                <th>Date</th>
                <th>Temperature (C)</th>
                <th>Temperature (F)</th>
                <th>Summary</th>
            </tr>
        </thead>
        $LitContent
    </table>    
</section>
"@

}


$fetchDataFunction = ""
if ($framework -eq "react" -or $framework -eq "solid" -or $framework -eq "preact" -or $framework -eq "angular" -or $framework -eq "lit" -or $framework -eq "svelte" -or $framework -eq "qwik") {
    $_constPointer = "const"
    $_constState = $null
    $_setState = $null
    if ($framework -eq "solid") {
        
        $_constState = "const [weatherData, setWeatherData] = createSignal<IWeatherData[]>([]);"
        $_setState = "setWeatherData(data)"
    }
    elseif ($framework -eq "react" -or $framework -eq "preact") {
        
        $_constState = "useState<IWeatherData[]>([])"
        $_setState = "setWeatherData(data)"
    }
    elseif ($framework -eq "angular") {
        $_constState = "public weatherData = signal<IWeatherData[]>([]);"
        $_constPointer = "public"
        $_setState = "this.weatherData.set(data);"
    }
    elseif ($framework -eq "qwik") {
        $_constPointer = "const"
        $_constState = "let weatherData = useSignal<IWeatherData[]>([]);"
        $_setState = "weatherData.value = data"
    }
    elseif ($framework -eq "lit") {
        $_constPointer = "private"
        $_setState = "this.weatherData = data;"
         $_constState=$null
    }
    else {
        $_setState = "weatherData = data;"
        $_constState="let weatherData: IWeatherData[] = [];"
    }
    $fetchDataFunction = @"

$_constState

$_constPointer fetchData = async () => {
    try {
        const response = await fetch('/api/weatherforecast');
        if (!response.ok) throw new Error('Network response was not ok');
        const data: IWeatherData[] = await response.json();
        $_setState;
    } catch (error) {
        console.error('Fetch error:', error);
    }
};
"@
}
elseif($framework -eq "marko") {

if($variantLanguage -eq "ts") {
    $typeTs = ": IWeatherData[]"
    $markInterface = @"
export $_IWeatherInterface
"@
}
$fetchDataFunction = 
@"
$markInterface

<let/weatherData$typeTs = []>   
<const/fetchData = async () => {
   const response = await fetch("/api/weatherforecast");
   const data$typeTs = await response.json();
    weatherData = data; // This triggers reactivity
}>
"@
}
else {
    $fetchDataFunction = @"
const fetchData = async () => {
    try {
        const response = await fetch('/api/weatherforecast');
        if (!response.ok) throw new Error('Network response was not ok');
        const data = await response.json();

        const tableBody = document.querySelector('#weatherData');
        tableBody.innerHTML = '';

        data.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = ``
            <td>`$`{new Date(item.date).toLocaleDateString()}</td>
            <td>`$`{item.temperatureC} &deg;C</td>
            <td>`$`{item.temperatureF} &deg;F</td>
            <td>`$`{item.summary}</td>
        ``;
        tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Fetch error:', error);
    }
};
"@
}
$counterAction = @{
    React   = @{
        ClickAttribute = "onClick"
        IncrementLogic = ""
        CountValue     = "{count}"
    }
    Vue     = @{
        ClickAttribute = "@click"
        IncrementLogic = "count++"
        CountValue     = "{{ count }}"
    }
    Svelte  = @{
        ClickAttribute = "onclick"
        CountValue     = "{count}"
    }
    
    Qwik    = @{
        ClickAttribute = "onClick$"
        CountValue     = "{count.value}"
    }
    Angular = @{
        ClickAttribute = "(click)"
        CountValue     = "{{ count }}"
    }
    Solid   = @{
        ClickAttribute = "onClick"
        IncrementLogic = ""
        CountValue     = "{count()}"
    }
    Preact  = @{
        ClickAttribute = "onClick"
        IncrementLogic = ""
        CountValue     = "{count}"
    }
    Lit     = @{
        ClickAttribute = "@click"
        CountValue     = "`$`{this.count}"
    }
    Marko   = @{
        ClickAttribute = "onClick()"
        CountValue     = "`$`{count}"
    }
    Vanilla = @{
        ClickAttribute = "onclick"
        CountValue     = "`$`{count}"
    }
    Others  = @{
        ClickAttribute = "onclick"
        CountValue     = "{count}"
    }
}
$counterButton = @()
$_globalButton = @"
<p id="counterValue"  $className="display-3 text-center">$($counterAction[$framework].CountValue)</p>
  <div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $($counterAction[$framework].ClickAttribute)={increment}>Increment</button>
    <button $className="btn btn-warning" $($counterAction[$framework].ClickAttribute)={decrement}>Decrement</button>
    <button $className="btn btn-danger" $($counterAction[$framework].ClickAttribute)={reset}>Reset</button>
  </div>
"@
if ($framework -eq "react" -or $framework -eq "preact" -or $framework -eq "solid" ) {
    $counterButton = $_globalButton
}
elseif ($framework -eq "vue") {
    $counterButton = $_globalButton
}
elseif ($framework -eq "svelte") {
    $counterButton = $_globalButton
}
elseif ($framework -eq "qwik") {
    $counterButton = $_globalButton
}
elseif ($framework -eq "lit") {
    $counterButton = @"
  <p id="counterValue"  $className="display-3 text-center">$($counterAction[$framework].CountValue)</p>
  <div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $($counterAction[$framework].ClickAttribute)=`$`{this.increment}>Increment</button>
    <button $className="btn btn-warning" $($counterAction[$framework].ClickAttribute)=`$`{this.decrement}>Decrement</button>
    <button $className="btn btn-danger" $($counterAction[$framework].ClickAttribute)=`$`{this.reset}>Reset</button>
  </div>
"@
}
elseif ($framework -eq "vanilla") {
    $counterButton = @"
  <p id="counterValue"  $className="display-3 text-center">$($counterAction[$framework].CountValue)</p>
   <div $className="d-flex justify-content-center gap-3">
        <button id="incrementBtn" class="btn btn-success">Increment</button>
        <button id="decrementBtn" class="btn btn-warning">Decrement</button>
        <button id="resetBtn" class="btn btn-danger">Reset</button>
    </div>
"@
}
elseif ($framework -eq "vanilla") {
    $counterButton = $_globalButton
}elseif ($framework -eq "marko") {
   $counterButton = @"
<p id="counterValue"  $className="display-3 text-center">$($counterAction[$framework].CountValue)</p>
<div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $($counterAction[$framework].ClickAttribute){increment()}>Increment</button>
    <button $className="btn btn-warning" $($counterAction[$framework].ClickAttribute){decrement()}>Decrement</button>
    <button $className="btn btn-danger" $($counterAction[$framework].ClickAttribute){reset()}>Reset</button>
</div>
"@
}
elseif ($framework -eq "angular" ) {
    $counterButton = @"
   <p id="counterValue"  $className="display-3 text-center">$($counterAction[$framework].CountValue)</p>
   <div $className="d-flex justify-content-center gap-3">
       <button $className="btn btn-success" $($counterAction[$framework].ClickAttribute)="increment()">Increment</button>
        <button $className="btn btn-warning" $($counterAction[$framework].ClickAttribute)="decrement()">Decrement</button>
        <button $className="btn btn-danger" $($counterAction[$framework].ClickAttribute)="reset()">Reset</button>
    </div>
"@
}

$counterContent = 
@"
<section $className="container px-4 py-5">
    <h1 $className="display-2 text-secondary text-center py-4">Counter</h1>
     <p $className="text-center lead">This is a simple counter component.</p>
          $counterButton
 </section>
"@

function  Get-ReactComponent([string]$htmlContent, [string]$componentName, [string]$scripts, [string]$imports) {
    return @"
$imports

const $componentName = () => {
    $scripts
    return (
        <>
            $htmlContent
        </>
    );
};
export default $componentName;
"@
}
function Get-VueTemplate([string]$htmlContent, [string]$scripts, [string]$imports) {
    return @"
<template>
    $htmlContent
</template>
<script setup lang='$variantLanguage'>
$imports
$scripts
</script>
<style scoped>
/* Add your styles here */
</style>

"@
}
function Get-SvelteTemplate([string]$htmlContent, [string]$scripts, [string]$imports, [string]$styles, [string]$Interface) {
    return @"
<script lang='$variantLanguage'>
$imports
$Interface
$scripts
</script>

$htmlContent

<style>
$styles
</style>
"@
}

function Convert-Cases {
    param(
        [string]$Component,
        [ValidateSet("PascalCase", "PipeCase", "SplitCapitalize", "HefinCase")]
        [string]$Format = "PascalCase"
    )

    # Step 1: Clean input - keep only alphanumerics
    $cleaned = $Component -replace '[^A-Za-z0-9]', ''

    # Step 2: Split by capital letters except first
    $words = @()
    $wordStart = 0
    for ($i = 1; $i -lt $cleaned.Length; $i++) {
        if ($cleaned[$i] -cmatch '[A-Z]') {
            $words += $cleaned.Substring($wordStart, $i - $wordStart)
            $wordStart = $i
        }
    }
    $words += $cleaned.Substring($wordStart) # Add the last segment

    # Normalize words: first letter uppercase, rest lowercase
    $words = $words | ForEach-Object {
        if ($_.Length -gt 1) {
            $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
        }
        else {
            $_.ToUpper()
        }
    }

    switch ($Format) {
        "PascalCase" {
            $result = ($words -join '')
        }

        "PipeCase" {
            $result = ($words -join '|')
        }

        "SplitCapitalize" {
            $result = ($words -join ' ')
        }

        "HefinCase" {
            $result = ($words | ForEach-Object { $_.ToLower() }) -join '-'
        }
    }

    return $result
}

function Get-LitTemplate([string]$htmlContent, [string]$scripts, [string]$Imports, [string]$componentName, [string]$styles, [string]$Interface, [string]$IsAnyFunction) {
    $ElementName = Convert-Cases -Component $componentName -Format "PascalCase"
    $forTitle = ""
    if ($componentName -eq "WeatherForecast" -or $componentName -eq "Counter" -or $componentName -eq "Home") {
        $forTitle = @"
    connectedCallback(){
        super.connectedCallback();
        document.title =  'Counter';
    }
"@
    }
    return @"
import { LitElement, html, css } from 'lit';
import {customElement} from 'lit/decorators.js';
$Imports
$Interface
@customElement('$($componentName.ToLower())-element')
export class $ElementName extends LitElement {
   createRenderRoot() {
        // Render into light DOM (no Shadow DOM)
        return this;
    }
    $forTitle
    static styles = css ``
        /* Add your styles here */
    ``;
   $scripts
    render() {
        return html ``
            $htmlContent
        ``;
    }
}

declare global {
  interface HTMLElementTagNameMap {
    '$($componentName.ToLower())-element': $ElementName;
  }
}
"@
}
function Get-QwikTemplate([string]$htmlContent, [string]$scripts, [string]$imports, [string]$componentName, [string]$styles) {
    return @"
$imports
import {component$} from '@builder.io/qwik';
export default component`$`(() => {
    $scripts
    return (
        <>
            $htmlContent
        </>
    );
});
"@
}

function Get-MarkoTemplate {
    param (
        [string]$htmlContent,
        [string]$scripts,
        [string]$imports,
        [string]$styles
    )
if($null -ne $imports){
    $_import = $imports
}
if($null -ne $scripts){
    $_script = $scripts;
}
return @"
$_import
$_script
$htmlContent
"@
}
function Get-VanillaTemplate {
    param (
        [string]$htmlContent,
        [string]$scripts,
        [string]$imports,
        [string]$addtionalScripts,
        [string]$componentName
    )
    $_extra = $null
    if ($imports) {
        $imports
    }
    if ($addtionalScripts) {
        $_extra = $addtionalScripts
    }
    $_setup = $null
    if ($componentName -eq "WeatherForecast" -or $componentName -eq "Counter") {
        $_setup = ", setup"
    }
    return @"
const $componentName = () => {
    $_extra
    const section = document.createElement('div');
    section.className = 'w-100 m-auto';
    section.innerHTML = ``
            $htmlContent
    ``;
    $scripts
    return {html:section $_setup};
};
export default $componentName;
"@
}


$weatherInterface = "export $_IWeatherInterface"
# Template wrapper for Vue
function Get-WrappedTemplate([string]$htmlContent, [string]$templateName ) {
    $extraImports = ""
    $extraScript = ""
    switch ($framework) {
        "react" {

            if ($templateName -eq "WeatherForecast") {
                $extraImports = @"
import { useEffect, useState } from 'react';
$_IWeatherInterface
"@
                $extraScript = @"
$fetchDataFunction

useEffect(() => {
    fetchData();
}, []);
"@
            }
            elseif ($templateName -eq "Counter") {
                $extraImports = 
                @"
import { useState } from 'react';
"@
                $extraScript = @"
const [count, setCount] = useState(0);

  const increment = () => {
    setCount(count + 1);
  };

  const decrement = () => {
    setCount(count - 1);
  };

  const reset = () => {
    setCount(0);
  };
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""
            }
            Get-ReactComponent -htmlContent $htmlContent -componentName $templateName -scripts $extraScript -imports $extraImports

        }      
        "preact" {
            if ($templateName -eq "WeatherForecast") {

                $extraImports = @"
import { useEffect, useState } from 'preact/hooks';
$_IWeatherInterface
"@
                $extraScript = @"

$fetchDataFunction

useEffect(() => {
    fetchData();
}, []);

"@
            }
            elseif ($templateName -eq "Counter") {
                $extraImports = 
                @"
import { useState } from 'preact/hooks';
"@
                $extraScript = @"
const [count, setCount] = useState(0);

const increment = () => {
    // To update, you call the setter function with the new value
    setCount(count + 1); // To read, you call the getter function: count()
  };

  const decrement = () => {
    setCount(count - 1);
  };

  const reset = () => {
    setCount(0);
  };
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""

            }
            Get-ReactComponent -htmlContent $htmlContent -componentName $templateName -scripts $extraScript -imports $extraImports
        }
        "solid" {
            if ($templateName -eq "WeatherForecast") {
                $extraImports = @"
import { createSignal, onMount } from 'solid-js';
$_IWeatherInterface
"@
                $extraScript = @"

$fetchDataFunction

onMount(() => {
    fetchData();
});
"@
            }
            elseif ($templateName -eq "Counter") {
                $extraImports = @"
import { createSignal } from 'solid-js';
"@
                $extraScript = @"
const [count, setCount] = createSignal(0);
const increment = () => {
    // To update, you call the setter function with the new value
    setCount(count() + 1); // To read, you call the getter function: count()
  };

  const decrement = () => {
    setCount(count() - 1);
  };

  const reset = () => {
    setCount(0);
  };
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""
            }
            Get-ReactComponent -htmlContent $htmlContent -componentName $templateName -scripts $extraScript -imports $extraImports
  
        }

        "vue" {
            if ($templateName -eq "WeatherForecast") {
                $extraImports = @"
import { onMounted } from 'vue';
"@
                $extraScript = @"
$fetchDataFunction
onMounted(() => {
 fetchData();    
});
"@
            }
            elseif ($templateName -eq "Counter") {
                $extraImports = @"
import { ref, computed } from 'vue';
"@
                $extraScript = @"
const count = ref(0);
const increment = computed(() => {
    count.value++;
    return count.value;
});
const decrement = computed(() => {
    count.value--;
    return count.value;
});
const reset = computed(() => {
    count.value = 0;
    return count.value;
});
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""
            }
            Get-VueTemplate -htmlContent $htmlContent -scripts $extraScript -imports $extraImports -styles ""
 
        }
        "lit" {
            if ($templateName -eq "WeatherForecast") {
                $isFunction = @"
 `$`{this.weatherData.map(item => html``
                        <tr>
                            <td>`$`{new Date(item.date).toLocaleDateString()}</td>
                            <td>`$`{item.temperatureC}</td>
                            <td>`$`{item.temperatureF}</td>
                            <td>`$`{item.summary}</td>
                        </tr>
                    ``)}
"@
                $extraImports = @"
import { state } from 'lit/decorators.js';
"@  

                $extraScript = @"
    @state()
    weatherData: IWeatherData[] = [];
    firstUpdated() {
        this.fetchData();
    }

    $fetchDataFunction
"@
            }
            elseif ($templateName -eq "Counter") {
                $extraImports = @"
        import { property } from 'lit/decorators.js';
"@
                $extraScript = @"
        @property({ type: Number })
        count = 0;

        private increment = () => {
                this.count++;
            };

            private decrement = () => {
                this.count--;
            };

            private reset = () => {
                this.count = 0;
            };
                    
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""
            }
            Get-LitTemplate -htmlContent $htmlContent -scripts $extraScript -imports $extraImports -componentName $templateName -styles "" -IsAnyFunction $isFunction -Interface $WeatherInterface
        }
        "svelte" {
           
            if ($templateName -eq "WeatherForecast") {
                $weatherInterface = $_IWeatherInterface
                $extraImports = @"
import { onMount } from 'svelte';
"@
                $extraScript = @"
let weatherData: IWeatherData[] = [];
$fetchDataFunction
onMount(() => {
    fetchData();
});
"@
            }
            elseif ($templateName -eq "Counter") {
                $weatherInterface = ""
                $extraImports = @"
import { onMount } from 'svelte';
"@

                $extraScript = @"
let count = `$`state(0);
const increment = () => {
    count++;
};
const decrement = () => {
    count--;
};
const reset = () => {
    count = 0;
};
"@
            }
            else {
                $weatherInterface = ""
                $extraImports = ""
                $extraScript = ""

            }
            Get-SvelteTemplate -htmlContent $htmlContent -scripts $extraScript -imports $extraImports -styles "" -Interface $weatherInterface
        }
        "qwik" {
            if ($templateName -eq "WeatherForecast") {
                $extraImports = @"
import { useSignal, useVisibleTask$ } from '@builder.io/qwik';
$_IWeatherInterface
"@
                $extraScript = @"

$fetchDataFunction

useVisibleTask`$`(() => {
    fetchData();
});
"@
            }
            elseif ($templateName -eq "Counter") {
                $extraImports = "import {$, useSignal } from '@builder.io/qwik';"
                $extraScript = @"
const count = useSignal(0);
const increment = `$`(() => {
    count.value++;
});  
const decrement = `$`(() => {
    count.value--;
});
const reset = `$`(() => {
    count.value = 0;
});
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""
            }
            Get-QwikTemplate -htmlContent $htmlContent -scripts $extraScript -imports $extraImports -componentName $templateName -styles ""
        }
        "vanilla" {
            if ($variantLanguage -eq "ts") {
                $_tsHtElType = "<HTMLElement>"
                $_tsBtnType = "<HTMLButtonElement>"
            }
            if ($templateName -eq "WeatherForecast") {
                $extraScript = @"
    const setup = () =>{
    $fetchDataFunction
    fetchData();
    };
"@
            }
            elseif ($templateName -eq "Counter") {
                $extraCode = "let count = 0;"
                $extraScript = @"
  const counterValue = section.querySelector$_tsHtElType ('#counterValue');
  const incrementBtn = section.querySelector$_tsBtnType ('#incrementBtn');
  const decrementBtn = section.querySelector$_tsBtnType ('#decrementBtn');
  const resetBtn = section!.querySelector$_tsBtnType ('#resetBtn');

  if (!counterValue || !incrementBtn || !decrementBtn || !resetBtn) {
    console.error('Counter elements not found');
    return { html: section.outerHTML, setup: () => {} };
  }

  const setup = () => {
    // Additional setup if needed
    const updateDisplay = () => {
      if (counterValue) counterValue.textContent = count.toString();
    };

    incrementBtn?.addEventListener("click", () => {
      count++;
      updateDisplay();
    });

    decrementBtn?.addEventListener("click", () => {
      count--;
      updateDisplay();
    });

    resetBtn?.addEventListener("click", () => {
      count = 0;
      updateDisplay();
    });
    updateDisplay();

  };
"@
            }
            else {
                $extraImports = ""
                $extraScript = ""
                $extraCode = ""

            }
            Get-VanillaTemplate -htmlContent $htmlContent -scripts $extraScript -styles "" -componentName $templateName -imports $extraImports -addtionalScripts $extraCode
        }
        "marko" {
            if ($templateName -eq "WeatherForecast") {
$extraScript = @"
$fetchDataFunction
<lifecycle 
 onMount(){
    fetchData();
 }
>
"@
}
elseif ($templateName -eq "Counter") {
$extraScript = @"
<let/count=0>
<const/increment = () =>{
    count++;
}>
<const/decrement = () => {
    count--;
}>
<const/reset = () => {
    count = 0;
}>
"@
}
else {
    $extraImports = ""
    $extraScript = ""
}
Get-MarkoTemplate -htmlContent $htmlContent -scripts $extraScript
        }
       
        default {
            Write-Error "Unsupported framework: $framework"
            return ""
        }
    }
}


# Define Home content based on the framework
$homeContent = ""

if ($framework -eq "react" -or $framework -eq "preact" -or $framework -eq "solid" -or $framework -eq "qwik" -or $framework -eq "lit" -or $framework -eq "svelte" -or $framework -eq "vanilla" -or $framework -eq "angular" -or $framework -eq "marko") {
    $homeContent = Get-HomeContent -MainFramework $framework -Mode "import" -Links $frameworkLink  -Class $className
} 
else {
    $homeContent = Get-HomeContent -MainFramework $framework -Mode "html" -Links $frameworkLink -Class $className
}

$fetchDataContent = ""
if ($framework -eq "lit" -or $framework -eq "svelte" -or $framework -eq "solid" -or $framework -eq "react" -or $framework -eq "preact" -or $framework -eq "angular" -or $framework -eq "qwik" -or $framework -eq "marko") {
    $fetchDataContent = Get-FetchContent -Content $true
}
else {
    $fetchDataContent = Get-FetchContent
}

#All components and pages with raw HTML content
$componentsTemplates = @(
    @{ name = "Navbar"; content = $navbarContent },
    @{ name = "Footer"; content = $footerContent },
    @{ name = "Home"; content = $homeContent },
    @{ name = "Counter"; content = $counterContent },
    @{ name = "WeatherForecast"; content = $fetchDataContent }
)
if ($framework -eq "angular") {
    Push-Location ./ClientApp
    foreach ($comp in $componentsTemplates.name) {
        $comp = Convert-Cases -Component $comp -Format "PascalCase"
        if ($comp -eq "Navbar" -or $comp -eq "Footer") {
            $comp = ".\components\" + $comp.toLower()
        }
        else {
            $comp = ".\pages\" + $comp.toLower()
        }
        # Create component using Angular CLI
        Write-Host "Creating Angular component: $comp"
        # Use the Angular CLI to generate the component
        # Assumes Angular CLI is installed and available in PATH
        
        ng g c $comp
    }

    npm i bootstrap

    Get-AddToFileContent -FilePath ".\src\app\" -FileName "app.routes.ts" -AddContent @"
import {Home } from './pages/home/home';
import { Counter } from './pages/counter/counter';
import { Weatherforecast } from './pages/weatherforecast/weatherforecast';
export const routes: Routes = [
  {
    path: '',
    component: Home,
    data: { title: 'Home Page', requiresAuth: false },
  },
  {
    path: 'counter',
    component: Counter,
    data: { title: 'Counter Page', requiresAuth: false },
  },
  {
    path: 'fetch-data',
    component: Weatherforecast,
    data: { title: 'Weather Forecast', requiresAuth: true },
  },
];
"@ -FindContent "export const routes\: Routes \= \[\];" -Action "replace"

    Set-Content -Path ".\src\app\app.html" -Value @"
<app-navbar/>
<div class="container">
  <router-outlet></router-outlet>
</div>
<app-footer/>
"@
    Get-AddToFileContent -FilePath ".\src\app\" -FileName "app.ts" -AddContent @"
import { Navbar } from './components/navbar/navbar';
import { Footer } from './components/footer/footer';
"@ -FindContent "import \{ RouterOutlet \} from \'\@angular\/router\'\;" -Action "below"
    Get-AddToFileContent -FilePath ".\src\app\" -FileName "app.ts" -AddContent "imports: [RouterOutlet, Navbar, Footer]," -FindContent "\[RouterOutlet\]" -Action "replace"

    #Add Home Page
    foreach ( $comp in $componentsTemplates) {
        $name = $comp.name
        $content = $comp.content
        if ($name -eq "Navbar" -or $name -eq "Footer") {
            $path = Join-Path ".\src\app\components" $name.ToLower()
        }
        else {
            $path = Join-Path '.\src\app\pages' $name.ToLower()
        }
        Set-Content -Path $path"\$($name.tolower()).html" -Value $content -Encoding UTF8
        if ($name -eq "Home") {
            Get-AddToFileContent -Path $path"\" -FileName "$($name.ToLower()).ts" -AddContent @"
        viteLogo = "vite.svg";
        dotnetLogo = "dotnet.svg";
        angularLogo = "angular.svg";
"@ -FindContent "export class $($name.ToLower()) \{" -Action "below"
        }
        elseif ($name -eq "Counter") {
            Get-AddToFileContent -Path $path"\" -FileName "$($name.ToLower()).ts" -AddContent @"
  public count: number = 0;

  constructor() { }

  public increment() {
    this.count++;
    return this.count;
  }

  public decrement() {
    this.count--;
    return this.count;
  }

  public reset() {
    this.count = 0;
    return this.count;
  }
"@ -FindContent "export class $($name.ToLower()) \{" -Action "below"
        }
        elseif ($name -eq "WeatherForecast") {
            Get-AddToFileContent -Path $path"\" -FileName "$($name.ToLower()).ts" -AddContent @"
$fetchDataFunction
ngOnInit() {
    this.fetchData();
}
formatDate(dateString: string): string {
        const date = new Date(dateString);
        return date.toLocaleDateString();
}
"@ -FindContent "export class $($name.ToLower()) \{" -Action "below"
            Get-AddToFileContent -Path $path"\" -FileName "$($name.ToLower()).ts" -AddContent @"
import { Component, OnInit, signal} from '@angular/core';

$_IWeatherInterface

"@ -FindContent "import \{ Component \}" -Action "replace"
            Get-AddToFileContent -Path $path"\" -FileName "$($name.ToLower()).ts" -AddContent @"
export class Weatherforecast implements OnInit {
"@ -FindContent "export class Weatherforecast \{" -Action "replace"
    
        }

    }
    Get-AddToFileContent -FilePath ".\" -FileName "package.json" -AddContent '    "dev": "ng serve",' -FindContent '\"build\"\:' -Action "above"
    Get-AddToFileContent -FilePath ".\" -FileName "angular.json" -AddContent '              "node_modules/bootstrap/dist/css/bootstrap.min.css",' -FindContent '\"src\/styles\.css\"' -Action "above"
    Get-AddToFileContent -FilePath "..\views\shared\" -FileName "_Layout.cshtml" -AddContent '' -FindContent 'href\=\"\/lib\/dist\/bootstrap\.min\.css\" ' -Action "replace"
    Set-Content -Path ".\src\styles.css" -Value @"
$mainStyle
.logo.angular:hover{
  filter: drop-shadow(0 0 2em #e205a7aa);
}

"@

    Pop-Location
    Get-AddToFileContent -FilePath ".\views\shared\" -FileName "_Layout.cshtml" -AddContent '<link rel="stylesheet" href="http://localhost:4200/styles.css" />' -FindContent 'vite\/client' -Action "above"
}
else{

    if($framework -eq "marko"){

        $componentsPath = $tagsPath
    }   
    # Define paths for components and pages for other frameworks
    foreach ($template in $componentsTemplates) {
        $name = $template.name
        $content = $template.content
        $wrappedContent = Get-WrappedTemplate -htmlContent $content -templateName $name

        if ($name -eq "Navbar" -or $name -eq "Footer") {
            $path = Join-Path $componentsPath "$name.$extension"
        }
        else {
            $path = Join-Path $pagesPath "$name.$extension"
        }

        Set-Content -Path $path -Value $wrappedContent -Encoding UTF8
    }

    # Add import statements for logos in Home component
    if ($framework -eq "react" -or $framework -eq "preact" -or $framework -eq "solid" -or $framework -eq "vanilla" ) {
        Get-AddToFileContent -FilePath $clientPath"/src/pages" -FileName "Home.$variantLanguage" -AddContent $svgImports -FindContent "const Home " -Action "above"
    }
    elseif($framework -eq "qwik" ){
        Get-AddToFileContent -FilePath $clientPath"/src/pages" -FileName "Home.$variantLanguage" -AddContent $svgImports -FindContent "export default component" -Action "above"
    }
    elseif ($framework -eq "marko") {
        Get-AddToFileContent -FilePath $clientPath"/src/pages" -FileName "Home.marko" -AddContent $svgImports -FindContent "\<section class\=\'" -Action "above"
    }
    elseif ($framework -eq "lit") {
        Get-AddToFileContent -FilePath $clientPath"/src/pages" -FileName "Home.$variantLanguage" -AddContent $svgImports -FindContent '\@customElement' -Action "above" 
    }
    elseif ($framework -eq "svelte") {
        Get-AddToFileContent -FilePath $clientPath"/src/pages" -FileName "Home.$extension" -AddContent $svgImports -FindContent "</script>" -Action "above"
        Move-Item -Path "$clientPath\public\assets\*.svg" -Destination $clientPath"\public\"
    }
    

    #remove Helloworld component
    if($framework -ne "marko") {
        Remove-Item -Path "$clientPath/src/components/HelloWorld.$extension" -Force -ErrorAction SilentlyContinue
    }
    # Modify App entry point
    $appPath = ""
    if ($framework -eq "preact" -or $framework -eq "qwik") {
        $appPath = Join-Path $clientPath "src/app.$extension "

    }
    else {
        $appPath = Join-Path $clientPath "src/App.$extension"
    }

    Set-Content -Path $appPath -Value ""
    function Get-RouteConfig (
        [string]$frameworks, [string]$variantLanguages 
    ) {
        $app = $null
        switch ($framework) {
            "react" {   
                $app = @"
import React, { lazy, Suspense } from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router';
import { routes as config } from './router.config';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
const pages = import.meta.glob('./pages/**/*.$variantLanguages');
const App = () => {
    return (
         <Router>
            <Navbar />
             <Routes>
                    {config.map(({ path, componentPath }, index) => {
                        const filePath = ``$`{componentPath}.$variantLanguages``; // Must match glob
                        const Component = lazy(() => pages[filePath]());
                        return (
                            <Route
                                key={index}
                                path={path}
                                element={
                                    <Suspense fallback={<div>Loading...</div>}>
                                        <Component />
                                    </Suspense>
                                }
                            />
                        );
                    })}
            </Routes>
            <Footer />
        </Router>
    );
}
export default App;
"@
                Set-Content -Path $clientPath"/src/index.css" -Value $mainStyle
                Set-Content -Path $clientPath"/src/App.css" -Value ""
                Copy-Item -Path $clientPath"\public\assets\react.svg" -Destination $clientPath"\public\"
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i react-router bootstrap"
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "import 'bootstrap/dist/css/bootstrap.min.css';" -FindContent "import App from " -Action "above"
            }
            "vue" {
                $app = @"
<template>
  <div class="w-100">
    <Navbar />
    <RouterView />
    <MainFooter />
  </div>
</template>
<script setup lang='$variantLanguage'>
import Navbar from './components/Navbar.vue';
import MainFooter from './components/Footer.vue';

</script>
"@
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i vue-router bootstrap"

                Set-Content -Path "$clientPath/src/route.$variantLanguage" -Value @"
import { createRouter, createWebHistory  } from 'vue-router';
import { routes as config } from './router.config';

const pages = import.meta.glob<() => Promise<any>>('./pages/**/*.vue');

const routes = config.map(route => {
  const filePath = ``$`{route.componentPath}.vue``;

  const component = pages[filePath];

  return {
    name: route.name,
    path: route.path,
    component,
    meta: route.meta
  };
});

const router = createRouter({
    history: createWebHistory(),
    routes
});
export default router;
"@
                Set-Content -Path "$clientPath/src/style.css" -Value ""
                Set-Content -Path "$clientPath/src/style.css" -Value $mainStyle
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent @"
import router from './route';
import 'bootstrap/dist/css/bootstrap.min.css';
"@ `
                    -FindContent "import App from " -Action "below"
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "createApp(App).use(router).mount('#app');" -FindContent "createApp\(App\)" -Action "replace"
            }
            "lit" {
                Set-Content -Path "$clientPath/src/main.$variantLanguage" -Value @"
import { LitElement, html } from 'lit';
import { customElement} from 'lit/decorators.js';

// Import the app-element so its tag is defined
import './app-element.$variantLanguage';

@customElement('main-element')
export class MainElement extends LitElement {
 createRenderRoot() {
        // Render into light DOM (no Shadow DOM)
        return this;
 }
  render() {
    return html ``
        <app-element></app-element>
    ``;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'main-element': MainElement;
  }

}
"@
                Set-Content -Path "$clientPath/src/index.css" -Value @"
@import "./node_modules/bootstrap/dist/css/bootstrap.min.css";
$mainStyle
"@
                Remove-Item "$clientPath/src/my-element.$variantLanguage" -Force -ErrorAction SilentlyContinue
                Set-Content $clientPath"/index.html" -Value @"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Dotnet + Vite + Lit + $($variantLanguage.toUpper())</title>
    <link rel="stylesheet" href="./src/index.css" />
    </head>
    <body>
    <main-element>
    </main-element>
    <script type="module" src="/src/main.$variantLanguage"></script>
  </body>
</html>
"@
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i @lit-labs/router bootstrap"
            }
            "marko"
            {

    
    
Set-Content -Path ".\clientapp\src\pages\index.marko" -Value @"
<Navbar />
<main id="router-view"></main>
<App-Footer />
"@
    Set-Content -Path ".\clientapp\src\main.$variantLanguage" @"
import { initRouter } from "./router";

initRouter(document.getElementById("app"));

"@
Get-AddToFileContent -FilePath ".\Views\shared\" -FileName "_Layout.cshtml" -AddContent '<link rel="stylesheet" href="http://localhost:5173/src/styles.css">' -FindContent "\@vite\/client" -Action "above"
Get-AddToFileContent -FilePath ".\Views\shared\" -FileName "_Layout.cshtml" -AddContent '<link rel="stylesheet" href="/bootstrap.min.css">' -FindContent "\@vite\/client" -Action "above"
Move-Item -Path "./wwwroot/lib/bootstrap/dist/css/bootstrap.min.css" -Destination "./wwwroot"
Set-Content -Path ".\clientapp\index.html" -Value @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <title>Dotnet + Vite + Marko</title>
    <link rel="stylesheet" href="./src/styles.css">
    <link rel="stylesheet" href="/bootstrap.min.css">
</head>
<body>
    <div id="app"></div>
    <script type="module" src="/src/main.$variantLanguage"></script>
</body>
</html>

"@
    Set-Content -Path ".\clientapp\src\styles.css" @"
$mainStyle

.logo.marko:hover {
filter: drop-shadow(0 0 1em #ff036caa);
}
"@

    Set-Content -Path ".\clientapp\public\vite.svg" -Value @"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFEA83"></stop><stop offset="8.333%" stop-color="#FFDD35"></stop><stop offset="100%" stop-color="#FFA800"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
"@
    Set-Content -Path ".\clientapp\public\marko.svg" -Value @"
    <svg xmlns="http://www.w3.org/2000/svg" width="512" viewBox="0 0 2560 1400" class="marko">
    <path fill="url(#a)" d="M427 0h361L361 697l427 697H427L0 698z" />
    <linearGradient id="a" x2="0" y2="1">
        <stop offset="0" stop-color="hsl(181, 96.3%, 38.8%)" />
        <stop offset=".25" stop-color="hsl(186, 94.9%, 46.1%)" />
        <stop offset=".5" stop-color="hsl(191, 93.3%, 60.8%)" />
        <stop offset=".5" stop-color="hsl(195, 94.3%, 50.8%)" />
        <stop offset=".75" stop-color="hsl(199, 95.9%, 48.0%)" />
        <stop offset="1" stop-color="hsl(203, 94.9%, 38.6%)" />
    </linearGradient>
    <path fill="url(#b)" d="M854 697h361L788 0H427z" />
    <linearGradient id="b" x2="0" y2="1">
        <stop offset="0" stop-color="hsl(170, 80.3%, 50.8%)" />
        <stop offset=".5" stop-color="hsl(161, 79.1%, 47.3%)" />
        <stop offset="1" stop-color="hsl(157, 78.1%, 38.9%)" />
    </linearGradient>
    <path fill="url(#c)" d="M1281 0h361l-427 697H854z" />
    <linearGradient id="c" x2="0" y2="1">
        <stop offset="0" stop-color="hsl(86, 95.9%, 37.1%)" />
        <stop offset=".5" stop-color="hsl(86, 91.9%, 45.0%)" />
        <stop offset="1" stop-color="hsl(90, 82.1%, 51.2%)" />
    </linearGradient>
    <path fill="url(#d)" d="M1642 0h-361l428 697-428 697h361l428-697z" />
    <linearGradient id="d" x2="0" y2="1">
        <stop offset="0" stop-color="hsl(55, 99.9%, 53.1%)" />
        <stop offset=".25" stop-color="hsl(51, 99.9%, 50.0%)" />
        <stop offset=".5" stop-color="hsl(47, 99.2%, 49.8%)" />
        <stop offset=".5" stop-color="hsl(39, 99.9%, 50.0%)" />
        <stop offset=".75" stop-color="hsl(35, 99.9%, 50.0%)" />
        <stop offset="1" stop-color="hsl(29, 99.9%, 46.9%)" />
    </linearGradient>
    <path fill="url(#e)" d="M2132 0h-361l427 697-428 697h361l428-697z" />
    <linearGradient id="e" x2="0" y2="1">
        <stop offset="0" stop-color="hsl(352, 99.9%, 62.9%)" />
        <stop offset=".25" stop-color="hsl(345, 90.3%, 51.8%)" />
        <stop offset=".5" stop-color="hsl(341, 88.3%, 51.8%)" />
        <stop offset=".5" stop-color="hsl(336, 80.9%, 45.4%)" />
        <stop offset=".75" stop-color="hsl(332, 80.3%, 44.8%)" />
        <stop offset="1.1" stop-color="hsl(328, 78.1%, 35.9%)" />
    </linearGradient>
    </svg>
"@
    Set-Content -Path ".\clientapp\public\dotnet.svg" -Value @"
    <svg width="456" height="456" viewBox="0 0 456 456" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="456" height="456" fill="#512BD4"/>
    <path d="M81.2738 291.333C78.0496 291.333 75.309 290.259 73.052 288.11C70.795 285.906 69.6665 283.289 69.6665 280.259C69.6665 277.173 70.795 274.529 73.052 272.325C75.309 270.121 78.0496 269.019 81.2738 269.019C84.5518 269.019 87.3193 270.121 89.5763 272.325C91.887 274.529 93.0424 277.173 93.0424 280.259C93.0424 283.289 91.887 285.906 89.5763 288.11C87.3193 290.259 84.5518 291.333 81.2738 291.333Z" fill="white"/>
    <path d="M210.167 289.515H189.209L133.994 202.406C132.597 200.202 131.441 197.915 130.528 195.546H130.044C130.474 198.081 130.689 203.508 130.689 211.827V289.515H112.149V171H134.477L187.839 256.043C190.096 259.57 191.547 261.994 192.192 263.316H192.514C191.977 260.176 191.708 254.859 191.708 247.365V171H210.167V289.515Z" fill="white"/>
    <path d="M300.449 289.515H235.561V171H297.87V187.695H254.746V221.249H294.485V237.861H254.746V272.903H300.449V289.515Z" fill="white"/>
    <path d="M392.667 187.695H359.457V289.515H340.272V187.695H307.143V171H392.667V187.695Z" fill="white"/>
    </svg>

"@
Rename-Item -Path "$clientPath/src/tags/Footer.marko" -NewName "App-Footer.marko"
            }
            "svelte" {
                $app = @"
<script lang='$variantLanguage'>
import { Router, Route } from 'svelte-routing';
import Navbar from './components/Navbar.svelte';
import Footer from './components/Footer.svelte';
import Home from './pages/Home.svelte';
import Counter from './pages/Counter.svelte';
import WeatherForecast from './pages/WeatherForecast.svelte';
let routes = [
    { path: '/', component: Home },
    { path: '/counter', component: Counter },
    { path: '/fetch-data', component: WeatherForecast }
];
</script>
<Router>
    <Navbar />
    {#each routes as route}
        <Route path={route.path}>
            <svelte:component this={route.component} />
        </Route>
    {/each}
    <Footer />

</Router>
"@
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i svelte-routing bootstrap"
                Set-Content -Path $clientPath"/src/app.css" -Value $mainStyle
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "import 'bootstrap/dist/css/bootstrap.min.css';" -FindContent "import \'.\/app.css\'" -Action "above"
            }
            "qwik" {
                $app = @"
import { component$, useSignal, useVisibleTask$ } from '@builder.io/qwik';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import Home  from './pages/Home';
import Counter from './pages/Counter';
import WeatherForecast from './pages/WeatherForecast';
import './app.css';

export default component`$`(() => {
  const currentPath = useSignal(window.location.pathname);

  const renderComponent = () => {
    switch (currentPath.value) {
      case '/counter':
        return <Counter />; //for lazy loading, you can use `lazy`$`(() => import('./pages/Counter'))` by importing lazy 
      case '/fetch-data':
        return <WeatherForecast />;
      default:
        return <Home />;
    }
  };

  useVisibleTask`$`(() => {
    const updatePath = () => {
      currentPath.value = window.location.pathname;
    };

    window.addEventListener('popstate', updatePath);
    window.addEventListener('click', (e) => {
      const target = e.target as HTMLAnchorElement;
      if (target.tagName === 'A' && target.href) {
        e.preventDefault();
        history.pushState({}, '', target.href);
        updatePath();
      }
    });

    return () => window.removeEventListener('popstate', updatePath);
  });

  return (
    <>
      <Navbar />
      <main class="container">
        {renderComponent()}
      </main>
      <Footer />
    </>
  );
});
"@
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i bootstrap"
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "import 'bootstrap/dist/css/bootstrap.min.css';" -FindContent "import \'.\/index.css\'" -Action "above"
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "import App from './app.$variantLanguage';" -FindContent "import { App } from " -Action "replace"
                Set-Content -Path $clientPath"/src/index.css" -Value $null
                Set-Content -Path $clientPath"/src/app.css" -Value @"
$mainStyle
.logo.qwik:hover {
  filter: drop-shadow(0 0 2em #673ab8aa);
}
"@
                Move-Item -Path $clientPath"\public\assets\*.svg" -Destination $clientPath"\public\"
}

            "solid" {
                $app = @"
import { Router, Route } from '@solidjs/router';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import routes from './router.config'; // Not destructuring
import './App.css';
function App() {
  return (
    <>
      <Navbar />
      <Router>
          {routes.map((m) => (
            <Route
              path={m.path}
              component={m.component} // Use `element` prop, not `component`
            />
          ))}
      </Router>
      <Footer />
    </>
  );
}

export default App;
"@
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i @solidjs/router bootstrap"
                Set-Content -Path $clientPath"/src/App.css" -Value @"
$mainStyle
.logo.solid:hover {
  filter: drop-shadow(0 0 2em #61dafbaa);
}
"@
                Set-Content -Path $clientPath"/src/index.css" -Value ""
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "index.$variantLanguage" -AddContent "import 'bootstrap/dist/css/bootstrap.min.css';" -FindContent "import \'.\/index.css\'" -Action "above"
                Rename-Item -Path $clientPath"/src/index.$variantLanguage" -NewName "main.$variantLanguage" -Force
            }
            "preact" {
                $app = @"
import { lazy, Suspense } from 'preact/compat';
import Router from 'preact-router';
import config from './router.config.ts';
import Navbar from './components/Navbar';
import Footer from './components/Footer';

const pages = import.meta.glob('./pages/**/*.$variantLanguage');

export function App() {
  return (
    <div>
      <Navbar />
      <Suspense fallback={<div>Loading...</div>}>
        <Router>
          {config.map(({ path, componentPath }, index) => {
            const filePath = ``$`{componentPath}.$variantLanguage``; // Must match glob
            const Component = lazy(() => pages[filePath]());
            return <Component key={index} path={path} />;
          })}
        </Router>
      </Suspense>
      <Footer />
    </div>
  );
};
export default App;
"@
                Start-Process -WorkingDirectory $clientPath -NoNewWindow -Wait -FilePath "powershell" -ArgumentList "npm i preact-router bootstrap"
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "import 'bootstrap/dist/css/bootstrap.min.css';" -FindContent "import { App } from " -Action "above"
                Get-AddToFileContent -FilePath $clientPath"/src/" -FileName "main.$variantLanguage" -AddContent "import App from './app.$variantLanguage';" -FindContent "import { App } from " -Action "replace"
                Set-Content -Path $clientPath"/src/index.css" -Value $mainStyle
                Move-Item -Path $clientPath"\public\assets\*.svg" -Destination $clientPath"\public\"
            }
            "lit" {
                $app = @"
import { LitElement, html } from 'lit';
import { customElement } from 'lit/decorators.js';
import { Router } from '@lit-labs/router';

// Importing components so they're registered
import './components/Navbar.$variantLanguage';
import './components/Footer.$variantLanguage';
import './pages/Home.$variantLanguage';
import './pages/Counter.$variantLanguage';
import './pages/WeatherForecast.$variantLanguage';

@customElement('app-element')
export class App extends LitElement {
 createRenderRoot() {
    // Render into light DOM (no Shadow DOM)
    return this;
  }

  render() {
    return html``
      <navbar-element></navbar-element>
      <div>`$`{this._routes.outlet()}</div>
      <footer-element></footer-element>
    ``;
  }

   private _routes = new Router(this, [
        { path: '/', render: () =>  html``<home-element></home-element>`` },
        { path: '/counter', render: () =>  html``<counter-element></counter-element>`` },
        { path: '/fetch-data', render: () =>  html``<weatherforecast-element></weatherforecast-element>`` },
    ]);
}
"@
}       
"vanilla" {
                if ($variantLanguage -eq "ts") {
                    $_tsHtElType = ": HTMLElement"
                    $_tsAsAnchorElType = "as HTMLAnchorElement"
                    $_tsComType = ": () => string | Node"
                    $_tsSelectorDivType = "<HTMLDivElement>"
                }
                $app = @"
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import Home from './pages/Home';
import Counter from './pages/Counter';
import Weather from './pages/WeatherForecast';

export function App() {
  const app = document.querySelector$_tsSelectorDivType('#app');
  if (!app) return;

  // Create layout once
  app.innerHTML = ``<div id="navbar"></div>
    <div id="route"></div>
    <div id="footer"></div>
  ``;

  // Inject navbar and footer
  const navbar = document.querySelector$_tsSelectorDivType('#navbar');
  const footer = document.querySelector$_tsSelectorDivType('#footer');
  const route = document.querySelector$_tsSelectorDivType('#route');

  const content = (data$_tsHtElType, component$_tsComType) => {
    const contents = component();
    if (typeof contents === 'string') {
      data.innerHTML = contents;
    } else if (contents instanceof Node) {
      data.replaceChildren(contents);
    }
    return '';
  }

  if (navbar) content(navbar, () => Navbar().html);

  if (footer) content(footer, () => Footer().html);


  if (!route) return;

  // Set content based on route
  const path = window.location.pathname;

  switch (path) {
    case '/': {
      const home = Home();
      route.replaceChildren(home.html);
      break;
    }
    case '/counter': {
      const counter = Counter();
      route.replaceChildren(counter.html);
      counter.setup();
      break;
    }
    case '/fetch-data': {
      const weather = Weather();
      route.replaceChildren(weather.html);
      weather.setup();
      break;
    }
    default:
      route.innerHTML = ``
        <section class="container text-center">
         <div class="py-5">
          <h1 class="display-2 text-secondary">404 - Page Not Found</h1>
          <p class="lead">The page you are looking for does not exist.</p>
          <a href="/" class="btn btn-primary">Go to Home</a>
          </div>
        </section>
      ``;
  }

  // Register SPA-style nav links
  document.querySelectorAll('[data-link]').forEach(link => {
    link.addEventListener('click', e => {
      e.preventDefault();
      const href = (e.currentTarget $_tsAsAnchorElType).getAttribute('href');
      if (href) {
        window.history.pushState(null, '', href);
        App();
      }
    });
  });
}
"@
                Set-Content -Path $clientPath"/src/style.css" -Value @"
$mainStyle
.logo.vanilla:hover {
  filter: drop-shadow(0 0 2em #3178c6aa);
}
"@
                Set-Content -Path $clientPath"/src/main.$variantLanguage" -Value @"
import { App } from './App';
import './style.css';

document.addEventListener('DOMContentLoaded', () => {
  App();

  // Handle browser back/forward
  window.addEventListener('popstate', () => {
    App();
  });
});
"@
                Get-AddToFileContent -FilePath "Views\Shared\" -FileName "_Layout.cshtml" -AddContent '<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.7/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-LN+7fdVzj6u52u30Kp6M/trliBMCMKTyK833zpbD+pXdCLuTusPj697FH4R/5mcr" crossorigin="anonymous">' -FindContent '<script type=\"module\" src=\"http\:\/\/localhost\:5173\/\@\@vite\/client\"><\/script>' -Action "above"
                Move-Item -Path $clientPath"\src\*.svg" -Destination $clientPath"\public\"

            }

            default {
                Write-Error "Unsupported framework: $framework"
                return ""
            }
        }
        if ($framework -eq "lit") {
            Set-Content -Path "$clientPath/src/app-element.$variantLanguage" -Value $app 
        }
        elseif($framework -ne "marko" -or $framework -ne "lit"){
            Set-Content -Path $appPath -Value $app 
        }
    }
    Get-RouteConfig -frameworks $framework -variantLanguages $variantLanguage
    # if ($framework -eq "lit") {
    #     Remove-Item -Path "$clientPath/src/App.$variantLanguage" -Force -ErrorAction SilentlyContinue
    # }
}


# Create the main entry point for the client application
Write-Host "Choose an option:" -ForegroundColor Cyan
Write-Host "1. Start development server" -ForegroundColor Yellow
Write-Host "2. Build and publish for production" -ForegroundColor Green
Write-Host "3. Exit \n" -ForegroundColor Red

$choice = Read-Host 
Write-Host "You chose option $choice" -ForegroundColor Cyan

if ($choice -eq "1") {
    Write-Host "Starting dotnet watch and npm dev server..."    -ForegroundColor Cyan
    Start-Process -WorkingDirectory ".\ClientApp" -NoNewWindow -FilePath "powershell" -ArgumentList "npm run dev"

    dotnet watch run
}
elseif ($choice -eq "2") {
    Write-Host "Choose publish target:"  -ForegroundColor Cyan
    Write-Host "1. Windows" -ForegroundColor Yellow
    Write-Host "2. Linux"  -ForegroundColor Green
    $publishTarget = Read-Host "Enter 1 or 2"

    Write-Host "Building .NET and $framework/Vite app for production..." -ForegroundColor Green
    Push-Location ./ClientApp

    # Run build and wait for completion
    $buildProcess = npm run build --silent

    if ($buildProcess.ExitCode -eq 0) {
        Write-Host "Build completed successfully." -ForegroundColor Green
        $distPath = Join-Path (Get-Location) "dist"
        $wwwrootPath = Join-Path (Get-Location) "..\wwwroot"
        if (Test-Path $distPath) {
            # Remove existing wwwroot content except for .gitignore (if present)
            Get-ChildItem -Path $wwwrootPath -Exclude ".gitignore" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            # Move all content from dist to wwwroot
            Get-ChildItem -Path $distPath | ForEach-Object {
                Move-Item -Path $_.FullName -Destination $wwwrootPath -Force
            }
            Write-Host "Moved build output to wwwroot." -ForegroundColor Green
        }
        else {
            Write-Host "Build output directory 'dist' not found." -ForegroundColor Red
        }
    }
    else {
        Write-Host "Build failed. Please check the error messages above." -ForegroundColor Red
    }
    Pop-Location

    if ($publishTarget -eq "1") {
        dotnet publish -c Release --self-contained true
        Write-Host "Published for Windows" -ForegroundColor Green
    }
    elseif ($publishTarget -eq "2") {
        dotnet publish -c Release -r linux-x64 --self-contained true
        Write-Host "Published for Linux" -ForegroundColor Green
    }
    else {
        Write-Host "Invalid publish target."  -ForegroundColor Red
    }
}
elseif ($choice -eq "3") {
    Write-Host "Exiting..." -ForegroundColor DarkYellow
    exit
}
else {
    Write-Host "Invalid option" -ForegroundColor Red
}
