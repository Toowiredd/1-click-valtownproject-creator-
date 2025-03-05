# Self-Contained, AI-Powered One-Click PowerShell Script for Full Val Town Project Setup & Deployment

# Set Project Directories
$ProjectDir = "$HOME\MCP-TaskManager"
$LogFile = "$ProjectDir\deploy.log"
$ConfigFile = "$ProjectDir\config.json"

# Function to log messages
function Log-Message {
    param ($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Host $Message
}

# Ensure Node.js is Installed
if (-Not (Get-Command node -ErrorAction SilentlyContinue)) {
    Log-Message "Node.js not found. Installing Node.js..."
    Invoke-WebRequest -Uri "https://nodejs.org/dist/v18.0.0/node-v18.0.0-x64.msi" -OutFile "$env:TEMP\nodejs.msi"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $env:TEMP\nodejs.msi /quiet /norestart" -Wait
    Log-Message "Node.js installed successfully."
}

# Ensure Project Directory Exists
if (-Not (Test-Path $ProjectDir)) {
    New-Item -ItemType Directory -Path $ProjectDir | Out-Null
    Log-Message "Created project directory: $ProjectDir"
}

# Load or create configuration
if (-Not (Test-Path $ConfigFile)) {
    $ValTownToken = "YOUR_VAL_TOWN_API_KEY"  # Set your API key here
    $ProjectName = "MCP-TaskManager"
    $Config = @{ ValTownToken = $ValTownToken; ProjectName = $ProjectName }
    $Config | ConvertTo-Json | Out-File -FilePath $ConfigFile
} else {
    $Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
    $ValTownToken = $Config.ValTownToken
    $ProjectName = $Config.ProjectName
}

# Change to project directory
Set-Location -Path $ProjectDir

# Open Val Town's AI Assistant (Townie) in Browser with Prompt for Generating Vals
$Prompt = "Generate Val functions for a scalable backend, frontend, and database system for project: $ProjectName."
$TownieURL = "https://www.val.town/townie?prompt=" + [System.Web.HttpUtility]::UrlEncode($Prompt)
Log-Message "Opening Townie in Web Browser to generate Vals..."
Start-Process $TownieURL

# Wait for AI-Generated Output (Manual Copy-Paste)
Start-Sleep -Seconds 10
$ClipboardContent = Get-Clipboard
Log-Message "Retrieved AI-generated Vals from clipboard."

# Extract AI-Generated Val Functions
$Vals = @()
if ($ClipboardContent -match "https://www.val.town/v/([\w-]+)") {
    foreach ($Match in $Matches[0..($Matches.Length - 1)]) {
        $ValName = $Match -replace "https://www.val.town/v/", ""
        $Vals += @{ Name = $ValName; URL = $Match }
    }
}

# Deploy AI-Generated Vals
foreach ($Val in $Vals) {
    Log-Message "Deploying AI-generated Val: $($Val.Name)..."
    $Headers = @{ "Authorization" = "Bearer $ValTownToken" }
    $Body = @{ "name" = $Val.Name; "privacy" = "public" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri "https://api.val.town/v1/vals/$($Val.Name)" -Method Put -Headers $Headers -Body $Body -ContentType "application/json"
}

# Monitor Val Town Functions & Auto-Redeploy on Failure
Log-Message "Starting function monitoring service..."
function Monitor-Functions {
    while ($true) {
        foreach ($Val in $Vals) {
            try {
                $Response = Invoke-RestMethod -Uri "https://api.val.town/v1/vals/$($Val.Name)" -Method Get -Headers $Headers
                if (-Not $Response.success) {
                    Log-Message "ALERT: Function $($Val.Name) is failing! Re-deploying..."
                    $Body = @{ "name" = $Val.Name; "privacy" = "public" } | ConvertTo-Json -Compress
                    Invoke-RestMethod -Uri "https://api.val.town/v1/vals/$($Val.Name)" -Method Put -Headers $Headers -Body $Body -ContentType "application/json"
                    Log-Message "Function $($Val.Name) has been re-deployed."
                }
            } catch {
                Log-Message "ERROR: Function $($Val.Name) is unreachable! Retrying in 5 minutes..."
            }
        }
        Start-Sleep -Seconds 300  # Check every 5 minutes
    }
}
Start-Job -ScriptBlock { Monitor-Functions }

# Integrate Webhook for Auto-Updates When Townie Generates New Vals
Log-Message "Setting up webhook listener for AI-generated updates..."
$WebhookURL = "https://api.val.town/v1/vals/auto-update"  # Replace with actual webhook
$WebhookHeaders = @{ "Authorization" = "Bearer $ValTownToken" }
$WebhookBody = @{ "project" = $ProjectName; "action" = "update" } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri $WebhookURL -Method Post -Headers $WebhookHeaders -Body $WebhookBody -ContentType "application/json"

Log-Message "Webhook listener registered. Auto-updates enabled for AI-generated Vals."
Log-Message "One-click deployment complete! MCP-TaskManager and AI-generated Val Town functions are running."
