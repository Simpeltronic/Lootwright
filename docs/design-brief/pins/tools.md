# Tools used for the pin options

Design choices (shapes, colours, layouts) were made by Claude (an AI assistant). The A-J pins E, F (target) and F, G (farm) are code/Krita shapes; the six *_flux pins are AI-generated (Flux 2 Klein 4B) and post-processed in PIL.

| File | Tool |
|---|---|
| pin_target_A_skull-ring, B_red-x, C_x-brass-ring, D_diamond-skull (.png) | Python PIL script `make_pins.py` (8x supersampling, Lanczos downscale to 64 px) |
| pin_farm_A_skull-ring, B_gem, C_dark-core-disc, D_diamond-skull, E_dark-x-disc (.png) | Python PIL script `make_pins.py` |
| pin_target_E_hex-x_krita, pin_target_F_reticle_krita (.png) | Krita 5 (headless `kritarunner`) via `make_pins_krita.py`: shapes painted with Qt QPainter (Krita's embedded PyQt5) at 512 px into a Krita document, scaled to 64x64 by Krita (Lanczos3) and exported as PNG by Krita. No PIL post-processing. |
| pin_farm_F_triple-dot_krita, pin_farm_G_hex_krita (.png) | same Krita script |
| pin_target_G_red-x_flux, pin_target_H_brass-medallion-x_flux, pin_target_I_loot-bag_flux, pin_farm_H_gem_flux, pin_farm_I_hex_flux, pin_farm_J_bag_flux (.png) | Flux 2 Klein 4B (flux-2-klein-4b-fp8.safetensors, Qwen3-4B text encoder, flux2-vae) via local ComfyUI at 127.0.0.1:8188, script `make_pins_flux.py`. 1024x1024 render, 4 steps, euler, BasicGuider (no CFG). Then PIL: flood-fill the white background to transparent, snap every pixel to the allowed brand colours (dark/brass/red or dark/green/bone), crop, scale to 58 px longest side (Lanczos), centre on a 64x64 transparent canvas. Prompts and seeds below. |
| pin_target_S1_route-x, S2_teardrop-x, S3_stamp-x, S4_brackets-x; pin_farm_S1_route-gem, S2_teardrop-green, S3_stamp-gem, S4_brackets-gem (.png) | Python PIL script `make_pins_sig.py` (8x supersampling, Lanczos to 64 px). No AI image model. |
| compare_other_addons.png | Python PIL script `make_compare.py`: generic stand-in shapes for other addons' markers drawn in code (no real addon art), our pins scattered among them |
| preview_sheet.png, density_preview.png, density_pair1..7.png | Python PIL script `make_preview.py` (parchment, blotches and lines are generated noise; pin counts are random numbers) |

## Flux prompts and seeds
Common suffix (STYLE): "flat vector game icon, simple bold shapes, very thick dark navy outline, solid flat colours, no gradients, no shading, no fine detail, centered, front view, isolated on a plain pure white background". Two seeds were rendered per prompt; the one kept is listed.
- pin_target_G_red-x_flux (seed 11): "a bold red letter X, two crossing thick rounded strokes, red with a thick dark navy outline, " + STYLE
- pin_target_H_brass-medallion-x_flux (seed 22): "a round brass-gold medallion with a thick dark navy rim and a bold red X in the middle, " + STYLE
- pin_target_I_loot-bag_flux (seed 31): "a small brass-gold loot bag sack tied at the top, thick dark navy outline, " + STYLE
- pin_farm_H_gem_flux (seed 42): "a single green faceted gem diamond shape, bright green with a thick dark navy outline, " + STYLE
- pin_farm_I_hex_flux (seed 52): "a bright green hexagon badge with a thick dark navy outline and a small cream dot in the center, " + STYLE
- pin_farm_J_bag_flux (seed 62): "a small bright green loot bag sack tied at the top, thick dark navy outline, " + STYLE
The script renders both seeds per prompt into a scratch folder; the kept ones were copied into this folder by hand. The ComfyUI server is Krita AI's local one; nothing left the machine.

Regenerate: `python make_pins.py`; for each Krita option run `PIN=<name> kritarunner.exe -s make_pins_krita <full path>\make_pins_krita.py` (one option per run, Krita crashes on a second document in one run); `python make_pins_flux.py <scratch dir>` (needs ComfyUI running; then copy the chosen *_64.png); then `python make_pins_sig.py`; `python make_preview.py`; `python make_compare.py`.

## ingame_mock.png
Composite made by `mock_real.py` (Python PIL): the world map cropped from Simon's own in-game screenshot (Thousand Needles, WoW Forever), with pin options pasted over the skull markers that `find_skulls.py` detects. Detection misses some skulls, so the mock mixes old skulls and new pins. No AI image model.

## Frame textures (item-icon pins)
Made by Python PIL script `make_frames.py` (8x supersampling, Lanczos to 64 px). No AI image model. The silk icon in the proof sheet is a 16x16 crop of a user screenshot; the other item stand-ins are flat colours drawn in code.
Files: frame_target_F1/F2/F3.png (brass #C9A24A), frame_farm_F1/F2/F3.png (green #4FD36A), 64x64, transparent outside and in the window. Layers: dark #14171C outer outline 3 px, coloured band, dark inner line 2 px, then the window.
Window rectangle at 64 px (the same for the brass and green version; icon goes here, drawn underneath; x/y inset from every edge, size = 64 - 2*inset):
| Variant | Band | Rounded outer corners | Window inset | Window rect (x0,y0)-(x1,y1) | Window size |
|---|---|---|---|---|---|
| F1 thin | 6 px | no | 11 px | (11,11)-(53,53) | 42x42 |
| F2 thick | 10 px | no | 15 px | (15,15)-(49,49) | 34x34 |
| F3 rounded | 8 px | yes, radius 10 px (window itself is square) | 13 px | (13,13)-(51,51) | 38x38 |
In fractions of the texture: F1 0.172 to 0.828, F2 0.234 to 0.766, F3 0.203 to 0.797.
frames_on_map.png: proof sheet (real in-game map crop, farm 11 px / target 15 px, real and 2x, plus a strip at 64/14/10 px), generated by `python make_frames.py <scratch dir containing map_crop.png>`.

## FINAL frames (Simon's choice: F2 thick + bone inner line; farm at 12 px, target at 14 px)
Files: frame_target.png (brass), frame_farm.png (green). Made by Python PIL script `make_frames_final.py` (no AI model). Layers from the outside in: dark #14171C outline 3 px, band 10 px (brass #C9A24A / green #4FD36A), dark line 1 px, bone #E8E4D8 line 2 px, transparent window. The 1 px dark line keeps the bone line from merging with the band.
Window rect at 64 px: (16,16)-(48,48), inset 16 px on every side, size 32x32. As fractions of the texture: left/top 0.25, right/bottom 0.75 (so the icon is half the width and height). At 12 px the window is 6 px, at 14 px 7 px.
frames_final_on_map.png: proof sheet (real map crop, farm 13 px / target 15 px, real and 2x, a 36-farm-pin density test where the extra pins are jittered copies so they overlap, and a strip at 64/14/12 px), made by the same script.
