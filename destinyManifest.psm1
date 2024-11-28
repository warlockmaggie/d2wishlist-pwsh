#Requires -Modules PSSQLite
Import-Module PSSQLite


function Get-DestinyManifest()
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $ApiKey="vootvoot",
        [Parameter()]
        [string]
        $Url = "https://www.bungie.net/Platform/Destiny2/Manifest/"
    )

    $datetime = ((get-date -Format "o") -split "T")[0]
    

    try {
        $output = Invoke-WebRequest -Headers @{"X-API-Key"=$ApiKey} -Uri $Url
        $manifestResponse = (ConvertFrom-Json $output).Response
        $manifestFile = "destiny-manifest-$datetime.sqlite3.zip"
        $actualManifest = $manifestResponse.mobileWorldContentPaths.en
        Invoke-WebRequest -Uri "https://www.bungie.net$actualManifest" -OutFile $ManifestFile
        Expand-Archive -Path $manifestFile -DestinationPath . -Force
        Remove-Item $manifestFile,"manifest.sqlite3" -ErrorAction SilentlyContinue
        Rename-item (get-item *.content | select -ExpandProperty Name) "manifest.sqlite3" -Force
    } catch {
        Write-Error "Failed to download manifest. Error: $($_.Exception.Message)"
    }

    write-host "Downloaded and unzipped Manifest at ./manifest.sqlite3"
}
function sql_id($hash)
{
    $id = [uint32]($hash)
    $MAX = 2147483648
    if(($id -band $MAX) -ne 0)
    {
        $id = $id - 1 * [Math]::pow(2,32)
    }
    return $id
}


function New-ManifestQuery($table,$hash)
{
    $id = sql_id $hash
    $result = Invoke-SqliteQuery "Select json from $table where id = $id" -DataSource .\manifest.sqlite3
    $json = [System.Text.Encoding]::UTF8.GetString($result.json)
    return $json
}

class PlugSet {
    [string]$hash
    [string]$definition
    


    PlugSet([string]$hash) { 
        $def = (New-ManifestQuery "DestinyPlugSetDefinition" $hash)
        $this.Init(@{hash = $hash;definition=$def})
    }
    PlugSet([hashtable]$Properties) { $this.Init($Properties) }

    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
    }

    [System.Collections.ArrayList] ReuseablePlugItems()
    {
        $temp = [System.Collections.ArrayList]::new()
        $definitionObj = $this.definition | ConvertFrom-Json
        foreach($p in $definitionObj.reusablePlugItems)
        {
            $item = [InventoryItem]::new($p.plugItemHash)
            # skip enhanced perks
            if(!$item.IsEnhanced()) {
                $temp.Add( $item ) | Out-Null
            }
        }
        return $temp
    }
}

class InventoryItem {
    [string]$hash
    [string]$definition
    [string]$name
    [System.Collections.ArrayList]$sockets = [System.Collections.ArrayList]::new()

    InventoryItem() { $this.Init(@{}) }
    InventoryItem([string]$hash) {
        $def = (New-ManifestQuery "DestinyInventoryItemDefinition" $hash)
        $nam = ($def | ConvertFrom-Json).DisplayProperties.Name
        $this.Init(@{
            hash = $hash;
            name = $nam;
            definition = $def;
        })
    }
    InventoryItem([hashtable]$Properties) { $this.Init($Properties) }

    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
    }

    [string] ToString() {
        return [string]::Format("{0} [{1}]",$this.name,$this.hash)
    }

    [bool] IsEnhanced()
    {
        $definitionObj = $this.definition | ConvertFrom-Json
        return ($definitionObj.itemTypeDisplayName -eq "Enhanced Trait")

    }

    [void] LoadSockets() {
        
        $WEAPON_PERKS = 4241085061

        $definitionObj = $this.definition | ConvertFrom-Json
        $indexes = $definitionObj.sockets.socketCategories | `
         Where-Object {$_.socketCategoryHash -eq $WEAPON_PERKS} | `
         Select-Object -ExpandProperty socketIndexes

        foreach($index in $indexes)
        {
            
            $plugs = @{}
            $entry = $definitionObj.sockets.socketEntries[$index]
            foreach($plug in $entry.reusablePlugItems)
            {
                $plugItem = [InventoryItem]::new($plug.plugItemHash)
                $plugs.Add($plugItem.hash, $plugItem) | Out-Null
            }

            $plugType = $entry.PSObject.Properties.Name | Where-Object {$_ -in @("randomizedPlugSetHash", "reusablePlugSetHash")}

            if($plugType)
            {
                $plugSet = [PlugSet]::new($entry.$plugType)
                foreach($plugItem in $plugSet.ReuseablePlugItems())
                {
                    try {
                        $plugs.add($plugItem.hash, $plugItem)
                    } catch {
                        continue
                    }
                }
            }

            $this.sockets.Add($plugs) | Out-Null
        }
    }
}

$ExportableTypes =@(
    [InventoryItem],[PlugSet]
)

# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        $Message = @(
            "Unable to register type accelerator '$($Type.FullName)'"
            'Accelerator already exists.'
        ) -join ' - '

        throw [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            'TypeAcceleratorAlreadyExists',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $Type.FullName
        )
    }
}
# Add type accelerators for every exportable type.
foreach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach($Type in $ExportableTypes) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()