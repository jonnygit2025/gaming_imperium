"""Finestra di gioco con pygame-ce. Pensata per PC datati:
- sfondo e strade disegnati UNA volta e riutilizzati,
- FPS limitati dal profilo,
- testi statici messi in cache.
"""
import sys

import pygame

from . import config as C
from .world import World

PARCH = (226, 210, 170)
INK = (60, 45, 30)
ROAD = (150, 120, 80)
HUD_BG = (40, 30, 22)
GOLD = (230, 190, 70)


class App:
    def __init__(self, profile=None):
        self.profile_name = profile or C.detect_profile()
        prof = C.PROFILES[self.profile_name]
        pygame.init()
        pygame.display.set_caption("Imperium - remake")
        self.screen = pygame.display.set_mode(prof["size"])
        self.fps = prof["fps"]
        self.smooth = prof["smooth"]
        self.w, self.h = prof["size"]
        self.hud_h = 56
        self.sx = self.w / C.MAP_W
        self.sy = (self.h - self.hud_h - 110) / C.MAP_H
        self.font = pygame.font.SysFont("georgia,timesnewroman,serif", 15)
        self.font_b = pygame.font.SysFont("georgia,timesnewroman,serif", 17, bold=True)
        self.font_big = pygame.font.SysFont("georgia,timesnewroman,serif", 42, bold=True)
        self.clock = pygame.time.Clock()
        self.world = World()
        self.selected = None
        self.speed = 1
        self.paused = False
        self._name_cache = {}
        self.background = self._build_background()

    # --- coordinate --------------------------------------------------------
    def to_screen(self, x, y):
        return int(x * self.sx), int(y * self.sy + self.hud_h + 20)

    def to_world(self, px, py):
        return px / self.sx, (py - self.hud_h - 20) / self.sy

    # --- disegno -----------------------------------------------------------
    def _build_background(self):
        bg = pygame.Surface((self.w, self.h))
        bg.fill(PARCH)
        for a in self.world.cities.values():
            for b in a.neighbors:
                if a.name < b.name:
                    pygame.draw.line(bg, ROAD, self.to_screen(a.x, a.y), self.to_screen(b.x, b.y), 3)
        return bg.convert()

    def _name(self, text):
        if text not in self._name_cache:
            self._name_cache[text] = self.font.render(text, self.smooth, INK)
        return self._name_cache[text]

    def draw(self):
        s, wd = self.screen, self.world
        s.blit(self.background, (0, 0))

        for c in wd.cities.values():
            col = wd.factions[c.owner].color
            pos = self.to_screen(c.x, c.y)
            r = 10 + min(10, c.population // 400)
            if c is self.selected:
                pygame.draw.circle(s, GOLD, pos, r + 5)
                for n in c.neighbors:
                    pygame.draw.line(s, GOLD, pos, self.to_screen(n.x, n.y), 2)
            pygame.draw.circle(s, col, pos, r)
            pygame.draw.circle(s, INK, pos, r, 2)
            num = self.font_b.render(str(c.soldiers), self.smooth, (255, 255, 255))
            s.blit(num, num.get_rect(center=pos))
            nm = self._name(c.name)
            s.blit(nm, nm.get_rect(midtop=(pos[0], pos[1] + r + 2)))

        for a in wd.armies:
            pos = self.to_screen(*a.pos)
            pygame.draw.rect(s, wd.factions[a.owner].color, (pos[0] - 7, pos[1] - 7, 14, 14))
            pygame.draw.rect(s, INK, (pos[0] - 7, pos[1] - 7, 14, 14), 1)
            t = self.font.render(str(a.size), self.smooth, INK)
            s.blit(t, (pos[0] + 9, pos[1] - 9))

        self._draw_hud()
        self._draw_log()
        if wd.winner:
            msg = "VITTORIA! L'Italia è tua." if wd.winner == "roma" else "SCONFITTA..."
            t = self.font_big.render(msg, True, (120, 20, 20))
            s.blit(t, t.get_rect(center=(self.w // 2, self.h // 2)))
        pygame.display.flip()

    def _draw_hud(self):
        s, wd = self.screen, self.world
        pygame.draw.rect(s, HUD_BG, (0, 0, self.w, self.hud_h))
        p = wd.player()
        n = sum(1 for c in wd.cities.values() if c.owner == p.key)
        stato = "PAUSA" if self.paused else f"x{self.speed}"
        txt = (f"Oro: {p.gold}    Città: {n}/{len(wd.cities)}    Giorno {wd.day}    "
               f"Velocità: {stato}    FPS: {self.clock.get_fps():.0f} ({self.profile_name})")
        s.blit(self.font_b.render(txt, True, GOLD), (12, 8))
        help_ = "R: recluta 10 (50 oro)   Tasto dx su città vicina: invia metà truppe   SPAZIO: pausa   +/-: velocità"
        if self.selected:
            c = self.selected
            help_ = f"{c.name} — popolazione {c.population}, reddito {c.income}/giorno.   " + help_
        s.blit(self.font.render(help_, True, (220, 210, 190)), (12, 32))

    def _draw_log(self):
        y = self.h - 20 * len(self.world.log) - 6
        for line in self.world.log:
            self.screen.blit(self.font.render(line, self.smooth, INK), (12, y))
            y += 20

    # --- input -------------------------------------------------------------
    def handle(self, ev):
        wd, p = self.world, self.world.player()
        if ev.type == pygame.QUIT:
            return False
        if ev.type == pygame.KEYDOWN:
            if ev.key == pygame.K_ESCAPE:
                return False
            if ev.key == pygame.K_SPACE:
                self.paused = not self.paused
            elif ev.key in (pygame.K_PLUS, pygame.K_KP_PLUS, pygame.K_EQUALS):
                self.speed = min(4, self.speed + 1)
            elif ev.key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                self.speed = max(1, self.speed - 1)
            elif ev.key == pygame.K_r and self.selected and self.selected.owner == p.key:
                wd.recruit(self.selected)
        if ev.type == pygame.MOUSEBUTTONDOWN:
            c = wd.city_at(*self.to_world(*ev.pos))
            if ev.button == 1:
                self.selected = c if c and c.owner == p.key else None
            elif ev.button == 3 and c and self.selected:
                wd.send_army(self.selected, c, 0.5)
        return True

    def run(self):
        running = True
        while running:
            dt = self.clock.tick(self.fps) / 1000
            for ev in pygame.event.get():
                running = self.handle(ev) and running
            if not self.paused:
                self.world.update(min(dt, 0.1) * self.speed)
            if self.selected and self.selected.owner != self.world.player().key:
                self.selected = None
            self.draw()
        pygame.quit()


def main():
    profile = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in C.PROFILES else None
    App(profile).run()
