# Reviewing shared loot (form shares)

Players paste their `/if share` text into a Google Form. Nothing counts until **you** approve it.
Think of it as an inbox: rows arrive unchecked, you check them, only checked rows go into the data.

## Setup (done 25 Nov 2026)

- Form "Share Lootwright loot data" (file "Lootwright loot shares" in your Google Drive): one required paragraph question, no email collection, no sign-in.
- Player link (in `Loot.lua` `SHARE_URL`): https://docs.google.com/forms/d/e/1FAIpQLSdIGto84x7yXrYVuymZ4tesnzN8PcrUmV0tHfGXat3XFk770A/viewform
- Answers go to the sheet "Untitled form (Responses)" (Drive, private). Columns: Timestamp, Paste your share text, **OK** (yours).

## Each time you want new shares in (about once per release)

1. Open the sheet. For each new row (empty OK cell), look at the share text:
   - It starts with `!LW:1!` and ends with `!End:LW!`.
   - It's not huge for one player (hundreds of mob kinds with thousands of corpses each is suspicious).
   - The same share ID repeated is fine: the latest approved one wins.
2. Looks fine? Type **x** in the OK column of that row. Looks fake or odd? Leave it empty (or write "no").
3. File > Download > **CSV**. Save it as `tools/data/form_shares.csv` (replace the old one).
4. Run `python -I tools/merge_loot.py`. It prints:
   - the approved totals (corpses, mob kinds with 20+ corpses),
   - **"N form rows wait for your review"** with, per row: share ID, build, mob kinds, corpses, and whether it updates an approved share. Anything listed there is NOT counted yet.
5. `python -I tools/release.py` does steps 4 and the rest of the build.

## Rules the data still has to pass (nothing to do by hand)

- A mob needs 20+ corpses from 2+ different contributors, and none over 75% of the corpses.
- An account (here: share ID) whose 95% range for some item doesn't overlap the others' gets dropped.

## Weak spot to know about

A form has no accounts, so one person could submit under many share IDs and look like several players.
The check above is you: don't approve several near-identical shares that arrive together.
Shares from GitHub issues still use the stricter `loot-ok` label process and work next to this one.
