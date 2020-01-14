param(
    [String]$directory,
    [String]$tenant
)

function Request-Module {
    if(!(get-module AzureADPreview -ListAvailable)) {
        try {
            Write-Host "Installing AzureADPreview Module" -ForegroundColor Yellow
            Install-Module AzureADPreview -force -AllowClobber
            Import-module AzureADPreview
        }catch{
            Write-host "Could not install AzureAD Module because of : $($error.exception.message)" -ForegroundColor Red
            exit
        }
    }
    Import-module AzureADPreview
}

if([String]::IsNullOrEmpty($directory)) {
    $directory = $PSScriptRoot
}

function Test-AzureConnection {
    try{
        get-azureadtenantDetail -ErrorAction stop | out-null
    }catch{
        try{
            Write-host "First you have to connect to Azure AD" -ForegroundColor Yellow
            if($tenant) {
                Connect-AzureAD -TenantId $tenant -ErrorAction Stop
            }else {
                Connect-AzureAD -ErrorAction Stop
            }
        }catch{
            Write-host "Could not connect to azureAd because : $($error.exception.message)" -ForegroundColor Red
            exit 1
        }
    }
}

function UploadPolicies {
    Write-Progress -Activity "Uploading Custom Policies" -Status "Getting Files" -PercentComplete 0 
    $files = gci $directory | ? {$_.Name -like "*B2C*"}
    $counter = 0
    foreach($file in $files) {
        try{
            $counter++
            $id = $file.Name.Substring($file.Name.IndexOf("B2C")).Split('.')[0]
            Write-Progress -Activity "Uploading Custom Policies" -Status "Uploading $id" -PercentComplete (($counter/$files.count) * 100)
            Set-AzureADMSTrustFrameworkPolicy -Id $id -InputFilePath $file.FullName | Out-Null
            Write-host "Successfully updated $id" -ForegroundColor Green
        }catch{
            Write-host "Could not set Policy : $($file.name) because of : $($error.exception.message)" -ForegroundColor Red
        }
    }
}
function main {
    try{
        Request-Module
        Test-AzureConnection
        UploadPolicies
    }catch{
        Write-host "Encountered unexpected Error : $($error.exception.message)" -ForegroundColor Red
        exit 1
    }
}

main