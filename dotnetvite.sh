#!/bin/bash
BLACK_TEXT=$'\033[0;90m'
RED_TEXT=$'\033[0;91m'
GREEN_TEXT=$'\033[0;92m'
YELLOW_TEXT=$'\033[0;93m'
BLUE_TEXT=$'\033[0;94m'
MAGENTA_TEXT=$'\033[0;95m'
CYAN_TEXT=$'\033[0;96m'
WHITE_TEXT=$'\033[0;97m'
DIM_TEXT=$'\033[2m'
STRIKETHROUGH_TEXT=$'\033[9m'
BOLD_TEXT=$'\033[1m'
RESET_FORMAT=$'\033[0m'


# Check if Angular CLI is installed
if command -v ng >/dev/null 2>&1; then
    echo -e "${GREEN_TEXT}🚀     INITIATING EXECUTION     🚀${RESET_FORMAT}"
else
    echo -e "${RED_TEXT}❌ Angular CLI not found. ⌛ Installing...${RESET_FORMAT}"

    # Install Angular CLI globally
    npm install -g @angular/cli

    # Check if the installation was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN_TEXT}📥 Angular CLI installed successfully.${RESET_FORMAT}"
        echo -e "${GREEN_TEXT}📂 Angular CLI installed. Open a new terminal and start the process again.${RESET_FORMAT}"
        ng version
    else
        echo -e "${RED_TEXT}❌ Failed to install Angular CLI. Please check your npm and network configuration.${RESET_FORMAT}"
        exit 1
    fi
fi

# Prompt for project name
echo -e "${CYAN_TEXT}📦 Enter your project name:${RESET_FORMAT}"
read projectName

# Create ASP.NET MVC project
dotnet new mvc -n "$projectName"

# Navigate into the project directory
cd "$projectName" || exit

# Create a Helpers directory
mkdir -p Helpers

# Function to modify file content
get_add_to_file_content() {
    local file_path="$1"
    local file_name="$2"
    local add_content="$3"
    local find_content="$4"
    local action="${5:-below}"

    # Find the file
    local file=$(find "$file_path" -type f -name "$file_name" | head -n 1)

    if [ -z "$file" ]; then
        echo -e "${RED_TEXT}${BOLD_TEXT}Error:${RESET_FORMAT} ${RED_TEXT}File '$file_name' not found in path '$file_path'"${RESET_FORMAT}
        return 1
    fi

    # Create a temporary file
    local tmp_file=$(mktemp)

    while IFS= read -r line; do
        if [[ "$line" =~ $find_content ]]; then
            case "$action" in
                above)
                    echo "$add_content" >> "$tmp_file"
                    echo "$line" >> "$tmp_file"
                    ;;
                below)
                    echo "$line" >> "$tmp_file"
                    echo "$add_content" >> "$tmp_file"
                    ;;
                replace)
                    echo "$add_content" >> "$tmp_file"
                    ;;
                *)
                    echo "$line" >> "$tmp_file"
                    ;;
            esac
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$file"

    # Replace original file with modified content
    mv "$tmp_file" "$file"
}

cat << EOF > ".\Helpers\ViteManifest.cs"
using System.Text.Json;
namespace ${projectName}.Helpers;

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

EOF



file_path="./Program.cs"
temp_file=$(mktemp)
inserted_using=false

while IFS= read -r line; do
    # Insert 'using' before 'var builder'
    if [[ "$inserted_using" = false && "$line" == var\ builder* ]]; then
        echo "using ${projectName}.Helpers;" >> "$temp_file"
        inserted_using=true
    fi

    echo "$line" >> "$temp_file"

    # Inject singleton service registration
    if [[ "$line" == *"builder.Services.AddControllersWithViews();"* ]]; then
        echo 'builder.Services.AddSingleton<ViteManifest>();' >> "$temp_file"
    fi

    # Inject fallback mapping for production
    if [[ "$line" == *".WithStaticAssets();"* ]]; then
        cat <<EOF >> "$temp_file"
if (!app.Environment.IsDevelopment())
{
    app.MapFallbackToFile("index.html");
}
EOF
    fi
done < "$file_path"

# Replace '.WithStaticAssets();' with ';'
sed -i 's/\.WithStaticAssets();/;/' "$temp_file"

# Overwrite original file
mv "$temp_file" "$file_path"


# Ensure required directories exist
mkdir -p ./Views/Home ./Views/Shared ./Controllers ./Models

# Clear _Layout.cshtml
> ./Views/Shared/_Layout.cshtml

# Remove all files in Views/Home except Index.cshtml
find ./Views/Home -type f ! -name 'Index.cshtml' -delete

# Remove all files in Views/Shared except _Layout.cshtml
find ./Views/Shared -type f ! -name '_Layout.cshtml' -delete

# Overwrite Index.cshtml
cat <<EOF > ./Views/Home/Index.cshtml
@{
    Layout = "_Layout";
}
EOF

# Overwrite HomeController.cs
cat <<EOF > ./Controllers/HomeController.cs 
using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using ${projectName}.Models;

namespace ${projectName}.Controllers;

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
EOF

# Overwrite WeatherForecastController.cs
cat <<EOF > ./Controllers/WeatherForecastController.cs
using Microsoft.AspNetCore.Mvc;
using ${projectName}.Controllers;
using ${projectName}.Models;

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
EOF

# Overwrite WeatherForecast.cs
cat <<EOF > ./Models/WeatherForecast.cs
using System;
namespace ${projectName}.Models;
public class WeatherForecast
{
    public DateTime Date { get; set; }
    public int TemperatureC { get; set; }
    public string? Summary { get; set; }

    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
EOF

declare -A colors=(
    [RED]="\e[1;31m"
    [GREEN]="\e[1;32m"
    [YELLOW]="\e[1;33m"
    [BLUE]="\e[1;34m"
    [PURPLE]="\e[1;35m"
    [CYAN]="\e[1;36m"
    [WHITE]="\e[2;37m"
    [LIGHT_RED]="\e[1;91m"
    [LIGHT_GREEN]="\e[1;92m"
    [LIGHT_PURPLE]="\e[1;95m"
)

# Frameworks list
frameworks=("angular" "lit" "marko" "preact" "qwik" "react" "solid" "svelte" "vanilla" "vue")

# Get color names as an array
color_keys=("${!colors[@]}")

# Print selection prompt
echo -e "${CYAN_TEXT}Select a framework:${RESET_FORMAT}"

# Loop through frameworks and assign colors
for i in "${!frameworks[@]}"; do
    color_name="${color_keys[$i % ${#color_keys[@]}]}"
    color_code="${colors[$color_name]}"
    name="${frameworks[$i]}"
    capitalized_name="$(tr '[:lower:]' '[:upper:]' <<< "${name:0:1}")${name:1}"
    echo -e "${color_code}$((i+1)). ${capitalized_name}${RESET_FORMAT}"
done

echo -e "${CYAN_TEXT}Enter the number of your selected framework:${RESET_FORMAT}"
read framework_index
framework="${frameworks[$((framework_index-1))]}"

template=""
variantLanguage=""

if [[ "$framework" == "react" ]]; then
    variants=("TypeScript" "TypeScript + SWC" "JavaScript" "JavaScript + SWC")
    templates=("react-ts" "react-swc" "react" "react-swc-js")
    langs=("tsx" "tsx" "jsx" "jsx")
elif [[ "$framework" == "preact" ]]; then
    variants=("TypeScript" "JavaScript")
    templates=("preact-ts" "preact")
    langs=("tsx" "jsx")
elif [[ "$framework" == "solid" ]]; then
    variants=("TypeScript" "JavaScript")
    templates=("solid-ts" "solid")
    langs=("tsx" "jsx")
elif [[ "$framework" == "qwik" ]]; then
    variants=("TypeScript" "JavaScript")
    templates=("qwik-ts" "qwik")
    langs=("tsx" "jsx")
elif [[ "$framework" == "angular" ]]; then
    echo "${YELLOW_TEXT}Angular does not have variants. Using default template.${RESET_FORMAT}"
    template="angular"
    variantLanguage="ts"
else
    variants=("TypeScript" "JavaScript")
    suffixes=("-ts" "")
    langs=("ts" "js")
fi

if [[ "$framework" != "angular" ]]; then
    echo -e "${colors[CYAN]}Select a variant:${RESET_FORMAT}"
    for i in "${!variants[@]}"; do
        color_name="${color_keys[$i % ${#color_keys[@]}]}"
        color_code="${colors[$color_name]}"
        echo -e "${color_code}$((i+1)). ${variants[$i]}${RESET_FORMAT}"
    done

    echo -e "${colors[CYAN]}Enter the number of your selected variant:${RESET_FORMAT}"
    read variant_index

    if [[ "$framework" == "react" || "$framework" == "preact" || "$framework" == "solid" || "$framework" == "qwik" ]]; then
        template="${templates[$((variant_index-1))]}"
        variantLanguage="${langs[$((variant_index-1))]}"
    else
        suffix="${suffixes[$((variant_index-1))]}"
        template="${framework}${suffix}"
        variantLanguage="${langs[$((variant_index-1))]}"
    fi
fi

echo -e "${CYAN_TEXT}Selected framework:${RESET_FORMAT} $framework"
echo -e "${CYAN_TEXT}Template:${RESET_FORMAT} $template"
echo -e "${CYAN_TEXT}Language extension:${RESET_FORMAT} $variantLanguage"

# Write IWeatherData interface
IWeatherData=$(cat <<EOF 
interface IWeatherData {
    date: string;
    temperatureC: number;
    temperatureF: number;
    summary: string;
}
EOF
)
# Set project name and client path
clientPath="ClientApp"

# Determine React Refresh injection
react_refresh=""
if [[ "$framework" == "react" && ("$variantLanguage" == "tsx" || "$variantLanguage" == "jsx") ]]; then
  react_refresh='<script type="module">
    import { injectIntoGlobalHook } from "http://localhost:5173/@@react-refresh";
    injectIntoGlobalHook(window);
    window.$RefreshReg$ = () => {};
    window.$RefreshSig$ = () => (type) => type;
  </script>'
fi

# Plugin import and usage setup
plugin_import=""
plugin_usage=""
framework_link=""
root_id=""
extension=""

case "$framework" in
  "vue")
    plugin_import="import vue from '@vitejs/plugin-vue'"
    plugin_usage="plugins: [vue()]"
    framework_link="https://vuejs.org/"
    root_id="app"
    extension="vue"
    ;;
  "react")
    plugin_import="import react from '@vitejs/plugin-react'"
    plugin_usage="plugins: [react()]"
    framework_link="https://react.dev/"
    root_id="root"
    extension="$variantLanguage"
    ;;
  "svelte")
    plugin_import="import { svelte } from '@sveltejs/vite-plugin-svelte'"
    plugin_usage="plugins: [svelte()]"
    framework_link="https://svelte.dev/"
    root_id="app"
    extension="svelte"
    ;;
  "lit")
    plugin_import="import lit from 'vite-plugin-lit'"
    plugin_usage="plugins: [lit()]"
    framework_link="https://lit.dev/"
    root_id="app"
    extension="$variantLanguage"
    ;;
  "solid")
    plugin_import="import solid from 'vite-plugin-solid'"
    plugin_usage="plugins: [solid()]"
    framework_link="https://www.solidjs.com/"
    root_id="root"
    extension="$variantLanguage"
    ;;
  "qwik")
    plugin_import="import { qwikVite } from '@builder.io/qwik/optimizer'"
    plugin_usage="plugins: [ qwikVite({ csr: true }) ]"
    framework_link="https://qwik.builder.io/"
    root_id="app"
    extension="$variantLanguage"
    ;;
  "marko")
    plugin_import="import marko from '@marko/vite'"
    plugin_usage="plugins: [marko()]"
    framework_link="https://markojs.com/"
    root_id="app"
    extension="marko"
    ;;
  "preact")
    plugin_import="import preact from '@preact/preset-vite'"
    plugin_usage="plugins: [preact()]"
    framework_link="https://preactjs.com/"
    root_id="app"
    extension="$variantLanguage"
    ;;
  "vanilla")
    plugin_import="// No plugin needed for vanilla"
    plugin_usage="plugins: []"
    framework_link="https://developer.mozilla.org/en-US/docs/Web/JavaScript"
    root_id="app"
    extension="$variantLanguage"
    ;;
  "angular")
    framework_link="https://angular.dev/"
    extension="$variantLanguage"
    ;;
  *)
    plugin_import="// Plugin not defined for selected framework"
    plugin_usage="plugins: []"
    root_id="app"
    extension="$variantLanguage"
    ;;
esac

# Setup class attribute
if [[ "$variantLanguage" == "tsx" || "$variantLanguage" == "jsx" ]]; then
  class_name="className"
else
  class_name="class"
fi
#case Change 
convert_cases(){

local component="$1"
local format="${2:-PascalCase}"

# Step 1: Clean input - keep only alphanumerics
cleaned=$(echo "$component" | tr -cd '[:alnum:]')

# Step 2: Split by capital letters except the first
words=()
word_start=0
for ((i=1; i<${#cleaned}; i++)); do
    char="${cleaned:$i:1}"
    if [[ "$char" =~ [A-Z] ]]; then
        words+=("${cleaned:$word_start:$((i - word_start))}")
        word_start=$i
    fi
done
words+=("${cleaned:$word_start}")

# Normalize words: first letter uppercase, rest lowercase
normalized=()
for word in "${words[@]}"; do
    first="${word:0:1}"
    rest="${word:1}"
    normalized+=("$(echo "$first" | tr '[:lower:]' '[:upper:]')$(echo "$rest" | tr '[:upper:]' '[:lower:]')")
done

# Format output
case "$format" in
    LowerCase)
        result=$(IFS=; echo "${normalized[*]}" | tr '[:upper:]' '[:lower:]')
        ;;
    UpperCase)
        result=$(IFS=; echo "${normalized[*]}" | tr '[:lower:]' '[:upper:]')
        ;;
    PascalCase)
        result=$(IFS=; echo "${normalized[*]}")
        ;;
    PipeCase)
        result=$(IFS='|'; echo "${normalized[*]}")
        ;;
    SplitCapitalize)
        result=$(IFS=' '; echo "${normalized[*]}")
        ;;
    HefinCase)
        lower=()
        for word in "${normalized[@]}"; do
            lower+=("$(echo "$word" | tr '[:upper:]' '[:lower:]')")
        done
        result=$(IFS='-'; echo "${lower[*]}")
        ;;
    *)
        result=$(IFS=; echo "${normalized[*]}")
        ;;
esac
return "$result"

}

# Determine main element and port
main_element=""
main_src="src/main.$variantLanguage"
port="5173"

if [[ "$framework" == "lit" ]]; then
  main_element="<main-element></main-element>"
elif [[ "$framework" == "angular" ]]; then
  main_element="<app-root></app-root>"
  port="4200"
  main_src="main.js"
else
  main_element="<div id="$root_id"></div>"
fi

# Generate _Layout.cshtml
layout_path="./Views/Shared/_Layout.cshtml"
mkdir -p "$(dirname "$layout_path")"
cat <<EOF > "$layout_path"
@using ${projectName}.Helpers
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
      $react_refresh
      <script type="module" src="http://localhost:$port/$main_src"></script>
    }
</head>
<body>
  $main_element
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
    <script type="module" src="http://localhost:$port/$main_src"></script>
  }
  @await RenderSectionAsync("Scripts", required: false)
</body>
</html>
EOF

# Update .csproj file
csproj_path="${projectName}.csproj"

vite_publish_target=$(cat <<'EOF'
<Target Name="PublishRunWebpack" AfterTargets="ComputeFilesToPublish">
  <ItemGroup>
    <DistFiles Include="ClientApp/build/**" />
    <ResolvedFileToPublish Include="@(DistFiles->%(FullPath))" Exclude="@(ResolvedFileToPublish)">
      <RelativePath>wwwroot\%(RecursiveDir)%(FileName)%(Extension)</RelativePath>
      <CopyToPublishDirectory>PreserveNewest</CopyToPublishDirectory>
      <ExcludeFromSingleFile>true</ExcludeFromSingleFile>
    </ResolvedFileToPublish>
  </ItemGroup>
</Target>
EOF
)

angular_public_files=$(cat <<'EOF'
<Target Name="CopyAngularPublic" BeforeTargets="Build">
  <Copy SourceFiles="@(AngularPublicFiles)" DestinationFolder="wwwroot" SkipUnchangedFiles="true" />
</Target>
<ItemGroup>
  <AngularPublicFiles Include="ClientApp/public/**/*.*" />
</ItemGroup>
EOF
)

if [[ "$framework" == "angular" ]]; then
  vite_publish_target="$vite_publish_target"$'\n'"$angular_public_files"
fi

if [[ -f "$csproj_path" ]]; then
printf '%s\n' "$vite_publish_target" | sed -i "/<\/Project>/e cat" "$csproj_path"
fi

if [[ "$framework" == "angular" ]]; then
    # Angular setup
    echo "Do you want to include Zone.js? (y/n):"
    read use_zone_js
    if [[ "$use_zone_js" == "y" ]]; then
        polyfills_option=""
        echo "Zone.js will be included."
    else
        polyfills_option="--zoneless"
        echo "Zone.js will be excluded (requires careful consideration for browser compatibility)."
    fi

    echo "Which CSS preprocessor do you want to use? (css/scss/less):"
    read css_preprocessor
    if [[ "$css_preprocessor" == "scss" ]]; then
        style_option="--style=scss"
        echo "SCSS selected."
    elif [[ "$css_preprocessor" == "less" ]]; then
        style_option="--style=less"
        echo "LESS selected."
    else
        style_option="--style=css"
        echo "CSS selected."
    fi

    echo "Do you want to enable SSR/SSG? (y/n):"
    read enable_ssr
    if [[ "$enable_ssr" == "y" ]]; then
        ssr_option="--ssr"
        echo "SSR/SSG will be enabled."
    else
        ssr_option=""
        echo "SSR/SSG will NOT be enabled."
    fi

    echo "Running: ng new clientapp $style_option $ssr_option $polyfills_option"
    ng new clientapp $style_option $ssr_option $polyfills_option

elif [[ "$framework" == "marko" ]]; then
    # Marko setup
mkdir -p ClientApp
cat <<EOF > ClientApp/package.json
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
EOF

    echo "Do you want to use TypeScript for Marko? (y/n):"
    read use_ts
    if [[ "$use_ts" == "y" ]]; then
        cat <<EOF > ClientApp/tsconfig.json
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
EOF
        variantLanguage="ts"
        type_any=":any"
        type_html_element=":HTMLElement"
        type_void=":void"
        type_record="?: Record<string, any>"
    else
        variantLanguage="js"
        type_any=""
        type_html_element=""
        type_void=""
        type_record=""
    fi

    mkdir -p ClientApp/src/pages
    cat <<EOF > ClientApp/src/router.${variantLanguage}
import page from "page";
import Home from "./pages/Home.marko";
import Counter from "./pages/Counter.marko";
import WeatherForecast from "./pages/WeatherForecast.marko";
import Layout from "./pages/index.marko";

let layoutInstance${type_html_element};
let routeContainer${type_html_element};
let currentView${type_html_element};

export function initRouter(mountPoint) {
    layoutInstance = Layout.mount({}, mountPoint);
    routeContainer = mountPoint.querySelector("#router-view");

    page("/", () => loadView(Home, { name: "Client" }));
    page("/counter", () => loadView(Counter));
    page("/fetch-data", () => loadView(WeatherForecast, {}));
    page();
}

function loadView(ViewComponent${type_any}, props${type_record})${type_void} {
    if (currentView) {
        currentView.destroy && currentView.destroy();
        routeContainer.innerHTML = "";
    }

    currentView = ViewComponent.mount(props, routeContainer);
}
EOF

    cd ClientApp
    npm install marko@next page
    npm install -D vite @marko/vite bootstrap
else 
    # Run Vite scaffolding
echo "Running: npm create vite@latest clientapp -- --template $template"
npm create vite@latest clientapp -- --template $template 
fi

if [[ "$framework" == "lit" ]]; then
    get_add_to_file_content "./src" "index.html" "<script type=\"module\" src=\"/src/main.$variantLanguage\"></script>" "\@\@vite\/client\"><\/script>" "below"
fi

if [ "$framework" != "marko" ]; then
    if [ -d "clientapp" ]; then
        mv clientapp temp_folder && mv temp_folder ClientApp
        cd ClientApp
        npm install
        cd ..
    fi
fi


# Define paths
clientPath="ClientApp"
componentsPath="$clientPath/src/components"
pagesPath="$clientPath/src/pages"
tagsPath="$clientPath/src/tags"

if [[ "$framework" == "marko" ]]; then

   mkdir "$clientPath/public" "$pagesPath" "$clientPath/src/tags"
fi
# Create folders
if [[ "$framework" != "angular" ]] && [[ "$framework" != "marko" ]]; then
    mkdir -p "$componentsPath" "$pagesPath"
fi

# Move assets to public
if [[ -d "$clientPath/src/assets" ]]; then
    mv -f "$clientPath/src/assets" "$clientPath/public" 
fi

if [[ "$framework" == "angular" ]]; then
    # creating angular svg
cat << EOF > "$clientPath/public/angular.svg"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" fill="none" viewBox="0 0 223 236" width="32" class="angular-logo"><g  clip-path="url(#a)"><path  fill="url(#b)" d="m222.077 39.192-8.019 125.923L137.387 0l84.69 39.192Zm-53.105 162.825-57.933 33.056-57.934-33.056 11.783-28.556h92.301l11.783 28.556ZM111.039 62.675l30.357 73.803H80.681l30.358-73.803ZM7.937 165.115 0 39.192 84.69 0 7.937 165.115Z"></path><path  fill="url(#c)" d="m222.077 39.192-8.019 125.923L137.387 0l84.69 39.192Zm-53.105 162.825-57.933 33.056-57.934-33.056 11.783-28.556h92.301l11.783 28.556ZM111.039 62.675l30.357 73.803H80.681l30.358-73.803ZM7.937 165.115 0 39.192 84.69 0 7.937 165.115Z"></path></g><defs ><linearGradient  id="b" x1="49.009" x2="225.829" y1="213.75" y2="129.722" gradientUnits="userSpaceOnUse"><stop  stop-color="#E40035"></stop><stop  offset=".24" stop-color="#F60A48"></stop><stop  offset=".352" stop-color="#F20755"></stop><stop  offset=".494" stop-color="#DC087D"></stop><stop  offset=".745" stop-color="#9717E7"></stop><stop  offset="1" stop-color="#6C00F5"></stop></linearGradient><linearGradient  id="c" x1="41.025" x2="156.741" y1="28.344" y2="160.344" gradientUnits="userSpaceOnUse"><stop  stop-color="#FF31D9"></stop><stop  offset="1" stop-color="#FF5BE1" stop-opacity="0"></stop></linearGradient><clipPath  id="a"><path  fill="#fff" d="M0 0h223v236H0z"></path></clipPath></defs></svg>
EOF
cat << EOF > "$clientPath/public/vite.svg"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFEA83"></stop><stop offset="8.333%" stop-color="#FFDD35"></stop><stop offset="100%" stop-color="#FFA800"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
EOF
fi
curl -o "$clientPath/public/dotnet.svg" "https://raw.githubusercontent.com/dotnet/brand/refs/heads/main/logo/dotnet-logo.svg"
# Create index.html
cat << EOF > "$clientPath/public/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dotnet Vite</title>
    <link rel="icon" type="image/x-icon" href="/dotnet.svg">
</head>
<body>
    <h1>Welcome to Dotnet Vite</h1>
</body>
</html>
EOF

if [[ "$framework" == "angular" ]]; then

cat <<EOF > "ClientApp/vite.config.$extention"
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
EOF

if [[ "$framework" =~ ^(vue|lit|solid|qwik|preact|react|vanilla)$ ]]; then
    case "$variantLanguage" in
        tsx) variant="ts" ;;
        jsx) variant="js" ;;
        *)   variant="$variantLanguage" ;;
    esac
fi

cat <<EOF > "$clientPath/src/router.config.$variant"
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
EOF
elif [ "$framework" -eq "solid" ]; then
cat <<EOF > "$clientPath/src/router.config.$variantLanguage"
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
EOF

_frameworkBasedSvg = $null
if [ "$framework" -eq "svelte" -o "$framework" -eq "solid" ]; then
    _frameworkBasedSvg = "import $($framework)Logo from '/assets/$framework.svg';"
elif [ "$framework" -eq "vanilla" ]; then
    if [ "$variantLanguage" -eq "ts" ]; then
        _frameworkBasedSvg = "import typescriptLogo from '/typescript.svg';"
    elif [ "$variantLanguage" -eq "js" ]; then
        _frameworkBasedSvg = "import javascriptLogo from '/javascript.svg';"
    fi
else
    _frameworkBasedSvg = "import $($framework)Logo from '/$framework.svg';"
fi

svgImports = $(cat <<EOF
import viteLogo from '/vite.svg';
$_frameworkBasedSvg
import dotnetLogo from '/dotnet.svg';
EOF
)

mainStyle = $(cat <<EOF
.logo {
  height: 6em;
  padding: 1.5em;
}
.logo:hover {
  filter: drop-shadow(0 0 2em #646cffaa);
}
EOF
)

case "$framework" in
  preact|lit|vanilla|solid|qwik)
    className="class"
    ;;
  *)
    if [ "$variantLanguage" = "tsx" ] || [ "$variantLanguage" = "jsx" ]; then
      className="className"
    else
      className="class"
    fi
    ;;
esac


navbarContent = $(cat <<EOF
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
EOF
)
CapitalizeTitle = "${projectName^^}"
footerContent = $(cat <<EOF
<footer $className="w-full bg-light text-center text-lg-start mt-5 py-4">
    <div $className="container d-flex justify-content-between align-items-center px-3">
        <p $className="mb-0 text-start">$CapitalizeTitle &copy; $(Get-Date -Format yyyy)</p>
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
EOF
)
get_home_content() {

# Inputs
main_framework="$1"     # e.g., react
mode="${2:-html}"       # default to html
links="$3"              # e.g., https://react.dev
css_class="$4"          # e.g., className
variantLanguage="${5:-tsx}"  # optional, used for logo selection

# Capitalize framework name
title="$(echo "$main_framework" | sed 's/.*/\u&/')"


# Determine logo image
if [[ "$framework" == "vanilla" && "$variantLanguage" == "js" ]]; then
    image="javascriptLogo"
elif [[ "$framework" == "vanilla" && "$variantLanguage" == "ts" ]]; then
    image="typescriptLogo"
else
    image="${framework}Logo"
fi

# Generate content block
if [[ "$framework" == "angular" && "$mode" == "import" ]]; then
    content=$(cat <<EOF
    <div $css_class='d-flex justify-content-center gap-4 py-4'>
        https://dotnet.microsoft.com
        https://vitejs.dev
        <a href="$links" target="_blank">
            <img [src]="angularLogo" $css_class="logo" alt="$title logo" />
        </a>
    </div>
EOF
)
elif [[ "$mode" == "import" && "$framework" =~ ^(lit|vanilla|marko)$ ]]; then
    content=$(cat <<EOF
    <div class="d-flex justify-content-center gap-4 py-4">
        https://dotnet.microsoft.com
        https://vitejs.dev
        <a href="$links" target="_blank">
            <img src="\${$image}" class="logo" alt="$framework logo" />
        </a>
    </div>
EOF
)
elif [[ "$mode" == "import" ]]; then
    content=$(cat <<EOF
    <div $css_class='d-flex justify-content-center gap-4 py-4'>
        https://dotnet.microsoft.com
        https://vitejs.dev
        <a href="$links" target="_blank">
            <img src={${image}} $css_class="logo" alt="$title logo" />
        </a>
    </div>
EOF
)
else
    content=$(cat <<EOF
    <div $css_class='d-flex justify-content-center gap-4 py-4'>
        https://dotnet.microsoft.com
        https://vitejs.dev
        <a href="$links" target="_blank">
            <img src="/${framework}.svg" $css_class="logo" alt="$title logo" />
        </a>
    </div>
EOF
)
fi

# Final section
cat <<EOF
<section $css_class='container px-4 py-5 text-center'>
    $content
    <h1 $css_class='display-1 fw-bold text-secondary'>Dotnet + Vite + $title</h1>
    <p $css_class='lead'>This is a simple ASP.NET MVC application with Vite.js setup.</p>
</section>
EOF
}

# Fetch Function Content

get_fetch_content() {
    local framework="$1"         # e.g., react, svelte, angular
    local content_enabled="$2"   # true or false
    local class_name="$3"        # e.g., className or class

    local tbody=""
    if [[ "$content_enabled" == "true" ]]; then
        case "$framework" in
            lit)
                tbody=$(cat <<EOF
<tbody>
    \${this.weatherData.map(item => html\`
        <tr>
            <td>\${new Date(item.date).toLocaleDateString()}</td>
            <td>\${item.temperatureC} &deg;C</td>
            <td>\${item.temperatureF} &deg;F</td>
            <td>\${item.summary}</td>
        </tr>
    \`)}
</tbody>
EOF
)
                ;;
            svelte)
                tbody=$(cat <<EOF
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
EOF
)
                ;;
            marko)
                tbody=$(cat <<EOF
<tbody>
    <for |item| of=weatherData>
        <tr>
            <td>\${new Date(item.date).toLocaleDateString()}</td>
            <td>\${item.temperatureC} &deg;C</td>
            <td>\${item.temperatureF} &deg;F</td>
            <td>\${item.summary}</td>
        </tr>
    </for>
</tbody>
EOF
)
                ;;
            angular)
                tbody=$(cat <<EOF
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
EOF
)
                ;;
            solid|react|preact|qwik)
                local data_accessor=""
                case "$framework" in
                    solid) data_accessor="weatherData()" ;;
                    qwik)  data_accessor="weatherData.value" ;;
                    *)     data_accessor="weatherData" ;;
                esac
                tbody=$(cat <<EOF
<tbody>
    \${$data_accessor.map((item, key) => (
        <tr key={key}>
            <td>{new Date(item.date).toLocaleDateString()}</td>
            <td>{item.temperatureC} &deg;C</td>
            <td>{item.temperatureF} &deg;F</td>
            <td>{item.summary}</td>
        </tr>
    ))}
</tbody>
EOF
)
                ;;
        esac
    else
        tbody='<tbody id="weatherData"></tbody>'
    fi

    # Final section
    cat <<EOF
<section $class_name="container px-4 py-5">
    <h1 $class_name="display-2 text-secondary text-center">Fetch Weather Forecast Data</h1>
    <p $class_name="lead text-center">
        This section fetches data from the ASP.NET WeatherForeCastController API.
        To view the API <a $class_name="linklink-underline-info" target="_blank" href="/api/weatherforecast">Click Here</a>
    </p>
    <table $class_name="mt-2 table table-striped table-bordered">
        <thead>
            <tr>
                <th>Date</th>
                <th>Temperature (C)</th>
                <th>Temperature (F)</th>
                <th>Summary</th>
            </tr>
        </thead>
        $tbody
    </table>
</section>
EOF

}


fetchDataFunction=""
_markInterface=""
_constPointer="const"
_constState=""
_setState=""

if [[ "$framework" =~ ^(react|solid|preact|angular|lit|svelte|qwik)$ ]]; then
    if [[ "$framework" == "solid" ]]; then
        _constState="const [weatherData, setWeatherData] = createSignal<IWeatherData[]>([]);"
        _setState="setWeatherData(data);"
    elif [[ "$framework" == "react" || "$framework" == "preact" ]]; then
        _constState="const [weatherData, setWeatherData] = useState<IWeatherData[]>([]);"
        _setState="setWeatherData(data);"
    elif [[ "$framework" == "angular" ]]; then
        _constPointer="public"
        _constState="public weatherData = signal<IWeatherData[]>([]);"
        _setState="this.weatherData.set(data);"
    elif [[ "$framework" == "qwik" ]]; then
        _constState="let weatherData = useSignal<IWeatherData[]>([]);"
        _setState="weatherData.value = data;"
    elif [[ "$framework" == "lit" ]]; then
        _constPointer="private"
        _constState=""
        _setState="this.weatherData = data;"
    else
        _constState="let weatherData: IWeatherData[] = [];"
        _setState="weatherData = data;"
    fi

    fetchDataFunction=$(cat <<EOF

$_constState

$_constPointer fetchData = async () => {
    try {
        const response = await fetch('/api/weatherforecast');
        if (!response.ok) throw new Error('Network response was not ok');
        const data: IWeatherData[] = await response.json();
        $_setState
    } catch (error) {
        console.error('Fetch error:', error);
    }
};
EOF
)

elif [[ "$framework" == "marko" ]]; then
    if [[ "$variantLanguage" == "ts" ]]; then
        _markInterface="export interface IWeatherData {
    date: string;
    temperatureC: number;
    temperatureF: number;
    summary: string;
}"
        _typeTs=": IWeatherData[]"
    else
        _typeTs=""
    fi

    fetchDataFunction=$(cat <<EOF
$_markInterface

<let/weatherData$_typeTs = []>   
<const/fetchData = async () => {
   const response = await fetch("/api/weatherforecast");
   const data$_typeTs = await response.json();
   weatherData = data; // This triggers reactivity
}>
EOF
)

else
    fetchDataFunction=$(cat <<'EOF'
const fetchData = async () => {
    try {
        const response = await fetch('/api/weatherforecast');
        if (!response.ok) throw new Error('Network response was not ok');
        const data = await response.json();

        const tableBody = document.querySelector('#weatherData');
        tableBody.innerHTML = '';

        data.forEach(item => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${new Date(item.date).toLocaleDateString()}</td>
                <td>${item.temperatureC} &deg;C</td>
                <td>${item.temperatureF} &deg;F</td>
                <td>${item.summary}</td>
            `;
            tableBody.appendChild(row);
        });
    } catch (error) {
        console.error('Fetch error:', error);
    }
};
EOF
)
fi

# Define framework-specific attributes
declare -A ClickAttributeMap=(
    [react]="onClick"
    [vue]="@click"
    [svelte]="onclick"
    [qwik]="onClick\$"
    [angular]="(click)"
    [solid]="onClick"
    [preact]="onClick"
    [lit]="@click"
    [marko]="onClick()"
    [vanilla]="onclick"
    [others]="onclick"
)

declare -A CountValueMap=(
    [react]="{count}"
    [vue]="{{ count }}"
    [svelte]="{count}"
    [qwik]="{count.value}"
    [angular]="{{ count }}"
    [solid]="{count()}"
    [preact]="{count}"
    [lit]='${this.count}'
    [marko]='${count}'
    [vanilla]='${count}'
    [others]='{count}'
)

clickAttr="${ClickAttributeMap[$framework]:-${ClickAttributeMap[others]}}"
countValue="${CountValueMap[$framework]:-${CountValueMap[others]}}"

# Generate counter button HTML
if [[ "$framework" == "lit" ]]; then
    counterButton=$(cat <<EOF
  <p id="counterValue"  $className="display-3 text-center">$countValue</p>
  <div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $clickAttr="\${this.increment}">Increment</button>
    <button $className="btn btn-warning" $clickAttr="\${this.decrement}">Decrement</button>
    <button $className="btn btn-danger" $clickAttr="\${this.reset}">Reset</button>
  </div>
EOF
)
elif [[ "$framework" == "vanilla" ]]; then
    counterButton=$(cat <<EOF
  <p id="counterValue"  $className="display-3 text-center">$countValue</p>
  <div $className="d-flex justify-content-center gap-3">
    <button id="incrementBtn" class="btn btn-success">Increment</button>
    <button id="decrementBtn" class="btn btn-warning">Decrement</button>
    <button id="resetBtn" class="btn btn-danger">Reset</button>
  </div>
EOF
)
elif [[ "$framework" == "marko" ]]; then
    counterButton=$(cat <<EOF
  <p id="counterValue"  $className="display-3 text-center">$countValue</p>
  <div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $clickAttr="{increment()}">Increment</button>
    <button $className="btn btn-warning" $clickAttr="{decrement()}">Decrement</button>
    <button $className="btn btn-danger" $clickAttr="{reset()}">Reset</button>
  </div>
EOF
)
elif [[ "$framework" == "angular" ]]; then
    counterButton=$(cat <<EOF
  <p id="counterValue"  $className="display-3 text-center">$countValue</p>
  <div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $clickAttr="increment()">Increment</button>
    <button $className="btn btn-warning" $clickAttr="decrement()">Decrement</button>
    <button $className="btn btn-danger" $clickAttr="reset()">Reset</button>
  </div>
EOF
)
else
    counterButton=$(cat <<EOF
  <p id="counterValue"  $className="display-3 text-center">$countValue</p>
  <div $className="d-flex justify-content-center gap-3">
    <button $className="btn btn-success" $clickAttr="{increment}">Increment</button>
    <button $className="btn btn-warning" $clickAttr="{decrement}">Decrement</button>
    <button $className="btn btn-danger" $clickAttr="{reset}">Reset</button>
  </div>
EOF
)
fi

# Final counter section
counterContent = cat <<EOF
<section $className="container px-4 py-5">
  <h1 $className="display-2 text-secondary text-center py-4">Counter</h1>
  <p $className="text-center lead">This is a simple counter component.</p>
  $counterButton
</section>
EOF

get_react_component(){
    local htmlContent="$1"        # HTML content to be wrapped
    local componentName="$2"      # Name of the React component
    local scripts="$3"            # Additional scripts to be included
    local imports="$4"            # Import statements for the component

cat <<EOF
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
EOF
}

get_vue_component(){
    local htmlContent="$1"        # HTML content to be wrapped
    local componentName="$2"      # Name of the Vue component
    local scripts="$3"            # Additional scripts to be included
    local imports="$4"            # Import statements for the component

cat <<EOF
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
EOF
}

get_svelte_component(){
    local htmlContent="$1"        # HTML content to be wrapped
    local componentName="$2"      # Name of the Svelte component
    local scripts="$3"            # Additional scripts to be included
    local imports="$4"            # Import statements for the component

cat <<EOF
<script lang='$variantLanguage'>
$imports
$Interface
$scripts
</script>

$htmlContent

<style>
$styles
</style>
EOF
}


get_lit_component() {
    local htmlContent="$1"
    local componentName="$2"
    local scripts="$3"
    local imports="$4"

    local _ElementName
    _ElementName=$(convert-cases "$componentName" "PascalCase")

    local formatedComponentName
    formatedComponentName=$(convert-cases "$componentName" "LowerCase")

    local forTitle=""
    if [[ "$componentName" == "WeatherForecast" || "$componentName" == "Counter" || "$componentName" == "Home" ]]; then
        forTitle=$(cat <<EOF
    connectedCallback(){
        super.connectedCallback();
        document.title = '${componentName}';
    }
EOF
)
    fi

    cat <<EOF
import { LitElement, html, css } from 'lit';
import {customElement} from 'lit/decorators.js';
$imports
$interface
@customElement('${formatedComponentName}-element')
export class ${_ElementName} extends LitElement {
    createRenderRoot() {
        // Render into light DOM (no Shadow DOM)
        return this;
    }
    $forTitle
    static styles = css\`
        /* Add your styles here */
    \`;
    $scripts
    render() {
        return html\`
            $htmlContent
        \`;
    }
}

declare global {
  interface HTMLElementTagNameMap {
    '${formatedComponentName}-element': ${_ElementName};
  }
}
EOF
}


get-qwik-component(){
    local htmlContent="$1"        # HTML content to be wrapped
    local scripts="$2"            # Additional scripts to be included
    local imports="$3"            # Import statements for the component

cat <<EOF
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
EOF

}

get-marko-component() {
    local htmlContent="$1"        # HTML content to be wrapped
    local scripts="$2"            # Additional scripts to be included
    local imports="$3"            # Import statements for the component
    local styles="$4"             # Styles for the component

    if [ $styles != "" ]; then
        $_style = $styles
    fi
    if [ $imports != "" ]; then
        $_import = $imports
    fi
    if [ $scripts != "" ]; then
        $_script = $scripts
    fi

return $(cat <<EOF
$_import
$_script
$htmlContent
EOF
)
}

get_vanilla_component() {
    local htmlContent="$1"        # HTML content to be wrapped
    local scripts="$2"            # Additional scripts to be included
    local imports="$3"            # Import statements for the component
    local componentName="$4"      # Name of the component
    local additionalScripts="$5"

_extra=""
    if [ $imports ]; then
        $_extra = $imports
    fi
    if [ $additionalScripts ]; then
        $_extra = $additionalScripts
    fi
_setup=""
    if [ $componentName == "WeatherForecast" ] || [ $componentName == "Counter" ]; then
        $_setup = ", setup"
    fi
    echo $(cat <<EOF
const $componentName = () => {
    $_extra
    const section = document.createElement('div');
    section.className = 'w-100 m-auto';
    section.innerHTML = \`
            $htmlContent
    \`;
    $scripts
    return {html:section $_setup};
};
export default $componentName;
EOF
)
}


get_wrapped_template() {
    local htmlContent="$1"
    local templateName="$2"

    extraImports=""
    extraScript=""
    weatherInterface=""

    case "$framework" in
        react)
            if [[ "$templateName" == "WeatherForecast" ]]; then
                extraImports=$(cat <<EOF
import { useEffect, useState } from 'react';
$weatherInterface
EOF
)
                extraScript=$(cat <<EOF
$fetchDataFunction

useEffect(() => {
    fetchData();
}, []);
EOF
)
            elif [[ "$templateName" == "Counter" ]]; then
                extraImports=$(cat <<EOF
import { useState } from 'react';
EOF
)
                extraScript=$(cat <<EOF
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
EOF
)
            fi
            get_react_component "$htmlContent" "$templateName" "$extraScript" "$extraImports"
            ;;
        
        preact)
            if [[ "$templateName" == "WeatherForecast" ]]; then
                extraImports=$(cat <<EOF
import { useEffect, useState } from 'preact/hooks';
$weatherInterface
EOF
)
                extraScript=$(cat <<EOF
$fetchDataFunction

useEffect(() => {
    fetchData();
}, []);
EOF
)
            elif [[ "$templateName" == "Counter" ]]; then
                extraImports=$(cat <<EOF
import { useState } from 'preact/hooks';
EOF
)
                extraScript=$(cat <<EOF
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
EOF
)
            fi
            get_react_component "$htmlContent" "$templateName" "$extraScript" "$extraImports"
            ;;
        
        solid)
            if [[ "$templateName" == "WeatherForecast" ]]; then
                extraImports=$(cat <<EOF
import { createSignal, onMount } from 'solid-js';
$weatherInterface
EOF
)
                extraScript=$(cat <<EOF
$fetchDataFunction

onMount(() => {
    fetchData();
});
EOF
)
            elif [[ "$templateName" == "Counter" ]]; then
                extraImports=$(cat <<EOF
import { createSignal } from 'solid-js';
EOF
)
                extraScript=$(cat <<EOF
const [count, setCount] = createSignal(0);

const increment = () => {
    setCount(count() + 1);
};

const decrement = () => {
    setCount(count() - 1);
};

const reset = () => {
    setCount(0);
};
EOF
)
            fi
            get_react_component "$htmlContent" "$templateName" "$extraScript" "$extraImports"
            ;;
        
        vue)
            if [[ "$templateName" == "WeatherForecast" ]]; then
                extraImports=$(cat <<EOF
import { onMounted } from 'vue';
EOF
)
                extraScript=$(cat <<EOF
$fetchDataFunction
onMounted(() => {
 fetchData();    
});
EOF
)
            elif [[ "$templateName" == "Counter" ]]; then
                extraImports=$(cat <<EOF
import { ref, computed } from 'vue';
EOF
)
                extraScript=$(cat <<EOF
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
EOF
)
            fi
            get_vue_template "$htmlContent" "$extraScript" "$extraImports" ""
            ;;
        
        # … (same pattern for lit, svelte, qwik, vanilla, marko)
        
        *)
            echo "Unsupported framework: $framework"
            return 1
            ;;
    esac
}

homeContent = ""

if [ $framework == "react" ] || [ $framework == "preact" ] || [ $framework == "solid" ] || [ $framework == "qwik" ] || [ $framework == "lit" ] || [ $framework == "svelte" ] || [ $framework == "vanilla" ] || [ $framework == "angular" ] || [ $framework == "marko" ]; then
    $homeContent = get_home_content $framework -Mode "import" -Links $frameworkLink  -Class $className
else 
    $homeContent = get_home_content $framework -Mode "html" -Links $frameworkLink -Class $className


fetchDataContent = ""
if [ $framework == "lit" ] || [ $framework == "svelte" ] || [ $framework == "solid" ] || [ $framework == "react" ] || [ $framework == "preact" ] || [ $framework == "angular" ] || [ $framework == "qwik" ] || [ $framework == "marko" ]; then
    $fetchDataContent = get_fetch_content -Content $true
else
    $fetchDataContent = get_fetch_content
fi

#All components and pages with raw HTML content
componentsTemplates=(
    "Navbar:$navbarContent"
    "Footer:$footerContent"
    "Home:$homeContent"
    "Counter:$counterContent"
    "WeatherForecast:$fetchDataContent"
)

if [ "$framework" = "angular" ]; then
    pushd ./ClientApp || exit

    # Create Angular components
    for compItem in "${componentsTemplates[@]}"; do
        compName="${compItem%%:*}"
        compNamePascal="$(echo "$compName" | sed -E 's/(^|_)([a-z])/\U\2/g')"

        if [ "$compNamePascal" = "Navbar" ] || [ "$compNamePascal" = "Footer" ]; then
            compPath="./components/${compName,,}"
        else
            compPath="./pages/${compName,,}"
        fi

        echo "Creating Angular component: $compPath"
        ng g c "$compPath"
    done

    npm i bootstrap

get_add_to_file_content "./src/app/" "app.routes.ts" \
"import { Home } from './pages/home/home';
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
];" \
    "export const routes: Routes = \[\];" "replace"

    cat <<EOF > "./src/app/app.html"
<app-navbar/>
<div class="container">
  <router-outlet></router-outlet>
</div>
<app-footer/>
EOF

get_add_to_file_content "./src/app/" "app.ts" \
"import { Navbar } from './components/navbar/navbar';
import { Footer } from './components/footer/footer';" \
    "import { RouterOutlet } from '@angular/router';" "below"

get_add_to_file_content "./src/app/" "app.ts" \
"imports: [RouterOutlet, Navbar, Footer]," \
    "\[RouterOutlet\]" "replace"

    # Add Home Page content
    for compItem in "${componentsTemplates[@]}"; do
        name="${compItem%%:*}"
        content="${compItem#*:}"

        if [ "$name" = "Navbar" ] || [ "$name" = "Footer" ]; then
            path="./src/app/components/${name,,}"
        else
            path="./src/app/pages/${name,,}"
        fi

        mkdir -p "$path"
        echo "$content" > "$path/${name,,}.html"

        if [ "$name" = "Home" ]; then
            get_add_to_file_content "$path/" "${name,,}.ts" \
"        viteLogo = \"vite.svg\";
        dotnetLogo = \"dotnet.svg\";
        angularLogo = \"angular.svg\";" \
                "export class ${name,,} \{" "below"

        elif [ "$name" = "Counter" ]; then
            get_add_to_file_content "$path/" "${name,,}.ts" \
"  public count: number = 0;

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
  }" \
                "export class ${name,,} \{" "below"

        elif [ "$name" = "WeatherForecast" ]; then
            get_add_to_file_content "$path/" "${name,,}.ts" \
"$fetchDataFunction
ngOnInit() {
    this.fetchData();
}
formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString();
}" \
                "export class ${name,,} \{" "below"

            get_add_to_file_content "$path/" "${name,,}.ts" \
"import { Component, OnInit, signal} from '@angular/core';

$_IWeatherInterface" \
                "import { Component }" "replace"

            get_add_to_file_content "$path/" "${name,,}.ts" \
"export class Weatherforecast implements OnInit {" \
                "export class Weatherforecast \{" "replace"
        fi
    done

    get_add_to_file_content "./" "package.json" \
'    "dev": "ng serve",' \
    '"build":' "above"

    get_add_to_file_content "./" "angular.json" \
'              "node_modules/bootstrap/dist/css/bootstrap.min.css",' \
    '"src/styles.css"' "above"

    get_add_to_file_content "../views/shared/" "_Layout.cshtml" \
'' \
    'href="/lib/dist/bootstrap.min.css"' "replace"

    cat <<EOF > "./src/styles.css"
$mainStyle
.logo.angular:hover {
  filter: drop-shadow(0 0 2em #e205a7aa);
}
EOF

    popd || exit

  get_add_to_file_content "./views/shared/" "_Layout.cshtml" '<link rel="stylesheet" href="http://localhost:4200/styles.css" />' 'vite/client' "above"
else
    if [[ $framework == "marko" ]]; then
        $componentsPath = $tagsPath
    fi
    for templateItem in "${componentsTemplates[@]}"; do
        name="${templateItem%%:*}"
        content="${templateItem#*:}"
        
        wrappedContent="$(get_wrapped_template "$content" "$name")"
        
        if [[ "$name" == "Navbar" || "$name" == "Footer" ]]; then
            path="$componentsPath/$name.$extension"
        else
            path="$pagesPath/$name.$extension"
        fi
        
        # Write wrapped content to file with UTF-8 encoding
cat << EOF > $path
	$wrappedContent
EOF
    done
# Add import statements for logos in Home component
	if [[ "$framework" == "react" || "$framework" == "preact" || "$framework" == "solid" || "$framework" == "vanilla" ]]; then
		get_add_to_file_content "$clientPath/src/pages" "Home.$variantLanguage" "$svgImports" "const Home " "above"
	elif [[ "$framework" == "qwik" ]]; then
		get_add_to_file_content "$clientPath/src/pages" "Home.$variantLanguage" "$svgImports" "export default component" "above"
	elif [[ "$framework" == "marko" ]]; then
		get_add_to_file_content "$clientPath/src/pages" "Home.marko" "$svgImports" "\<section class='" "above"
	elif [[ "$framework" == "lit" ]]; then
		get_add_to_file_content "$clientPath/src/pages" "Home.$variantLanguage" "$svgImports" "\@customElement" "above"
	elif [[ "$framework" == "svelte" ]]; then
		get_add_to_file_content "$clientPath/src/pages" "Home.$extension" "$svgImports" "\<\/script\>" "above"
		mv "$clientPath/public/assets/"*.svg "$clientPath/public/"
	fi

# Remove HelloWorld component if framework is not marko
	if [[ "$framework" != "marko" ]]; then
		rm -f "$clientPath/src/components/HelloWorld.$extension"
	fi

# Modify App entry point path

	if [[ "$framework" == "preact" || "$framework" == "qwik" ]]; then
		appPath="$clientPath/src/app.$extension"
	else
		appPath="$clientPath/src/App.$extension"
	fi

	get_app_config(){
		local frame="$1" # e.g., react, svelte, angular
		local variants="$2" # e.g., ts, js, jsx
		declare -g app="" 
		case "$frame" in
        react)
$app=$(cat <<EOF
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
                        const filePath = \`${componentPath}.$variantLanguages\`; // Must match glob
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
EOF
)
cat << EOF > $clientPath"/src/index.css"
   $mainStyle
EOF
> $clientPath"/src/App.css"
cp "$clientPath\public\assets\react.svg" "$clientPath\public"
npm i react-router bootstrap
get_add_to_file_content "$clientPath/src/" "main.$variantLanguage" "import 'bootstrap/dist/css/bootstrap.min.css';" "import App from " "above"
            ;;
        solid)
$app = $(cat <<EOF
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
EOF
)
npm i @solidjs/router bootstrap
cat > $clientPath"/src/App.css" << EOF
$mainStyle
.logo.solid:hover {
  filter: drop-shadow(0 0 2em #61dafbaa);
}
EOF
> $clientPath"/src/index.css"
get_add_to_file_content "$clientPath/src/" "index.$variantLanguage" "import 'bootstrap/dist/css/bootstrap.min.css';" "import \'.\/index.css\'" "above"
rename "$clientPath/src/index.$variantLanguage" "main.$variantLanguage"

            ;;
        vue)
$app=$(cat <<EOF
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
EOF
)
npm i vue-router bootstrap

cat > "$clientPath/src/route.$variantLanguage" <<EOF
import { createRouter, createWebHistory  } from 'vue-router';
import { routes as config } from './router.config';

const pages = import.meta.glob<() => Promise<any>>('./pages/**/*.vue');

const routes = config.map(route => {
  const filePath = \`\${route.componentPath}.vue\`;

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
EOF
cat > "$clientPath/src/style.css" <<EOF
$mainStyle
EOF
_add=$(cat <<EOF
import router from './route';
import 'bootstrap/dist/css/bootstrap.min.css';
EOF
)
get_add_to_file_content "$clientPath/src/"  "main.$variantLanguage" "$_add" "import App from" "below"
get_add_to_file_content "$clientPath/src/"  "main.$variantLanguage" "createApp(App).use(router).mount('#app');" "createApp\(App\)" "replace"
            ;;
        lit)
cat >  "$clientPath/src/main.$variantLanguage" <<EOF
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
    return html \`
        <app-element></app-element>
    \`;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'main-element': MainElement;
  }

}
EOF
cat > "$clientPath/src/index.css" <<EOF
@import "./node_modules/bootstrap/dist/css/bootstrap.min.css";
$mainStyle
EOF
rm -r "$clientPath/src/my-element.$variantLanguage"
cat > $clientPath"/index.html" <<EOF
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
EOF
npm i @lit-labs/router bootstrap
            ;;
        svelte)
$app=$(cat <<EOF
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
EOF
)
npm i svelte-routing bootstrap
cat > "$clientPath/src/app.css" <<EOF
$mainStyle
EOF
get_add_to_file_content "$clientPath/src/" "main.$variantLanguage" "import 'bootstrap/dist/css/bootstrap.min.css';" "import \'.\/app.css\'" "above"
            ;;
        qwik)
$app= $(cat <<EOF
import { component$, useSignal, useVisibleTask$ } from '@builder.io/qwik';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import Home  from './pages/Home';
import Counter from './pages/Counter';
import WeatherForecast from './pages/WeatherForecast';
import './app.css';

export default component\$(() => {
  const currentPath = useSignal(window.location.pathname);

  const renderComponent = () => {
    switch (currentPath.value) {
      case '/counter':
        return <Counter />; //for lazy loading, you can use lazy\$(() => import('./pages/Counter')) by importing lazy 
      case '/fetch-data':
        return <WeatherForecast />;
      default:
        return <Home />;
    }
  };

  useVisibleTask\$(() => {
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
EOF
)
npm i bootstrap
get_add_to_file_content "$clientPath/src/" "main.$variantLanguage" "import 'bootstrap/dist/css/bootstrap.min.css';"  "import \'.\/index.css\'" "above"
get_add_to_file_content "$clientPath/src/" "main.$variantLanguage" "import App from './app.$variantLanguage';"  "import { App } from " "replace"
> "$clientPath/src/index.css"
cat <<EOF > "$clientPath/src/app.css" 
$mainStyle
.logo.qwik:hover {
  filter: drop-shadow(0 0 2em #673ab8aa);
}
EOF
mv "$clientPath/public/assets/*.svg" "$clientPath/public/"
            ;;
        marko)
cat <<EOF >  ".\clientapp\src\pages\index.marko" 
<Navbar />
<main id="router-view"></main>
<App-Footer />
EOF
cat <<EOF >  ".\clientapp\src\main.$variantLanguage" 
import { initRouter } from "./router";

initRouter(document.getElementById("app"));
EOF

get_add_to_file_content ".\Views\shared\\"  "_Layout.cshtml"  '<link rel="stylesheet" href="http://localhost:5173/src/styles.css">'  "vite\/client"  "above"
get_add_to_file_content ".\Views\shared\\"  "_Layout.cshtml"  '<link rel="stylesheet" href="/bootstrap.min.css">'  "vite\/client"  "above"
mv  "./wwwroot/lib/bootstrap/dist/css/bootstrap.min.css" "./wwwroot"
cat <<EOF > ".\\${clientPath}\\index.html"
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
    <script type="module" src="/src/main.${variantLanguage}"></script>
</body>
</html>
EOF

cat <<EOF >  ".\\${clientPath}\\src\\styles.css"
$mainStyle

.logo.marko:hover {
filter: drop-shadow(0 0 1em #ff036caa);
}
EOF

cat  <<EOF >  ".\\${clientPath}\\public\\vite.svg" 
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFEA83"></stop><stop offset="8.333%" stop-color="#FFDD35"></stop><stop offset="100%" stop-color="#FFA800"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
EOF

cat <<EOF > ".\\${clientPath}\\public\\marko.svg" 
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
EOF

    cat <<EOF >  ".\\${clientPath}\\public\\dotnet.svg" 
    <svg width="456" height="456" viewBox="0 0 456 456" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="456" height="456" fill="#512BD4"/>
    <path d="M81.2738 291.333C78.0496 291.333 75.309 290.259 73.052 288.11C70.795 285.906 69.6665 283.289 69.6665 280.259C69.6665 277.173 70.795 274.529 73.052 272.325C75.309 270.121 78.0496 269.019 81.2738 269.019C84.5518 269.019 87.3193 270.121 89.5763 272.325C91.887 274.529 93.0424 277.173 93.0424 280.259C93.0424 283.289 91.887 285.906 89.5763 288.11C87.3193 290.259 84.5518 291.333 81.2738 291.333Z" fill="white"/>
    <path d="M210.167 289.515H189.209L133.994 202.406C132.597 200.202 131.441 197.915 130.528 195.546H130.044C130.474 198.081 130.689 203.508 130.689 211.827V289.515H112.149V171H134.477L187.839 256.043C190.096 259.57 191.547 261.994 192.192 263.316H192.514C191.977 260.176 191.708 254.859 191.708 247.365V171H210.167V289.515Z" fill="white"/>
    <path d="M300.449 289.515H235.561V171H297.87V187.695H254.746V221.249H294.485V237.861H254.746V272.903H300.449V289.515Z" fill="white"/>
    <path d="M392.667 187.695H359.457V289.515H340.272V187.695H307.143V171H392.667V187.695Z" fill="white"/>
    </svg>
EOF
mv "$clientPath/src/tags/Footer.marko"  "App-Footer.marko"
            ;;
        vanilla)
            echo "// Vanilla JS entry point for ${frame} framework."
			;;
			*)
			echo "Invalid"
    esac
}
get_app_config "$framework" "$variantLanguage"
fi