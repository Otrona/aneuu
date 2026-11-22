# 바뀐 것 (Changes)

## 0, 2026-11-22: tested in the VM, before real laptops

ISO: `aneuu-0-x86_64.iso` from the 2026-11-22 full build. All VM checks pass (see below).

### 빨라진 부팅 (Faster boot)
- The initramfs went from 171 MB to 21 MB. The profile's `kms` feature put every
  graphics driver and all their firmware into it (128 + 137 MB unpacked), and the boot
  loader reads all of it before the kernel starts. The drivers now load from the
  modloop a few seconds later, like every other driver. The build prints
  `>> initramfs: N MB` and warns over 40 MB.
- The login prompt appears 8 s after the kernel starts.

### 메모리 (Memory): 2 GB minimum
- The boot set (what lives in RAM) and the optional programs are separate.
  NetSurf, DOSBox, ScummVM, Mesa and the VA-API drivers stay in the ISO's repository.
  `had NAME` installs one of them without Wi-Fi, and `hadr NAME` removes it again.
  Mesa and LLVM are removed when the last program needing them goes.
- mpv is built for the console (drm, ALSA, VA-API; no EGL/GL/X11), so the boot set
  has no LLVM or Mesa (183 + 42 MB saved).
- The fonts are smaller in RAM: one Unifont OTF, and the BDF fonts packed as PCF.
  The Baekmuk fonts are gone because they lacked most syllables (뷁, 똠).
- The RAM disk may grow to 90% of the memory, and zram swap is on below 4 GB.
- On a 2 GB VM, / uses 612 MB of 1.7 GB.

### 한글 화면과 입력 (Korean screen and input)
- Kernel console font: DOSMyungjo for Hangul and Terminus for English, put into the
  cjktty table at build time (`tools/kfont`). fbterm's default is the same pair.
- New ddakong patches:
  - DDKDBL: 그러니까 is no longer typed as 그러닉가 (a final ㄲ/ㅆ before a vowel
    now moves whole).
  - DDKENG: SIGUSR1 switches to English and SIGUSR2 switches back.
  - DDKEINTR: no "epoll_wait: Interrupted system call" message when desk opens.
- English keys follow the focus. While a video plays (yt) or the podcast player is in
  front (pod), single keys like ㅍ ㄴ ㅂ work as v s q. Other panes keep Korean.

### 새 기능 (New)
- `hkb`: the laptop as a Bluetooth keyboard for a phone, for typing into Gemini or
  other apps there. Hold Right Ctrl (or the 한자 key) with:
  - Tab: keys to the laptop and back
  - V: type desk's copied text into the phone (Korean included)
  - U: type the copy page's address into the phone
  - Q: quit

  Typing is paced (`hkb -d MS` changes the speed), and Esc stops it. Line breaks are
  typed as Shift+Enter, because Enter would send a chat message. A small web page lets
  the phone send text back to the laptop.
- `noad`: ad blocking for every program, from a list of 76,104 blocked names (the
  StevenBlack hosts list) put into /etc/hosts at boot. `noad off` turns it off and
  `noad on` turns it back on.
- yt-dlp keeps Deno as its JS runtime (QuickJS was 17 s per video).
  `/etc/yt-dlp/config` allows QuickJS for 32-bit.
- Short command names without hyphens: `hdos`, `hwifi`, `hbt`, `husb`, `hinst`,
  `hfb`, `had`. The old `han-...` names still work.
- `hdos` shows DOSBox's error instead of disappearing.

### 고친 것 (Fixed)
- ^M on the plain console after leaving desk.
- `doc` topic numbers.
- `wg NAME` now opens NAME.wg and saves NAME.odt next to it.

### 확인 (Checked in the VM, 2026-11-22)
- Kernel `6.18.64-900-lts`, `rootflags=size=90%`, zram swap, initramfs 21 MB.
- No LLVM or Mesa in the boot set; yt-dlp uses Deno 2.7.4.
- noad blocks 76,104 names.
- The hkb packages are in the boot set, and both tmux focus hooks work.
- ddakong survives USR1/USR2.
- All commands and the old names are present.
- The PCF fonts and unifont are there, with no Baekmuk left.
- `had dosbox` followed by `hadr dosbox` installs and removes DOSBox with Mesa.

### 아직 (Not yet)
- Real laptops:
  - `hinst` to a disk
  - DOSBox, ScummVM, NetSurf and `had hwdec`
  - battery, lid and built-in Wi-Fi
  - noad's speed on old hardware
- hkb's copy page over Wi-Fi, the 한자 key, and an iPhone.
