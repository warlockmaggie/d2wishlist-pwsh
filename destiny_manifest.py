#!/usr/bin/env python3

import sqlite3
import json

from functools import lru_cache

manifest = sqlite3.connect("manifest.sqlite3")

# Table names
INVITEMDEF = "DestinyInventoryItemDefinition"
PLUGSETDEF = "DestinyPlugSetDefinition"

# socketCategories[].socketCategoryHash for weapon perks
WEAPON_PERKS = 4241085061


@lru_cache(maxsize=128)
def query_manifest(table, hash):
    id = sql_id(hash)
    c = manifest.cursor()
    r = c.execute(f"SELECT json FROM {table} WHERE id = ?", (id,))
    row = r.fetchone()
    if not row:
        raise LookupError(f"No {table} for {hash}")
    itemdef = json.loads(row[0])
    return itemdef


def sql_id(hash):
    id = int(hash)
    if (id & (1 << (32 - 1))) != 0:
        id = id - (1 << 32)
    return id


class LookupError(Exception):
    pass


class PlugSet(object):
    def __init__(self, hash):
        self.hash = str(hash)
        self.definition = query_manifest(PLUGSETDEF, hash)

    def reusable_plug_items(self):
        return [
            InventoryItem(p["plugItemHash"])
            for p in self.definition["reusablePlugItems"]
        ]


class InventoryItem(object):
    def __init__(self, hash):
        self.hash = str(hash)
        self.definition = query_manifest(INVITEMDEF, hash)
        self.name = self.definition["displayProperties"]["name"]
        self.sockets = []
        self.load_sockets()

    def __str__(self):
        return f"{self.name} [{self.hash}]"

    def __repr__(self):
        return f"{self.name} [{self.hash}]"

    def load_sockets(self):
        if "sockets" not in self.definition:
            return

        # Find sockets for weapon perks
        socket_indexes = [
            s["socketIndexes"]
            for s in self.definition["sockets"]["socketCategories"]
            if s["socketCategoryHash"] == WEAPON_PERKS
        ][0]
        for i in socket_indexes:
            plugs = dict()
            entry = self.definition["sockets"]["socketEntries"][i]

            # plug options specified directly in the item definition
            for plug in entry["reusablePlugItems"]:
                plugitem = InventoryItem(plug["plugItemHash"])
                plugs[plugitem.hash] = plugitem

            # plug options specified via plug sets (either randomized or reusable)
            plug_type = None
            for t in ("randomizedPlugSetHash", "reusablePlugSetHash"):
                if t in entry:
                    plug_type = t
                    break

            if plug_type:
                plugset = PlugSet(entry[plug_type])
                for plugitem in plugset.reusable_plug_items():
                    plugs[plugitem.hash] = plugitem

            self.sockets.append(plugs)
