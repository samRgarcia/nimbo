"""Genera index.html: la composición HyperFrames del video de Nimbo (1920x1080, 30 s).
Generates index.html: the HyperFrames composition for the Nimbo video (1920x1080, 30 s).

Uso / Usage:   python3 gen.py es   |   python3 gen.py en
"""
import random
import sys

LANG = sys.argv[1] if len(sys.argv) > 1 else "es"
rnd = random.Random(11)

T = {
    "es": dict(
        lang="es", tag="Clima vivo en el escritorio de tu Mac.",
        c2=("La nieve se junta en tus ventanas.", "Muévelas y cae."),
        c3=("Diez escenas.", "Lluvia, tormenta, hojas, luciérnagas, meteoros y más."),
        c4=("Sigue el clima real de tu ciudad.", "Se actualiza sola cada 15 minutos."),
        c5=("Taller de invierno.", "Muñecos de nieve, árbol de Navidad y quitanieves."),
        names=["Lluvia", "Tormenta", "Hojas", "Luciérnagas"],
        city="Tu ciudad", cond="Lluvia ligera", wind="viento 12 km/h", now="Ahora",
        free="Gratis para Mac", get="Descárgala gratis",
    ),
    "en": dict(
        lang="en", tag="Live weather on your Mac desktop.",
        c2=("Snow gathers on your windows.", "Move them and it falls."),
        c3=("Ten scenes.", "Rain, storm, leaves, fireflies, meteors and more."),
        c4=("Follows the real weather in your city.", "It updates itself every 15 minutes."),
        c5=("Winter workshop.", "Snowmen, a Christmas tree and a snowplow."),
        names=["Rain", "Storm", "Leaves", "Fireflies"],
        city="Your city", cond="Light rain", wind="wind 12 km/h", now="Now",
        free="Free for Mac", get="Get it free",
    ),
}[LANG]

TOTAL = 30.0
SC = {"s1": (0.0, 3.6), "s2": (3.6, 6.0), "s3": (9.6, 6.0), "s4": (15.6, 4.8), "s5": (20.4, 4.8), "s6": (25.2, 4.8)}

# Geometría del escritorio de ejemplo / sample desktop geometry (px inside .desk)
DESK_W, DESK_H = 1600, 640
WIN_A = (150, 150, 620, 360)   # left, top, width, height
WIN_B = (900, 240, 520, 320)
DOCK = (500, 560, 600, 62)


def flakes(count, width, height, size=(5, 12), cls="fl"):
    out = []
    for _ in range(count):
        s = rnd.uniform(*size)
        out.append(
            f'<i class="{cls}" style="left:{rnd.uniform(0, width):.0f}px;width:{s:.1f}px;height:{s:.1f}px;opacity:{rnd.uniform(0.55, 1):.2f}" '
            f'data-d="{rnd.uniform(3.2, 6.0) * (14 / (s + 6)):.2f}" data-f="{rnd.random():.3f}" data-sw="{rnd.uniform(-60, 60):.0f}" data-h="{height}"></i>'
        )
    return "".join(out)


def pile(width, peak, cls="pile", seed=1):
    r = random.Random(seed)
    steps = max(6, int(width / 26))
    pts, h = [], peak * 0.7
    for i in range(steps + 1):
        h = max(peak * 0.45, min(peak, h + r.uniform(-4, 4)))
        edge = min(1.0, min(i, steps - i) / 2 + 0.12)
        pts.append((width * i / steps, 30 - h * edge))
    d = f"M0 30 L{pts[0][0]:.1f} {pts[0][1]:.1f} "
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d += f"Q{x0:.1f} {y0:.1f} {(x0 + x1) / 2:.1f} {(y0 + y1) / 2:.1f} "
    d += f"L{width} 30 Z"
    return f'<svg class="{cls}" viewBox="0 0 {width} 30" preserveAspectRatio="none" style="width:{width}px"><path d="{d}"/></svg>'


def window(geo, wid, extra="", snow=True, seed=1):
    left, top, w, h = geo
    lines = "".join(f'<b style="width:{rnd.randint(38, 92)}%"></b>' for _ in range(int((h - 110) / 38)))
    cap = pile(w, 26, seed=seed) if snow else ""
    return (f'<div class="win {wid}" style="left:{left}px;top:{top}px;width:{w}px;height:{h}px">{cap}'
            f'<div class="bar"><i></i><i></i><i></i><u></u></div><div class="side"></div><div class="lines">{lines}</div>{extra}</div>')


def dock(snow=True, extra=""):
    left, top, w, h = DOCK
    tones = ["#6084c4", "#d67860", "#6eaa82", "#dcb45a", "#9678be", "#5aa0be", "#c86e96", "#828ca0", "#78b46e"]
    tiles = "".join(f'<i style="background:{c}"></i>' for c in tones)
    cap = pile(w, 22, cls="pile dockpile", seed=9) if snow else ""
    return f'<div class="dock" style="left:{left}px;top:{top}px;width:{w}px;height:{h}px">{cap}{extra}<div class="tiles">{tiles}</div></div>'


def desk(inner, cls="", floor=False):
    ground = pile(DESK_W, 24, cls="pile floor", seed=7) if floor else ""
    return f'<div class="desk {cls}"><div class="menu"><i></i><i></i><i></i><i></i><em></em><em></em></div>{inner}{ground}</div>'


def cap(key):
    return f'<div class="cap"><h2>{T[key][0]}</h2><p>{T[key][1]}</p></div>'


body = []


def clip(sid, html):
    start, dur = SC[sid]
    body.append(f'<div id="{sid}" class="clip scene" data-start="{start}" data-duration="{dur}" data-track-index="0">{html}</div>')


ICON = '<img class="icon" src="assets/icon.png" alt="">'

# 1. Portada / intro
clip("s1", f'''
  <div class="fx">{flakes(70, 1920, 1080, size=(6, 16))}</div>
  <div class="intro">{ICON}<h1>Nimbo</h1><p class="tag">{T["tag"]}</p></div>''')

# 2. Nieve sobre las ventanas / snow on the windows
spill = "".join(
    f'<i class="sp" style="left:{rnd.uniform(0, WIN_B[2]):.0f}px;width:{s:.0f}px;height:{s:.0f}px" data-dx="{rnd.uniform(-40, 40):.0f}" data-dy="{rnd.uniform(260, 420):.0f}" data-t="{rnd.uniform(0, 0.25):.2f}"></i>'
    for s in [rnd.uniform(6, 12) for _ in range(34)])
clip("s2", desk(
    window(WIN_A, "wa", seed=2) + window(WIN_B, "wb", extra=f'<div class="spill">{spill}</div>', seed=3) + dock()
    + f'<div class="fx">{flakes(90, DESK_W, DESK_H)}</div>'
    + '<svg class="cursor" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 2l15 9-6.5 1.6L9 20z"/></svg>', floor=True) + cap("c2"))

# 3. Diez escenas / ten scenes
rain = "".join(
    f'<i class="rn" style="left:{rnd.uniform(-40, DESK_W + 120):.0f}px;height:{rnd.uniform(26, 44):.0f}px;opacity:{rnd.uniform(0.35, 0.75):.2f}" data-d="{rnd.uniform(0.45, 0.7):.2f}" data-f="{rnd.random():.3f}"></i>'
    for _ in range(110))
leaf_colors = ["#d85a1a", "#f29a1e", "#b2341a", "#e6c034"]
leaves = "".join(
    f'<i class="lf" style="left:{rnd.uniform(0, DESK_W):.0f}px;background:{rnd.choice(leaf_colors)}" data-d="{rnd.uniform(2.2, 3.4):.2f}" data-f="{rnd.random():.3f}" data-sw="{rnd.uniform(-160, 160):.0f}" data-r="{rnd.uniform(-540, 540):.0f}"></i>'
    for _ in range(46))
flies = "".join(
    f'<i class="ff" style="left:{rnd.uniform(40, DESK_W - 40):.0f}px;top:{rnd.uniform(150, DESK_H - 60):.0f}px" data-dx="{rnd.uniform(-70, 70):.0f}" data-dy="{rnd.uniform(-50, 50):.0f}" data-t="{rnd.uniform(0, 0.6):.2f}"></i>'
    for _ in range(30))
names = "".join(f'<span class="nm n{i}">{name}</span>' for i, name in enumerate(T["names"]))
clip("s3", desk(
    '<div class="sky k0"></div><div class="sky k1"></div><div class="sky k2"></div><div class="sky k3"></div>'
    + window(WIN_A, "wa", snow=False) + window(WIN_B, "wb", snow=False) + dock(snow=False)
    + f'<div class="fx g0">{rain}</div><div class="fx g2">{leaves}</div><div class="fx g3">{flies}</div>'
    + '<div class="flash"></div><svg class="bolt" viewBox="0 0 200 420" aria-hidden="true"><path d="M120 0 L92 96 L128 132 L84 236 L118 262 L70 420"/></svg>'
    + f'<div class="names">{names}</div>', "multi") + cap("c3"))

# 4. Clima real / real weather
hours = ["", "+1 h", "+2 h", "+3 h", "+4 h", "+5 h", "+6 h", "+7 h"]
temps = [18, 18, 17, 17, 16, 15, 15, 14]
kinds = ["r", "r", "r", "c", "c", "c", "m", "m"]
strip = "".join(
    f'<div class="hr"><em data-layout-ignore>{h or T["now"]}</em><i class="wx {k}"></i><b>{t}°</b></div>'
    for h, t, k in zip(hours, temps, kinds))
rain2 = "".join(
    f'<i class="rn" style="left:{rnd.uniform(-20, 760):.0f}px;height:{rnd.uniform(24, 40):.0f}px;opacity:{rnd.uniform(0.35, 0.7):.2f}" data-d="{rnd.uniform(0.45, 0.7):.2f}" data-f="{rnd.random():.3f}"></i>'
    for _ in range(60))
clip("s4", f'''
  <div class="card">
    <div class="top"><i class="wx r big"></i><div><h3>{T["city"]}</h3><p data-layout-ignore>{T["cond"]} · {T["wind"]}</p></div><strong>18°</strong></div>
    <div class="strip">{strip}</div>
  </div>
  <div class="mini"><div class="mwin"><div class="bar"><i></i><i></i><i></i></div></div><div class="fx">{rain2}</div></div>''' + cap("c4"))

# 5. Taller de invierno / winter workshop
snowman = ('<div class="man"><i class="b b1"></i><i class="b b2"></i><i class="b b3"><u class="e1"></u><u class="e2"></u><u class="nose"></u></i>'
           '<i class="hat"></i></div>')
orn = "".join(f'<u style="left:{x}px;top:{y}px;background:{c}"></u>' for x, y, c in [
    (58, 150, "#e62834"), (96, 162, "#ffcc34"), (40, 118, "#408cff"), (84, 112, "#e62834"), (62, 78, "#ffcc34"),
    (72, 44, "#408cff"), (108, 128, "#ffffff"), (30, 158, "#ffffff")])
tree = f'<div class="tree"><i class="t t1"></i><i class="t t2"></i><i class="t t3"></i><i class="trunk"></i><i class="star"></i>{orn}</div>'
plow = '<div class="plow"><i class="body"></i><i class="cab"></i><i class="glass"></i><i class="blade"></i><i class="wh w1"></i><i class="wh w2"></i></div>'
cabin = '<div class="cabin"><i class="chim"></i><i class="walls"></i><i class="roof"></i><i class="door"></i><i class="lit"></i><i class="puff p1"></i><i class="puff p2"></i><i class="puff p3"></i></div>'
clip("s5", desk(
    window(WIN_A, "wa", seed=4) + window(WIN_B, "wb", extra=snowman, seed=5) + dock(extra=plow) + cabin + tree
    + f'<div class="fx">{flakes(80, DESK_W, DESK_H)}</div>', floor=True) + cap("c5"))

# 6. Cierre / outro
clip("s6", f'''
  <div class="fx">{flakes(70, 1920, 1080, size=(6, 16))}</div>
  <div class="intro outro">{ICON}<h1>Nimbo</h1><p class="tag">{T["free"]}</p>
    <div class="btn">{T["get"]}</div><p class="url">github.com/samRgarcia/nimbo</p></div>''')

CSS = '''
@font-face { font-family: "Bricolage"; font-weight: 700; src: url("assets/bricolage-grotesque-latin-700-normal.woff2") format("woff2"); }
@font-face { font-family: "Plex"; font-weight: 400; src: url("assets/ibm-plex-sans-latin-400-normal.woff2") format("woff2"); }
@font-face { font-family: "Plex"; font-weight: 500; src: url("assets/ibm-plex-sans-latin-500-normal.woff2") format("woff2"); }
@font-face { font-family: "Plex"; font-weight: 600; src: url("assets/ibm-plex-sans-latin-600-normal.woff2") format("woff2"); }
:root { --night: #0a1024; --ink: #f4f7ff; --muted: #a9b6d6; --accent: #8fc2ff; }
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: 1920px; height: 1080px; overflow: hidden; background: var(--night); }
#root { position: relative; width: 1920px; height: 1080px; color: var(--ink); font-family: "Plex", sans-serif;
  background: radial-gradient(1200px 700px at 78% -10%, #24407e 0%, rgba(36,64,126,0) 70%), radial-gradient(1000px 700px at 8% 110%, #1b2c5c 0%, rgba(27,44,92,0) 70%), var(--night); }
.scene { position: absolute; left: 0; top: 0; width: 1920px; height: 1080px; }
i, u, b, em { font-style: normal; text-decoration: none; display: block; }
svg { display: block; }

/* Portada y cierre / intro and outro */
.intro { position: absolute; left: 0; top: 0; width: 1920px; height: 1080px; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.icon { width: 300px; height: 300px; }
.intro h1 { font: 700 200px "Bricolage", sans-serif; letter-spacing: -7px; line-height: 1; margin-top: 4px; }
.tag { font-size: 52px; color: var(--muted); margin-top: 22px; }
.outro .icon { width: 220px; height: 220px; }
.outro h1 { font-size: 150px; letter-spacing: -5px; }
.outro .tag { font-size: 46px; margin-top: 14px; }
.btn { margin-top: 44px; padding: 26px 64px; border-radius: 999px; background: var(--ink); color: var(--night); font: 600 48px "Plex", sans-serif; }
.url { margin-top: 34px; font: 500 40px "Plex", sans-serif; color: var(--accent); }

/* Partículas / particles */
.fx { position: absolute; left: 0; top: 0; width: 100%; height: 100%; overflow: hidden; }
.fl { position: absolute; top: 0; border-radius: 50%; background: #f6faff; }
.rn { position: absolute; top: 0; width: 3px; border-radius: 2px; background: linear-gradient(rgba(214,230,255,0), rgba(214,230,255,0.95)); transform: rotate(12deg); }
.lf { position: absolute; top: 0; width: 28px; height: 16px; border-radius: 0 100% 0 100%; }
.ff { position: absolute; width: 12px; height: 12px; border-radius: 50%; background: #f0ffb0; box-shadow: 0 0 26px 10px rgba(200,255,90,0.55); }

/* Escritorio de ejemplo / sample desktop */
.desk { position: absolute; left: 160px; top: 70px; width: 1600px; height: 640px; border-radius: 36px; overflow: hidden;
  background: linear-gradient(#283a6c, #7e9ccc); box-shadow: 0 40px 90px rgba(0,0,0,0.45), 0 0 0 2px rgba(255,255,255,0.14); }
.menu { position: absolute; left: 0; top: 0; width: 100%; height: 34px; background: rgba(255,255,255,0.16); display: flex; align-items: center; gap: 22px; padding: 0 26px; }
.menu i { width: 44px; height: 9px; border-radius: 5px; background: rgba(255,255,255,0.7); }
.menu i:first-child { width: 18px; }
.menu em { width: 14px; height: 14px; border-radius: 50%; background: rgba(255,255,255,0.7); }
.menu em:first-of-type { margin-left: auto; }
.win { position: absolute; background: #f6f7fa; border-radius: 16px; box-shadow: 0 26px 54px rgba(5,10,30,0.4); }
.win .bar { position: absolute; left: 0; top: 0; width: 100%; height: 46px; background: #e6e8ee; border-radius: 16px 16px 0 0; display: flex; align-items: center; gap: 9px; padding-left: 18px; }
.win .bar i { width: 13px; height: 13px; border-radius: 50%; background: #c4c9d4; }
.win .bar u { width: 150px; height: 9px; border-radius: 5px; background: #cdd2dc; margin-left: 150px; }
.win .side { position: absolute; left: 22px; top: 68px; bottom: 22px; width: 130px; border-radius: 10px; background: #e6e8ee; }
.win .lines { position: absolute; left: 178px; right: 26px; top: 72px; display: flex; flex-direction: column; gap: 26px; }
.win .lines b { height: 12px; border-radius: 6px; background: #d0d4dc; }
.pile { position: absolute; left: 0; top: -29px; height: 30px; overflow: visible; }
.pile path { fill: #ffffff; stroke: #b2c8e4; stroke-width: 1.5; }
.pile.floor { top: 612px; }
.dock { position: absolute; border-radius: 22px; background: rgba(255,255,255,0.3); }
.dock .tiles { position: absolute; left: 0; top: 0; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; gap: 14px; }
.dock .tiles i { width: 46px; height: 46px; border-radius: 12px; }
.cursor { position: absolute; left: 1010px; top: 420px; width: 46px; height: 46px; }
.cursor path { fill: #111; stroke: #fff; stroke-width: 1.6; stroke-linejoin: round; }
.spill { position: absolute; left: 0; top: -20px; width: 100%; height: 0; }
.sp { position: absolute; top: 0; border-radius: 50%; background: #fff; }

/* Escenas múltiples / multi scene */
.sky { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
.k0 { background: linear-gradient(#323c4c, #64728a); }
.k1 { background: linear-gradient(#141828, #3e445a); }
.k2 { background: linear-gradient(#e2a460, #804c38); }
.k3 { background: linear-gradient(#0c1826, #1a3a32); }
.flash { position: absolute; left: 0; top: 0; width: 100%; height: 100%; background: #fff; opacity: 0; }
.bolt { position: absolute; left: 760px; top: 0; width: 200px; height: 420px; opacity: 0; }
.bolt path { fill: none; stroke: #f2f6ff; stroke-width: 6; stroke-linejoin: round; filter: drop-shadow(0 0 14px #b8d0ff); }
.names { position: absolute; left: 44px; top: 62px; height: 74px; }
.nm { position: absolute; left: 0; top: 0; white-space: nowrap; padding: 12px 32px; border-radius: 999px; background: rgba(10,16,36,0.72); color: #fff; font: 600 40px "Plex", sans-serif; }

/* Clima real / real weather */
.card { position: absolute; left: 160px; top: 110px; width: 900px; height: 560px; border-radius: 40px; background: rgba(255,255,255,0.08); box-shadow: 0 0 0 2px rgba(255,255,255,0.16); padding: 54px; }
.card .top { display: flex; align-items: center; gap: 34px; }
.card h3 { font: 700 76px "Bricolage", sans-serif; letter-spacing: -2px; line-height: 1; }
.card .top p { font-size: 30px; color: var(--muted); margin-top: 12px; white-space: nowrap; }
.card strong { margin-left: auto; font: 700 150px "Bricolage", sans-serif; letter-spacing: -6px; line-height: 1; }
.strip { position: absolute; left: 54px; right: 54px; bottom: 54px; display: flex; justify-content: space-between; }
.hr { width: 84px; display: flex; flex-direction: column; align-items: center; gap: 18px; }
.hr em { font-size: 26px; color: var(--muted); white-space: nowrap; }
.hr b { font: 600 34px "Plex", sans-serif; }
.wx { position: relative; width: 54px; height: 40px; }
.wx::before { content: ""; position: absolute; left: 0; top: 4px; width: 54px; height: 28px; border-radius: 16px; background: #dfe8fa; box-shadow: 14px -10px 0 -2px #dfe8fa; }
.wx.r::after { content: ""; position: absolute; left: 12px; top: 36px; width: 5px; height: 12px; border-radius: 3px; background: #8fc2ff; box-shadow: 13px 0 0 #8fc2ff, 26px 0 0 #8fc2ff; }
.wx.m::before { background: #ffe9a8; width: 34px; height: 34px; border-radius: 50%; left: 10px; top: 2px; box-shadow: none; }
.wx.big { width: 54px; height: 40px; transform: scale(2.3); margin: 30px 44px 30px 36px; }
.mini { position: absolute; left: 1110px; top: 110px; width: 650px; height: 560px; border-radius: 40px; overflow: hidden; background: linear-gradient(#323c4c, #64728a); box-shadow: 0 0 0 2px rgba(255,255,255,0.16); }
.mwin { position: absolute; left: 90px; top: 190px; width: 470px; height: 300px; border-radius: 16px; background: #f6f7fa; box-shadow: 0 26px 54px rgba(5,10,30,0.4); }
.mwin .bar { height: 46px; background: #e6e8ee; border-radius: 16px 16px 0 0; display: flex; align-items: center; gap: 9px; padding-left: 18px; }
.mwin .bar i { width: 13px; height: 13px; border-radius: 50%; background: #c4c9d4; }

/* Taller de invierno / winter workshop */
.man { position: absolute; left: 70px; top: -134px; width: 100px; height: 132px; }
.man .b { position: absolute; border-radius: 50%; background: #fff; box-shadow: inset 0 0 0 2px #c4cede; }
.b1 { left: 14px; top: 62px; width: 72px; height: 72px; }
.b2 { left: 24px; top: 26px; width: 52px; height: 52px; }
.b3 { left: 32px; top: -6px; width: 38px; height: 38px; }
.b3 u { position: absolute; background: #1a1a1a; border-radius: 50%; width: 5px; height: 5px; top: 13px; }
.b3 .e1 { left: 11px; } .b3 .e2 { left: 22px; }
.b3 .nose { left: 18px; top: 19px; width: 18px; height: 5px; border-radius: 0 5px 5px 0; background: #ff801a; }
.hat { position: absolute; left: 36px; top: -30px; width: 30px; height: 28px; background: #1a1a1a; border-radius: 3px; box-shadow: 0 26px 0 -11px #1a1a1a, -10px 26px 0 -11px #1a1a1a, 10px 26px 0 -11px #1a1a1a; }
.tree { position: absolute; left: 1250px; top: 424px; width: 150px; height: 200px; }
.tree .t { position: absolute; left: 0; width: 0; height: 0; border-style: solid; border-color: transparent transparent #17643a transparent; }
.t1 { top: 96px; border-width: 0 75px 90px 75px; }
.t2 { top: 48px; left: 17px !important; border-width: 0 58px 80px 58px; border-bottom-color: #1b7444 !important; }
.t3 { top: 8px; left: 35px !important; border-width: 0 40px 66px 40px; border-bottom-color: #20844e !important; }
.trunk { position: absolute; left: 64px; top: 184px; width: 22px; height: 18px; background: #5c381e; }
.star { position: absolute; left: 62px; top: -8px; width: 26px; height: 26px; background: #ffd640; clip-path: polygon(50% 0, 62% 36%, 100% 38%, 70% 60%, 80% 100%, 50% 76%, 20% 100%, 30% 60%, 0 38%, 38% 36%); }
.tree u { position: absolute; width: 14px; height: 14px; border-radius: 50%; }
.cabin { position: absolute; left: 250px; top: 516px; width: 140px; height: 110px; }
.cabin .walls { position: absolute; left: 14px; top: 46px; width: 112px; height: 64px; background: #74482a; }
.cabin .roof { position: absolute; left: 0; top: 0; width: 0; height: 0; border-style: solid; border-width: 0 70px 50px 70px; border-color: transparent transparent #fff transparent; filter: drop-shadow(0 6px 0 #4c2e1a); }
.cabin .chim { position: absolute; left: 92px; top: 4px; width: 20px; height: 40px; background: #4c2e1a; }
.cabin .door { position: absolute; left: 30px; top: 68px; width: 24px; height: 42px; background: #4c2e1a; border-radius: 3px 3px 0 0; }
.cabin .lit { position: absolute; left: 74px; top: 62px; width: 32px; height: 26px; background: #ffd068; border-radius: 3px; box-shadow: 0 0 30px 8px rgba(255,200,90,0.55); }
.puff { position: absolute; left: 94px; top: -14px; width: 18px; height: 18px; border-radius: 50%; background: rgba(230,232,238,0.75); }
.plow { position: absolute; left: -110px; top: -46px; width: 100px; height: 48px; }
.plow .body { position: absolute; left: 0; top: 12px; width: 56px; height: 24px; border-radius: 4px; background: #f28c1a; }
.plow .cab { position: absolute; left: 52px; top: 0; width: 28px; height: 36px; border-radius: 4px; background: #f28c1a; }
.plow .glass { position: absolute; left: 60px; top: 6px; width: 14px; height: 12px; border-radius: 2px; background: #b4e0ff; }
.plow .blade { position: absolute; left: 86px; top: 14px; width: 12px; height: 32px; border-radius: 3px; background: #c0c4cc; transform: skewX(-12deg); }
.plow .wh { position: absolute; top: 30px; width: 18px; height: 18px; border-radius: 50%; background: #1e1e1e; }
.plow .w1 { left: 8px; } .plow .w2 { left: 56px; }

/* Rótulo inferior / lower caption */
.cap { position: absolute; left: 160px; top: 760px; width: 1600px; }
.cap h2 { font: 700 100px "Bricolage", sans-serif; letter-spacing: -3px; line-height: 1.04; }
.cap p { font-size: 46px; color: var(--muted); margin-top: 18px; }
'''

JS = '''
const tl = gsap.timeline({ paused: true });
const each = function (sel, fn) { document.querySelectorAll(sel).forEach(fn); };

// Entrada y salida suave de cada escena / soft in and out for every scene
function scene(id, start, dur, first) {
  if (!first) tl.fromTo("#" + id, { opacity: 0 }, { opacity: 1, duration: 0.35, ease: "power2.out" }, start);
  tl.to("#" + id, { opacity: 0, duration: 0.3, ease: "power2.in" }, start + dur - 0.3);
}
function caption(id, at) {
  tl.fromTo("#" + id + " .cap h2", { opacity: 0, y: 46 }, { opacity: 1, y: 0, duration: 0.55, ease: "power3.out" }, at);
  tl.fromTo("#" + id + " .cap p", { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.55, ease: "power3.out" }, at + 0.14);
}
// Caída continua: cada elemento empieza a media caída y repite hasta el final de la escena.
// Continuous fall: every element starts mid-fall and repeats until the scene ends.
function fall(sel, start, end, dist, rotate) {
  each(sel, function (el) {
    const d = parseFloat(el.dataset.d), f = parseFloat(el.dataset.f);
    const h = dist || parseFloat(el.dataset.h) + 40;
    const sw = parseFloat(el.dataset.sw || 0), r = rotate ? parseFloat(el.dataset.r || 0) : 0;
    const firstDur = d * (1 - f);
    tl.fromTo(el, { y: -40 + h * f, x: sw * f, rotation: r * f }, { y: h, x: sw, rotation: r, duration: firstDur, ease: "none" }, start);
    let t = start + firstDur;
    while (t + 0.05 < end) {
      const dur = Math.min(d, end - t);
      const p = dur / d;
      tl.fromTo(el, { y: -40, x: 0, rotation: 0 }, { y: -40 + (h + 40) * p, x: sw * p, rotation: r * p, duration: dur, ease: "none", immediateRender: false }, t);
      t += d;
    }
  });
}
function pop(sel, at, gap) {
  each(sel, function (el, i) {
    tl.fromTo(el, { opacity: 0, scale: 0.4 }, { opacity: 1, scale: 1, duration: 0.42, ease: "back.out(2)" }, at + i * (gap || 0));
  });
}

// 1. Portada / intro
scene("s1", 0, 3.6, true);
fall("#s1 .fl", 0, 3.6);
tl.fromTo("#s1 .icon", { scale: 0.7, rotation: -8 }, { scale: 1, rotation: 0, duration: 0.9, ease: "back.out(1.8)" }, 0);
tl.fromTo("#s1 h1", { y: 30 }, { y: 0, duration: 0.7, ease: "power3.out" }, 0);
tl.fromTo("#s1 .tag", { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.55, ease: "power3.out" }, 0.9);

// 2. Nieve sobre las ventanas / snow on the windows
scene("s2", 3.6, 6.0);
caption("s2", 3.8);
fall("#s2 .fl", 3.6, 9.6);
tl.fromTo("#s2 .pile", { scaleY: 0, transformOrigin: "50% 100%" }, { scaleY: 1, duration: 2.6, ease: "power1.out" }, 4.0);
tl.fromTo("#s2 .cursor", { opacity: 0, x: 220, y: 200 }, { opacity: 1, x: 0, y: -160, duration: 0.7, ease: "power2.inOut" }, 6.6);
tl.to("#s2 .wb", { x: 110, y: 40, duration: 0.9, ease: "power2.inOut" }, 7.4);
tl.to("#s2 .cursor", { x: 110, y: -120, duration: 0.9, ease: "power2.inOut" }, 7.4);
tl.to("#s2 .wb .pile", { opacity: 0, duration: 0.25 }, 7.45);
each("#s2 .sp", function (el) {
  const t = 7.45 + parseFloat(el.dataset.t);
  tl.fromTo(el, { opacity: 0, x: 0, y: 0 }, { opacity: 1, duration: 0.05 }, t);
  tl.to(el, { x: parseFloat(el.dataset.dx) - 110, y: parseFloat(el.dataset.dy), duration: 1.0, ease: "power2.in" }, t);
  tl.to(el, { opacity: 0, duration: 0.25 }, t + 0.8);
});
tl.to("#s2 .cursor", { opacity: 0, duration: 0.3 }, 8.5);

// 3. Diez escenas: lluvia, tormenta, hojas, luciérnagas / ten scenes
scene("s3", 9.6, 6.0);
caption("s3", 9.8);
const cuts = [9.6, 11.2, 12.7, 14.1, 15.6];
tl.set("#s3 .k1, #s3 .k2, #s3 .k3, #s3 .g2, #s3 .g3, #s3 .nm", { opacity: 0 }, 9.6);
tl.set("#s3 .win", { filter: "brightness(1)" }, 9.6);
for (let i = 0; i < 4; i++) {
  if (i > 0) tl.to("#s3 .k" + i, { opacity: 1, duration: 0.5, ease: "power1.inOut" }, cuts[i] - 0.25);
  tl.fromTo("#s3 .n" + i, { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.35, ease: "power3.out" }, cuts[i] + 0.1);
  if (i < 3) tl.to("#s3 .n" + i, { opacity: 0, duration: 0.2 }, cuts[i + 1] - 0.15);
}
fall("#s3 .rn", 9.6, 12.7, 700);
tl.to("#s3 .g0", { opacity: 0, duration: 0.4 }, 12.5);
[11.7, 12.15].forEach(function (t) {
  tl.to("#s3 .flash", { opacity: 0.32, duration: 0.05 }, t);
  tl.to("#s3 .flash", { opacity: 0, duration: 0.35 }, t + 0.06);
  tl.to("#s3 .bolt", { opacity: 1, duration: 0.04 }, t);
  tl.to("#s3 .bolt", { opacity: 0, duration: 0.3 }, t + 0.1);
});
tl.to("#s3 .win", { filter: "brightness(0.42)", duration: 0.5 }, 10.95);
tl.to("#s3 .win", { filter: "brightness(1)", duration: 0.5 }, 12.45);
tl.to("#s3 .g2", { opacity: 1, duration: 0.4 }, 12.6);
fall("#s3 .lf", 12.6, 14.3, 700, true);
tl.to("#s3 .g2", { opacity: 0, duration: 0.35 }, 13.95);
tl.to("#s3 .win", { filter: "brightness(0.34)", duration: 0.5 }, 13.85);
tl.to("#s3 .g3", { opacity: 1, duration: 0.4 }, 14.0);
each("#s3 .ff", function (el) {
  const t = 14.0 + parseFloat(el.dataset.t);
  tl.fromTo(el, { opacity: 0.1, x: 0, y: 0 }, { opacity: 1, x: parseFloat(el.dataset.dx), y: parseFloat(el.dataset.dy), duration: 0.75, ease: "sine.inOut", yoyo: true, repeat: 1 }, t);
});

// 4. Clima real / real weather
scene("s4", 15.6, 4.8);
caption("s4", 15.8);
tl.fromTo("#s4 .card", { opacity: 0, x: -60 }, { opacity: 1, x: 0, duration: 0.6, ease: "power3.out" }, 15.8);
tl.fromTo("#s4 .mini", { opacity: 0, x: 60 }, { opacity: 1, x: 0, duration: 0.6, ease: "power3.out" }, 15.95);
tl.fromTo("#s4 .card strong", { opacity: 0, scale: 0.6 }, { opacity: 1, scale: 1, duration: 0.5, ease: "back.out(1.8)" }, 16.3);
each("#s4 .hr", function (el, i) {
  tl.fromTo(el, { opacity: 0, y: 34 }, { opacity: 1, y: 0, duration: 0.4, ease: "power3.out" }, 16.6 + i * 0.09);
});
fall("#s4 .rn", 15.6, 20.4, 620);

// 5. Taller de invierno / winter workshop
scene("s5", 20.4, 4.8);
caption("s5", 20.6);
fall("#s5 .fl", 20.4, 25.2);
pop("#s5 .man .b", 21.0, 0.22);
pop("#s5 .hat", 21.7);
tl.fromTo("#s5 .cabin", { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.5, ease: "back.out(1.6)" }, 21.2);
each("#s5 .puff", function (el, i) {
  tl.fromTo(el, { opacity: 0, x: 0, y: 0, scale: 0.6 }, { opacity: 0.8, x: 16, y: -44, scale: 1.5, duration: 1.1, ease: "power1.out", repeat: 2 }, 21.6 + i * 0.36);
  tl.to(el, { opacity: 0, duration: 0.2 }, 21.6 + i * 0.36 + 3.2);
});
tl.fromTo("#s5 .tree", { scale: 0, transformOrigin: "50% 100%" }, { scale: 1, duration: 0.6, ease: "back.out(1.7)" }, 21.9);
pop("#s5 .tree u", 22.4, 0.07);
tl.fromTo("#s5 .star", { scale: 0, rotation: -90 }, { scale: 1, rotation: 0, duration: 0.45, ease: "back.out(2.4)" }, 22.9);
tl.fromTo("#s5 .plow", { x: 0 }, { x: 820, duration: 2.0, ease: "none" }, 22.9);
tl.fromTo("#s5 .dockpile", { clipPath: "inset(-40px 0px 0px 0%)" }, { clipPath: "inset(-40px 0px 0px 100%)", duration: 1.47, ease: "none" }, 23.14);

// 6. Cierre / outro
scene("s6", 25.2, 4.8);
fall("#s6 .fl", 25.2, 30);
tl.fromTo("#s6 .icon", { scale: 0.6, opacity: 0 }, { scale: 1, opacity: 1, duration: 0.6, ease: "back.out(1.6)" }, 25.35);
tl.fromTo("#s6 h1", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, 25.6);
tl.fromTo("#s6 .tag", { opacity: 0, y: 26 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, 25.85);
tl.fromTo("#s6 .btn", { opacity: 0, scale: 0.9 }, { opacity: 1, scale: 1, duration: 0.5, ease: "back.out(1.6)" }, 26.2);
tl.fromTo("#s6 .url", { opacity: 0, y: 26 }, { opacity: 1, y: 0, duration: 0.5, ease: "power3.out" }, 26.5);
tl.to("#s6 .btn", { scale: 1.05, duration: 0.4, repeat: 3, yoyo: true, ease: "sine.inOut" }, 27.4);

window.__timelines = window.__timelines || {};
window.__timelines["main"] = tl;
tl.seek(0);
'''

html = f'''<!doctype html>
<html lang="{T["lang"]}">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <title>Nimbo · video</title>
    <script src="assets/gsap.min.js"></script>
    <style>{CSS}</style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{TOTAL}" data-width="1920" data-height="1080">
      {"".join(body)}
    </div>
    <script>{JS}</script>
  </body>
</html>
'''
open("index.html", "w", encoding="utf-8").write(html)
print("index.html:", LANG, len(html), "bytes")
