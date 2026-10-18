"""Impostazioni del gioco. Il profilo si adatta alle risorse del PC."""
import os

PROFILES = {
    #          risoluzione    fps  antialias
    "basso": {"size": (960, 640), "fps": 30, "smooth": False},
    "medio": {"size": (1152, 768), "fps": 45, "smooth": True},
    "alto": {"size": (1280, 853), "fps": 60, "smooth": True},
}


def detect_profile():
    forced = os.environ.get("IMPERIUM_PROFILE")
    if forced in PROFILES:
        return forced
    cores = os.cpu_count() or 1
    try:
        import psutil
        ram = psutil.virtual_memory().total / 1024**3
    except ImportError:
        ram = 4
    if ram < 3 or cores <= 2:
        return "basso"
    if ram < 6 or cores <= 4:
        return "medio"
    return "alto"


# Coordinate logiche della mappa (scalate sulla finestra)
MAP_W, MAP_H = 1000, 700

# Economia
RECRUIT_COST = 50      # oro per 10 soldati
RECRUIT_SIZE = 10
DAY_SECONDS = 1.0      # durata di un "giorno" a velocità 1x
DEFENSE_BONUS = 1.25   # chi difende una città combatte meglio
ARMY_SPEED = 60        # unità mappa al secondo
