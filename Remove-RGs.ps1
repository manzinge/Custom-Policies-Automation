param (
    [String]$Tenant,
    [Bool]$testmode = $true
)

function Test-AzureConnection {
    Write-host "Checking Azure Connection" -ForegroundColor Green
    try{
        if([String]::IsNullOrEmpty((Get-AzContext)[0].SubscriptionName)) {
            if([String]::IsNullOrEmpty($tenant)){
                Connect-AzAccount
            }
            else {
                Connect-AzAccount -Tenant $Tenant
            }
        }
    }catch{
        Write-host "Error during Azure Connection establishment : $($error.exception.message)" -ForegroundColor Red
        exit 1
    }
}

function Get-AzureSubscriptions {
    Write-host "Getting Subscriptions" -ForegroundColor Green
    try{
        $currentTenant = (Get-azcontext).Tenant.Id
        $subscriptions = Get-AzSubscription | ? {$_.TenantId -eq $currentTenant}
        return $subscriptions
    }catch{
        Write-host "Could not get Subscriptions because : $($error.exception.message)" -ForegroundColor Red
        exit 1
    }
}

function Remove-ResourceGroups($subscriptions) {
    foreach($sub in $subscriptions) {
        Set-AzContext -SubscriptionObject $sub | Out-Null
        Write-host "Deleting all ResourceGroups in subscription $($sub.name)" -ForegroundColor Yellow
        try{
            if($testmode) {
                Get-AzResourceGroup | % {Write-host "($($sub.name)) Would delete $($_.resourcegroupname)" }
            }else {
                Get-azresourcegroup | Remove-AzResourceGroup -force | Out-Null
                Write-host "Removed all ResourceGroups in subscription $($sub.name)" -ForegroundColor Green
            }
        }catch{
            Write-host "Could not remove all ResourceGroups in subscription $($sub.name) because of $($error.exception.message)" -ForegroundColor Red
            exit 1
        }
    }
}


function main {
    try{
        Test-AzureConnection
        $subscriptions = Get-AzureSubscriptions
        Remove-ResourceGroups($subscriptions)
    }catch{
        Write-host "Unhandeled Error : $($error.exception.message)" -ForegroundColor Red
        exit 1
    }
}

main