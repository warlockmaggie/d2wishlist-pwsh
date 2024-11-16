#!/usr/bin/env python3

from destiny_manifest import InventoryItem

import fileinput
import re
import itertools

TAGMAP = {
    "pvp": "PvP",
    "pve": "PvE",
    "mkb": "M+KB",
    "controller": "Controller",
    "dps": "DPS",
    "gambit": "Gambit",
}
TAGORDER = tuple(TAGMAP.keys())


def tagsort(x):
    return TAGORDER.index(x)


class LookupError(Exception):
    pass


class Recommendation(object):
    def __init__(self):
        self.tags = []
        self.perks = []
        self.masterwork = None

    def __str__(self):
        return f"tags={','.join(self.tags)} masterwork={self.masterwork}"

    def print_wishlist(self, parser, item, description):
        # sort and pretty up the tags
        tags = sorted(self.tags, key=tagsort)
        tag_string = " / ".join([TAGMAP.get(t, f"??? {t} ???") for t in tags])

        tagstr = ""
        tagstag = ""
        if tag_string:
            tagstr = f" ({tag_string})"
            tagstag = f"|tags:{','.join(tags)}"

        mw = ""
        if self.masterwork:
            mw = f" Recommended MW: {self.masterwork}."

        # translate perks to their hashes
        hashes = []
        for slot in self.perks:
            perkhashes = []
            for perk in slot:
                perkhash = None

                for sock in item.sockets:
                    try:
                        perkhash = [p for p in sock.values() if p.name == perk][0]
                    except IndexError:
                        continue
                    else:
                        break

                if perkhash:
                    perkhashes.append(perkhash)
                else:
                    raise LookupError(f"Could not find hash for perk {perk}!")
            hashes.append(perkhashes)

        print(f"// {item.name}")
        print(f'//notes:{parser.reviewer}{tagstr}: "{description}"{mw}{tagstag}')

        for roll in itertools.product(*hashes):
            perk_string = ",".join([p.hash for p in roll])
            print(f"dimwishlist:item={item.hash}&perks={perk_string}")

        print("")


class Weapon(object):
    def __init__(self, item):
        self.item = item
        self.adept = None
        self.recs = []
        self.description = []

    def condense_pvp(self):
        pvp_rolls = [r for r in self.recs if "pvp" in r.tags]

        if len(pvp_rolls) != 2:
            return

        if pvp_rolls[0].masterwork != pvp_rolls[1].masterwork:
            return

        for i in range(len(pvp_rolls[0].perks)):
            l1 = pvp_rolls[0].perks[i]
            l2 = pvp_rolls[1].perks[i]
            if l1 != l2:
                return

        # Add unique tags from the second roll to the first
        tags = [t for t in pvp_rolls[1].tags if t not in pvp_rolls[0].tags]
        pvp_rolls[0].tags.extend(tags)

        self.recs.remove(pvp_rolls[1])

    def finish(self, parser):
        self.condense_pvp()

        try:
            for r in self.recs:
                try:
                    if "pve" in r.tags:
                        descr = self.description[0]
                    else:
                        descr = self.description[1]
                except IndexError:
                    descr = ""

                r.print_wishlist(parser, self.item, descr)
                if self.adept:
                    r.print_wishlist(parser, self.adept, descr)
        except LookupError as e:
            print(f"Error while printing {self.item}: {e}")
            raise


class PandaText(object):
    def __init__(self):
        self.heading = None
        self.reviewer = "pandapaxxy"
        self.weapon = None

    def process_line(self, rawline):
        line = rawline.strip()

        # Start of section, should probably split into separate output files
        if line.startswith("###"):
            self.heading = line[3:]
            return

        # Start of a new item section
        if line.startswith("**["):
            m = re.match(r".*https://light.gg/db/items/([0-9]+)/.*", line)
            item = InventoryItem(m.group(1))

            if "(Adept)" in item.name:
                self.weapon.adept = item
            else:
                if self.weapon:
                    self.weapon.finish(self)
                self.weapon = Weapon(item)

            return

        if line.startswith("Recommended"):
            rec = Recommendation()

            if "PvE" in line:
                rec.tags = ["pve", "mkb", "controller"]
            if "Controller PvP" in line:
                rec.tags = ["pvp", "controller"]
            if "MnK PvP" in line:
                rec.tags = ["pvp", "mkb"]

            self.weapon.recs.append(rec)

            return

        for perktype in ("Sights:", "Magazine:", "Perk 1:", "Perk 2:"):
            if perktype in line:
                m = re.match(r".*: (.*)$", line)
                if "Eyes Up, Guardian" == m.group(1):
                    perks = ["Eyes Up, Guardian"]
                else:
                    perks = [p.strip() for p in m.group(1).rstrip(",").split(",")]
                self.weapon.recs[-1].perks.append(perks)
                return

        if "Masterwork:" in line:
            m = re.match(r".*Masterwork: (.*)$", line)
            self.weapon.recs[-1].masterwork = m.group(1)

            return

        if line.startswith(("Source:", "Curated Roll:", "- ")):
            return

        if self.weapon and len(line) > 10:
            self.weapon.description.append(line)
            return


if __name__ == "__main__":
    parser = PandaText()
    for line in fileinput.input(encoding="utf-8"):
        parser.process_line(line)
    if parser.weapon:
        parser.weapon.finish(parser)
