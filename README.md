# d2wishlist
Create DIM-style wishlists via Powershell. Forked from https://github.com/2bithacker/d2wishlist

## Usage

Load up a Powershell windows and enter:
```PowerShell
using module .\wishlist.psm1
```
You'll need a copy of the Destiny 2 Manifest:

```PowerShell
Get-DestinyManifest
> Downloaded and unzipped Manifest at ./manifest.sqlite3
```

Afterwards, download a [u/pandapaxxy](https://www.reddit.com/user/pandapaxxy/)-style breakdown post. The Markdown can be grabbed from reddit using the same url but with a ".json" at the end.

```PowerShell
$url = "https://www.reddit.com/r/sharditkeepit/comments/1gsqph3/festival_of_the_lost_breakdown.json"
$json = (Invoke-WebRequest -uri $url).content | convertfrom-json
$json[0].data.children[0].data.selftext | Out-File ./breakdown.txt
```
Then run `main` to generate the wishlist from the post contents:

```PowerShell
$inObj = get-content .\breakdown.txt
main($inObj)
```

Your wishlist will be at `./output.txt`