#!/usr/bin/env python3
"""Generate the four pictorial wiring guides from one source of truth.

Variants
--------
  1a  without UWB, CIT_FC design
  1b  without UWB, Loftwork bench scheme (test _003), scaled to 8 servos
  2a  with UWB,    CIT_FC design
  2b  with UWB,    Loftwork bench scheme + DWM3000 added

Four near-identical diagrams maintained by hand drift apart; they already did
once (the old with-dwm.svg kept GPIO35/36 pin labels after the I2C bus moved
to GPIO2/3). Keeping them in one generator makes that class of bug impossible.

The netlist in docs/wiring/ remains the source of truth. This only draws it.

Usage:  python3 generate.py          # writes *.svg next to this file
"""

from pathlib import Path

W, H = 1780, 1080

# ---- layout constants -------------------------------------------------
# Named because the wire router references them. Hard-coding these inline is
# what put the MCU pin stack on top of the PCA9685 in the first draft.
MCU_X, MCU_Y, MCU_W, MCU_H = 990, 560, 220, 300
MCU_PIN_L = MCU_X - 70          # 920  left pin-box left edge
MCU_PIN_RE = MCU_X + 296        # 1286 right pin-box right edge
SIDE_X = 1330                   # OLED / UWB column left edge
UWB_Y, UWB_H = 560, 300
UWB_PIN = SIDE_X + 16           # 1346 UWB header pin left edge

PCA_X, PCA_Y, PCA_W, PCA_H = 470, 600, 360, 160
DIST_X, DIST_Y, DIST_W = 470, 410, 360
GND_Y, RAIL_Y = DIST_Y + 31, DIST_Y + 77      # bar centre lines: 441 / 487
BAR_L, BAR_R = DIST_X + 14, DIST_X + 346      # 484 / 816

# PCA9685 pin anchor points (absolute)
PCA_VP = (PCA_X + 12, PCA_Y + 57)             # 482, 657  V+
PCA_GND = (PCA_X + 12, PCA_Y + 83)            # 482, 683  GND
PCA_VCC_Y = PCA_Y + 109                       # 709       VCC 3V3
PCA_PIN_BOT = PCA_Y + 146                     # 746       bottom of I2C row
SDA_X, SCL_X, OE_X = 517, 595, 676            # risers into SDA / SCL / OE
SDA_X2, SCL_X2 = 535, 613                     # second tap (OLED) on same pins

# MCU left pin centres (absolute)
M5V, M3V3, MGND, MSDA, MSCL, MOE = 641, 669, 697, 725, 753, 781
# MCU right pin centres (UWB SPI), top to bottom
SPI_Y = [641, 669, 697, 725, 753, 781, 809, 837]
# UWB header pin centres
HDR_Y = [622, 646, 670, 694, 718, 742, 766, 790]

# OLED bottom pin taps (absolute x)
OL_GND, OL_VCC, OL_SCL, OL_SDA = SIDE_X + 40, SIDE_X + 95, SIDE_X + 150, SIDE_X + 205
OLED_BOT = 480

STYLE = """
    .wire{fill:none;stroke-width:6;stroke-linecap:round;stroke-linejoin:round}
    .w5v{stroke:#e23b2e}.gnd{stroke:#141414}.sig{stroke:#f6a623}
    .sda{stroke:#33aa44}.scl{stroke:#2aa4dd}.oe{stroke:#8e44ad}
    .v33{stroke:#f4b400}.spi{stroke:#7a5cff}
    .board{stroke:#333;stroke-width:2}
    .lbl{font-size:18px;fill:#111}.lbls{font-size:14px;fill:#222}
    .pin{font-size:13px;fill:#fff;font-weight:bold}
    .note{font-size:14px;fill:#7a2b12}
    .warn{font-size:14px;fill:#b00020;font-weight:bold}
    .h1{font-size:32px;font-weight:bold;fill:#1c1c1c}
    .h2{font-size:20px;font-weight:bold;fill:#7b2d8e}
    .h3{font-size:15px;fill:#555}
    .cap{font-size:15px;fill:#333;font-weight:bold}
    .badge{font-size:15px;font-weight:bold}
"""

# Servo channel -> upstream servoPins[] leg index (preserved for Sesame Studio)
LEGS = [1, 2, 4, 6, 8, 10, 13, 14]


class Variant:
    def __init__(self, vid, uwb, scheme):
        self.vid = vid
        self.uwb = uwb
        self.ours = scheme == "ours"
        if self.ours:
            self.rail = "5.2 V"
            self.cells = "2S 18650 protected"
            self.cells2 = "7.4 V nom &#183; XH2.54-2P"
            self.oe = True
            self.gndname = "GND_STAR"
            self.gndkind = "star"
            self.dualsrc = True
            self.bulkcap = True
            self.origin = "CIT_FC design (this repo)"
            self.accent = "#7b2d8e"
        else:
            self.rail = "5.0 V"
            self.cells = "2S 14500"
            self.cells2 = "7.4 V nom"
            self.oe = False
            self.gndname = "COMMON GND RAIL"
            self.gndkind = "breadboard"
            self.dualsrc = False
            self.bulkcap = False
            self.origin = "Loftwork bench scheme &#8212; Robotics/Design test _003"
            self.accent = "#1746a2"


def header(v):
    sub = "WITH UWB (DWM3000)" if v.uwb else "WITHOUT UWB"
    return f'''  <g transform="translate(40,30)">
    <g fill="#e8632a">
      <rect x="4" y="10" width="14" height="14" rx="3"/><rect x="24" y="4" width="14" height="14" rx="3"/>
      <rect x="44" y="10" width="14" height="14" rx="3"/><rect x="14" y="28" width="34" height="16" rx="4"/>
      <rect x="6" y="46" width="8" height="16"/><rect x="22" y="46" width="8" height="16"/>
      <rect x="34" y="46" width="8" height="16"/><rect x="50" y="46" width="8" height="16"/>
    </g>
    <text x="78" y="28" class="h1">Sesame Robot &#183; {v.vid.upper()}</text>
    <text x="78" y="54" class="h2">ESP32-S3 Super Mini &#183; PCA9685 &#8212; {sub}</text>
    <text x="78" y="76" class="h3">{v.origin}</text>
  </g>

  <g transform="translate(1200,30)">
    <rect x="0" y="0" width="112" height="40" rx="8" fill="{v.accent}"/>
    <text x="56" y="27" text-anchor="middle" class="badge" fill="#fff">{v.vid.upper()}</text>
  </g>'''


def legend(v):
    rows_l = [("#e23b2e", f"5V / V+ ({v.rail})"),
              ("#141414", f"GND ({v.gndkind})"),
              ("#f6a623", "Servo PWM signal"),
              ("#f4b400", "3V3 logic")]
    rows_r = [("#33aa44", "I2C SDA (GPIO2)"),
              ("#2aa4dd", "I2C SCL (GPIO3)")]
    if v.oe:
        rows_r.append(("#8e44ad", "PCA9685 OE (GPIO18)"))
    if v.uwb:
        rows_r.append(("#7a5cff", "UWB SPI bus"))
    o = ['  <g transform="translate(1360,26)">',
         '    <rect x="0" y="0" width="392" height="124" rx="10" fill="#fafafa" class="board"/>',
         '    <text x="14" y="24" class="lbl" font-weight="bold">Wire colour key</text>',
         '    <g stroke-width="6" stroke-linecap="round">']
    for i, (c, t) in enumerate(rows_l):
        y = 44 + i * 22
        o.append(f'      <line x1="16" y1="{y}" x2="52" y2="{y}" stroke="{c}"/>'
                 f'<text x="60" y="{y+5}" class="lbls">{t}</text>')
    for i, (c, t) in enumerate(rows_r):
        y = 44 + i * 22
        o.append(f'      <line x1="200" y1="{y}" x2="236" y2="{y}" stroke="{c}"/>'
                 f'<text x="244" y="{y+5}" class="lbls">{t}</text>')
    o += ['    </g>', '  </g>']
    return "\n".join(o)


def power_in(v):
    o = [f'''  <g transform="translate(40,150)">
    <rect x="0" y="0" width="250" height="120" rx="8" fill="#fff" class="board"/>
    <text x="125" y="46" text-anchor="middle" font-size="24" fill="#111">BATTERY</text>
    <text x="125" y="76" text-anchor="middle" font-size="17" fill="#b00020">{v.cells}</text>
    <text x="125" y="100" text-anchor="middle" font-size="13" fill="#555">{v.cells2}</text>
    <text x="256" y="30" class="lbls">+Ve</text>
    <text x="256" y="106" class="lbls">&#8722;Ve</text>
  </g>''']
    if v.dualsrc:
        o.append('''  <g transform="translate(360,120)">
    <rect x="0" y="0" width="70" height="46" rx="8" fill="#222"/>
    <rect x="8" y="8" width="54" height="30" rx="4" fill="#444"/>
    <text x="35" y="-8" text-anchor="middle" class="lbls">power switch</text>
  </g>
  <g transform="translate(40,300)">
    <rect x="0" y="0" width="250" height="70" rx="8" fill="#fff" class="board"/>
    <text x="125" y="30" text-anchor="middle" font-size="18" fill="#111">USB-C 5V</text>
    <text x="125" y="54" text-anchor="middle" font-size="13" fill="#555">alternate source</text>
  </g>
  <g transform="translate(360,300)">
    <rect x="0" y="0" width="90" height="70" rx="8" fill="#eef" class="board"/>
    <text x="45" y="28" text-anchor="middle" font-size="14" fill="#111">SPDT</text>
    <text x="45" y="46" text-anchor="middle" font-size="11" fill="#555">source</text>
    <text x="45" y="60" text-anchor="middle" font-size="11" fill="#555">select</text>
  </g>''')
    else:
        o.append('''  <g transform="translate(360,300)">
    <rect x="0" y="0" width="90" height="70" rx="8" fill="#f7f7f7" class="board" stroke-dasharray="5,4"/>
    <text x="45" y="30" text-anchor="middle" font-size="11" fill="#888">battery only</text>
    <text x="45" y="48" text-anchor="middle" font-size="11" fill="#888">no USB-C source</text>
  </g>''')
    o.append(f'''  <g transform="translate(470,150)">
    <rect x="0" y="0" width="220" height="120" rx="8" fill="#1746a2" class="board"/>
    <rect x="18" y="20" width="60" height="80" rx="4" fill="#0f2f6e"/>
    <circle cx="150" cy="60" r="26" fill="#c9c9c9"/>
    <rect x="120" y="30" width="18" height="18" fill="#e6b800"/>
    <text x="150" y="65" text-anchor="middle" font-size="11" fill="#333">adj</text>
    <text x="-4" y="-10" font-size="15" fill="#111">&#9660; LM2596S &#8212; set to {v.rail} (no load)</text>
    <text x="-16" y="32" text-anchor="end" class="lbls" fill="#111">IN+</text>
    <text x="-16" y="108" text-anchor="end" class="lbls" fill="#111">IN&#8722;</text>
    <text x="236" y="32" class="lbls" fill="#111">OUT+</text>
    <text x="236" y="108" class="lbls" fill="#111">OUT&#8722;</text>
  </g>''')
    return "\n".join(o)


def distribution(v):
    o = [f'''  <g transform="translate({DIST_X},{DIST_Y})">
    <rect x="0" y="0" width="{DIST_W}" height="110" rx="8" fill="#3fae4a" class="board"/>
    <text x="180" y="-12" text-anchor="middle" class="lbl" font-weight="bold">Power distribution &#38; ground</text>
    <rect x="14" y="14" width="332" height="34" rx="6" fill="#141414"/>
    <text x="180" y="37" text-anchor="middle" class="pin">{v.gndname}</text>
    <rect x="14" y="60" width="332" height="34" rx="6" fill="#e23b2e"/>
    <text x="180" y="83" text-anchor="middle" class="pin">5V_RAIL ({v.rail})</text>
  </g>''']
    if v.bulkcap:
        o.append('''  <g transform="translate(858,500)">
    <rect x="0" y="0" width="22" height="56" rx="4" fill="#111"/>
    <rect x="4" y="0" width="14" height="56" fill="#3a3a3a"/>
    <text x="11" y="74" text-anchor="middle" class="cap">1000&#181;F</text>
    <text x="11" y="90" text-anchor="middle" font-size="11" fill="#555">at V+</text>
  </g>''')
    return "\n".join(o)


def pca(v):
    oe_fill = "#8e44ad" if v.oe else "#9a9a9a"
    oe_txt = "OE" if v.oe else "OE  n/c"
    return f'''  <g transform="translate({PCA_X},{PCA_Y})">
    <rect x="0" y="0" width="{PCA_W}" height="{PCA_H}" rx="8" fill="#0c7c59" class="board"/>
    <text x="180" y="26" text-anchor="middle" font-size="19" fill="#fff" font-weight="bold">PCA9685  (I2C 0x40)</text>
    <text x="180" y="44" text-anchor="middle" font-size="11" fill="#eaffea">ch0&#8230;ch7 &#8594; legs  |  ch8 reserved  |  ch9&#8211;15 spare</text>
    <g font-size="12" fill="#fff">
      <rect x="12" y="46" width="70" height="22" rx="4" fill="#e23b2e"/><text x="47" y="61" text-anchor="middle" class="pin">V+ (5V)</text>
      <rect x="12" y="72" width="70" height="22" rx="4" fill="#141414"/><text x="47" y="87" text-anchor="middle" class="pin">GND</text>
      <rect x="12" y="98" width="70" height="22" rx="4" fill="#f4b400"/><text x="47" y="113" text-anchor="middle" class="pin" fill="#111">VCC 3V3</text>
      <rect x="12" y="124" width="70" height="22" rx="4" fill="#33aa44"/><text x="47" y="139" text-anchor="middle" class="pin">SDA</text>
      <rect x="90" y="124" width="70" height="22" rx="4" fill="#2aa4dd"/><text x="125" y="139" text-anchor="middle" class="pin">SCL</text>
      <rect x="168" y="124" width="80" height="22" rx="4" fill="{oe_fill}"/><text x="208" y="139" text-anchor="middle" class="pin">{oe_txt}</text>
    </g>
    <g fill="#f6a623">
      <circle cx="266" cy="60" r="5"/><circle cx="284" cy="60" r="5"/><circle cx="302" cy="60" r="5"/><circle cx="320" cy="60" r="5"/>
      <circle cx="266" cy="82" r="5"/><circle cx="284" cy="82" r="5"/><circle cx="302" cy="82" r="5"/><circle cx="320" cy="82" r="5"/>
      <text x="293" y="106" text-anchor="middle" font-size="11" fill="#eaffea">ch0&#8211;ch7 3-pin headers</text>
    </g>
  </g>'''


def servos(v):
    o = ['  <g transform="translate(40,560)">',
         '    <text x="0" y="-14" class="lbl" font-weight="bold">Servos (channel &#8594; upstream servoPins index)</text>',
         '    <g font-size="13">']
    for i, leg in enumerate(LEGS):
        y = i * 34
        o.append(f'      <rect x="0" y="{y}" width="150" height="26" rx="5" fill="#f6a623"/>'
                 f'<text x="8" y="{y+18}" fill="#111">ch{i} &#8594; leg {leg}</text>')
    o += ['    </g>',
          '    <text x="0" y="292" class="note">Each servo\'s V+ / GND come from the PCA9685\'s own</text>',
          '    <text x="0" y="310" class="note">3-pin headers &#8212; not separate rail runs.</text>',
          '    <text x="0" y="328" class="note">22AWG power, 30AWG data.</text>']
    if not v.ours:
        o += ['    <text x="0" y="354" class="warn">Scaled here from the 3-servo bench test</text>',
              '    <text x="0" y="372" class="warn">(ch0&#8211;ch2); topology otherwise unchanged.</text>']
    o.append('  </g>')
    return "\n".join(o)


def mcu(v):
    o = [f'''  <g transform="translate({MCU_X},{MCU_Y})">
    <rect x="0" y="0" width="{MCU_W}" height="{MCU_H}" rx="14" fill="#8e1f6b" class="board"/>
    <text x="110" y="28" text-anchor="middle" font-size="17" fill="#fff" font-weight="bold">ESP32-S3 Super Mini</text>
    <text x="110" y="48" text-anchor="middle" font-size="11" fill="#f4c6e6">ESP32-S3FH4R2 &#183; quad PSRAM</text>
    <rect x="80" y="256" width="60" height="30" rx="6" fill="#333"/>
    <text x="110" y="276" text-anchor="middle" font-size="11" fill="#ccc">USB-C</text>
    <g font-size="12">
      <rect x="-70" y="70" width="66" height="22" rx="4" fill="#e23b2e"/><text x="-37" y="85" text-anchor="middle" class="pin">5V</text>
      <rect x="-70" y="98" width="66" height="22" rx="4" fill="#f4b400"/><text x="-37" y="113" text-anchor="middle" class="pin" fill="#111">3V3</text>
      <rect x="-70" y="126" width="66" height="22" rx="4" fill="#141414"/><text x="-37" y="141" text-anchor="middle" class="pin">GND</text>
      <rect x="-70" y="154" width="66" height="22" rx="4" fill="#33aa44"/><text x="-37" y="169" text-anchor="middle" class="pin">2 SDA</text>
      <rect x="-70" y="182" width="66" height="22" rx="4" fill="#2aa4dd"/><text x="-37" y="197" text-anchor="middle" class="pin">3 SCL</text>''']
    if v.oe:
        o.append('      <rect x="-70" y="210" width="66" height="22" rx="4" fill="#8e44ad"/>'
                 '<text x="-37" y="225" text-anchor="middle" class="pin">18 OE</text>')
    o.append('    </g>')
    if v.uwb:
        pins = [("12 SCK", 70), ("11 MOSI", 98), ("13 MISO", 126), ("10 CSn", 154),
                ("14 IRQ", 182), ("21 RSTn", 210), ("16 WAKE", 238), ("17 EXTON", 266)]
        o.append('    <g font-size="12">')
        for t, y in pins:
            o.append(f'      <rect x="224" y="{y}" width="72" height="22" rx="4" fill="#7a5cff"/>'
                     f'<text x="260" y="{y+15}" text-anchor="middle" class="pin">{t}</text>')
        o.append('    </g>')
    o.append('  </g>')
    return "\n".join(o)


def oled():
    return f'''  <g transform="translate({SIDE_X},300)">
    <rect x="0" y="0" width="300" height="180" rx="12" fill="#1b6fb0" class="board"/>
    <rect x="24" y="44" width="252" height="104" rx="8" fill="#0a0a0a"/>
    <text x="150" y="114" text-anchor="middle" font-size="38" fill="#eaeaea">(&#183;&#183;&#183;&#711;&#969;&#711;&#183;&#183;&#183;)</text>
    <text x="150" y="26" text-anchor="middle" font-size="15" fill="#fff">SSD1306 OLED (I2C 0x3C)</text>
    <g font-size="12" fill="#fff">
      <text x="40" y="172" text-anchor="middle">GND</text><text x="95" y="172" text-anchor="middle">VCC</text>
      <text x="150" y="172" text-anchor="middle">SCL</text><text x="205" y="172" text-anchor="middle">SDA</text>
    </g>
  </g>'''


def uwb_block(v):
    if not v.uwb:
        return f'''  <g transform="translate({SIDE_X},{UWB_Y})">
    <rect x="0" y="0" width="380" height="{UWB_H}" rx="12" fill="#f7f7f7" class="board" stroke-dasharray="7,5"/>
    <text x="16" y="30" class="lbl" font-weight="bold" fill="#777">UWB 8-pin SPI header &#8212; NOT FITTED</text>
    <text x="16" y="60" class="lbls" fill="#777">GPIO 10&#8211;14, 16, 17 and 21 stay free.</text>
    <text x="16" y="82" class="lbls" fill="#777">Land the header pads anyway so the DWM3000</text>
    <text x="16" y="104" class="lbls" fill="#777">drops in later without reworking the board.</text>
    <rect x="40" y="130" width="300" height="120" rx="8" fill="#fff" stroke="#bbb" stroke-width="2" stroke-dasharray="7,5"/>
    <text x="190" y="184" text-anchor="middle" font-size="15" fill="#aaa">reserved footprint</text>
    <text x="190" y="208" text-anchor="middle" font-size="13" fill="#bbb">see variant 2a / 2b</text>
  </g>'''
    rows = [("SCK &#8592; GPIO12", "#7a5cff"), ("MOSI &#8592; GPIO11", "#7a5cff"),
            ("MISO &#8594; GPIO13", "#7a5cff"), ("CSn &#8592; GPIO10", "#7a5cff"),
            ("IRQ &#8594; GPIO14", "#7a5cff"), ("RSTn &#8212; GPIO21", "#b00020"),
            ("WAKE &#8592; GPIO16", "#7a5cff"), ("EXTON &#8594; GPIO17", "#7a5cff")]
    o = [f'''  <g transform="translate({SIDE_X},{UWB_Y})">
    <rect x="0" y="0" width="380" height="{UWB_H}" rx="12" fill="#f3f0ff" class="board"/>
    <text x="16" y="28" class="lbl" font-weight="bold">UWB 8-pin SPI header &#8212; POPULATED</text>
    <rect x="200" y="46" width="160" height="150" rx="8" fill="#2b2b2b"/>
    <text x="280" y="70" text-anchor="middle" font-size="15" fill="#fff">DWM3000</text>
    <rect x="228" y="84" width="104" height="54" rx="4" fill="#c9a24a"/>
    <text x="280" y="116" text-anchor="middle" font-size="12" fill="#111">UWB antenna</text>
    <text x="280" y="162" text-anchor="middle" font-size="11" fill="#bbb">3V3 logic only</text>
    <text x="280" y="180" text-anchor="middle" font-size="11" fill="#bbb">&#8212; not 5V tolerant</text>
    <g font-size="12" fill="#fff">''']
    for i, (t, c) in enumerate(rows):
        y = 52 + i * 24
        o.append(f'      <rect x="16" y="{y}" width="150" height="20" rx="3" fill="{c}"/>'
                 f'<text x="24" y="{y+15}">{t}</text>')
    o += ['    </g>',
          '    <text x="16" y="262" class="warn">RSTn is open-drain &#8212; never drive it high.</text>',
          '    <text x="16" y="284" class="note">GPIO10&#8211;14 are Priority 2 on the S3 &#8212; free to use.</text>',
          '  </g>']
    return "\n".join(o)


def wires(v):
    o = ['  <!-- ============ WIRES ============ -->']

    # --- source side -> buck ---
    if v.dualsrc:
        o += ['  <path class="wire w5v" d="M296,175 L360,143"/>',
              '  <path class="wire w5v" d="M430,143 L454,143 L454,178 L470,178"/>',
              '  <path class="wire w5v" d="M290,320 L360,320"/>',
              f'  <path class="wire w5v" d="M450,335 L462,335 L462,{RAIL_Y} L{BAR_L},{RAIL_Y}"/>']
    else:
        o += ['  <path class="wire w5v" d="M296,175 L400,175 L400,178 L470,178"/>']
    o += [f'  <path class="wire gnd" d="M296,255 L330,255 L330,{GND_Y} L{BAR_L},{GND_Y}"/>',
          f'  <path class="wire w5v" d="M690,178 L740,178 L740,{RAIL_Y} L{BAR_R},{RAIL_Y}"/>',
          f'  <path class="wire gnd" d="M690,254 L716,254 L716,392 L640,392 L640,{DIST_Y+14}"/>']

    # --- rail -> loads ---
    o += [f'  <path class="wire w5v" d="M520,{DIST_Y+94} L520,562 L428,562 L428,{PCA_VP[1]} L{PCA_VP[0]},{PCA_VP[1]}"/>',
          f'  <path class="wire w5v" d="M{BAR_R},{RAIL_Y} L892,{RAIL_Y} L892,{M5V} L{MCU_PIN_L},{M5V}"/>',
          f'  <path class="wire gnd" d="M{PCA_GND[0]},{PCA_GND[1]} L450,{PCA_GND[1]} L450,{GND_Y} L{BAR_L},{GND_Y}"/>',
          f'  <path class="wire gnd" d="M{MCU_PIN_L},{MGND} L906,{MGND} L906,392 L600,392 L600,{DIST_Y+14}"/>']
    if v.bulkcap:
        # + stub up to the 5V run, - stub across to the MCU ground return
        o += [f'  <path class="wire w5v" d="M869,500 L869,{RAIL_Y}"/>',
              '  <path class="wire gnd" d="M869,556 L869,580 L906,580"/>']

    # --- MCU -> PCA9685 (corridors below the PCA board) ---
    o += [f'  <path class="wire v33" d="M{MCU_PIN_L},{M3V3} L880,{M3V3} L880,830 L414,830 L414,{PCA_VCC_Y} L{PCA_VP[0]},{PCA_VCC_Y}"/>',
          f'  <path class="wire sda" d="M{MCU_PIN_L},{MSDA} L868,{MSDA} L868,850 L{SDA_X},850 L{SDA_X},{PCA_PIN_BOT}"/>',
          f'  <path class="wire scl" d="M{MCU_PIN_L},{MSCL} L856,{MSCL} L856,866 L{SCL_X},866 L{SCL_X},{PCA_PIN_BOT}"/>']
    if v.oe:
        o.append(f'  <path class="wire oe" d="M{MCU_PIN_L},{MOE} L844,{MOE} L844,882 L{OE_X},882 L{OE_X},{PCA_PIN_BOT}"/>')

    # --- servo leads: one bundle from the ch0-ch7 3-pin headers ---
    o += ['  <path class="wire sig" d="M763,760 L763,806 L212,806 L212,578 L190,578"/>',
          '  <text x="250" y="800" font-size="13" fill="#7a2b12">8 &#215; 3-pin servo leads (V+, GND, PWM) from ch0&#8211;ch7</text>']

    # --- GND spine along the top of the right-hand column ---
    o.append(f'  <path class="wire gnd" d="M{BAR_R},{GND_Y} L836,{GND_Y} L836,544 L1500,544"/>')
    o.append(f'  <path class="wire gnd" d="M{OL_GND},{OLED_BOT} L{OL_GND},544"/>')
    if v.uwb:
        o.append(f'  <path class="wire gnd" d="M1450,{UWB_Y} L1450,544"/>')

    # --- OLED power + I2C: down the right margin into the bottom corridors ---
    o += [f'  <path class="wire v33" d="M{OL_VCC},{OLED_BOT} L{OL_VCC},500 L1752,500 L1752,896 L392,896 L392,{PCA_VCC_Y+6} L{PCA_VP[0]},{PCA_VCC_Y+6}"/>',
          f'  <path class="wire scl" d="M{OL_SCL},{OLED_BOT} L{OL_SCL},514 L1740,514 L1740,910 L{SCL_X2},910 L{SCL_X2},{PCA_PIN_BOT}"/>',
          f'  <path class="wire sda" d="M{OL_SDA},{OLED_BOT} L{OL_SDA},528 L1728,528 L1728,924 L{SDA_X2},924 L{SDA_X2},{PCA_PIN_BOT}"/>']

    # --- UWB ---
    if v.uwb:
        for i in range(8):
            xj = 1292 + i * 6
            o.append(f'  <path class="wire spi" d="M{MCU_PIN_RE},{SPI_Y[i]} L{xj},{SPI_Y[i]} '
                     f'L{xj},{HDR_Y[i]} L{UWB_PIN},{HDR_Y[i]}"/>')
        # DWM3000 3V3 taps the same 3V3 corridor that feeds the OLED
        o.append(f'  <path class="wire v33" d="M1400,{UWB_Y+UWB_H} L1400,896"/>')
    return "\n".join(o)


def notes(v):
    lines = [
        ("warn", "Critical: PCA9685 VCC (3V3) is logic only &#8212; it is NOT V+ (5V)."),
        ("warn", "Critical: the S3 5V branch is taken from the rail node, NOT chained off the PCA9685 V+ terminal."),
        ("warn", "Critical: servo current never flows through the ESP32."),
    ]
    if v.ours:
        lines.append(("note", f"Set the LM2596S to {v.rail} with no load before connecting anything. "
                              "Confirm 0x3C &#38; 0x40 enumerate before attaching servos."))
    else:
        lines.append(("warn", "OE left unconnected: PCA9685 outputs go live the instant the rail comes up "
                              "&#8212; servos cannot be held off during boot."))
        lines.append(("note", f"Set the LM2596S to {v.rail} with no load. No bulk cap at V+ in this scheme "
                              "&#8212; expect more rail sag under simultaneous servo load."))
    o = ['  <g>']
    y = 966
    for kind, text in lines:
        o.append(f'    <text x="470" y="{y}" class="{kind}">{text}</text>')
        y += 22
    o.append('  </g>')
    return "\n".join(o)


def build(v):
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
             f'font-family="Verdana, Segoe UI, sans-serif">',
             f'  <defs>\n    <style>{STYLE}    </style>\n  </defs>',
             f'  <rect x="0" y="0" width="{W}" height="{H}" fill="#ffffff"/>',
             header(v), legend(v), power_in(v), distribution(v), pca(v),
             servos(v), mcu(v), oled(), uwb_block(v), wires(v), notes(v),
             '</svg>']
    return "\n\n".join(parts) + "\n"


VARIANTS = [
    Variant("1a", uwb=False, scheme="ours"),
    Variant("1b", uwb=False, scheme="loftwork"),
    Variant("2a", uwb=True, scheme="ours"),
    Variant("2b", uwb=True, scheme="loftwork"),
]

NAMES = {"1a": "1a-no-uwb-citfc.svg", "1b": "1b-no-uwb-loftwork.svg",
         "2a": "2a-uwb-citfc.svg", "2b": "2b-uwb-loftwork.svg"}

if __name__ == "__main__":
    here = Path(__file__).parent
    for v in VARIANTS:
        p = here / NAMES[v.vid]
        p.write_text(build(v), encoding="utf-8")
        print(f"wrote {p.name}  ({p.stat().st_size:,} bytes)")
