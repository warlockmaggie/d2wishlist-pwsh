using module .\destinyManifest.psm1


$TAGMAP = @{
    "pvp"= "PvP"
    "pve"= "PvE"
    "mkb"= "M+KB"
    "controller"= "Controller"
    "dps"= "DPS"
    "gambit"= "Gambit"
}
$TAGORDER = @("pvp","pve","mkb","controller","dps","gambit")

function New-CartesianProductLists
{
    param
    (
        $Lists
    )

    function New-TempList
    {
        param
        (
            $Head, $Tail
        )

        if ($Tail -is [Object[]])
        {
            # List already so just extend
            $Result = ,$Head + $Tail
        }
        else
        {
            # Create List
            $Result = @($Head, $Tail)
        }

        ,$Result
    }

    switch (,$Lists) {
        $Null 
        { 
            break 
        }

        # 1 List so just return it
        { $_.Count -eq 1 } 
        { 
            $_ 
        }

        # More than one list so recurse
        { $_.Count -gt 1 } 
        {  
            $Head = $_[0]
            $Index = $_.Count - 1
            $Tail = $_[1..$Index]

            $Next = New-CartesianProductLists $Tail

            $Result = @()

            foreach ($HeadItem in $Head)
            {
                foreach ($NextItem in $Next)
                {            
                    $Result += ,(New-TempList $HeadItem $NextItem)
                }
            }

            ,$Result
        }
    }    
}


class Recommendation {
    [System.Collections.ArrayList] $tags = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList] $perks = [System.Collections.ArrayList]::new()
    [string] $masterwork = $null

    Recommendation() { $this.Init(@{}) }
    Recommendation([hashtable]$Properties) { $this.Init($Properties) }

    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
    }

    [string] ToString() {
        return [string]::Format("tags={0} masterwork={1}", $($this.tags -join ','), $this.masterwork)
    }

    [void] PrintWishlist($parser, $item, $description)
    {
        $tagString = $tagHeader = $tagFooter = $mw = ""
        $tagsObj = ($this.tags | Sort-Object -Property { $TAGORDER.IndexOf($_) })
        $tagString = ($tagsObj | ForEach-Object{ $TAGMAP[$_] }) -join " / "
        if (![String]::IsNullOrEmpty($tagString))
        {
            $tagHeader = "($tagString)"
            $tagFooter = "|tags:$($tagsObj -join ",")"
        }
        if(![string]::IsNullOrEmpty($this.masterwork))
        {
            $mw = [string]::format("Recommended MW: {0}", $this.masterwork)
        }

        $hashes = [System.Collections.ArrayList]::new()
        foreach($slot in $this.perks)
        {
            $perkHashes = [System.Collections.ArrayList]::new()
            foreach($perk in $slot)
            {
                $perkHash = $item.sockets.values | Where-Object {$_.name -eq $perk}

                if(![string]::IsNullOrEmpty($perkHash))
                {
                    $perkHashes.Add($perkHash) | out-null
                }
                else {
                    Write-Error "Couldn't find hash for perk `"$perk`" for $($item.name) w/ $tagFooter!"
                }
            }
            $hashes.Add($perkHashes) | Out-Null
        }


        $text = "// $($item.name)`n"
        $text += [string]::format("//notes:{0} {1}: `"{2}`" {3}{4}`n",$parser.reviewer,$tagHeader,$description,$mw,$tagFooter)
        foreach($roll in (New-CartesianProductLists $hashes))
        {
            $perkstring = ($roll | ForEach-Object{ $_.hash }) -join ","
            $text += [string]::format("dimwishlist:item={0}&perks={1}`n",$item.hash,$perkstring)
        }
        $text | Tee-Object -FilePath ./output.txt -Append
    }
}

class Weapon {

    [InventoryItem] $item
    [System.Collections.ArrayList] $variants = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList] $recs = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList] $description = [System.Collections.ArrayList]::new()


    Weapon() { $this.Init(@{}) }
    Weapon([InventoryItem]$item) { $this.Init(@{item=$item}) }
    Weapon([hashtable]$Properties) { $this.Init($Properties) }

    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
        if($this.item)
        {
            $this.item.LoadSockets()
        }
    }

    [void] CondensePvp()
    {
        $PvpRolls = $this.recs | Where-Object {"pvp" -in $_.tags }
        if($PvpRolls.Count -eq 2 -and $PvpRolls[0].masterwork -eq $PvpRolls[1].masterwork)
        {
            if((Compare-Object $PvpRolls[0].perks $PvpRolls[1].perks).count -eq 0)
            {
                $tags = $($PvpRolls[1].tags; $PvpRolls[0].tags) | `
                  Sort-Object -Property { $TAGORDER.IndexOf($_) } -Unique
                $PvpRolls[0].tags = $tags
                $this.recs.remove($PvpRolls[1])
            }
        }

    }

    [void] Finish($parser)
    {
        $this.CondensePvp()
		$index = 0
        foreach($rec in $this.recs)
        {

            $descriptionText = $this.description[$index]
            foreach($variant in $this.variants)
            {
                $rec.PrintWishlist($parser, $variant, $descriptionText)
            }
            $rec.PrintWishlist($parser, $this.item, $descriptionText)
			$index++
        }
    }
}

class Parser {
    [string]$heading
    [string]$headerMarker
    [string]$itemSectionMarker
    [string]$recommendationMarker
    [string]$reviewer
    [Weapon]$weapon 

    Parser() { $this.Init(@{}) }
    Parser([hashtable]$Properties) { $this.Init($Properties) }

    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
    }

    #[void] ParseRecommendation([string] $line) { return }

    #[void] ParsePerks([string] $line) { return }

    #[void] ParseItem([string] $line) { return }

    #[void] ProcessLine ([string]$rawLine) { return }
}

class PandaText : Parser
{   
    PandaText(){
        $prop = @{
            reviewer="pandapaxxy"
            headerMarker="###"
            RecommendationMarker="Recommended"
            itemSectionMarker="**["
        }
        $this.Init($prop)
    }

    [void] ProcessLine($rawLine)
    {
        $line = $rawLine.Trim()
        # Header
        if($line.StartsWith($this.headerMarker))
        {
            $this.heading = $line.Substring(($this.headerMarker.Length))
            return
        }
        # new item
        if($line.startswith($this.itemSectionMarker))
        {
            $this.ParseItem($line)
            return
        }

        if($line.StartsWith($this.recommendationMarker))
        {
            $this.ParseRecommendation($line)
            return
        }

        $perkTypes = @("Sights:", "Barrels:", "Magazine:", "Perk 1:", "Perk 2:", "Perk 3", "Grips:")
        foreach($perktype in $perkTypes)
        {
            if($line -like "*$perktype*")
            {
                $this.ParsePerks($line)
                return
            }
        }

        if($line -like "*Masterwork:*")
        {
            $line -match ".*Masterwork: (.*)$"
            $this.weapon.recs[-1].masterwork = $Matches[1]
            return
        }
        
        if($line -like "Source:*" -or $line -like "Curated Roll:*" -or $line -like "- *")
        {
            return
        }

        if($null -ne $this.weapon -and $line.Length -gt 10)
        {
            $this.weapon.description.Add($line)
            return
        }
    }

    [void] ParseItem($line)
    {
        if($line -match ".*https://light.gg/db/items/([0-9]+)/.*")
        {
            $item = [InventoryItem]::new($Matches[1])

            if($this.weapon) {
                if($this.weapon.recs.count -gt 0)
                {
                    $this.weapon.Finish($this)
                    $this.weapon = [Weapon]::new($item)
                }
                else
                {
                    $this.weapon.variants.Add($item) | Out-Null
                }
            }
            else 
            {
                $this.weapon = [Weapon]::new($item)
            }
            return
        }
    }

    [void] ParseRecommendation($line)
    {
        $rec = [Recommendation]::new()
        if($line -like "*PvE*")
        {
            $rec.tags = @("pve", "mkb", "controller")
        }
        if($line -like "*Controller PvP*")
        {
            $rec.tags = @("pvp", "controller")
        }
        if($line -like "*MnK PvP*")
        {
            $rec.tags = @("pvp","mkb")
        }
        $this.weapon.recs.Add($rec) | Out-Null
    }

    [void] ParsePerks($line)
    {            
        $perks = [System.Collections.ArrayList]::new()
        $line -match ".*: (.*)$"
        if($Matches[1] -eq "Eyes Up, Guardian")
        {
            $perks.Add("Eyes Up, Guardian") | Out-Null
        }
        else {
                $perks.add(@($Matches[1].split(',').trim())) | Out-Null
        }
        $perks | ForEach-Object { $this.weapon.recs[-1].perks.add($_) | Out-Null }
        return
    
        
    }
}

$ExportableTypes =@(
    [Weapon],[Recommendation],[Parser],[PandaText]
)

function main($inObj)
{
    $parser = [PandaText]::new()
    foreach($line in $inObj)
    {
        $parser.ProcessLine($line)
    }
    if($null -ne $parser.weapon)
    {
        $parser.weapon.finish($parser)
    }
}



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