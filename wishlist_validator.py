#!/usr/bin/env python3

from destiny_manifest import InventoryItem

import fileinput
import urllib.parse

from rich.console import Console

console = Console()


class ValidationError(Exception):
    pass


class DIMWishlist(object):
    def __init__(self):
        self.last_item = None
        self.lineno = 0

    def validate(self, item, perks):
        roll = dict()
        for perk_hash in perks:
            n = 0
            for s in item.sockets:
                try:
                    perk_info = s[perk_hash]
                    if n in roll:
                        raise ValidationError(
                            f"Two perks in same column! {roll[n]['displayProperties']['name']} [{roll[n]['hash']}] and {perk_info['displayProperties']['name']} [{perk_info['hash']}]"
                        )
                    roll[n] = perk_info
                    break
                except KeyError:
                    n += 1
                    continue

        if len(perks) > len(roll):
            r = set([str(x.hash) for x in roll.values()])
            missing = [InventoryItem(x) for x in perks if x not in r]
            raise ValidationError(
                f"Perks not in manifest: {', '.join([str(x) for x in missing])}"
            )

        return roll

    def process_item(self, line):
        # dimwishlist:item=3969379530&perks=839105230,1087426260,3619207468,3047969693
        itemdict = urllib.parse.parse_qs(line[12:])
        itemhash = itemdict["item"][0]

        if self.last_item and self.last_item.hash == itemhash:
            item = self.last_item
        else:
            item = InventoryItem(itemhash)
            self.last_item = item

        try:
            self.validate(item, itemdict["perks"][0].split(","))

        #            roll = self.validate(item, itemdict["perks"][0].split(','))
        #            perks = ", ".join([r.name for r in roll.values()])
        #            console.print(f"{self.lineno} [blue]{item}[/blue] [green]Valid![/green] {perks}")
        except ValidationError as e:
            console.print(f"{self.lineno} [blue]{item}[/blue] [red]Error![/red] {e}")
        except LookupError as e:
            console.print(f"{self.lineno} [blue]{item}[/blue] [red]Error![/red] {e}")

    def process_line(self, rawline):
        line = rawline.strip()
        self.lineno += 1

        if line == "":
            return
        if line.startswith("//"):
            return

        if line.startswith("title:"):
            console.print(f"[bold blue]{line[6:]}[/bold blue]")
            return
        if line.startswith("description:"):
            console.print(f"[blue]{line[12:]}[/blue]")
            return

        if line.startswith("dimwishlist:"):
            try:
                self.process_item(line)
            except:
                console.print(f"[red]Error[/red] while processing line {self.lineno}")
                console.print(line)
                raise
            return

        print(f"Unhandled line: {line}")


if __name__ == "__main__":
    parser = DIMWishlist()
    for line in fileinput.input(encoding="utf-8"):
        parser.process_line(line)
