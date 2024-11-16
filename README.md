# d2wishlist
Create and validate DIM-style wishlists

## Usage

First, you'll need a copy of the Destiny 2 Manifest, this can be fetched using `fetch_manifest.sh`:


```
$ ./fetch_manifest.sh
Current manifest version: 229199.24.10.30.2000-1-bnet.57522
=== Fetching manifest archive...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 23.4M  100 23.4M    0     0  45.5M      0 --:--:-- --:--:-- --:--:-- 45.5M
=== Extracting manifest database...
Archive:  manifest.sqlite.zip
 extracting: world_sql_content_cd9d69b569421ae2921a88739507f991.content
```

Next, you'll need a [u/pandapaxxy](https://www.reddit.com/user/pandapaxxy/)-style breakdown post in Markdown format. This can be fetched by grabbing the Reddit post with a `.json` on the end and extracting the original text. Example:


```
$ curl -s "https://www.reddit.com/r/sharditkeepit/comments/1gsqph3/festival_of_the_lost_breakdown.json" \
    | jq -r .[0].data.children[0].data.selftext > panda_s24_fotl_post.txt
```

Now, you can run `wishlist_creator.py` on that post to generate the wishlist:

```
$ ./wishlist_creator.py panda_s24_fotl_post.txt > panda_s24_fotl.txt
$ head panda_s24_fotl.txt
// BrayTech Werewolf
//notes:pandapaxxy (PvE / M+KB / Controller): "Braytech Werewolf is the sole survivor of the two FotL auto rifle conundrum we've had. Poor Horror Story (though whether it's a glitch or not, you can enhance your old FotL weapons…SGA). When using Braytech Werewolf in PvE your best roll is Rewind Rounds or Subsistence paired with your choice of Onslaught or Kinetic Tremors. It entirely depends on how you would like to use this auto. All 4 perks are great on their own and make this auto feel incredible." Recommended MW: Reload Speed.|tags:pve,mkb,controller
dimwishlist:item=3558681245&perks=839105230,1087426260,3418782618,95528736
dimwishlist:item=3558681245&perks=839105230,1087426260,3418782618,3891536761
dimwishlist:item=3558681245&perks=839105230,1087426260,3418782618,2109543898
dimwishlist:item=3558681245&perks=839105230,1087426260,1820235745,95528736
dimwishlist:item=3558681245&perks=839105230,1087426260,1820235745,3891536761
dimwishlist:item=3558681245&perks=839105230,1087426260,1820235745,2109543898
dimwishlist:item=3558681245&perks=839105230,1087426260,3643424744,95528736
dimwishlist:item=3558681245&perks=839105230,1087426260,3643424744,3891536761
```
