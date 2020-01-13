param(
    [String]$ConnectionString,
    [String]$directory,
    [String]$container
)

function CheckForModule {
    if(!(get-module Azure.Storage -ListAvailable)) {
        try {
            Write-Host "Installing Azure.Storage Module" -ForegroundColor Yellow
            Install-Module Azure.Storage -force -AllowClobber
            Import-module Azure.Storage
        }catch{
            Write-host "Could not install Azure.Storage Module because of : $($error.exception.message)" -ForegroundColor red
            exit
        }
    }
    Import-module Azure.Storage
}

if([String]::IsNullOrEmpty($directory)) {
    $directory = $PSScriptRoot
}

function CreateNewContext {
    $context = $null
    if([String]::IsNullOrEmpty($ConnectionString)) {
        $context = New-azurestoragecontext -connectionstring (Read-Host -Prompt "Please enter your Storage Connection String")
    }else {
        $context = New-azurestoragecontext -connectionstring $ConnectionString
    }
    return $context
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
function UploadFiles($context) {
    $files = gci $directory 
    if([String]::IsNullOrEmpty($container)) {
        $container = (Read-Host -Prompt "Please enter the desired Container (You can also create one)")
    }
    $tmp = Get-azurestoragecontainer -Context $context -name $container -ErrorAction SilentlyContinue
    if($tmp.count -eq 0) {
        New-AzureStorageContainer -Name $container -Context $context | Out-Null
        Set-AzureStorageContainerAcl -Name $container -Permission blob -Context $context
        Write-host "A new storage container with Name : $container was created!"
    }
    if((Get-azurestoragecontaineracl -name $container -Context $context).PublicAccess -ne "Blob") {
        Write-host "WARNING: Your ACL is not set to Blob, this might interfere with your CORS / Access from Custom Policy" -ForegroundColor Yellow
    }
    $counter = 0
    foreach($file in $files) {
        $counter++
        try{
            Set-AzureStorageBlobContent -Container $container -Context $context -File $file.FullName | Out-null
            Write-Progress -Activity "Uploading Template Files" -Status "Uploading $($file.Name)" -PercentComplete (($counter/$files.count) * 100)
            Write-host "successfully uploaded file : $($file.Name) to Container $container" -ForegroundColor Green
        }catch{
            Write-host "could not upload file $($file.Name) because of : $($error.exception.message)" -ForegroundColor Red
        }
        
    }
}

function main {
    try{
        CheckForModule
        $ctx = CreateNewContext
        UploadFiles -Context $ctx
    }catch{
        Write-host "Encountered unexpected Error : $($error.exception.message)" -ForegroundColor Red
        exit 1
    }
}

main