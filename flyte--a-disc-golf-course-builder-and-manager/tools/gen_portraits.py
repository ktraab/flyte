#!/usr/bin/env python3
"""Generate the story portraits in assets/portraits/*.svg — original flat-vector art.

One shared bust template (same head, lighting, framing and backdrop) with a
per-character layer for hair, face details and clothing, so the cast reads as one
set. Pure stdlib:  python3 -I tools/gen_portraits.py   (overwrites the SVGs).

Only characters that appear in "dialogue"-style beats are drawn here:
player (male + female looks), jess_nakamura, marcus_bell, diana_cross, visitor. (Uncle Ray only writes
a letter and Dani Walsh only bylines the newspaper, so neither shows a portrait.)

Light comes from the upper left; shadows fall to the right. Characters face the
viewer. Canvas 256x256.
"""
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "portraits")

# ── Shared template ─────────────────────────────────────────────────────────

HEAD = ("M84 104 C84 66 102 54 128 54 C154 54 172 66 172 104 "
        "C172 134 160 157 141 166 Q128 172 115 166 C96 157 84 134 84 104 Z")
BODY = "M22 256 C26 206 70 186 128 186 C186 186 230 206 234 256 Z"
NECK = "M110 138 L110 180 Q128 194 146 180 L146 138 Z"


def backdrop(c1, c2, hill):
    return f"""
  <defs>
    <radialGradient id="bg" cx="0.42" cy="0.34" r="0.8">
      <stop offset="0" stop-color="{c1}"/>
      <stop offset="1" stop-color="{c2}"/>
    </radialGradient>
    <clipPath id="frame"><rect width="256" height="256" rx="28"/></clipPath>
    <clipPath id="head"><path d="{HEAD}"/></clipPath>
    <clipPath id="body"><path d="{BODY}"/></clipPath>
  </defs>
  <g clip-path="url(#frame)">
  <rect width="256" height="256" fill="url(#bg)"/>
  <path d="M0 196 Q48 168 104 184 Q160 200 204 176 Q232 162 256 170 L256 256 L0 256 Z" fill="{hill}" fill-opacity="0.55"/>
  <path d="M0 222 Q70 200 140 214 Q200 226 256 206 L256 256 L0 256 Z" fill="{hill}" fill-opacity="0.75"/>"""


def bust(skin, shade):
    """Neck, ears and face with upper-left lighting."""
    return f"""
  <path d="{NECK}" fill="{shade}"/>
  <path d="M110 160 Q128 176 146 160 L146 150 Q128 164 110 150 Z" fill="#000" fill-opacity="0.12"/>
  <ellipse cx="85" cy="113" rx="8" ry="12" fill="{skin}"/>
  <ellipse cx="171" cy="113" rx="8" ry="12" fill="{shade}"/>
  <path d="{HEAD}" fill="{skin}"/>
  <g clip-path="url(#head)">
    <ellipse cx="200" cy="118" rx="44" ry="76" fill="{shade}" fill-opacity="0.75"/>
    <ellipse cx="128" cy="184" rx="60" ry="22" fill="{shade}" fill-opacity="0.45"/>
  </g>"""


def eyes(iris, lids="#2b211c", y=110, lidded=False):
    lid = ""
    if lidded:  # heavy upper lids: amused / unimpressed
        lid = (f'<path d="M101 {y-6} Q111 {y-9} 121 {y-5} L121 {y-1} Q111 {y-4} 101 {y-1} Z" fill="{lids}" fill-opacity="0.55"/>'
               f'<path d="M135 {y-5} Q145 {y-9} 155 {y-6} L155 {y-1} Q145 {y-4} 135 {y-1} Z" fill="{lids}" fill-opacity="0.55"/>')
    out = []
    for cx in (111, 145):
        out.append(f"""
  <ellipse cx="{cx}" cy="{y}" rx="9" ry="6" fill="#fbf7f2"/>
  <circle cx="{cx+1}" cy="{y}" r="4.6" fill="{iris}"/>
  <circle cx="{cx+1}" cy="{y}" r="2.2" fill="#140f0c"/>
  <circle cx="{cx-0.6}" cy="{y-1.8}" r="1.3" fill="#fff"/>
  <path d="M{cx-10} {y-1} Q{cx} {y-9} {cx+10} {y-1}" stroke="{lids}" stroke-width="2.6" fill="none" stroke-linecap="round"/>""")
    return "".join(out) + lid


def brows(color, left, right, w=4.5):
    return (f'\n  <path d="{left}" stroke="{color}" stroke-width="{w}" fill="none" stroke-linecap="round"/>'
            f'\n  <path d="{right}" stroke="{color}" stroke-width="{w}" fill="none" stroke-linecap="round"/>')


def nose(shade):
    return f"""
  <path d="M130 112 Q133 124 136 130 Q130 135 122 131 Q127 129 128 124 Z" fill="{shade}" fill-opacity="0.9"/>
  <circle cx="124" cy="129" r="1.6" fill="#000" fill-opacity="0.18"/>"""


def blush(color="#e0806a", o=0.22):
    return (f'\n  <ellipse cx="103" cy="128" rx="9" ry="5" fill="{color}" fill-opacity="{o}"/>'
            f'\n  <ellipse cx="153" cy="128" rx="9" ry="5" fill="{color}" fill-opacity="{o * 0.7:.2f}"/>')


def svg(title, *parts):
    body = "".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n'
            f'  <title>{title}</title>{body}\n  </g>\n</svg>\n')


# ── Characters ──────────────────────────────────────────────────────────────

# Both player looks share the backdrop, skin, eyes and work jacket, so they read
# as the same person-type; only hair and a few face details differ.
_P_SKIN, _P_SHADE = "#d9a67e", "#b9825d"
_P_HAIR, _P_HAIR_HI = "#4a3324", "#6b4a33"


def _player_base():
    return (
        backdrop("#6fae6a", "#24502c", "#1c3d22")
        # tiny basket on the far hill — the reason you're here
        + '\n  <g fill="#14301a" fill-opacity="0.8"><rect x="211" y="150" width="2.4" height="26"/>'
        '<path d="M203 160 h18 l-2 7 h-14 Z"/><rect x="204" y="148" width="16" height="2.4"/></g>'
        # work jacket over a tee
        + f'\n  <path d="{BODY}" fill="#5b6b3a"/>'
        '\n  <g clip-path="url(#body)"><path d="M150 186 C190 190 228 210 234 256 L170 256 Z" fill="#000" fill-opacity="0.18"/>'
        '<path d="M106 186 L128 228 L150 186 Z" fill="#e9e3d6"/>'
        '<path d="M100 186 L128 236 L104 256 L74 256 L82 200 Z" fill="#6b7c45"/>'
        '<path d="M156 186 L128 236 L152 256 L182 256 L174 200 Z" fill="#4e5c31"/>'
        '<rect x="56" y="226" width="26" height="16" rx="3" fill="#4e5c31"/>'
        '<path d="M58 226 h22" stroke="#3c4826" stroke-width="2"/></g>'
    )


def player():
    """You (male look) — lapsed amateur back on the land: work jacket, tousled hair."""
    skin, shade, hair, hair_hi = _P_SKIN, _P_SHADE, _P_HAIR, _P_HAIR_HI
    return svg("You",
        _player_base(),
        bust(skin, shade),
        eyes("#4b6a3a"),
        brows(hair, "M100 97 Q110 92 121 96", "M135 96 Q146 92 156 97"),
        nose(shade),
        '\n  <path d="M115 145 Q128 153 142 144" stroke="#7a4434" stroke-width="3.2" fill="none" stroke-linecap="round"/>',
        blush(o=0.16),
        # tousled short hair
        f'\n  <path d="M82 108 C76 70 98 46 128 46 C160 46 182 66 174 108 C170 90 166 80 158 76 '
        f'C150 84 132 82 122 76 C114 86 98 86 92 80 C88 88 85 96 82 108 Z" fill="{hair}"/>',
        f'\n  <path d="M100 58 C114 50 138 48 156 58 C140 56 124 58 110 66 Z" fill="{hair_hi}"/>',
        f'\n  <path d="M150 76 C158 70 166 74 170 82 C164 80 158 80 150 76 Z" fill="#000" fill-opacity="0.2"/>',
    )


def player_female():
    """You (female look) — same jacket and backdrop; shoulder-length hair, side part."""
    skin, shade, hair, hair_hi = _P_SKIN, _P_SHADE, _P_HAIR, _P_HAIR_HI
    return svg("You",
        _player_base(),
        # hair falling behind the head and resting on the shoulders (neck/head drawn over it)
        f'\n  <path d="M80 150 C70 100 78 48 128 44 C178 48 186 100 176 150 C180 178 178 198 170 212 '
        f'Q160 214 150 204 L146 150 L110 150 L106 204 Q96 214 86 212 C78 198 76 178 80 150 Z" fill="{hair}"/>',
        f'\n  <path d="M166 150 C172 172 172 192 166 206" stroke="#000" stroke-opacity="0.18" stroke-width="5" fill="none" stroke-linecap="round"/>',
        bust(skin, shade),
        eyes("#4b6a3a"),
        # lashes at the outer corners
        '\n  <path d="M102 107 l-5 -3 M154 107 l5 -3" stroke="#2b211c" stroke-width="2" stroke-linecap="round"/>',
        brows(hair, "M101 97 Q110 92 121 95", "M135 95 Q146 92 155 97", 3.4),
        nose(shade),
        '\n  <path d="M116 145 Q128 155 141 144 Q128 150 116 145 Z" fill="#b5585a"/>',
        '\n  <path d="M116 145 Q128 153 141 144" stroke="#8a3a3c" stroke-width="2" fill="none" stroke-linecap="round"/>',
        blush(o=0.22),
        # crown with a side part, bangs swept across the forehead
        f'\n  <path d="M84 114 C80 70 100 50 128 48 C158 48 176 68 172 114 C170 94 164 82 152 78 '
        f'C136 84 112 88 98 98 C92 102 88 108 84 114 Z" fill="{hair}"/>',
        f'\n  <path d="M150 52 C126 56 100 72 90 108 C100 88 120 80 140 74 C148 70 152 62 150 52 Z" fill="{hair_hi}"/>',
        # strands framing the face
        f'\n  <path d="M78 100 C72 130 80 160 92 178 C90 152 94 128 98 106 Z" fill="{hair}"/>',
        f'\n  <path d="M178 100 C184 130 176 160 164 178 C166 152 162 128 158 106 Z" fill="{hair}"/>',
    )


def jess():
    """Jess Nakamura — young touring pro. Visor, ponytail, sponsor jersey, honest half-smile."""
    skin, shade = "#ecc39c", "#cc9c74"
    hair, hair_hi = "#17120f", "#3a2e28"
    return svg("Jess Nakamura",
        backdrop("#f0c75a", "#8a5a12", "#5e3c08"),
        # ponytail behind
        f'\n  <path d="M158 70 C200 72 210 124 190 176 C186 150 178 122 162 104 Z" fill="{hair}"/>',
        f'\n  <path d="M176 92 C190 108 192 132 188 150" stroke="{hair_hi}" stroke-width="3" fill="none" stroke-linecap="round"/>',
        # jersey
        f'\n  <path d="{BODY}" fill="#1f8a9a"/>',
        '\n  <g clip-path="url(#body)"><path d="M150 186 C190 190 228 210 234 256 L172 256 Z" fill="#000" fill-opacity="0.2"/>'
        '<path d="M22 228 L234 214 L234 230 L22 244 Z" fill="#f4f1ea"/>'
        '<path d="M108 186 L128 210 L148 186 Z" fill="#14606c"/>'
        '<circle cx="172" cy="206" r="9" fill="#f4f1ea"/><circle cx="172" cy="206" r="5" fill="none" stroke="#1f8a9a" stroke-width="2"/></g>',
        bust(skin, shade),
        '\n  <circle cx="85" cy="123" r="2.2" fill="#f2d16b"/>',
        eyes("#3a2618", y=112),
        # one brow up: honest, a little skeptical
        brows(hair, "M100 100 Q110 96 121 99", "M135 97 Q146 90 157 95", 4),
        nose(shade),
        '\n  <path d="M116 147 Q130 153 143 142" stroke="#8a4a3c" stroke-width="3.2" fill="none" stroke-linecap="round"/>',
        '\n  <path d="M141 141 Q145 142 146 145" stroke="#8a4a3c" stroke-width="2" fill="none" stroke-linecap="round"/>',
        blush("#e57a6a", 0.24),
        # hair under the visor + side strands
        f'\n  <path d="M84 116 C78 70 98 48 128 48 C158 48 178 70 172 116 C168 98 160 88 148 86 '
        f'C132 92 112 90 100 86 C92 92 86 104 84 116 Z" fill="{hair}"/>',
        f'\n  <path d="M86 100 C84 118 86 134 92 146 C88 126 90 112 94 100 Z" fill="{hair}"/>',
        f'\n  <path d="M104 56 C116 50 140 50 154 58 C140 56 124 56 112 62 Z" fill="{hair_hi}"/>',
        f'\n  <path d="M160 66 C166 64 170 70 168 76 C164 74 162 70 160 66 Z" fill="#d8475a"/>',
        # visor: band + brim with a shadow on the brow
        '\n  <g clip-path="url(#head)"><rect x="80" y="84" width="96" height="10" fill="#000" fill-opacity="0.16"/></g>',
        '\n  <path d="M80 76 Q128 58 176 76 L176 86 Q128 70 80 86 Z" fill="#f7f5f0"/>',
        '\n  <path d="M72 84 Q128 66 184 84 Q176 98 128 94 Q80 98 72 84 Z" fill="#ffffff"/>',
        '\n  <path d="M72 84 Q128 66 184 84 Q178 90 160 92 Q128 80 96 92 Q78 90 72 84 Z" fill="#1f8a9a"/>',
        '\n  <path d="M118 74 h20" stroke="#1f8a9a" stroke-width="3" stroke-linecap="round"/>',
    )


def marcus():
    """Marcus Bell — WDGA regional rep. Rumpled jacket, loose tie, clipboard, big grin."""
    skin, shade = "#8a5a3c", "#6e452c"
    hair = "#1d1612"
    return svg("Marcus Bell",
        backdrop("#6f9fd8", "#1f3d6e", "#18305a"),
        # jacket, shirt, tie
        f'\n  <path d="{BODY}" fill="#a8875a"/>',
        '\n  <g clip-path="url(#body)"><path d="M150 186 C190 190 228 210 234 256 L172 256 Z" fill="#000" fill-opacity="0.18"/>'
        '<path d="M104 186 L128 244 L152 186 Z" fill="#cfe0f2"/>'
        '<path d="M122 196 L134 196 L138 240 L128 252 L118 240 Z" fill="#8c2f2f" transform="rotate(6 128 196)"/>'
        '<path d="M120 188 L136 188 L134 198 L122 198 Z" fill="#7a2626" transform="rotate(6 128 196)"/>'
        '<path d="M98 186 L128 246 L110 256 L72 256 L80 204 Z" fill="#b8976a"/>'
        '<path d="M158 186 L128 246 L146 256 L184 256 L176 204 Z" fill="#8e7048"/>'
        # rumples
        '<path d="M60 222 Q70 230 66 244 M196 216 Q188 230 194 246 M84 214 Q90 222 86 232" stroke="#7e6240" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
        '<path d="M152 204 h14 v10 h-14 Z" fill="#cfe0f2"/><path d="M155 204 v-6 M160 204 v-8" stroke="#2a3f66" stroke-width="2.2"/></g>',
        bust(skin, shade),
        eyes("#3a2416", lids="#1d1612"),
        # big raised brows — enthusiastic
        brows(hair, "M99 94 Q110 87 121 92", "M135 92 Q146 87 157 94", 5),
        # round glasses
        '\n  <g fill="none" stroke="#2a2420" stroke-width="3"><circle cx="111" cy="110" r="13"/><circle cx="145" cy="110" r="13"/>'
        '<path d="M124 108 Q128 105 132 108"/><path d="M98 108 L86 104 M158 108 L170 104"/></g>',
        '\n  <path d="M102 102 Q106 98 112 98" stroke="#fff" stroke-opacity="0.5" stroke-width="2" fill="none" stroke-linecap="round"/>',
        nose(shade),
        # grin + mustache
        '\n  <path d="M110 143 Q128 166 146 143 Q128 150 110 143 Z" fill="#3a1a14"/>',
        '\n  <path d="M113 144 Q128 150 143 144 L141 149 Q128 153 115 149 Z" fill="#fbf7f2"/>',
        f'\n  <path d="M108 141 Q118 132 128 137 Q138 132 148 141 Q138 138 128 141 Q118 138 108 141 Z" fill="{hair}"/>',
        blush("#c05a3a", 0.18),
        # short cropped hair, receding a little
        f'\n  <path d="M84 104 C80 70 100 50 128 50 C156 50 176 70 172 104 C170 90 166 80 160 74 '
        f'Q146 66 128 68 Q110 66 96 74 C90 80 86 90 84 104 Z" fill="{hair}"/>',
        '\n  <path d="M100 60 Q128 50 156 60" stroke="#3a2e28" stroke-width="2" fill="none" stroke-linecap="round"/>',
        # clipboard held up at the left
        '\n  <g transform="rotate(-10 64 224)">'
        '<rect x="30" y="186" width="66" height="84" rx="5" fill="#8a5a2e"/>'
        '<rect x="36" y="196" width="54" height="70" rx="2" fill="#f6f2e6"/>'
        '<path d="M42 210 h40 M42 220 h36 M42 230 h40 M42 240 h30" stroke="#9aa6b8" stroke-width="2.4" stroke-linecap="round"/>'
        '<path d="M44 248 l4 4 l8 -9" stroke="#3a8a46" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
        '<rect x="50" y="180" width="26" height="12" rx="3" fill="#b9bec6"/><rect x="56" y="176" width="14" height="6" rx="2" fill="#8e949c"/>'
        f'<ellipse cx="96" cy="228" rx="9" ry="12" fill="{skin}"/></g>',
    )


def diana():
    """Diana Cross — rival owner of Cross Pines. Sleek bob, navy blazer, pearls, knowing look."""
    skin, shade = "#f0cdb4", "#d3a589"
    hair, hair_hi = "#d9c9a8", "#f3e8cf"
    return svg("Diana Cross",
        backdrop("#a2445a", "#3e1020", "#2c0a16"),
        # bob, back layer
        f'\n  <path d="M78 156 C70 104 78 50 128 46 C178 50 186 104 178 156 Q168 164 156 158 L100 158 Q88 164 78 156 Z" fill="#bfae8a"/>',
        # blazer + blouse
        f'\n  <path d="{BODY}" fill="#22304f"/>',
        '\n  <g clip-path="url(#body)"><path d="M150 186 C190 190 228 210 234 256 L172 256 Z" fill="#000" fill-opacity="0.25"/>'
        '<path d="M108 186 L128 236 L148 186 Z" fill="#f5f2ee"/>'
        '<path d="M108 186 L118 206 L128 196 Z M148 186 L138 206 L128 196 Z" fill="#e2ddd6"/>'
        '<path d="M102 186 L128 242 L112 256 L74 256 L84 202 Z" fill="#2c3c60"/>'
        '<path d="M154 186 L128 242 L144 256 L182 256 L172 202 Z" fill="#1a2540"/>'
        # gold lapel pin: a little pine
        '<path d="M86 214 l6 -12 l6 12 Z" fill="#d6b04a"/><rect x="91" y="214" width="2" height="4" fill="#d6b04a"/></g>',
        bust(skin, shade),
        # pearls
        '\n  <circle cx="84" cy="128" r="3.6" fill="#f8f4ec"/><circle cx="83" cy="127" r="1.2" fill="#fff"/>',
        eyes("#4a6a7a", lids="#3a2a24", lidded=True),
        # one brow arched — she already knows your answer
        brows("#a08a66", "M100 99 Q110 95 121 98", "M135 96 Q147 88 157 94", 3.6),
        nose(shade),
        '\n  <path d="M115 145 Q124 144 128 145 Q133 144 142 140 Q134 152 128 151 Q120 151 115 145 Z" fill="#b2333f"/>',
        '\n  <path d="M118 145 Q128 147 140 141" stroke="#7e1e28" stroke-width="1.6" fill="none" stroke-linecap="round"/>',
        blush("#d9707a", 0.18),
        # side-parted fringe sweeping across the forehead
        f'\n  <path d="M84 112 C80 72 100 54 132 52 C160 54 176 72 172 112 C168 92 160 80 146 76 '
        f'C124 80 102 92 88 124 Z" fill="{hair}"/>',
        f'\n  <path d="M146 54 C122 58 98 74 88 120 C96 92 114 80 132 74 C142 70 146 62 146 54 Z" fill="{hair_hi}"/>',
        f'\n  <path d="M172 112 C176 128 176 144 172 156 L164 156 C170 140 170 126 166 104 Z" fill="#bfae8a"/>',
    )


def visitor():
    """A Regular — local who has played Ray's holes for years. Bucket hat, grey beard, flannel."""
    skin, shade = "#e2b08e", "#c08b69"
    beard, beard_hi = "#c9c4bc", "#e6e2dc"
    return svg("A Regular",
        backdrop("#d39a5a", "#5e3416", "#46260e"),
        # flannel
        f'\n  <path d="{BODY}" fill="#a8362e"/>',
        '\n  <g clip-path="url(#body)">'
        '<path d="M22 212 H234 M22 236 H234 M60 186 V256 M100 186 V256 M156 186 V256 M196 186 V256" stroke="#5e1a16" stroke-width="7" stroke-opacity="0.55"/>'
        '<path d="M22 224 H234 M80 186 V256 M176 186 V256" stroke="#e8c27a" stroke-width="2" stroke-opacity="0.5"/>'
        '<path d="M150 186 C190 190 228 210 234 256 L172 256 Z" fill="#000" fill-opacity="0.2"/>'
        '<path d="M106 186 L128 214 L150 186 Z" fill="#6a6660"/>'
        '<path d="M100 186 L128 222 L112 230 L92 200 Z M156 186 L128 222 L144 230 L164 200 Z" fill="#8e2a24"/></g>',
        bust(skin, shade),
        eyes("#5a7088", y=111),
        # crow's feet — he smiles a lot
        '\n  <path d="M96 108 l-6 -3 M96 112 l-6 1 M160 108 l6 -3 M160 112 l6 1" stroke="#a87458" stroke-width="1.8" stroke-linecap="round"/>',
        brows(beard, "M99 99 Q110 94 121 98", "M135 98 Q146 94 157 99", 5),
        nose(shade),
        blush("#d8705a", 0.26),
        # beard + mustache, with the smile showing through
        f'\n  <path d="M86 112 C86 150 104 180 128 182 C152 180 170 150 170 112 C166 132 156 142 146 144 '
        f'Q128 136 110 144 C100 142 90 132 86 112 Z" fill="{beard}"/>',
        f'\n  <path d="M92 130 C98 156 112 172 128 174 C114 166 102 152 96 132 Z" fill="{beard_hi}"/>',
        '\n  <path d="M115 148 Q128 157 141 148" stroke="#6a3a2c" stroke-width="3" fill="none" stroke-linecap="round"/>',
        f'\n  <path d="M108 142 Q118 134 128 138 Q138 134 148 142 Q138 141 128 143 Q118 141 108 142 Z" fill="{beard_hi}"/>',
        # bucket hat
        '\n  <g clip-path="url(#head)"><rect x="80" y="86" width="96" height="9" fill="#000" fill-opacity="0.15"/></g>',
        '\n  <path d="M90 84 C90 52 108 44 128 44 C148 44 166 52 166 84 Z" fill="#6e7444"/>',
        '\n  <path d="M90 76 Q128 68 166 76 L166 84 Q128 76 90 84 Z" fill="#4e5430"/>',
        '\n  <path d="M70 88 Q128 70 186 88 Q182 100 128 96 Q74 100 70 88 Z" fill="#7c8350"/>',
        '\n  <path d="M100 52 Q114 46 130 48" stroke="#8e9560" stroke-width="3" fill="none" stroke-linecap="round"/>',
        '\n  <path d="M150 86 Q170 86 182 92 Q170 98 150 96 Z" fill="#000" fill-opacity="0.15"/>',
    )


PORTRAITS = {
    "player": player,
    "player_female": player_female,
    "jess_nakamura": jess,
    "marcus_bell": marcus,
    "diana_cross": diana,
    "visitor": visitor,
}

if __name__ == "__main__":
    for name, fn in PORTRAITS.items():
        path = os.path.join(OUT, name + ".svg")
        with open(path, "w") as f:
            f.write(fn())
        print("wrote", os.path.relpath(path))
