#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11,<3.14"
# dependencies = [
#   "torch>=2.9",
#   "diffusers>=0.35",
#   "transformers",
#   "accelerate",
#   "safetensors",
#   "compel>=2.1",
#   "pillow>=11",
#   "rembg[cpu]",
#   "fonttools",
# ]
# [tool.uv.sources]
# torch = { index = "pytorch-cu132" }
# [[tool.uv.index]]
# name = "pytorch-cu132"
# url = "https://download.pytorch.org/whl/cu132"
# explicit = true
# ///
"""Render a series strip: paint panels locally (SDXL + IP-Adapter), letter them, lay them out.

  render.py --setup                 download fonts and models, check the GPU
  render.py STRIP.json --out DIR    paint, letter and lay out every panel
  render.py STRIP.json --out DIR --only 2,3    repaint only those panels
  render.py STRIP.json --out DIR --relayout    reuse painted panels; redo text and layout
"""

import argparse
import functools
import json
import math
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")  # before torch is imported

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

DATA = Path(os.environ.get("SERIES_STRIP_HOME", Path.home() / ".local/share/series-strip"))
REFS = DATA / "refs"
FONT_DIR = DATA / "fonts"
CAST_FILE = Path(__file__).resolve().parent.parent / "assets" / "cast.json"

MODEL = "stabilityai/stable-diffusion-xl-base-1.0"
VAE = "madebyollin/sdxl-vae-fp16-fix"
IP_REPO = "h94/IP-Adapter"
IP_WEIGHTS = "ip-adapter-plus_sdxl_vit-h.safetensors"
PANEL_W, PANEL_H = 1152, 896  # an SDXL training bucket, close to the 5:4 of the references
FONTS = {
    "bubble": ("Bangers-Regular.ttf", "https://github.com/google/fonts/raw/main/ofl/bangers/Bangers-Regular.ttf"),
    "caption": ("ComicNeue-Bold.ttf", "https://github.com/google/fonts/raw/main/ofl/comicneue/ComicNeue-Bold.ttf"),
}
NEON = {"green": (57, 255, 120), "magenta": (255, 60, 200), "cyan": (40, 230, 255), "orange": (255, 140, 40), "red": (255, 60, 60)}
MIN_FREE_VRAM_MB = 9000
FALLBACK_CHARSET = "2192 2713 2665 2605"  # → ✓ ♥ ★, for fc-match
# Two custom characters in one SDXL prompt bleed into each other, so each actor is painted alone,
# cut out and pasted onto an empty background.
ACTOR_W, ACTOR_H = 896, 1152  # portrait SDXL bucket for one full-body character
ACTOR_X = {"left": 0.27, "center": 0.5, "right": 0.73}  # actor centre, share of panel width
ACTOR_PROMPT = "full body shot of one single character, {}, standing alone, isolated on a plain flat light grey background, simple background"
ACTOR_NEGATIVE = "scenery, detailed background, multiple characters, two characters, cropped, cut off feet"
EMPTY_PROMPT = "empty scene, nobody, no characters"
EMPTY_NEGATIVE = "person, people, character, animal, cat, tiger, robot, mascot, monster"
BG_IP_SCALE = 0.2  # the refs show the cast; keep that pull faint in an empty background
OUTLINE_PX = 6
ACTOR_GREY = (214, 214, 214)
SOLID_CUTOUT = 0.9  # an actor whose cut-out is this opaque kept its background


def log(msg):
    print(msg, file=sys.stderr, flush=True)


# ---------- setup ----------

def ensure_fonts():
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for name, url in FONTS.values():
        dest = FONT_DIR / name
        if not dest.exists():
            log(f"font: downloading {name}")
            urllib.request.urlretrieve(url, dest)


class Font:
    """A comic font plus a fallback for the glyphs it lacks (→ ✓ ♥ in Bangers and Comic Neue)."""

    def __init__(self, kind, size):
        from fontTools.ttLib import TTFont

        path = FONT_DIR / FONTS[kind][0]
        self.main = ImageFont.truetype(str(path), size)
        self.cmap = set(TTFont(path).getBestCmap())
        fb = subprocess.run(["fc-match", "-f", "%{file}", f"DejaVu Sans:bold:charset={FALLBACK_CHARSET}"], capture_output=True, text=True).stdout
        self.fallback = ImageFont.truetype(fb, int(size * 0.82)) if fb else self.main
        self.size = size

    def runs(self, text):
        out = []
        for ch in text:
            f = self.main if ord(ch) in self.cmap or ch == " " else self.fallback
            if out and out[-1][1] is f:
                out[-1][0] += ch
            else:
                out.append([ch, f])
        return out

    def length(self, draw, text):
        return sum(draw.textlength(t, font=f) for t, f in self.runs(text))

    def draw(self, draw, xy, text, fill):
        x, y = xy
        for t, f in self.runs(text):
            dy = (self.size - f.size) * 0.55 if f is self.fallback else 0
            draw.text((x, y + dy), t, font=f, fill=fill)
            x += draw.textlength(t, font=f)

    def getmetrics(self):
        return self.main.getmetrics()


@functools.cache
def font(kind, size):
    return Font(kind, size)


def check_gpu():
    import torch

    if not torch.cuda.is_available():
        sys.exit(f"no CUDA GPU visible to torch {torch.__version__}; reinstall with: uv run --reinstall-package torch --script {__file__} --setup")
    free, total = (x // 2**20 for x in torch.cuda.mem_get_info())
    log(f"gpu: {torch.cuda.get_device_name(0)}, {free} of {total} MiB free, torch {torch.__version__}")
    return free


# ---------- prompts ----------

def load_cast():
    return json.loads(CAST_FILE.read_text())


def build_prompt(panel, cast):
    """`scene` may name {tiger} {robot} {monster} {monsters}; `setting` picks a cast.json setting."""
    scene = panel["scene"].format(**cast["cast"])
    parts = [scene]
    if panel.get("setting"):
        parts.append(cast["settings"][panel["setting"]])
    parts.append(cast["style"])
    return ", ".join(parts)


# ---------- painting ----------

def load_pipe(args):
    import torch
    from diffusers import AutoencoderKL, DPMSolverMultistepScheduler, StableDiffusionXLPipeline
    from transformers import CLIPVisionModelWithProjection

    dtype = torch.float16
    encoder = CLIPVisionModelWithProjection.from_pretrained(IP_REPO, subfolder="models/image_encoder", dtype=dtype)
    vae = AutoencoderKL.from_pretrained(VAE, dtype=dtype)
    kw = dict(vae=vae, image_encoder=encoder, dtype=dtype, use_safetensors=True)
    try:
        pipe = StableDiffusionXLPipeline.from_pretrained(args.model, variant="fp16", **kw)
    except (OSError, ValueError):
        pipe = StableDiffusionXLPipeline.from_pretrained(args.model, **kw)
    pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config, use_karras_sigmas=True)
    pipe.load_ip_adapter(IP_REPO, subfolder="sdxl_models", weight_name=IP_WEIGHTS)
    pipe.set_ip_adapter_scale(args.ip_scale)
    if args.offload:
        pipe.enable_model_cpu_offload()
    else:
        pipe.to("cuda")
    pipe.vae.enable_tiling()  # the full-size VAE decode is what ran out of VRAM on a 12 GB card
    return pipe


def encoder_for(pipe):
    from compel import CompelForSDXL

    # SDXL's CLIP stops at 77 tokens; Compel chunks longer prompts so the cast description is not cut off.
    return CompelForSDXL(pipe)


IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}


def images_in(folder):
    return [Image.open(p).convert("RGB") for p in sorted(folder.iterdir()) if p.suffix.lower() in IMAGE_EXT] if folder.is_dir() else []


def load_refs(names):
    refs = [Image.open(REFS / n).convert("RGB") for n in names] if names else images_in(REFS)
    if not refs:
        sys.exit(f"no reference images in {REFS}")
    return refs


def mentions(text, name):
    return "{" + name + "}" in text


def clean_refs(name):
    """The crops in refs/<name>/, cut out and set on flat grey (cached in refs/<name>/_clean/).

    IP-Adapter copies a reference's background too; busy references gave busy actor backgrounds that rembg could not cut.
    """
    src, cache = REFS / name, REFS / name / "_clean"
    out = []
    for path in sorted(p for p in src.iterdir() if p.suffix.lower() in IMAGE_EXT) if src.is_dir() else []:
        cached = cache / f"{path.stem}.png"
        if not cached.exists():
            cache.mkdir(exist_ok=True)
            figure = cut_out(Image.open(path).convert("RGB"))
            flat = Image.new("RGB", figure.size, ACTOR_GREY)
            flat.paste(figure, (0, 0), figure)
            flat.save(cached)
            log(f"refs: cleaned {path.name} for {name}")
        out.append(Image.open(cached).convert("RGB"))
    return out


def actor_refs(text, cast, fallback):
    """An actor looks only at its own character's crops, so it borrows nothing from the other."""
    own = [img for name in cast["cast"] if mentions(text, name) for img in clean_refs(name)]
    return own or fallback


def actor_negative(text, cast):
    return ", ".join(avoid for name, avoid in cast["avoid"].items() if not mentions(text, name))


def paint(pipe, compel, prompt, negative, refs, seed, args, size=(PANEL_W, PANEL_H), ip_scale=None):
    import torch

    pipe.set_ip_adapter_scale(args.ip_scale if ip_scale is None else ip_scale)
    c = compel(prompt, negative_prompt=negative)
    return pipe(
        prompt_embeds=c.embeds,
        pooled_prompt_embeds=c.pooled_embeds,
        negative_prompt_embeds=c.negative_embeds,
        negative_pooled_prompt_embeds=c.negative_pooled_embeds,
        ip_adapter_image=[refs],
        width=size[0],
        height=size[1],
        num_inference_steps=args.steps,
        guidance_scale=args.cfg,
        generator=torch.Generator("cuda").manual_seed(seed),
    ).images[0]


# ---------- cut-out and compositing ----------

@functools.cache
def cutter():
    from rembg import new_session

    return new_session("isnet-anime")  # trained on drawn characters; keeps thick outlines


def cut_out(img):
    from rembg import remove

    rgba = remove(img, session=cutter())
    # hard edges: rembg's soft edge left a grey haze around light figures; the ink outline hides the steps
    rgba.putalpha(rgba.getchannel("A").point(lambda v: 255 if v > 150 else 0))
    return rgba.crop(rgba.getchannel("A").getbbox())


def outlined(actor):
    """Thick black outline around the cut-out, like the ink lines in the references."""
    pad = OUTLINE_PX + 2
    canvas = Image.new("RGBA", (actor.width + 2 * pad, actor.height + 2 * pad), (0, 0, 0, 0))
    canvas.paste(actor, (pad, pad))
    solid = canvas.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    ink = Image.new("RGBA", canvas.size, (0, 0, 0, 255))
    ink.putalpha(solid.filter(ImageFilter.MaxFilter(2 * OUTLINE_PX + 1)))
    ink.alpha_composite(canvas)
    return ink


def compose(bg, actors, specs):
    img = bg.convert("RGB")
    for actor, spec in zip(actors, specs):
        a = outlined(actor)
        h = int(PANEL_H * spec.get("height", 0.82))
        w = int(a.width * h / a.height)
        a = a.resize((w, h), Image.LANCZOS)
        if spec.get("flip"):
            a = ImageOps.mirror(a)
        x = int(PANEL_W * ACTOR_X[spec.get("pos", "left")] - w / 2)
        y = PANEL_H - h + int(PANEL_H * 0.04)  # feet just below the frame edge
        img.paste(a, (x, y), a)
    return img


# ---------- lettering ----------

def wrap(draw, text, fnt, max_w):
    lines = []
    for para in text.split("\n"):
        line = ""
        for word in para.split():
            trial = f"{line} {word}".strip()
            if fnt.length(draw, trial) <= max_w or not line:
                line = trial
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def text_block(draw, text, fnt, max_w, spacing=6):
    lines = wrap(draw, text, fnt, max_w)
    asc, desc = fnt.getmetrics()
    line_h = asc + desc
    w = max(fnt.length(draw, l) for l in lines)
    return lines, w, line_h * len(lines) + spacing * (len(lines) - 1), line_h + spacing


def anchor(pos, box_w, box_h, margin=34):
    v, _, h = pos.partition("-")
    x = {"left": margin, "center": (PANEL_W - box_w) // 2, "right": PANEL_W - box_w - margin}[h or "center"]
    y = {"top": margin, "middle": (PANEL_H - box_h) // 2, "bottom": PANEL_H - box_h - margin}[v]
    return x, y


def draw_lines(draw, lines, x0, y0, box_w, step, fnt, fill):
    for i, line in enumerate(lines):
        lw = fnt.length(draw, line)
        fnt.draw(draw, (x0 + (box_w - lw) / 2, y0 + i * step), line, fill)


def bubble(img, b):
    draw = ImageDraw.Draw(img)
    shout = b.get("style") == "shout"
    fnt = font("bubble", b.get("size", 50 if shout else 44))
    lines, tw, th, step = text_block(draw, b["text"], fnt, PANEL_W * 0.34)
    bw, bh = int(tw * 1.22 + 54), int(th * 1.3 + 48)
    x, y = anchor(b.get("pos", "top-left"), bw, bh)
    cx, cy = x + bw / 2, y + bh / 2
    tail = b.get("tail", "left" if "right" not in b.get("pos", "") else "right")
    fill = (255, 236, 80) if shout else (255, 255, 255)
    ink, width = (0, 0, 0), 5
    tail_poly = None
    if tail != "none":
        dx = {"left": -1, "right": 1, "down": 0}[tail]
        base_y = cy + bh * 0.32
        tip = (cx + dx * bw * 0.32, y + bh + 90)
        tail_poly = [(cx - 26 + dx * bw * 0.12, base_y), (cx + 26 + dx * bw * 0.12, base_y), tip]
        draw.polygon(tail_poly, fill=fill, outline=ink, width=width)
    if shout:
        pts, n = [], 22
        for i in range(n * 2):
            a = math.pi * i / n
            r = 1.0 if i % 2 == 0 else 0.8
            pts.append((cx + math.cos(a) * bw / 2 * r * 1.08, cy + math.sin(a) * bh / 2 * r * 1.12))
        draw.polygon(pts, fill=fill, outline=ink, width=width)
    else:
        draw.ellipse([x, y, x + bw, y + bh], fill=fill, outline=ink, width=width)
    if tail_poly:
        a, b2, tip = tail_poly
        draw.polygon([(a[0] + 6, a[1] - 14), (b2[0] - 6, b2[1] - 14), ((a[0] + b2[0]) / 2 + (tip[0] - cx) * 0.25, a[1] + 18)], fill=fill)
    draw_lines(draw, lines, cx - tw / 2, cy - th / 2 - 4, tw, step, fnt, ink)


def caption(img, c):
    draw = ImageDraw.Draw(img)
    fnt = font("caption", c.get("size", 34))
    lines, tw, th, step = text_block(draw, c["text"], fnt, PANEL_W * 0.42)
    bw, bh = int(tw + 44), int(th + 34)
    x, y = anchor(c.get("pos", "bottom-left"), bw, bh, margin=0)
    draw.rectangle([x, y, x + bw, y + bh], fill=(255, 226, 90), outline=(0, 0, 0), width=4)
    draw_lines(draw, lines, x + 22, y + 15, tw, step, fnt, (20, 20, 20))


def neon_label(img, n):
    color = NEON[n.get("color", "green")]
    fnt = font("bubble", n.get("size", 46))
    probe = ImageDraw.Draw(img)
    lines, tw, th, step = text_block(probe, n["text"], fnt, PANEL_W * 0.45)
    bw, bh = int(tw + 56), int(th + 40)
    x, y = anchor(n.get("pos", "top-right"), bw, bh)
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.rounded_rectangle([x, y, x + bw, y + bh], 16, outline=color + (255,), width=10)
    draw_lines(g, lines, x + 28, y + 18, tw, step, fnt, color + (255,))
    glow = glow.filter(ImageFilter.GaussianBlur(9))
    panel = Image.new("RGBA", img.size, (0, 0, 0, 0))
    p = ImageDraw.Draw(panel)
    p.rounded_rectangle([x, y, x + bw, y + bh], 16, fill=(8, 10, 24, 215), outline=color + (255,), width=4)
    draw_lines(p, lines, x + 28, y + 18, tw, step, fnt, (235, 255, 240, 255))
    base = img.convert("RGBA")
    base.alpha_composite(glow)
    base.alpha_composite(panel)
    img.paste(base.convert("RGB"))


def letter(raw, panel):
    img = raw.copy()
    for n in panel.get("labels", []):
        neon_label(img, n)
    for c in panel.get("captions", []):
        caption(img, c)
    for b in panel.get("bubbles", []):
        bubble(img, b)
    return img


# ---------- layout ----------

def layout(panels, strip):
    n = len(panels)
    cols = {1: 1, 2: 2, 4: 2}.get(n, 3)
    rows = math.ceil(n / cols)
    gut, title_h = 26, 170
    W = cols * PANEL_W + (cols + 1) * gut
    H = title_h + rows * PANEL_H + (rows + 1) * gut
    sheet = Image.new("RGB", (W, H), (12, 10, 22))
    d = ImageDraw.Draw(sheet)
    font("bubble", 104).draw(d, (gut + 6, 22), strip.get("title", "Veckans strip"), NEON["magenta"])
    if strip.get("subtitle"):
        font("caption", 36).draw(d, (gut + 10, 124), strip["subtitle"], NEON["cyan"])
    for i, p in enumerate(panels):
        r, c = divmod(i, cols)
        in_row = min(cols, n - r * cols)
        offset = (cols - in_row) * (PANEL_W + gut) // 2
        x = gut + offset + c * (PANEL_W + gut)
        y = title_h + gut + r * (PANEL_H + gut)
        d.rectangle([x - 6, y - 6, x + PANEL_W + 5, y + PANEL_H + 5], fill=(0, 0, 0))
        sheet.paste(p, (x, y))
    return sheet


# ---------- main ----------

def parse_only(spec, n):
    if not spec:
        return set(range(1, n + 1))
    picked = {int(s) for s in spec.split(",") if s.strip()}
    bad = sorted(i for i in picked if not 1 <= i <= n)
    if bad:
        sys.exit(f"--only {bad}: the strip has panels 1..{n}")
    return picked


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("strip", nargs="?", help="strip JSON (see SKILL.md)")
    ap.add_argument("--out", help="output folder")
    ap.add_argument("--setup", action="store_true", help="download fonts and models, check the GPU, then exit")
    ap.add_argument("--only", help="comma-separated panel numbers to repaint")
    ap.add_argument("--relayout", action="store_true", help="skip painting; reuse panels/raw-NN.png")
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--steps", type=int, default=30)
    ap.add_argument("--cfg", type=float, default=6.0)
    ap.add_argument("--ip-scale", type=float, default=0.6, help="how strongly the reference images steer each character")
    ap.add_argument("--offload", action="store_true", help="CPU offload when another process holds VRAM (slower)")
    args = ap.parse_args()

    ensure_fonts()
    if args.setup:
        free = check_gpu()
        pipe = load_pipe(args)
        encoder_for(pipe)
        cutter()
        log(f"setup: models cached; refs in {REFS}: {len(load_refs(None))} images; fonts in {FONT_DIR}")
        if free < MIN_FREE_VRAM_MB:
            log(f"setup: only {free} MiB VRAM free now; stop other GPU users or pass --offload")
        return
    if not (args.strip and args.out):
        ap.error("STRIP and --out are required (or --setup)")

    strip = json.loads(Path(args.strip).read_text())
    panels = strip["panels"]
    out = Path(args.out)
    (out / "panels").mkdir(parents=True, exist_ok=True)
    todo = set() if args.relayout else parse_only(args.only, len(panels))
    cast = load_cast()
    base_seed = strip.get("seed", 1234)
    record = []

    pipe = compel = refs = None
    if todo:
        free = check_gpu()
        if free < MIN_FREE_VRAM_MB and not args.offload:
            log(f"warning: {free} MiB VRAM free; falling back to --offload")
            args.offload = True
        t0 = time.time()
        pipe = load_pipe(args)
        compel = encoder_for(pipe)
        refs = load_refs(strip.get("refs"))
        log(f"model loaded in {time.time() - t0:.0f}s")

    lettered = []
    for i, panel in enumerate(panels, 1):
        p = out / "panels"
        raw_path, bg_path = p / f"raw-{i:02d}.png", p / f"bg-{i:02d}.png"
        specs = panel.get("actors", [])
        actor_paths = [p / f"actor-{i:02d}-{k}.png" for k in range(1, len(specs) + 1)]
        seed = panel.get("seed", base_seed + i)
        negative = cast["negative"] + ", " + panel.get("negative", "")
        prompt = build_prompt(panel, cast)
        if i in todo:
            t0 = time.time()
            if specs:
                prompt = f"{prompt}, {EMPTY_PROMPT}"
                paint(pipe, compel, prompt, f"{negative}, {EMPTY_NEGATIVE}", refs, seed, args, ip_scale=BG_IP_SCALE).save(bg_path)
                for k, (spec, path) in enumerate(zip(specs, actor_paths), 1):
                    actor_prompt = build_prompt({"scene": ACTOR_PROMPT.format(spec["text"])}, cast)
                    actor_neg = f"{negative}, {actor_negative(spec['text'], cast)}, {ACTOR_NEGATIVE}"
                    img = paint(pipe, compel, actor_prompt, actor_neg, actor_refs(spec["text"], cast, refs), seed + 100 * k, args, size=(ACTOR_W, ACTOR_H))
                    figure = cut_out(img)
                    figure.save(path)
                    img.save(path.with_name(path.stem + "-painted.png"))
                    opaque = sum(figure.getchannel("A").histogram()[129:]) / (figure.width * figure.height)
                    if opaque > SOLID_CUTOUT or figure.height < ACTOR_H * 0.4:
                        log(f"panel {i}: actor {k} cut badly ({opaque:.0%} opaque, {figure.height}px tall); change the panel seed and repaint")
            else:
                paint(pipe, compel, prompt, negative, refs, seed, args).save(raw_path)
            log(f"panel {i}: painted in {time.time() - t0:.0f}s (seed {seed})")
            import torch

            torch.cuda.empty_cache()
        if specs and bg_path.exists() and all(a.exists() for a in actor_paths):
            # recomposed on every run, so --relayout picks up changed `pos`, `height` and `flip`
            compose(Image.open(bg_path), [Image.open(a).convert("RGBA") for a in actor_paths], specs).save(raw_path)
        elif not raw_path.exists():
            sys.exit(f"panel {i}: {raw_path} missing; paint it first (drop --relayout or add it to --only)")
        img = letter(Image.open(raw_path).convert("RGB"), panel)
        img.save(out / "panels" / f"panel-{i:02d}.png")
        lettered.append(img)
        record.append({"panel": i, "seed": seed, "prompt": prompt})

    sheet = layout(lettered, strip)
    sheet.save(out / "strip.png")
    sheet.convert("RGB").save(out / "strip.jpg", quality=90)
    (out / "render.json").write_text(json.dumps({"args": vars(args), "panels": record}, indent=2, ensure_ascii=False))
    print(out / "strip.png")


if __name__ == "__main__":
    main()
