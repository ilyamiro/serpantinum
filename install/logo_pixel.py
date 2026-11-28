#!/usr/bin/env python3

import argparse
import base64
import os
import shutil
import struct
import sys
import termios
import tty
import zlib


LOGO_PIXEL_WIDTH = 40
LOGO_PIXEL_HEIGHT = 44
LOGO_PIXEL_ROWS = LOGO_PIXEL_HEIGHT // 2

LOGO_PIXEL_GRID = (
    "..........HWWB..........................",
    "........HWWBBBBM........................",
    ".......HHWBBBBBBBM.......HBBBM..........",
    ".......HBBM..HHWBBBM...HBM...BM.........",
    ".......HBM....HWWBHHBM........BM........",
    ".......HBM......HWWBHHBM.......B........",
    ".......HBM......HBS..WHBM......BM.......",
    ".......HBM.......HBM...HBM.....BM.......",
    "........HBM.......HBBMSHHBM....BM.......",
    "........HBM.......SMBBBBHHBM...BM.......",
    "........HBBM.....H....SMBM.....HHBBB....",
    ".........HBM....HB.........HBBBBBBBBBM..",
    "..........HBM...HB....HBBBBM...B.....HB.",
    "..........HBBM.HB..HBBBM......BB......BM",
    "...........HHBBBSMBM..........BM......BM",
    "............HBBBM.............B.......BM",
    "...........BHBBBM............BB.......BM",
    ".........HBBMSHBBM...........BM......BM.",
    ".......HBM..BM.HBBM..........B......BM..",
    ".....HBM...BM...HBBM........BM.....BM...",
    "...HBM.....BM....HBBM.......B....BBM....",
    "..HB......BM.......HBBM....BM..MBBM.....",
    ".HB.......BM........HBBM..SM.BBBM.......",
    "HB.......BM...........HBBBBSBBM.........",
    "HB.......B.............HBBBM............",
    "BM......BM............SHBBBM............",
    "BM......BM.........MBBS.HBBBM...........",
    "BM.....BM.......MBBBM..HB..HBM..........",
    ".MBM...BM..BBBBBBM....HBM....HB.........",
    "..MBBBBBBBBMMM........HB......HB........",
    "......HB.............HBM......HBM.......",
    "......HB............HBM........HBM......",
    "......HB...........HBBM.........HB......",
    "......HB..........HBBBBM........HBM.....",
    ".....HB..........HBBBBBBM.......HBM.....",
    ".....HB........SHWWBBBBBBM.......HBM....",
    "......HB.....SHBBBBBBBBBBBM......HBM....",
    "......HBBBBBBBBBBM.....HBBBBBM..HBBM....",
    "......HBBBBBBBBBM.......HBBBBBBBBBBM....",
    ".......MBBBBM............HBBBBBBBBBM....",
    "..........................HBBBBBBBBM....",
    "...........................HBBBBBBBM....",
    ".............................MBBBBM.....",
    "..............................SMBM......",
)

PALETTES = {
    "lavender": {
        "W": (245, 235, 255),
        "H": (226, 200, 255),
        "B": (203, 166, 247),
        "M": (166, 107, 232),
        "S": (118, 60, 194),
    },
    "installer": {
        "W": (224, 248, 255),
        "H": (166, 224, 248),
        "B": (158, 184, 244),
        "M": (175, 134, 238),
        "S": (122, 76, 198),
    },
    "mono": {
        "W": (203, 166, 247),
        "H": (203, 166, 247),
        "B": (203, 166, 247),
        "M": (203, 166, 247),
        "S": (203, 166, 247),
    },
}

BASIC_MAP = {
    "W": 97,
    "H": 95,
    "B": 95,
    "M": 35,
    "S": 35,
}

RESET = "\x1b[0m"


def detect_color_depth():
    if os.environ.get("NO_COLOR"):
        return 0
    term = os.environ.get("TERM", "").lower()
    if term == "dumb":
        return 0
    colorterm = os.environ.get("COLORTERM", "").lower()
    term_prog = os.environ.get("TERM_PROGRAM", "").lower()
    if colorterm in ("truecolor", "24bit") or any(
        k in term for k in ("kitty", "foot", "alacritty", "ghostty", "wezterm", "direct")
    ) or term_prog in ("wezterm", "ghostty", "iterm.app", "vscode", "hyper"):
        return 24
    if "256color" in term:
        return 8
    return 4


def rgb_to_256(r, g, b):
    if r == g == b:
        if r < 8:
            return 16
        if r > 248:
            return 231
        return round(((r - 8) / 247) * 24) + 232
    ri = round(r / 255 * 5)
    gi = round(g / 255 * 5)
    bi = round(b / 255 * 5)
    return 16 + 36 * ri + 6 * gi + bi


def _fg_seq(rgb, key, depth):
    if depth == 24:
        return f"\x1b[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m"
    if depth == 8:
        return f"\x1b[38;5;{rgb_to_256(*rgb)}m"
    if depth == 4:
        return f"\x1b[{BASIC_MAP.get(key, 35)}m"
    return ""


def _bg_seq(rgb, key, depth):
    if depth == 24:
        return f"\x1b[48;2;{rgb[0]};{rgb[1]};{rgb[2]}m"
    if depth == 8:
        return f"\x1b[48;5;{rgb_to_256(*rgb)}m"
    if depth == 4:
        return f"\x1b[{BASIC_MAP.get(key, 35) + 10}m"
    return ""


def _downsample_grid(target_width, target_height, threshold=0.42):
    src_h = len(LOGO_PIXEL_GRID)
    src_w = len(LOGO_PIXEL_GRID[0])
    if target_width == src_w and target_height == src_h:
        return LOGO_PIXEL_GRID
    rank = {".": 0, "S": 1, "M": 2, "B": 3, "H": 4, "W": 5}
    inv = {v: k for k, v in rank.items()}
    out = []
    for y in range(target_height):
        y0 = y * src_h / target_height
        y1 = (y + 1) * src_h / target_height
        row = []
        for x in range(target_width):
            x0 = x * src_w / target_width
            x1 = (x + 1) * src_w / target_width
            vals = []
            area = 0.0
            covered = 0.0
            for sy in range(int(y0), min(src_h, int(y1) + 1)):
                oy = max(0.0, min(y1, sy + 1) - max(y0, sy))
                if oy <= 0:
                    continue
                for sx in range(int(x0), min(src_w, int(x1) + 1)):
                    ox = max(0.0, min(x1, sx + 1) - max(x0, sx))
                    if ox <= 0:
                        continue
                    wt = ox * oy
                    area += wt
                    r = rank[LOGO_PIXEL_GRID[sy][sx]]
                    if r > 0:
                        covered += wt
                        vals.append((wt, r))
            if area > 0 and (covered / area) >= threshold:
                avg = sum(wt * r for wt, r in vals) / covered
                row.append(inv[max(1, min(5, round(avg)))])
            else:
                row.append(".")
        out.append("".join(row))
    return tuple(out)


def _render_grid_lines(grid, palette="lavender", color_depth=None, bg=None):
    depth = detect_color_depth() if color_depth is None else color_depth
    colors = PALETTES.get(palette, PALETTES["lavender"]) if isinstance(palette, str) else palette
    width = len(grid[0]) if grid else 0
    lines = []

    for row_idx in range(0, len(grid), 2):
        top_row = grid[row_idx]
        bot_row = grid[row_idx + 1] if row_idx + 1 < len(grid) else "." * width
        out = []
        last_style = None

        for top_ch, bot_ch in zip(top_row, bot_row):
            top_rgb = colors.get(top_ch)
            bot_rgb = colors.get(bot_ch)

            if top_rgb is None and bot_rgb is None:
                ch = " "
                style = ("bg", bg) if (bg is not None and depth > 0) else None
            elif top_rgb is not None and bot_rgb is None:
                ch = "▀"
                style = (top_rgb, top_ch, bg, None) if depth > 0 else None
            elif top_rgb is None and bot_rgb is not None:
                ch = "▄"
                style = (bot_rgb, bot_ch, bg, None) if depth > 0 else None
            elif top_rgb == bot_rgb:
                ch = "█"
                style = (top_rgb, top_ch, bg, None) if depth > 0 else None
            else:
                ch = "▀"
                style = (top_rgb, top_ch, bot_rgb, bot_ch) if depth > 0 else None

            if style != last_style:
                if style is None:
                    if last_style is not None:
                        out.append(RESET)
                elif style[0] == "bg":
                    out.append(RESET + _bg_seq(style[1], "S", depth))
                else:
                    fg_rgb, fg_k, bg_rgb, bg_k = style
                    seq = []
                    if last_style is not None and bg_rgb is None:
                        seq.append(RESET)
                    seq.append(_fg_seq(fg_rgb, fg_k, depth))
                    if bg_rgb is not None:
                        seq.append(_bg_seq(bg_rgb, bg_k or "S", depth))
                    out.append("".join(seq))
                last_style = style

            out.append(ch)

        if last_style is not None:
            out.append(RESET)
        lines.append("".join(out))

    return lines


def render_logo_lines(palette="lavender", color_depth=None, bg=None):
    return _render_grid_lines(LOGO_PIXEL_GRID, palette=palette, color_depth=color_depth, bg=bg)


def render_scaled_logo_lines(width=24, height=26, palette="installer", color_depth=None, bg=None, threshold=0.42):
    grid = _downsample_grid(width, height, threshold=threshold)
    return _render_grid_lines(grid, palette=palette, color_depth=color_depth, bg=bg)


def default_logo_png_path():
    return os.path.join(os.path.dirname(os.path.realpath(__file__)), "assets", "logo-installer.png")


def load_logo_png(path=None):
    target = path or default_logo_png_path()
    if not os.path.isfile(target):
        return None
    try:
        with open(target, "rb") as fh:
            return fh.read()
    except OSError:
        return None


def _paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def decode_png_rgba(data):
    if not data or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    pos = 8
    width = 0
    height = 0
    bit_depth = 0
    color_type = 0
    idat = bytearray()
    total = len(data)
    while pos + 8 <= total:
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        pos += 8
        chunk = data[pos:pos + length]
        pos += length + 4
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
                return None
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break
    if width <= 0 or height <= 0 or not idat:
        return None
    bpp = 4 if color_type == 6 else 3
    stride = width * bpp
    raw = zlib.decompress(bytes(idat))
    out = bytearray(width * height * 4)
    prev = bytearray(stride)
    src_i = 0
    for y in range(height):
        ftype = raw[src_i]
        src_i += 1
        row = bytearray(raw[src_i:src_i + stride])
        src_i += stride
        if ftype == 1:
            for x in range(bpp, stride):
                row[x] = (row[x] + row[x - bpp]) & 0xFF
        elif ftype == 2:
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 0xFF
        elif ftype == 3:
            for x in range(stride):
                left = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + ((left + prev[x]) >> 1)) & 0xFF
        elif ftype == 4:
            for x in range(stride):
                a = row[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + _paeth(a, b, c)) & 0xFF
        prev = row
        dst_base = y * width * 4
        if bpp == 4:
            out[dst_base:dst_base + width * 4] = row
        else:
            for x in range(width):
                s = x * 3
                d = dst_base + x * 4
                out[d] = row[s]
                out[d + 1] = row[s + 1]
                out[d + 2] = row[s + 2]
                out[d + 3] = 255
    return width, height, bytes(out)


def _sample_rgba(rgba, src_w, src_h, dst_w, dst_h):
    out = []
    for y in range(dst_h):
        y0 = int(y * src_h / dst_h)
        y1 = max(y0 + 1, int((y + 1) * src_h / dst_h))
        y1 = min(src_h, y1)
        row = []
        for x in range(dst_w):
            x0 = int(x * src_w / dst_w)
            x1 = max(x0 + 1, int((x + 1) * src_w / dst_w))
            x1 = min(src_w, x1)
            r_sum = 0
            g_sum = 0
            b_sum = 0
            a_sum = 0
            cnt = 0
            for sy in range(y0, y1):
                base = sy * src_w * 4
                for sx in range(x0, x1):
                    idx = base + sx * 4
                    a = rgba[idx + 3]
                    a_sum += a
                    if a > 0:
                        r_sum += rgba[idx] * a
                        g_sum += rgba[idx + 1] * a
                        b_sum += rgba[idx + 2] * a
                    cnt += 1
            if cnt == 0 or a_sum == 0:
                row.append((0, 0, 0, 0))
            else:
                row.append((r_sum // a_sum, g_sum // a_sum, b_sum // a_sum, a_sum // cnt))
        out.append(row)
    return out


BRAILLE_BITS = (
    (0x01, 0x08),
    (0x02, 0x10),
    (0x04, 0x20),
    (0x40, 0x80),
)


def render_braille_logo_lines(cols=24, rows=12, palette="installer", color_depth=None, rgba_info=None):
    depth = detect_color_depth() if color_depth is None else color_depth
    sub_w = cols * 2
    sub_h = rows * 4

    if rgba_info is not None:
        src_w, src_h, rgba = rgba_info
        pixels = _sample_rgba(rgba, src_w, src_h, sub_w, sub_h)
        lines = []
        for cy in range(rows):
            out = []
            last_rgb = None
            for cx in range(cols):
                mask = 0
                r_sum = 0
                g_sum = 0
                b_sum = 0
                hits = 0
                for dy in range(4):
                    py = cy * 4 + dy
                    for dx in range(2):
                        px = cx * 2 + dx
                        r, g, b, a = pixels[py][px]
                        if a >= 92:
                            mask |= BRAILLE_BITS[dy][dx]
                            r_sum += r
                            g_sum += g
                            b_sum += b
                            hits += 1
                if mask == 0:
                    if last_rgb is not None:
                        out.append(RESET)
                        last_rgb = None
                    out.append(" ")
                else:
                    rgb = (r_sum // hits, g_sum // hits, b_sum // hits)
                    if depth > 0 and rgb != last_rgb:
                        out.append(_fg_seq(rgb, "B", depth))
                        last_rgb = rgb
                    out.append(chr(0x2800 + mask))
            if last_rgb is not None:
                out.append(RESET)
            lines.append("".join(out))
        return lines

    colors = PALETTES.get(palette, PALETTES["installer"]) if isinstance(palette, str) else palette
    grid = _downsample_grid(sub_w, sub_h, threshold=0.35)
    lines = []
    for cy in range(rows):
        out = []
        last_rgb = None
        for cx in range(cols):
            mask = 0
            r_sum = 0
            g_sum = 0
            b_sum = 0
            hits = 0
            key = "B"
            for dy in range(4):
                py = cy * 4 + dy
                for dx in range(2):
                    px = cx * 2 + dx
                    ch = grid[py][px]
                    rgb = colors.get(ch)
                    if rgb is not None:
                        mask |= BRAILLE_BITS[dy][dx]
                        r_sum += rgb[0]
                        g_sum += rgb[1]
                        b_sum += rgb[2]
                        hits += 1
                        key = ch
            if mask == 0:
                if last_rgb is not None:
                    out.append(RESET)
                    last_rgb = None
                out.append(" ")
            else:
                rgb = (r_sum // hits, g_sum // hits, b_sum // hits)
                if depth > 0 and rgb != last_rgb:
                    out.append(_fg_seq(rgb, key, depth))
                    last_rgb = rgb
                out.append(chr(0x2800 + mask))
        if last_rgb is not None:
            out.append(RESET)
        lines.append("".join(out))
    return lines


def build_kitty_graphics_seq(png_bytes, row, col, cols, rows, image_id=101):
    encoded = base64.b64encode(png_bytes).decode("ascii")
    chunk_size = 4096
    chunks = [encoded[i:i + chunk_size] for i in range(0, len(encoded), chunk_size)]
    parts = [f"\x1b[{row};{col}H"]
    for idx, chunk in enumerate(chunks):
        more = 1 if idx + 1 < len(chunks) else 0
        if idx == 0:
            parts.append(f"\x1b_Ga=T,f=100,i={image_id},p=1,c={cols},r={rows},C=1,q=2,m={more};{chunk}\x1b\\")
        else:
            parts.append(f"\x1b_Gm={more};{chunk}\x1b\\")
    return "".join(parts)


def build_kitty_clear_seq():
    return "\x1b_Ga=d,d=a,q=2\x1b\\"


def build_sixel_seq(rgba_info, target_w, target_h, row, col):
    if rgba_info is None or target_w <= 0 or target_h <= 0:
        return ""
    src_w, src_h, rgba = rgba_info
    pixels = _sample_rgba(rgba, src_w, src_h, target_w, target_h)
    palette = []
    pal_index = {}
    indexed = []
    for y in range(target_h):
        row_idx = []
        for x in range(target_w):
            r, g, b, a = pixels[y][x]
            if a < 96:
                row_idx.append(-1)
                continue
            qr = (r >> 4) * 17
            qg = (g >> 4) * 17
            qb = (b >> 4) * 17
            key = (qr, qg, qb)
            ci = pal_index.get(key)
            if ci is None:
                if len(palette) < 64:
                    ci = len(palette) + 1
                    palette.append(key)
                    pal_index[key] = ci
                else:
                    best_i = 1
                    best_d = 10**9
                    for pi, prgb in enumerate(palette, 1):
                        d = (prgb[0] - r) ** 2 + (prgb[1] - g) ** 2 + (prgb[2] - b) ** 2
                        if d < best_d:
                            best_d = d
                            best_i = pi
                    ci = best_i
            row_idx.append(ci)
        indexed.append(row_idx)

    out = [f"\x1b[{row};{col}H\x1bP0;1;0q\"1;1;{target_w};{target_h}"]
    for ci, (r, g, b) in enumerate(palette, 1):
        out.append(f"#{ci};2;{r * 100 // 255};{g * 100 // 255};{b * 100 // 255}")

    for band_y in range(0, target_h, 6):
        band_colors = {}
        for dy in range(6):
            y = band_y + dy
            if y >= target_h:
                break
            bit = 1 << dy
            row_idx = indexed[y]
            for x in range(target_w):
                ci = row_idx[x]
                if ci > 0:
                    arr = band_colors.get(ci)
                    if arr is None:
                        arr = [0] * target_w
                        band_colors[ci] = arr
                    arr[x] |= bit
        first = True
        for ci, arr in band_colors.items():
            if not first:
                out.append("$")
            first = False
            out.append(f"#{ci}")
            x = 0
            while x < target_w:
                val = arr[x]
                run = 1
                while x + run < target_w and arr[x + run] == val:
                    run += 1
                ch = chr(63 + val)
                if run >= 4:
                    out.append(f"!{run}{ch}")
                else:
                    out.append(ch * run)
                x += run
        if band_y + 6 < target_h:
            out.append("-")
    out.append("\x1b\\")
    return "".join(out)


def _wait_key():
    if not sys.stdin.isatty():
        return
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)


def main():
    parser = argparse.ArgumentParser(description="Render the Serpantinum pixel art logo in the terminal.")
    parser.add_argument("--palette", choices=tuple(PALETTES.keys()), default="lavender")
    parser.add_argument("--depth", type=int, choices=(0, 4, 8, 24), default=None)
    parser.add_argument("--raw", action="store_true")
    parser.add_argument("--hold", action="store_true")
    args = parser.parse_args()

    depth = detect_color_depth() if args.depth is None else args.depth
    logo_lines = render_logo_lines(palette=args.palette, color_depth=depth)

    if args.raw:
        sys.stdout.write("\n".join(logo_lines) + "\n")
        return

    cols, rows = shutil.get_terminal_size((80, 30))
    pad_x = max(0, (cols - LOGO_PIXEL_WIDTH) // 2)
    margin = " " * pad_x

    title = "S E R P A N T I N U M"
    subtitle = "40×44 pixel art  •  40×22 terminal cells"
    hint = "Press any key to close"

    total_h = len(logo_lines) + (4 if args.hold else 3)
    pad_y = max(1, (rows - total_h) // 2) if args.hold else 1

    if args.hold:
        sys.stdout.write("\x1b[2J\x1b[H\x1b[?25l")

    try:
        sys.stdout.write("\n" * pad_y)
        for line in logo_lines:
            sys.stdout.write(margin + line + "\n")
        sys.stdout.write("\n")

        title_pad = " " * max(0, (cols - len(title)) // 2)
        sub_pad = " " * max(0, (cols - len(subtitle)) // 2)
        if depth >= 8:
            t_fg = _fg_seq((203, 166, 247), "B", depth)
            s_fg = _fg_seq((166, 173, 200), "M", depth)
            h_fg = _fg_seq((108, 112, 134), "S", depth)
            sys.stdout.write(f"{title_pad}\x1b[1m{t_fg}{title}{RESET}\n")
            sys.stdout.write(f"{sub_pad}{s_fg}{subtitle}{RESET}\n")
            if args.hold:
                hint_pad = " " * max(0, (cols - len(hint)) // 2)
                sys.stdout.write(f"\n{hint_pad}{h_fg}{hint}{RESET}")
        else:
            sys.stdout.write(f"{title_pad}{title}\n")
            sys.stdout.write(f"{sub_pad}{subtitle}\n")
            if args.hold:
                hint_pad = " " * max(0, (cols - len(hint)) // 2)
                sys.stdout.write(f"\n{hint_pad}{hint}")

        sys.stdout.flush()
        if args.hold:
            _wait_key()
    finally:
        if args.hold:
            sys.stdout.write("\x1b[?25h\x1b[0m\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
