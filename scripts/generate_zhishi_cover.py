#!/usr/bin/env python3

from __future__ import annotations

import math
import random
from pathlib import Path


WIDTH = 1920
HEIGHT = 1080
CX = WIDTH / 2
CY = HEIGHT / 2
SEED = 20260318
SVG_PATH = Path("/Users/ink/Documents/Hugo/mysite/static/images/blog/zhishi-migong-cover.svg")


def fmt(value: float) -> str:
    return f"{value:.2f}"


def point(angle: float, radius: float, y_scale: float = 1.0, x_scale: float = 1.0) -> tuple[float, float]:
    return (
        CX + math.cos(angle) * radius * x_scale,
        CY + math.sin(angle) * radius * y_scale,
    )


def polygon_path(
    sides: int,
    radius: float,
    rotation: float = 0.0,
    y_scale: float = 1.0,
    x_scale: float = 1.0,
) -> str:
    pts = [point(rotation + math.tau * i / sides, radius, y_scale, x_scale) for i in range(sides)]
    head = f"M {fmt(pts[0][0])} {fmt(pts[0][1])}"
    tail = " ".join(f"L {fmt(x)} {fmt(y)}" for x, y in pts[1:])
    return f"{head} {tail} Z"


def star_path(outer_r: float, inner_r: float, points_count: int, rotation: float = 0.0) -> str:
    pts = []
    for i in range(points_count * 2):
        radius = outer_r if i % 2 == 0 else inner_r
        angle = rotation + math.pi * i / points_count
        pts.append(point(angle, radius, 1.08))
    head = f"M {fmt(pts[0][0])} {fmt(pts[0][1])}"
    tail = " ".join(f"L {fmt(x)} {fmt(y)}" for x, y in pts[1:])
    return f"{head} {tail} Z"


def bezier_point(p0, p1, p2, p3, t: float):
    omt = 1 - t
    x = (
        omt * omt * omt * p0[0]
        + 3 * omt * omt * t * p1[0]
        + 3 * omt * t * t * p2[0]
        + t * t * t * p3[0]
    )
    y = (
        omt * omt * omt * p0[1]
        + 3 * omt * omt * t * p1[1]
        + 3 * omt * t * t * p2[1]
        + t * t * t * p3[1]
    )
    return x, y


def bezier_path(points: list[tuple[float, float]]) -> str:
    p0, p1, p2, p3 = points
    return (
        f"M {fmt(p0[0])} {fmt(p0[1])} "
        f"C {fmt(p1[0])} {fmt(p1[1])}, {fmt(p2[0])} {fmt(p2[1])}, {fmt(p3[0])} {fmt(p3[1])}"
    )


def arc_path(radius: float, start: float, end: float, y_scale: float = 1.0, x_scale: float = 1.0) -> str:
    sweep = end - start
    large = 1 if abs(sweep) > math.pi else 0
    direction = 1 if sweep > 0 else 0
    x1, y1 = point(start, radius, y_scale, x_scale)
    x2, y2 = point(end, radius, y_scale, x_scale)
    return (
        f"M {fmt(x1)} {fmt(y1)} "
        f"A {fmt(radius * x_scale)} {fmt(radius * y_scale)} 0 {large} {direction} {fmt(x2)} {fmt(y2)}"
    )


def glow_circle(x: float, y: float, r: float, fill: str, opacity: float) -> str:
    return f'<circle cx="{fmt(x)}" cy="{fmt(y)}" r="{fmt(r)}" fill="{fill}" opacity="{opacity:.3f}"/>'


def build_svg() -> str:
    random.seed(SEED)
    parts: list[str] = []
    parts.append(
        """<svg width="1920" height="1080" viewBox="0 0 1920 1080" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="220" y1="84" x2="1710" y2="986" gradientUnits="userSpaceOnUse">
      <stop stop-color="#04070D"/>
      <stop offset="0.55" stop-color="#081018"/>
      <stop offset="1" stop-color="#0C161C"/>
    </linearGradient>
    <radialGradient id="tealHaze" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(960 540) rotate(90) scale(440 440)">
      <stop stop-color="#5FF5D7" stop-opacity="0.22"/>
      <stop offset="0.5" stop-color="#4CD3BD" stop-opacity="0.08"/>
      <stop offset="1" stop-color="#4CD3BD" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="outerHaze" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(960 540) rotate(90) scale(980 700)">
      <stop stop-color="#64F2DD" stop-opacity="0.08"/>
      <stop offset="1" stop-color="#64F2DD" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="vignette" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(960 540) rotate(90) scale(1160 820)">
      <stop stop-color="#000000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0.48"/>
    </radialGradient>
    <linearGradient id="lineGlow" x1="640" y1="210" x2="1316" y2="830" gradientUnits="userSpaceOnUse">
      <stop stop-color="#F0FFFB" stop-opacity="0.90"/>
      <stop offset="0.45" stop-color="#AFFFF3" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#71E4CF" stop-opacity="0.16"/>
    </linearGradient>
    <linearGradient id="glassFill" x1="746" y1="258" x2="1194" y2="808" gradientUnits="userSpaceOnUse">
      <stop stop-color="#7CFFF0" stop-opacity="0.12"/>
      <stop offset="1" stop-color="#7CFFF0" stop-opacity="0.03"/>
    </linearGradient>
    <linearGradient id="accent" x1="1182" y1="308" x2="1318" y2="446" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFA17D"/>
      <stop offset="1" stop-color="#FF4C74"/>
    </linearGradient>
    <filter id="softBlur" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="24"/>
    </filter>
    <filter id="lineBloom" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="0" stdDeviation="12" flood-color="#71E4CF" flood-opacity="0.26"/>
    </filter>
    <filter id="accentBloom" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="0" stdDeviation="18" flood-color="#FF6F83" flood-opacity="0.34"/>
    </filter>
    <pattern id="grid" width="24" height="24" patternUnits="userSpaceOnUse">
      <path d="M24 0H0V24" stroke="#C0FFF7" stroke-opacity="0.035"/>
    </pattern>
  </defs>
"""
    )

    parts.append('  <rect width="1920" height="1080" fill="url(#bg)"/>')
    parts.append('  <rect width="1920" height="1080" fill="url(#grid)"/>')
    parts.append('  <rect width="1920" height="1080" fill="url(#outerHaze)"/>')
    parts.append('  <rect width="1920" height="1080" fill="url(#tealHaze)"/>')
    parts.append('  <rect width="1920" height="1080" fill="url(#vignette)"/>')

    # Frame lines.
    parts.append('  <g opacity="0.20">')
    parts.append('    <path d="M140 168H1780" stroke="#B5FFF5" stroke-opacity="0.12"/>')
    parts.append('    <path d="M140 912H1780" stroke="#B5FFF5" stroke-opacity="0.12"/>')
    parts.append('    <path d="M252 96V984" stroke="#B5FFF5" stroke-opacity="0.08"/>')
    parts.append('    <path d="M1668 96V984" stroke="#B5FFF5" stroke-opacity="0.08"/>')
    parts.append("  </g>")

    # Broken rings.
    parts.append('  <g opacity="0.22">')
    ring_specs = [
        (438, 0.76, [(0.10, 1.18), (1.62, 2.90), (3.42, 4.62), (5.12, 6.00)]),
        (374, 0.82, [(0.26, 1.40), (1.86, 3.04), (3.58, 4.48), (4.98, 5.92)]),
        (308, 0.88, [(0.52, 1.34), (1.66, 2.56), (3.10, 4.04), (4.66, 5.70)]),
        (236, 0.94, [(0.22, 1.04), (1.34, 2.30), (3.08, 3.92), (4.52, 5.58)]),
    ]
    for radius, y_scale, arcs in ring_specs:
        for start, end in arcs:
            parts.append(
                f'    <path d="{arc_path(radius, start, end, y_scale=y_scale)}" '
                'stroke="#C9FFF8" stroke-opacity="0.22" stroke-width="1.2" stroke-linecap="round"/>'
            )
    parts.append("  </g>")

    # Dense orbit particles.
    orbit_particles: list[str] = []
    for radius, y_scale, count, spread in [
        (462, 0.82, 460, 0.015),
        (394, 0.87, 520, 0.020),
        (330, 0.91, 460, 0.022),
        (270, 0.96, 300, 0.018),
    ]:
        for _ in range(count):
            angle = random.uniform(0, math.tau)
            rr = radius + random.uniform(-8, 8)
            x, y = point(angle, rr, y_scale)
            size = random.uniform(0.7, 1.7)
            opacity = random.uniform(0.10, 0.48)
            color = "#E8FFFB" if random.random() > 0.38 else "#79E8D4"
            orbit_particles.append(glow_circle(x, y, size, color, opacity))
            if random.random() < spread:
                orbit_particles.append(glow_circle(x + random.uniform(-3, 3), y + random.uniform(-3, 3), size * 0.6, color, opacity * 0.6))
    parts.append('  <g opacity="0.90">')
    parts.extend(f"    {item}" for item in orbit_particles)
    parts.append("  </g>")

    # Flow curves and particles.
    flow_paths = [
        [(240, 538), (510, 500), (660, 478), (794, 412)],
        [(240, 542), (514, 566), (668, 590), (794, 668)],
        [(1680, 538), (1410, 500), (1260, 478), (1126, 412)],
        [(1680, 542), (1406, 566), (1252, 590), (1126, 668)],
        [(958, 116), (944, 260), (930, 334), (878, 398)],
        [(962, 116), (976, 260), (990, 334), (1042, 398)],
        [(958, 964), (944, 820), (930, 744), (878, 682)],
        [(962, 964), (976, 820), (990, 744), (1042, 682)],
    ]
    parts.append('  <g opacity="0.26">')
    for pts in flow_paths:
        parts.append(
            f'    <path d="{bezier_path(pts)}" stroke="#9CEFE0" stroke-width="1.4" stroke-dasharray="1 10" stroke-linecap="round"/>'
        )
    parts.append("  </g>")

    flow_particles: list[str] = []
    for pts in flow_paths:
        for idx in range(48):
            t = idx / 47
            x, y = bezier_point(*pts, t)
            offset = math.sin(t * math.pi * 8 + pts[0][0] * 0.01) * 5
            x += offset * (0.16 if idx % 2 == 0 else -0.10)
            y += offset * (0.12 if idx % 2 else -0.08)
            size = 2.0 - 1.2 * t if pts[0][1] in (116, 964) else 1.8 - 1.0 * t
            opacity = 0.34 + 0.24 * (1 - t)
            flow_particles.append(glow_circle(x, y, max(size, 0.6), "#DFFFFA", opacity))
            if idx % 3 == 0:
                flow_particles.append(glow_circle(x + random.uniform(-4, 4), y + random.uniform(-4, 4), 0.7, "#7EE7D6", opacity * 0.5))
    parts.append('  <g opacity="0.85">')
    parts.extend(f"    {item}" for item in flow_particles)
    parts.append("  </g>")

    # Main symbol glass shards.
    parts.append('  <g filter="url(#lineBloom)">')
    parts.append(f'    <path d="{polygon_path(8, 296, rotation=math.radians(22), y_scale=1.05)}" fill="url(#glassFill)" stroke="url(#lineGlow)" stroke-width="2.4"/>')
    parts.append(f'    <path d="{polygon_path(8, 228, rotation=math.radians(22), y_scale=1.07)}" fill="url(#glassFill)" stroke="url(#lineGlow)" stroke-width="2"/>')
    parts.append(f'    <path d="{star_path(214, 154, 4, rotation=math.radians(45))}" fill="url(#glassFill)" stroke="url(#lineGlow)" stroke-width="2.2"/>')
    parts.append(f'    <path d="{polygon_path(6, 134, rotation=math.radians(30), y_scale=1.12)}" fill="url(#glassFill)" stroke="url(#lineGlow)" stroke-width="1.8"/>')
    parts.append("  </g>")

    parts.append('  <g opacity="0.28" filter="url(#lineBloom)">')
    parts.append('    <path d="M 960 146 L 1092 258 L 1048 388 L 960 432 L 872 388 L 828 258 Z" fill="#67F0DA" fill-opacity="0.08" stroke="#D9FFFA" stroke-opacity="0.28" stroke-width="1.8"/>')
    parts.append('    <path d="M 960 934 L 1092 822 L 1048 692 L 960 648 L 872 692 L 828 822 Z" fill="#67F0DA" fill-opacity="0.08" stroke="#D9FFFA" stroke-opacity="0.28" stroke-width="1.8"/>')
    parts.append('    <path d="M 566 540 L 698 430 L 830 474 L 874 540 L 830 606 L 698 650 Z" fill="#67F0DA" fill-opacity="0.06" stroke="#D9FFFA" stroke-opacity="0.24" stroke-width="1.8"/>')
    parts.append('    <path d="M 1354 540 L 1222 430 L 1090 474 L 1046 540 L 1090 606 L 1222 650 Z" fill="#67F0DA" fill-opacity="0.06" stroke="#D9FFFA" stroke-opacity="0.24" stroke-width="1.8"/>')
    parts.append("  </g>")

    # Additional translucent shards.
    shard_paths = [
        "M 782 272 L 904 330 L 860 492 L 726 438 Z",
        "M 1138 272 L 1194 438 L 1060 492 L 1016 330 Z",
        "M 734 646 L 864 590 L 904 758 L 780 804 Z",
        "M 1056 590 L 1186 646 L 1138 804 L 1016 758 Z",
        "M 900 198 L 1020 198 L 1148 304 L 1032 342 L 888 342 L 772 304 Z",
        "M 888 738 L 1032 738 L 1148 776 L 1020 882 L 900 882 L 772 776 Z",
    ]
    parts.append('  <g opacity="0.20">')
    for path in shard_paths:
        parts.append(f'    <path d="{path}" fill="#74F0DB" fill-opacity="0.06" stroke="#D7FFFA" stroke-opacity="0.20" stroke-width="1.4"/>')
    parts.append("  </g>")

    # Bold ring fragments to break the symmetry a bit.
    parts.append('  <g opacity="0.40" filter="url(#lineBloom)">')
    fragment_specs = [
        (424, 0.88, 4.86, 5.74, 4.8),
        (424, 0.88, 0.28, 1.04, 4.8),
        (348, 0.94, 2.08, 2.82, 3.8),
        (348, 0.94, 3.44, 4.18, 3.8),
        (270, 1.00, 0.92, 1.52, 3.0),
        (270, 1.00, 4.08, 4.72, 3.0),
    ]
    for radius, y_scale, start, end, width in fragment_specs:
        parts.append(
            f'    <path d="{arc_path(radius, start, end, y_scale=y_scale)}" '
            f'stroke="url(#lineGlow)" stroke-width="{width}" stroke-linecap="round"/>'
        )
    parts.append("  </g>")

    # Core circuitry.
    circuit_lines = [
        "M 960 212 V 316",
        "M 960 764 V 868",
        "M 604 540 H 742",
        "M 1178 540 H 1316",
        "M 778 336 H 908 V 252",
        "M 1012 252 V 336 H 1142",
        "M 1142 744 H 1012 V 828",
        "M 908 828 V 744 H 778",
        "M 750 416 H 844 V 346 H 960",
        "M 1170 416 H 1076 V 346 H 960",
        "M 750 664 H 844 V 734 H 960",
        "M 1170 664 H 1076 V 734 H 960",
        "M 856 458 H 1064",
        "M 856 622 H 1064",
        "M 960 388 V 692",
        "M 818 540 H 1102",
        "M 820 472 H 892 V 398",
        "M 1100 472 H 1028 V 398",
        "M 820 608 H 892 V 682",
        "M 1100 608 H 1028 V 682",
    ]
    parts.append('  <g stroke="url(#lineGlow)" stroke-width="5.6" stroke-linecap="round" opacity="0.78">')
    for path in circuit_lines:
        parts.append(f'    <path d="{path}"/>')
    parts.append("  </g>")

    parts.append('  <g stroke="#E4FFFB" stroke-opacity="0.36" stroke-width="2.4" stroke-linecap="round" opacity="0.84">')
    parts.append('    <path d="M 846 246 L 846 320 L 774 320"/>')
    parts.append('    <path d="M 1074 246 L 1074 320 L 1146 320"/>')
    parts.append('    <path d="M 846 834 L 846 760 L 774 760"/>')
    parts.append('    <path d="M 1074 834 L 1074 760 L 1146 760"/>')
    parts.append('    <path d="M 646 426 L 718 426 L 718 356"/>')
    parts.append('    <path d="M 1274 426 L 1202 426 L 1202 356"/>')
    parts.append('    <path d="M 646 654 L 718 654 L 718 724"/>')
    parts.append('    <path d="M 1274 654 L 1202 654 L 1202 724"/>')
    parts.append("  </g>")

    micro_lines = [
        "M 720 540 H 828",
        "M 1092 540 H 1200",
        "M 960 282 V 382",
        "M 960 698 V 798",
        "M 832 350 H 1088",
        "M 832 730 H 1088",
        "M 786 448 H 870",
        "M 1050 448 H 1134",
        "M 786 632 H 870",
        "M 1050 632 H 1134",
        "M 892 312 L 960 278 L 1028 312",
        "M 892 768 L 960 802 L 1028 768",
    ]
    parts.append('  <g stroke="#D9FFFA" stroke-opacity="0.28" stroke-width="1.8" stroke-linecap="round" opacity="0.8">')
    for path in micro_lines:
        parts.append(f'    <path d="{path}"/>')
    parts.append("  </g>")

    # Core.
    parts.append('  <g opacity="0.90">')
    parts.append('    <path d="M 960 270 L 1080 350 L 1080 538 L 960 614 L 840 538 L 840 350 Z" fill="#78F0DC" fill-opacity="0.06" stroke="#E8FFFB" stroke-opacity="0.20" stroke-width="1.6"/>')
    parts.append('    <path d="M 960 466 L 1012 502 L 1012 578 L 960 614 L 908 578 L 908 502 Z" fill="#E9FFFB" fill-opacity="0.10" stroke="#E9FFFB" stroke-opacity="0.28" stroke-width="1.4"/>')
    parts.append('    <circle cx="960" cy="540" r="22" fill="#EBFFFC"/>')
    parts.append('    <circle cx="960" cy="540" r="42" stroke="#E9FFFC" stroke-opacity="0.42" stroke-width="2"/>')
    parts.append('    <circle cx="960" cy="540" r="78" stroke="#9DEFE2" stroke-opacity="0.18" stroke-width="1.6"/>')
    parts.append('    <circle cx="960" cy="540" r="116" stroke="#9DEFE2" stroke-opacity="0.10" stroke-width="1.4" stroke-dasharray="2 12"/>')
    parts.append("  </g>")

    # Nodes.
    node_points = [
        (960, 212), (960, 868), (742, 540), (1178, 540),
        (908, 252), (1012, 252), (908, 828), (1012, 828),
        (750, 416), (750, 664), (1170, 416), (1170, 664),
        (856, 458), (1064, 458), (856, 622), (1064, 622),
        (820, 472), (1100, 472), (820, 608), (1100, 608),
    ]
    parts.append('  <g opacity="0.88">')
    for x, y in node_points:
        parts.append(f'    <circle cx="{x}" cy="{y}" r="3.8" fill="#DFFFFA"/>')
        parts.append(f'    <circle cx="{x}" cy="{y}" r="8" stroke="#A8F1E4" stroke-opacity="0.18" stroke-width="1"/>')
    parts.append("  </g>")

    # Interior micro particles.
    interior_particles: list[str] = []
    for _ in range(1100):
        angle = random.uniform(0, math.tau)
        radius = random.triangular(30, 310, 160)
        x, y = point(angle, radius, random.uniform(0.88, 1.12))
        if abs(x - CX) > 340 or abs(y - CY) > 360:
            continue
        size = random.uniform(0.45, 1.45)
        opacity = random.uniform(0.08, 0.34)
        fill = "#DEFFFA" if random.random() > 0.44 else "#6FE7D2"
        interior_particles.append(glow_circle(x, y, size, fill, opacity))
    parts.append('  <g opacity="0.75">')
    parts.extend(f"    {item}" for item in interior_particles)
    parts.append("  </g>")

    # Accent interruption.
    parts.append('  <g filter="url(#accentBloom)">')
    parts.append('    <rect x="1180" y="286" width="222" height="16" rx="8" transform="rotate(42 1180 286)" fill="url(#accent)"/>')
    parts.append('    <rect x="1192" y="270" width="222" height="16" rx="8" transform="rotate(42 1192 270)" fill="#FFD0C2" opacity="0.30" filter="url(#softBlur)"/>')
    parts.append('    <rect x="1218" y="326" width="92" height="8" rx="4" transform="rotate(42 1218 326)" fill="#FFE0D8" opacity="0.72"/>')
    parts.append("  </g>")

    # Side particle clouds.
    cloud_particles: list[str] = []
    for side in (-1, 1):
        base_x = CX + side * 485
        for _ in range(340):
            t = random.random()
            x = base_x + side * random.uniform(-140, 16) + math.sin(t * math.tau * 3) * 20
            y = CY + random.uniform(-190, 190) + math.cos(t * math.tau * 5) * 12
            size = random.uniform(0.6, 2.2)
            opacity = random.uniform(0.05, 0.32)
            fill = "#DFFFFA" if random.random() > 0.40 else "#80E8D7"
            cloud_particles.append(glow_circle(x, y, size, fill, opacity))
    parts.append('  <g opacity="0.82">')
    parts.extend(f"    {item}" for item in cloud_particles)
    parts.append("  </g>")

    # Hard diagonal energy rails.
    rails = [
        "M 292 632 L 688 564",
        "M 292 448 L 688 516",
        "M 1628 632 L 1232 564",
        "M 1628 448 L 1232 516",
    ]
    parts.append('  <g opacity="0.24">')
    for path in rails:
        parts.append(f'    <path d="{path}" stroke="#A9F1E6" stroke-width="1.4" stroke-dasharray="1 9" stroke-linecap="round"/>')
    parts.append("  </g>")

    # Subtle scanlines.
    parts.append('  <g opacity="0.10">')
    for y in range(196, 885, 22):
        parts.append(f'    <path d="M 404 {y} H 1516" stroke="#C0FFF7" stroke-opacity="0.12"/>')
    parts.append("  </g>")

    parts.append("</svg>\n")
    return "\n".join(parts)


def main() -> None:
    SVG_PATH.parent.mkdir(parents=True, exist_ok=True)
    SVG_PATH.write_text(build_svg(), encoding="utf-8")


if __name__ == "__main__":
    main()
