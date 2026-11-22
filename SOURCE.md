# Aneuu (다시): the files

Packed 2026-11-22 12:20. Everything needed to rebuild and change Aneuu.

## Top level (what you use)
- `aneuu.md`: the project file: state, rules, tests, plans (in the source pack; not in the repository, where CHANGES.md is the summary).
- `README.txt`: setting up the laptop (Docker, dk, building, avm words).
- `mkiso`: the build script. It holds every Aneuu tool, doc page and the manual text inside it.
- `avm`: test the ISO in QEMU (640x480, SDL, 4:3 also in full screen).
- `dk`: start/stop Docker with its data on the SSD.

To build, the build folder needs `mkiso`, `patches/cjktty-6.18.63.patch.xz` and
`patches/netsurf-fb-hangul.patch` next to each other (copy the two patches next to mkiso).

## patches/
- `cjktty-6.18.63.patch.xz`: Korean on the kernel console (picked up by mkiso, needed).
- `netsurf-fb-hangul.patch`: Korean in NetSurf (picked up by mkiso, needed).
- Already inside mkiso, kept here as separate files for reading and for upstream:
  - `ddakong-ime.patch` (DDKIME): ddakong reports 한/EN to the status bar (imestate).
  - `ddakong-dblcons.patch` (DDKDBL): final ㄲ/ㅆ before a vowel moves whole (그러니까, not 그러닉가).
  - `ddakong-english.patch` (DDKENG): SIGUSR1/SIGUSR2 switch ddakong to English and back (hfb, videos).
  - `ddakong-eintr.patch` (DDKEINTR): a signal interrupting epoll_wait is not an error (no "epoll_wait: Interrupted system call" when desk opens).
  - `fbida-b-key.patch` (FBIDAB): b = previous page in hv/fbgs.
  - `netsurf-fb-quit.patch` (NSQUIT): Ctrl+Q quits NetSurf.

## src/ (where changes are made)
`src/build-hangul-iso.sh` is the same file as `mkiso`. Some parts of it are generated:
- `docs.py`: the doc topics (doc ko/en).
- `cheats.py`: the F12 key panels.
- `tools/han-book` (hb), `tools/aneuu.txt` (the manual as text for F11/hb).
- `tools/` also: bib, bibr (bibt = bibr), dic, wn2dict, gem, gempane, web2wg, pod: reference copies.
  embed.py does NOT copy these: a change goes into tools/X AND its heredoc in build-hangul-iso.sh
  (kept identical; checked 2026-11-21).
- `tools/kfont`: the kernel console font (DOSMyungjo Hangul + Terminus English) written into the
  cjktty patch's font table before the kernel is compiled (DOSMyungjo + Terminus).
- `tools/hkb`: the phone keyboard (Bluetooth HID, copy page).
- `tools/embed.py`: puts docs, cheats, han-book, the manual text, gem, kfont and hkb back into
  build-hangul-iso.sh.
- `tools/totxt.py`: dasi.epub -> plain text for tools/aneuu.txt.
- `book/`: the manual: dasi.md (source), book.css, cover.png, dasi.epub.
- `kfont/kfont.py`: the first prototype of the kernel font (kept for reference; tools/kfont is
  the one the build uses).

Rebuild after a change (run in src/, needs python3 and pandoc):
```
cd book && pandoc dasi.md -o dasi.epub --css book.css --epub-cover-image cover.png --toc --split-level=1 && cd ..
python3 tools/totxt.py book/dasi.epub | cat -s > tools/aneuu.txt
python3 tools/embed.py
cp build-hangul-iso.sh ../mkiso
```
Checked when packing: these steps give back exactly this mkiso and this manual text.
pandoc prints warnings about ko-KR translations: harmless.
