"""Logica del gioco: città, fazioni, economia, eserciti, battaglie, IA.

Nessuna dipendenza da pygame: si può testare e far girare senza grafica.
"""
import math
import random
from dataclasses import dataclass, field

from . import config as C


@dataclass
class Faction:
    key: str
    name: str
    color: tuple
    is_player: bool = False
    gold: int = 150
    alive: bool = True


@dataclass
class City:
    name: str
    x: float
    y: float
    owner: str
    population: int = 1000
    soldiers: int = 20
    neighbors: list = field(default_factory=list)

    @property
    def income(self):
        return 2 + self.population // 400


@dataclass
class Army:
    owner: str
    size: int
    src: City
    dst: City
    progress: float = 0.0  # 0..1 lungo la strada

    @property
    def pos(self):
        return (self.src.x + (self.dst.x - self.src.x) * self.progress,
                self.src.y + (self.dst.y - self.src.y) * self.progress)


# --- Mappa iniziale: Italia antica ------------------------------------------
CITIES = [
    # nome, x, y, fazione, popolazione
    ("Mediolanum", 250, 110, "galli", 1400),
    ("Genua", 190, 210, "galli", 900),
    ("Aquileia", 520, 80, "galli", 1000),
    ("Ravenna", 430, 190, "galli", 900),
    ("Pisae", 290, 300, "etruschi", 1000),
    ("Arretium", 380, 300, "etruschi", 1100),
    ("Ancona", 520, 290, "etruschi", 900),
    ("Roma", 410, 400, "roma", 2000),
    ("Capua", 490, 460, "roma", 1200),
    ("Neapolis", 500, 510, "greci", 1300),
    ("Tarentum", 680, 500, "greci", 1400),
    ("Brundisium", 780, 460, "greci", 900),
    ("Rhegium", 640, 610, "greci", 900),
    ("Messana", 600, 640, "cartagine", 900),
    ("Syracusae", 610, 690, "cartagine", 1600),
    ("Panormus", 470, 630, "cartagine", 1000),
]

ROADS = [
    ("Mediolanum", "Genua"), ("Mediolanum", "Aquileia"), ("Mediolanum", "Ravenna"),
    ("Aquileia", "Ravenna"), ("Genua", "Pisae"), ("Ravenna", "Arretium"),
    ("Ravenna", "Ancona"), ("Pisae", "Arretium"), ("Arretium", "Ancona"),
    ("Pisae", "Roma"), ("Arretium", "Roma"), ("Ancona", "Capua"), ("Roma", "Capua"),
    ("Capua", "Neapolis"), ("Capua", "Tarentum"), ("Neapolis", "Tarentum"),
    ("Tarentum", "Brundisium"), ("Neapolis", "Rhegium"), ("Tarentum", "Rhegium"),
    ("Rhegium", "Messana"), ("Messana", "Syracusae"), ("Messana", "Panormus"),
    ("Panormus", "Syracusae"),
]

FACTIONS = [
    ("roma", "Roma", (196, 48, 43), True),
    ("galli", "Galli", (70, 140, 60), False),
    ("etruschi", "Etruschi", (200, 150, 50), False),
    ("greci", "Magna Grecia", (60, 110, 190), False),
    ("cartagine", "Cartagine", (130, 70, 160), False),
]


class World:
    def __init__(self, seed=None):
        self.rng = random.Random(seed)
        self.factions = {k: Faction(k, n, col, p) for k, n, col, p in FACTIONS}
        self.cities = {n: City(n, x, y, o, pop) for n, x, y, o, pop in CITIES}
        for a, b in ROADS:
            self.cities[a].neighbors.append(self.cities[b])
            self.cities[b].neighbors.append(self.cities[a])
        self.armies = []
        self.day = 0
        self._day_timer = 0.0
        self._ai_timer = 0.0
        self.log = ["Ave! Conquista l'Italia. Clic sinistro: seleziona, destro: attacca."]
        self.winner = None

    # --- comandi del giocatore / IA ---------------------------------------
    def recruit(self, city):
        f = self.factions[city.owner]
        if f.gold < C.RECRUIT_COST or city.population < 200:
            return False
        f.gold -= C.RECRUIT_COST
        city.soldiers += C.RECRUIT_SIZE
        city.population -= C.RECRUIT_SIZE * 5
        return True

    def send_army(self, src, dst, fraction=0.5):
        if dst not in src.neighbors or src.soldiers < 2:
            return False
        size = max(1, int(src.soldiers * fraction))
        src.soldiers -= size
        self.armies.append(Army(src.owner, size, src, dst))
        return True

    # --- simulazione -------------------------------------------------------
    def update(self, dt):
        if self.winner:
            return
        for army in list(self.armies):
            dist = math.hypot(army.dst.x - army.src.x, army.dst.y - army.src.y) or 1
            army.progress += C.ARMY_SPEED * dt / dist
            if army.progress >= 1:
                self.armies.remove(army)
                self._arrive(army)

        self._day_timer += dt
        while self._day_timer >= C.DAY_SECONDS:
            self._day_timer -= C.DAY_SECONDS
            self._new_day()

        self._ai_timer += dt
        if self._ai_timer >= 2.0:
            self._ai_timer = 0
            self._run_ai()

    def _new_day(self):
        self.day += 1
        for city in self.cities.values():
            f = self.factions[city.owner]
            f.gold += city.income
            upkeep = city.soldiers // 25
            f.gold -= upkeep
            if city.population < 5000:
                city.population += max(1, city.population // 200)
        for f in self.factions.values():
            if f.gold < 0:  # niente soldi: i soldati disertano
                f.gold = 0
                for c in self.cities.values():
                    if c.owner == f.key and c.soldiers > 5:
                        c.soldiers -= 1
        self._check_end()

    def _arrive(self, army):
        city = army.dst
        if city.owner == army.owner:
            city.soldiers += army.size
            return
        attack = army.size * self.rng.uniform(0.85, 1.15)
        defense = city.soldiers * C.DEFENSE_BONUS * self.rng.uniform(0.85, 1.15)
        attacker = self.factions[army.owner].name
        if attack > defense:
            survivors = max(1, int(army.size * (1 - defense / attack)))
            old = self.factions[city.owner].name
            city.owner, city.soldiers = army.owner, survivors
            city.population = int(city.population * 0.85)
            self._say(f"Giorno {self.day}: {attacker} conquista {city.name} ({old}).")
        else:
            city.soldiers = max(0, int(city.soldiers * (1 - attack / max(defense, 1))))
            self._say(f"Giorno {self.day}: {city.name} respinge {attacker}.")

    def _run_ai(self):
        for f in self.factions.values():
            if f.is_player or not f.alive:
                continue
            mine = [c for c in self.cities.values() if c.owner == f.key]
            # recluta nelle città di confine più minacciate
            border = [c for c in mine if any(n.owner != f.key for n in c.neighbors)]
            for c in sorted(border or mine, key=lambda c: c.soldiers):
                if f.gold >= C.RECRUIT_COST * 1.5:
                    self.recruit(c)
            # attacca il vicino più debole se c'è un buon vantaggio
            for c in border:
                targets = [n for n in c.neighbors if n.owner != f.key]
                if not targets:
                    continue
                t = min(targets, key=lambda n: n.soldiers)
                if c.soldiers * 0.6 > t.soldiers * C.DEFENSE_BONUS * 1.3 and c.soldiers > 15:
                    self.send_army(c, t, 0.6)

    def _check_end(self):
        owners = {c.owner for c in self.cities.values()} | {a.owner for a in self.armies}
        for f in self.factions.values():
            if f.alive and f.key not in owners:
                f.alive = False
                self._say(f"{f.name} è stata sconfitta!")
        city_owners = {c.owner for c in self.cities.values()}
        if len(city_owners) == 1:
            self.winner = city_owners.pop()
        elif "roma" not in owners:
            self.winner = "nemici"

    def _say(self, msg):
        self.log.append(msg)
        self.log = self.log[-6:]

    # utilità
    def player(self):
        return next(f for f in self.factions.values() if f.is_player)

    def city_at(self, x, y, radius=22):
        for c in self.cities.values():
            if math.hypot(c.x - x, c.y - y) <= radius:
                return c
        return None
