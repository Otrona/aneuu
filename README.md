# 다시 (Aneuu)

구형 랩탑용(ram 2g+) 한글 콘솔 리눅스 (a Korean console Linux that brings old laptops back to life).

다시 is based on Alpine Linux 3.24 and runs from a USB stick in RAM, or from a disk.
It's made for Korean beginners.

- **Korean everywhere:** the screen shows Korean without X (a kernel with the cjktty
  patch), and ddakong handles Korean typing.
- **desk:** a tmux desktop with function keys, side panels and a Korean manual (F11).
- **Programs:**
  - writing: WordGrinder (`wg`), saving .odt files too
  - books and documents: `hb` (epub, pdf, hwp, docx and more)
  - dictionary: `dic`
  - AI chat: `gem`
  - Bible readings: `bib`, `bibr`, `bibt`
  - YouTube: `yt`; podcasts: `pod`; news feeds
  - the laptop as a phone's Bluetooth keyboard: `hkb`
- **Light:** 2 GB of RAM is enough. Heavier programs stay in the ISO and are added
  with `had NAME`.

다시 is not an official Alpine Linux project.

## Files

| | |
|---|---|
| `mkiso` | the build script. Everything is in it: the tools, docs and manual |
| `README.txt` | how to build the ISO and test it (Docker, QEMU) |
| `SOURCE.md` | what is where in `src/` and `patches/`, and how to change things |
| `CHANGES.md` | what changed |
| `avm`, `dk` | test in QEMU, and run Docker with its data on another disk |
| `src/` | the sources `mkiso` is made from: tools, docs, manual (`src/book/dasi.md`) |
| `patches/` | patches to the kernel (cjktty), ddakong, NetSurf and fbida |

## Build

```
sudo sh mkiso                    # full: our kernel, about 2 hours
sudo HAN_KERNEL=no sh mkiso      # quick: Alpine's kernel, Korean only in fbterm
```

README.txt has the details.

## License

Aneuu's own files (mkiso, src/, avm, dk, the docs and the manual) are under the GNU
General Public License, version 3: see LICENSE. The patches in `patches/` keep the
licenses of the projects they change: the Linux kernel and cjktty (GPL-2.0), ddakong
(GPL-3.0), NetSurf (GPL-2.0) and fbida (GPL-2.0). The fonts and the programs that the
build downloads keep their own licenses.
