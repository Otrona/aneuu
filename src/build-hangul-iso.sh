#!/bin/sh
# Build an Alpine live ISO with Korean console input built in:
#   fbterm (framebuffer terminal) + ddakong (Hangul input)
#   Fonts, by size: 12 px (Galmuri Mono 9, Mulmaru Mono), 16 px (six
#   DOS-style fonts incl. DOSMyungjo (default; English in Terminus; the
#   same pair is the Korean kernel's console font), Galmuri Mono 11, Neo
#   Dunggeunmo Code, GNU Unifont), 24 px (Miraero; Mulmaru Mono x2),
#   32 px (Neo Dunggeunmo Code x2).
#   All under MIT or SIL OFL 1.1. "han" opens WordGrinder directly.
#   Right Alt / Hangul key toggles Korean. WordGrinder and a set of
#   console programs (file manager, browser, mail, ...) are included.
#
# Korean on the plain text console (no fbterm): put the cjktty kernel patch
# for Alpine's linux-lts next to this script, e.g. cjktty-6.18.63.patch.xz.
# The build then compiles linux-lts with it (long: about an hour) and "han"
# runs on the normal console. Without the patch, han uses fbterm.
#
# Korean in the NetSurf framebuffer browser: put netsurf-fb-hangul.patch
# next to this script. NetSurf is then rebuilt with Korean fonts (Nanum)
# and a built-in Hangul input method (Right Alt, 2-beolsik).
#
# Run on Xubuntu (needs docker or podman):
#     sudo apt install docker.io
# ALPINE_MIRROR=https://.../alpine  sh mkiso   uses another Alpine mirror
#     sudo sh mkiso
#     sudo HAN_KERNEL=no sh mkiso     # skip the kernel build
#     sudo HAN_ARCH="x86_64 x86" sh mkiso   # 64- and 32-bit
# Result: ./aneuu-out/aneuu-0-x86_64.iso (and aneuu-0-x86.iso)
set -eu

# The cjktty patch must match this release's linux-lts (3.24: 6.18.63).
# Aneuu (다시) release number, in the ISO name and /etc/aneuu-release
ANEUU_VERSION=0
ALPINE_IMAGE="${ALPINE_IMAGE:-alpine:3.24}"
HAN_KERNEL="${HAN_KERNEL:-auto}"
# Flavors to build: x86_64 (64-bit), x86 (32-bit), or both: "x86_64 x86".
HAN_ARCH="${HAN_ARCH:-x86_64}"

DDAKONG_TAG=v1.3
GALMURI_TAG=v2.40.4
NEODGM_NPM=0.5.0          # @kfonts/neodgm-code on npm: Neo Dunggeunmo Code TTF
NEODGM_TAG=v1.601         # for its licence file
MULMARU_TAG=v1.0
# Byte the toggle key sends. 0x1e = Ctrl+^ ; the keymap below maps
# Right Alt and the Hangul key to it. Keep the two in step.
TOGGLE_BYTE=0x1e
TOGGLE_KEYSYM=Control_asciicircum

# Console programs that stand in for desktop apps: installed at every boot
# (the live system keeps all of them in RAM). Edit freely: a name that
# Alpine does not have is skipped with a warning instead of failing the build.
# The choice follows K.Mandla's console desktop (kmandla.wordpress.com,
# "On the menu") and his Inconsolation blog. mpv is our own build without
# Mesa (build_mpv_drm): Alpine's pulls in Mesa + LLVM, about 225 MB of RAM.
# yt-dlp brings Deno (110 MB of RAM) for YouTube's JavaScript check: fast,
# and 2 GB, Aneuu's minimum, has room. (QuickJS: 1 MB but about 17 s per video.)
EXTRA_APPS="
	nnn lsblk tree file less
	w3m chawan curl rsync lftp aria2
	aerc abook irssi newsboat rtorrent
	nano vim tmux dialog ripgrep fd
	sc-im bc calcurse sdcv
	cmus mpg123 alsa-utils alsa-utils-openrc mpv
	fbida-fbi fbida-fbgs fbgrab epy python3
	yt-dlp translate-shell
	poppler-utils odt2txt antiword unrtf
	unzip zip 7zip
	btop ncdu iftop usbutils pciutils acpi brightnessctl
	iwd dbus openresolv tzdata chrony
	acpid zzz kbd-vlock openssh-client-default
	bluez bluez-openrc bluez-alsa bluez-alsa-openrc bluez-alsa-utils
	py3-evdev py3-dbus-next
	dosfstools exfatprogs ntfs-3g
	nethack cmatrix
"
EXTRA_OK="${EXTRA_OK:-}"

# Optional programs: in the ISO's own package repository (installed later
# without Wi-Fi, by "had"), not installed at boot, so they take no RAM until
# wanted. mesa-*: NetSurf, DOSBox and ScummVM draw through SDL, whose console
# backend (KMSDRM) needs Mesa's EGL, GBM and a graphics driver (Mesa pulls in
# LLVM). mesa-va-gallium, libva-intel-driver, intel-media-driver: hardware
# video decoding (mpv --hwdec=vaapi-copy). X with Firefox stays online (had firefox).
OPTIONAL_APPS="
	netsurf-framebuffer dosbox-staging scummvm
	mesa-egl mesa-gbm mesa-gl mesa-gles mesa-dri-gallium
	mesa-va-gallium libva-intel-driver intel-media-driver
"
OPT_OK="${OPT_OK:-}"
# Always installed at boot, besides EXTRA_APPS
BOOT_BASE="alpine-base fontconfig font-terminus freetype kbd libstdc++ mandoc
	ncurses-terminfo-base wordgrinder"

STAGE=/home/build/stage

# ---------------------------------------------------------------------------
# Files that end up on the live system
# ---------------------------------------------------------------------------
stage_files() {
	mkdir -p "$STAGE/usr/local/bin" "$STAGE/etc/local.d" "$STAGE/etc/fonts" \
		"$STAGE/etc/apk/protected_paths.d"

	# Right Alt (100) and the Korean Hangul key (122) send the toggle byte.
	cat > "$STAGE/etc/hangul-key.map" <<EOF
keycode 100 = $TOGGLE_KEYSYM
keycode 122 = $TOGGLE_KEYSYM
EOF

	cat > "$STAGE/etc/local.d/hangul-key.start" <<'EOF'
#!/bin/sh
loadkeys -q /etc/hangul-key.map
EOF
	chmod 755 "$STAGE/etc/local.d/hangul-key.start"

	# Let fontconfig offer bitmap fonts.
	cat > "$STAGE/etc/fonts/local.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <selectfont>
    <acceptfont>
      <pattern><patelt name="scalable"><bool>false</bool></patelt></pattern>
    </acceptfont>
  </selectfont>
  <!-- The TTF pixel fonts: no smoothing, so they stay sharp at 1x and 2x -->
  <match target="font">
    <test name="family" compare="contains"><string>Dunggeunmo</string></test>
    <edit name="antialias" mode="assign"><bool>false</bool></edit>
    <edit name="hinting" mode="assign"><bool>false</bool></edit>
  </match>
  <match target="font">
    <test name="family" compare="contains"><string>Mulmaru</string></test>
    <edit name="antialias" mode="assign"><bool>false</bool></edit>
    <edit name="hinting" mode="assign"><bool>false</bool></edit>
  </match>
</fontconfig>
EOF

	cat > "$STAGE/usr/local/bin/han" <<'EOF'
#!/bin/sh
# Hangul console: fbterm + ddakong. Right Alt / Hangul key toggles Korean.
#   han [FONT] [FILE]     open WordGrinder (optionally a document)
#   han -s [FONT]         open a shell instead
#   han -t [FONT]         the console desktop (same as: desk)
#   han -d [FONT...]      show a sample of each font, one screen per font
#   han -l                list fonts
#   han -f ...            use fbterm even on the Korean kernel console
#   man han               full manual
# HAN_FONT / HAN_SIZE override the font family and pixel size.
# Font table, written at build time, ordered by size:  name|px|family|label
TABLE=/usr/share/han/fonts
[ -s "$TABLE" ] || { echo "han: $TABLE missing" >&2; exit 1; }
FONTS="$(cut -d'|' -f1 "$TABLE" | tr '\n' ' ')"

pick_font() {
	line="$(grep "^$1|" "$TABLE")" ||
		{ echo "han: unknown font '$1' (han -l lists them)" >&2; exit 1; }
	size="$(echo "$line" | cut -d'|' -f2)"
	fam="$(echo "$line" | cut -d'|' -f3)"
}

list_fonts() {
	awk -F'|' '$2 != last { printf "%s%3s px  ", (NR > 1 ? "\n" : ""), $2; last = $2 }
		{ printf "%-10s", $1 } END { print "" }' "$TABLE"
	echo "Default: myungjo (English letters: ${LATIN:-the same font}). Samples: han -l -v, han -d"
}

# kernel = the console itself shows Hangul (cjktty kernel), fbterm otherwise.
HAN_CONSOLE=fbterm
[ -r /etc/han.conf ] && . /etc/han.conf
# Only our own kernel (release N-900-lts) shows Hangul. If an update put
# Alpine's kernel in its place, use fbterm instead.
case "$(uname -r)" in *-900-*) ;; *) HAN_CONSOLE=fbterm ;; esac
use_fbterm=no
[ "$HAN_CONSOLE" = kernel ] || use_fbterm=yes

# English letters from an English font (Terminus), Hangul from the Korean
# font: fbterm takes each glyph from the first font that has it.
# LATIN="" in /etc/han.conf (or HAN_LATIN=) uses the Korean font for both.
LATIN="${HAN_LATIN-${LATIN-Terminus}}"
[ -n "$LATIN" ] && ! fc-list 2>/dev/null | grep -qi ": *$LATIN[,:]" && LATIN=""

mode=wg
case "${1:-}" in
	-f) use_fbterm=yes; shift ;;
esac
case "${1:-}" in
	-l) if [ "${2:-}" = -v ]; then
		awk -F'|' '$2 != last { printf "\n%s px\n", $2; last = $2 }
			{ printf "  %-10s %s\n", $1, $4 }' "$TABLE"
	    else list_fonts; fi; exit 0 ;;
	-h|--help) sed -n '2,8p' "$0"; exit 0 ;;
	-s) mode=sh; shift ;;
	-t) mode=desk; shift ;;
	-d) mode=demo; shift ;;
esac

export LANG="${LANG:-C.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-C.UTF-8}"
# Naming a font (or -d) means fbterm: the kernel console has one font.
case "$mode ${1:-}" in demo*) use_fbterm=yes ;; esac
case " $FONTS " in *" ${1:-} "*) [ -n "${1:-}" ] && use_fbterm=yes ;; esac

# Already inside han (fbterm + ddakong running): just switch program.
# A second fbterm cannot start from here ("stdin isn't a interactive tty").
if [ -n "${HAN_ACTIVE:-}" ] && [ "$mode" != demo ]; then
	case " $FONTS " in *" ${1:-} "*)
		if [ -n "${1:-}" ]; then
			echo "글꼴은 han 을 새로 켤 때만 바뀝니다: exit 로 나간 뒤  han $1"
			echo "The font only changes when han starts: type exit, then  han $1"
			exit 1
		fi ;;
	esac
	export HAN_MODE="$mode" HAN_FILE="${1:-}" HAN_REAL_SHELL="${SHELL:-/bin/sh}"
	exec /usr/local/bin/han-child
fi

if [ "$use_fbterm" = no ]; then
	[ "$(id -u)" = 0 ] && loadkeys -q /etc/hangul-key.map 2>/dev/null
	export HAN_MODE="$mode" HAN_FILE="${1:-}" HAN_REAL_SHELL="${SHELL:-/bin/sh}"
	export HAN_ACTIVE=1
	old="$(stty -g 2>/dev/null)"
	SHELL=/usr/local/bin/han-child /usr/local/lib/han/ddk -q
	rc=$?
	# back on the plain console: its normal settings, whatever happened
	if [ -n "$old" ]; then stty "$old" 2>/dev/null; else stty sane 2>/dev/null; fi
	exit $rc
fi

if [ ! -e /dev/fb0 ]; then
	echo "han: /dev/fb0 not found - no framebuffer, fbterm cannot start" >&2
	exit 1
fi

if [ "$mode" = demo ]; then
	[ $# -gt 0 ] || set -- $FONTS
	stop="/tmp/han-demo-stop.$$"
	rm -f "$stop"
	for f in "$@"; do
		pick_font "$f"
		HAN_MODE=demo HAN_DEMO_NAME="$f" HAN_DEMO_FAM="$fam" HAN_DEMO_SIZE="$size" \
		HAN_DEMO_STOP="$stop" \
			fbterm -n "${LATIN:+$LATIN,}$fam,Unifont" -s "$size" -- /usr/local/bin/han-child
		[ -e "$stop" ] && break
	done
	rm -f "$stop"
	exit 0
fi

# DOSMyungjo for Hangul, Terminus for English letters, both 16 px:
# the same pair as the Korean kernel's own console font.
# The bigger fonts are a choice: han miraero, han neodgm32 ...
font=myungjo
grep -q '^myungjo|' "$TABLE" || font="$(head -n1 "$TABLE" | cut -d'|' -f1)"
case " $FONTS " in *" ${1:-} "*) [ -n "${1:-}" ] && { font="$1"; shift; } ;; esac
pick_font "$font"
fam="${HAN_FONT:-$fam}"
size="${HAN_SIZE:-$size}"

[ "$(id -u)" = 0 ] && loadkeys -q /etc/hangul-key.map 2>/dev/null

# ddakong starts $SHELL with no arguments, so hand it a small launcher.
export HAN_MODE="$mode" HAN_FILE="${1:-}" HAN_REAL_SHELL="${SHELL:-/bin/sh}"
export HAN_ACTIVE=1
old="$(stty -g 2>/dev/null)"
SHELL=/usr/local/bin/han-child \
	fbterm -n "${LATIN:+$LATIN,}$fam,Unifont" -s "$size" -- /usr/local/lib/han/ddk -q
rc=$?
if [ -n "$old" ]; then stty "$old" 2>/dev/null; else stty sane 2>/dev/null; fi
exit $rc
EOF
	cat > "$STAGE/usr/local/bin/han-child" <<'EOF'
#!/bin/sh
# Runs inside fbterm; see han.
if [ "${HAN_MODE:-wg}" = demo ]; then
	cat <<DEMO

  Font: $HAN_DEMO_NAME   ($HAN_DEMO_FAM, $HAN_DEMO_SIZE px)
  Start WordGrinder with it:  han $HAN_DEMO_NAME

  다람쥐 헌 쳇바퀴에 타고파.
  가나다라마바사아자차카타파하  ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎ  ㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣ
  한글 입력 시험: 값 읽다 닭 삶 앉다 많다 뷁 똠

  The quick brown fox jumps over the lazy dog.
  ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz
  0123456789  . , ; : ! ? ( ) [ ] { } < > + - * / = _ @ # % &

DEMO
	printf '  Enter = next font, q + Enter = stop: '
	read -r ans
	case "$ans" in q*|Q*) : > "$HAN_DEMO_STOP" ;; esac
	exit 0
fi
export SHELL="${HAN_REAL_SHELL:-/bin/sh}"
# fbterm sets TERM=fbterm; without its terminfo entry every full-screen
# program fails ("unknown terminal type"). fbterm also speaks "linux".
t1="$(printf %.1s "${TERM:-linux}")"
[ -e "/usr/share/terminfo/$t1/$TERM" ] || [ -e "/etc/terminfo/$t1/$TERM" ] ||
	export TERM=linux
[ "${HAN_MODE:-wg}" = sh ] && exec "$SHELL"
if [ "${HAN_MODE:-wg}" = desk ] && [ -n "${TMUX:-}" ]; then
	echo "Already in the desktop: F1 menu, F4 new shell."
	exit 0
fi
if [ "${HAN_MODE:-wg}" = desk ]; then
	# Offline with a Wi-Fi card: start on the list of networks.
	if ! tmux has-session -t desk 2>/dev/null &&
	   ! ip -4 route get 1.1.1.1 >/dev/null 2>&1 &&
	   iw dev 2>/dev/null | grep -q Interface; then
		exec tmux -f /etc/han/tmux.conf new-session -s desk -n wifi \
			"hwifi; exec $SHELL"
	fi
	exec tmux -f /etc/han/tmux.conf new-session -A -s desk
fi
if [ -n "${HAN_FILE:-}" ]; then exec wordgrinder "$HAN_FILE"; fi
exec wordgrinder
EOF
	chmod 755 "$STAGE/usr/local/bin/han-child"
	chmod 755 "$STAGE/usr/local/bin/han"

	stage_desktop_files

	# Korean welcome text only on our Korean kernel console; the plain
	# console (fbterm setup) shows boxes for it, so English there.
	cat > "$STAGE/etc/motd.en" <<'EOF'

 Aneuu 0 - console desktop with Korean input

  desk       desktop        (F1 menu, F12 keys for the program on screen)
  doc        guide          (Korean and English)
  hwifi   Wi-Fi          (F5 in desk)
  han        writing
  passwd     set a password
  hinst   install to the hard disk
  poweroff   power off

 Korean is shown and typed inside desk, han and doc.
 Started from USB, everything is lost at power off:
 copy your files to a USB stick (husb), or install with hinst.

EOF
	cat > "$STAGE/etc/local.d/han-motd.start" <<'EOF'
#!/bin/sh
. /etc/han.conf 2>/dev/null
case "$(uname -r)" in *-900-*) k=yes ;; *) k=no ;; esac
if [ "$k" = yes ] && [ "${HAN_CONSOLE:-}" = kernel ]; then
	cp /etc/motd.ko /etc/motd
else
	cp /etc/motd.en /etc/motd
fi
EOF
	chmod 755 "$STAGE/etc/local.d/han-motd.start"
	# Sound cards start muted at 0%. Until the user has set the volume
	# once (and it was saved), turn it on at a comfortable level.
	cat > "$STAGE/etc/local.d/han-sound.start" <<'EOF'
#!/bin/sh
[ -s /var/lib/alsa/asound.state ] && exit 0
for c in $(awk '$1 ~ /^[0-9]+$/ { print $1 }' /proc/asound/cards 2>/dev/null); do
	amixer -c "$c" scontrols 2>/dev/null | sed -n "s/^Simple mixer control '\([^']*\)',.*/\1/p" |
	while IFS= read -r m; do
		case "$m" in
			Master|Speaker|Headphone|PCM|Front|"Bass Speaker"|"Line Out")
				amixer -q -c "$c" sset "$m" 75% unmute 2>/dev/null ||
				amixer -q -c "$c" sset "$m" 75% 2>/dev/null ;;
		esac
	done
done
exit 0
EOF
	chmod 755 "$STAGE/etc/local.d/han-sound.start"
	cat > "$STAGE/etc/motd.ko" <<'EOF'

 Aneuu 다시 0 - console desktop with Korean input

  desk       desktop       데스크톱   (F1 menu 메뉴, F12 keys 키 도움말)
  doc        guide         안내서
  hwifi   Wi-Fi         무선랜     (F5 in desk)
  han        writing       문서 작성
  passwd     set password  비밀번호 정하기
  hinst   install       하드디스크에 설치
  poweroff   power off     끄기

 Started from USB, everything is lost at power off.
 USB 로 켜면 끌 때 모두 사라집니다. 파일은 USB 에 복사하거나 hinst.

EOF
	cp "$STAGE/etc/motd.en" "$STAGE/etc/motd"

	mkdir -p "$STAGE/usr/share/man/man1"
	cat > "$STAGE/usr/share/man/man1/han.1" <<'EOF'
.TH HAN 1 "November 2026" "hangul console" "User Commands"
.SH NAME
han \- WordGrinder with Korean input on the text console
.SH SYNOPSIS
.B han
.RI [ FONT ]
.RI [ FILE ]
.br
.B han \-s
.RI [ FONT ]
.br
.B han \-d
.RI [ FONT ...]
.br
.B han \-l
.SH DESCRIPTION
.B han
starts the ddakong Hangul input method and opens WordGrinder in it.
If the kernel was built with the cjktty patch, the console itself shows
Hangul and nothing else is needed. Its built-in font is the same pair
han uses by default: DOSMyungjo for Hangul and Terminus for English
letters, 16 pixels high (other fonts need fbterm:
.BR "han \-f" ). Otherwise, and whenever a
.I FONT
is named,
.B han
runs inside the framebuffer terminal fbterm.
Quitting WordGrinder returns to the plain console.
.PP
Run it from a text console (tty1 to tty6), not over SSH.
.SH OPTIONS
.TP
.I FONT
Short name of the font to use; see FONTS. Default: myungjo (16 px).
.TP
.I FILE
Document to open in WordGrinder.
.TP
.B \-f
Use fbterm even when the console can show Hangul by itself.
.TP
.B \-s
Open a shell instead of WordGrinder.
.TP
.B \-d
Font showcase: show a screen of sample text in each font in turn
(or only in the fonts named). Enter moves to the next font;
q and Enter stops.
.TP
.B \-l
List the font names, grouped by size.
.B han \-l \-v
adds a description of each.
.TP
.B \-h
Show a short usage summary.
.SH GUIDE
.B doc
shows a guide to the console desktop and each program, in Korean or
English (chosen at the first run;
.B doc ko
or
.B doc en
switches).
.B doc wifi
opens one topic directly. Korean pages need the Korean console, so
read them inside
.BR desk .
.SH THE CONSOLE DESKTOP
.B desk
(the same as
.BR "han \-t" )
starts a tmux session with Korean input, a status line (battery,
network, free memory, date and time) and a program menu.
.TP
.B F1
The program menu (also Ctrl+b, then m): word processor, files, web,
mail, feeds, calendar, spreadsheet, music, chat and more.
.TP
.B F2, F3
Previous and next window.
.TP
.B F4
A new shell window.
.TP
.B F5
The Wi-Fi networks in range.
.TP
.B F12
A summary of keys for the program in the current window opens in a
panel on the right, a third of the screen wide, in the guide's language;
F12 again (or q) closes it. In a shell it shows the main commands.
.TP
.B F6, F7
Copy text from the screen (arrows, Space to start, Enter to copy), paste it.
.TP
.B F8
Bluetooth devices.
.TP
.B F11, F10, F9
A book in a pane on the right (the manual, or one set with
.BR "hb FILE" ),
its next and previous page.
.TP
.B Alt+G
The AI chat (gem) in a pane on the right; Alt+G again closes it.
.TP
.B Alt+O
Over to the other pane (your work, the AI chat or the book).
.TP
.B Alt+D
The English dictionary (WordNet): type the start of a word on the
screen, Tab for the next match, Enter for its meaning.
.TP
.B Alt+N
The news feeds (newsboat) in a panel on the right; Alt+N again hides it.
.TP
.B Alt+P
Show or hide the podcast player (pod).
.TP
.B Alt+V
Back to the video playing on its own screen (Tab there returns).
.TP
.B Alt+W
In w3m: the page's text, without menus and ads, as a new WordGrinder
document.
.PP
Each program opens in its own window; the status line lists them.
.SH NETWORK
A network cable works by itself. For Wi-Fi,
.B hwifi
(F5 on the desktop) searches for networks and lists them with signal
strength and whether they need a password; type a number to connect.
When the desktop starts without a connection it opens this list by
itself. Networks used before are joined again automatically.
.PP
On a system running from memory the saved networks are lost at
power-off unless you save the configuration (lbu commit) or install
to disk.
.SH PROGRAMS THAT DRAW ON THE SCREEN
NetSurf (a browser with pictures, little JavaScript), the picture
viewer fbi, the video player mpv and ScummVM draw on the screen
themselves, so they need the whole screen. Typed by their usual names
they open on a free console by themselves and return to the desktop
when they end (under X they run as usual):
.PP
.nf
    netsurf https://example.org
    fbi photo.jpg
    mpv film.mp4
.fi
.PP
.B hfb
.I PROGRAM
does the same for any other such program.
.PP
NetSurf and ScummVM are installed once with
.B had
(see ADDING MORE). Ads and trackers are blocked by name for every program:
.B noad
says whether it is on;
.B noad off
and
.B noad on
(as root) turn it off for a site that breaks, and on again. The list,
StevenBlack/hosts (MIT), goes into
.I /etc/hosts
at boot. NetSurf on this system is built with Korean fonts and its own Hangul
input: Right Alt (or Shift+Space) switches Korean/English, in the
address bar and in pages, and the status bar shows the state. If the
build could not apply that change, the stock NetSurf is used and shows
no Korean. fbi and mpv take no text.
.SH DOS GAMES
.B hdos
runs DOSBox Staging full screen on the console (install it once with
.BR "had dosbox" ).
If DOSBox stops with an error, hdos shows why; "EGL" means there is
no driver for the graphics chip (a virtual machine's plain VGA has none). Put games in
.I ~/dos
(it becomes drive C:), or give a folder or a program:
.PP
.nf
    hdos                 DOS prompt, ~/dos is C:
    hdos /mnt/games      that folder is C:
    hdos ~/dos/game/GAME.EXE
.fi
.PP
Ctrl+F10 frees the mouse, Ctrl+F9 quits. Settings:
.IR /etc/han/dosbox.conf .
On 32-bit x86 this DOSBox is built with the portable dynrec CPU core.
.SH PHONE KEYBOARD
.B hkb
(as root) makes this laptop a Bluetooth keyboard for a phone, to type
into the phone's AI chat and the like. Pick "Aneuu keyboard" in the
phone's Bluetooth list once; then every key goes to the phone.
Its command key is Right Ctrl (on Korean laptops often the Hanja key;
both work), held with another key; it is never sent to the phone, and
Left Ctrl stays the phone's Ctrl.
.B Right Ctrl+Tab
gives the keys back to desk without disconnecting (and again to the
phone);
.B Right Ctrl+Q
quits. (Ctrl+Alt is avoided: in a VM, Xfce and QEMU on the host take it.)
The phone makes the Korean: set its physical keyboard to Korean
2-beolsik; Right Alt sends Shift+Space (Android's switch), on an iPhone
use Caps Lock. While it runs, bluetoothd runs without its input plugin,
so Bluetooth headphones drop; the normal service comes back afterwards.
.B Right Ctrl+V
types the text copied in desk (F6) into the phone, Korean included (hkb
switches the phone between Korean and English as needed). It types
slowly so the phone keeps up: 20 ms key down and 20 ms up, longer around a
Korean/English switch; a progress line shows in desk, Esc stops.
.B hkb -d MS
sets the milliseconds (5 to 200); if the phone drops letters, try
.BR "hkb -d 40" .
A line break is typed as Shift+Enter, because Enter sends the message in a
chat app; line breaks at the end are left out.
From the phone: on the same Wi-Fi, hkb shows an address with a random
part (Right Ctrl+U types it into the phone); open it in the phone's
browser, paste, send, then Right Ctrl+Tab and F7 pastes it in desk. The page also
shows the laptop's copied text, and is gone when hkb ends.
.SH ADDING MORE
Started from USB, the whole system lives in memory, so heavier programs
are not installed at boot.
.B had
lists them, with the memory they take, and
.B had
.I NAME
installs one (as root):
.TP
.B netsurf
NetSurf with Korean (see above).
.TP
.B dosbox
DOSBox Staging, for
.BR hdos .
.TP
.B scummvm
ScummVM, for classic adventure games (free ones are listed on
scummvm.org).
.TP
.B hwdec
Video decoding on the graphics chip (VA\-API: Intel, AMD); sets
.B hwdec=vaapi\-copy
in
.IR /etc/mpv/mpv.conf .
.TP
.B firefox
X on demand with Firefox and Korean input. It needs about 2 GB of
memory (4 GB to be comfortable) and refuses below that; under 4 GB it
turns on compressed swap. Then
.B hx firefox
runs Firefox full screen, and quitting it returns to the console.
.B hx
takes any graphical program.
.TP
.B hwp, ocr, yt, net
Hancom .hwp files, scanned PDFs as text, a newer yt\-dlp, and Alpine's
online packages.
.PP
netsurf, dosbox, scummvm and hwdec come from the USB stick itself, with
no network; the rest need the internet. netsurf, dosbox and scummvm draw
through SDL, which needs Mesa (about 230 MB, shared). On the live USB
anything added is gone after a reboot. A program that is not installed
says how to get it.
.B hadr
.I NAME
removes one again (with no name it lists what is installed); Mesa is
removed only when no other program still needs it.
.B han\-add
is the old name of
.BR had .
.SH KEYS
.TP
.B Right Alt, Hangul key
Switch between Korean and English.
.TP
.B Ctrl+^
Does the same. Press it twice to send a real Ctrl+^.
.PP
The layout is 2-beolsik (Dubeolsik).
.SH FONTS
All are monospaced, so Korean takes two columns and Latin one, and all
have the full set of 11,172 Hangul syllables. Grouped by size; larger
sizes suit high-resolution screens.
.SS 12 pixels
.TP
.B galmuri9
Galmuri Mono 9, modern pixel style (SIL OFL)
.TP
.B mulmaru
Mulmaru Mono, bold strokes with rounded edges (SIL OFL)
.SS 16 pixels
.TP
.B myungjo
DOSMyungjo, serif; the default, with Terminus for English letters (MIT)
.TP
.B gothic
DOSGothic, sans serif (MIT)
.TP
.B saemmul
DOSSaemmul (MIT)
.TP
.B iyagi
IyagiBoldU: DOSIyagiBoldface relabelled for Unicode, bold (MIT)
.TP
.B pilgi
DOSPilgi, handwriting style (MIT)
.TP
.B sam3
Sam3KRFont (MIT)
.TP
.B galmuri
Galmuri Mono 11, modern pixel style (SIL OFL)
.TP
.B neodgm
Neo Dunggeunmo Code, the classic DOS Dunggeunmo look (SIL OFL)
.TP
.B unifont
GNU Unifont, plain and complete
.SS 24 pixels
.TP
.B miraero
Miraero Normal (MIT)
.TP
.B mulmaru24
Mulmaru Mono at twice its size
.SS 32 pixels
.TP
.B neodgm32
Neo Dunggeunmo Code at twice its size
.PP
.B han \-l
shows which of these this system has.
.PP
This manual is drawn in whatever font the console is using, so it
cannot show what the fonts look like. To see them, run
.B han \-d
for a sample screen of every font, or for example
.B han \-d iyagi pilgi
for just those two.
.PP
The font applies to the whole screen. To change it, quit and start
.B han
again with another name.
.SH ENVIRONMENT
.TP
.B HAN_FONT
Font family name, overriding the short name.
.TP
.B HAN_SIZE
Font size in pixels.
.SH EXAMPLES
.TP
.B han
WordGrinder with the default font (DOSMyungjo with Terminus, 16 pixels).
.TP
.B han myungjo
WordGrinder with DOSMyungjo.
.TP
.B han gothic letter.wg
Open letter.wg with DOSGothic.
.TP
.B wg letter.wg
The same as han letter.wg; inside han or desk it opens WordGrinder right there.
.TP
.B han \-s
A shell with Korean input.
.TP
.B han \-d
Look through all the fonts.
.SH EXPORTING AND SAVING
WordGrinder saves its own .wg format; every save (Ctrl+S) also writes an
\&.odt of the same name next to it, for LibreOffice and other office
programs. A lone English "i" becomes "I" as you type.
.PP
.B wg ADDRESS
makes a web page's text into a new document (in ~/web);
.B bib
opens this coming Sunday's Revised Common Lectionary readings with the
Sunday's name (Vanderbilt's RCL calendar; texts from Bible Gateway; in
~/bible) to write notes between the lines;
.B bibt
today's readings of the one-year plan (1517.org) in hb (< > the day
before or after, a whole chapters);
.B bibr
any book of the Bible, where you stopped (< > chapters). Both: English
(Bible Gateway) or Korean (bskorea.or.kr) translations, c chooses, Alt+W
writes notes in WordGrinder. For other formats use File, Export in its menu
(press Esc for the menu), or convert from the command line:
.PP
.nf
    wordgrinder \-\-convert letter.wg letter.odt
    wordgrinder \-\-convert letter.wg letter.txt
.fi
.PP
The file type follows the ending: .odt, .txt, .html, .md, .rtf,
\&.tex or .tr. It can also import .odt, .html, .md and .txt.
.PP
This system runs from memory, so files are lost at power-off.
Save them to a second USB stick or a disk:
.PP
.nf
    lsblk                      find the stick, e.g. sdb1
    mount /dev/sdb1 /mnt
    cp letter.wg letter.odt /mnt/
    umount /mnt
.fi
.SH CONSOLE PROGRAMS
Stand-ins for desktop applications. Start
.B desk
and pick them from the menu, or start
.B han \-s
first so that Korean displays and can be typed, then run them.
The selection follows K.Mandla's console desktop.
.PP
.nf
    Files           nnn
    Web             w3m, chawan (cha)
    Mail            aerc, abook (addresses)
    Chat (IRC)      irssi
    News feeds      newsboat
    Text editors    nano, vim
    Search          rg (text in files), fd (file names)
    Spreadsheet     sc-im
    Calculator      bc
    Calendar        calcurse
    Dictionary      dic, sdcv (WordNet, English; Alt+D)
    AI chat         gem (Alt+G)
    News feeds      newsboat (Alt+N)
    Podcasts        pod (Alt+P)
    Music           cmus, mpg123, alsamixer
    Web, pictures   netsurf
    Pictures        fbi
    Video           mpv
    Screenshot      fbgrab
    PDF to text     pdftotext
    Old documents   odt2txt, antiword, unrtf
    Archives        unzip, zip, 7z
    Downloads       aria2c, rtorrent, curl, lftp, rsync
    Several screens tmux
    Wi-Fi           hwifi
    System          btop, ncdu, iftop, acpi, lsblk, lsusb
    DOS games       hdos (DOSBox Staging)
    Games           nethack, cmatrix
.fi
.SH FILES
.TP
.I /etc/hangul-key.map
Console keymap that makes Right Alt and the Hangul key the toggle.
.TP
.I /usr/share/fonts/hangul-bitmap
The Korean bitmap fonts.
.TP
.I /etc/han/tmux.conf, /etc/han/menu.tmux
The desktop's settings and its menu; edit the menu to taste.
.SH SEE ALSO
.BR wordgrinder (1),
.BR tmux (1)
EOF

	cat > "$STAGE/etc/issue" <<'EOF'
Aneuu 0 (Alpine Linux) \l
Log in as root.  Then: desk = desktop, doc = guide

EOF

	# Keep these when saving config with lbu or installing to disk.
	cat > "$STAGE/etc/apk/protected_paths.d/lbu.list" <<'EOF'
+usr/local
+usr/share/fonts/hangul-bitmap
+usr/share/fonts/nanum
+usr/share/man/man1/han.1
+usr/share/han
+etc/profile.d/han.sh
+etc/acpi/handler.sh
+usr/share/terminfo/f/fbterm
+etc/localtime
+root
+etc/han.conf
+etc/han
+etc/iwd
+var/lib/iwd
EOF
}

# ---------------------------------------------------------------------------
# The console desktop (tmux), optional add-ons (had) and X on demand (hx)
# ---------------------------------------------------------------------------
stage_desktop_files() {
	mkdir -p "$STAGE/etc/han" "$STAGE/usr/local/lib/han"

	cat > "$STAGE/usr/local/bin/doc" <<'EOF'
#!/bin/sh
# doc: guide to the console desktop, in Korean or English.
#   doc            list of topics       doc TOPIC   one topic (e.g. doc wifi)
#   doc ko         Korean               doc en      English   (remembered)
D=/usr/share/han/doc
C="${XDG_CONFIG_HOME:-$HOME/.config}/han"
case "${1:-}" in
	ko|en) mkdir -p "$C"; echo "$1" > "$C/lang"; shift ;;
esac
lang="$(cat "$C/lang" 2>/dev/null)"
if [ "$lang" != ko ] && [ "$lang" != en ]; then
	printf '\n  1) 한국어\n  2) English\n\n  > '
	read -r a
	case "$a" in 1|k*|K*) lang=ko ;; *) lang=en ;; esac
	mkdir -p "$C"; echo "$lang" > "$C/lang"
fi

# Korean shows only on the Korean console: inside desk or han, or with
# the cjktty kernel.
if [ "$lang" = ko ] && [ -z "${HAN_ACTIVE:-}" ] &&
   ! { grep -q '^HAN_CONSOLE=kernel' /etc/han.conf 2>/dev/null &&
       case "$(uname -r)" in *-900-*) true ;; *) false ;; esac; }; then
	echo "Korean text needs the Korean console: start  desk  (or han -s),"
	echo "then run doc again.   For English now:  doc en"
	exit 1
fi

# One screen at a time from the top; the bottom line says which keys.
page() {
	if [ "$lang" = ko ]; then
		p='Space 다음 쪽   b 앞 쪽   q 닫기?e   (끝).'
	else
		p='Space next page   b previous page   q close?e   (end).'
	fi
	less -c -Ps"$p" -Pm"$p" -PM"$p" "$D/$lang/$1.txt"
}

if [ $# -gt 0 ]; then
	if [ -f "$D/$lang/$1.txt" ]; then page "$1"; exit 0; fi
	echo "doc: no topic '$1'"
	ls "$D/$lang" | sed -n 's/\.txt$//p' | grep -v '^index$' | tr '\n' ' '; echo
	exit 1
fi

while :; do
	clear
	cat "$D/$lang/index.txt"
	printf '\n  > '
	read -r t || exit 0
	case "$t" in q|Q|"") exit 0 ;; ko|en) exec "$0" "$t" ;; esac
	# the list has two columns: "  1 cmds   ...   15 cal ..."; a number
	# leads to the topic name right after it
	n="$(awk -v t="$t" '{ for (i = 1; i < NF; i++) if ($i == t && $(i+1) ~ /^[a-z]+$/) { print $(i+1); exit } }' "$D/$lang/index.txt" 2>/dev/null)"
	[ -n "$n" ] || n="$t"
	[ -f "$D/$lang/$n.txt" ] && page "$n"
done
EOF
	chmod 755 "$STAGE/usr/local/bin/doc"

	mkdir -p "$STAGE/usr/share/han/doc/ko" "$STAGE/usr/share/han/doc/en"
	cat > "$STAGE/usr/share/han/doc/ko/index.txt" <<'HANDOC'
안내서 - 주제를 고르세요

  1 cmds   명령 요약                    16 sheet  스프레드시트 (sc-im)
  2 start  처음 시작하기                17 music  음악 (cmus)
  3 korean 한글 입력                    18 video  동영상과 사진
  4 desk   콘솔 데스크톱                19 chat   채팅 (irssi)
  5 wifi   무선랜                       20 down   내려받기 (aria2, rtorrent)
  6 bt     블루투스                     21 sys    시스템 (btop, ncdu)
  7 setup  처음 설정                    22 search 찾기 (rg, fd)
  8 save   저장과 설치                  23 dos    도스 게임 (hdos)
  9 files  파일 관리 (nnn)              24 x      Firefox (hx)
 10 write  문서 작성 (WordGrinder)      25 add    더 설치하기 (had)
 11 edit   텍스트 편집 (nano)           26 read   문서와 책 보기
 12 web    웹 (w3m, chawan, NetSurf)    27 yt     유튜브 (yt)
 13 mail   메일 (aerc)                  28 more   그 밖의 도구
 14 feeds  뉴스, 팟캐스트 (newsboat)    29 fix    문제 해결
 15 cal    일정 (calcurse)

번호나 이름을 입력하고 Enter.  q = 닫기,  doc en = English
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/cmds.txt" <<'HANDOC'
명령 요약   (F12 로 열고 닫기)
=========

  desk            콘솔 데스크톱          F1 메뉴, F5 무선랜
  doc             안내서                doc 주제, doc ko / doc en
  wg              문서 작성 (WordGrinder) wg 파일.wg, desk 안에서도
  han             한글 화면 + wg        han -s 셸, han -l 글꼴, han -d 견본
  han 글꼴이름      그 글꼴로             예: han neodgm32
  hwifi        무선랜 목록과 연결
  hbt          블루투스 기기          F8
  hinst        하드디스크에 설치      doc save
  had             더 설치하기            hadr 이름: 다시 빼기
  noad            광고 막기 켜짐/꺼짐     noad off, noad on
  hkb             폰의 블루투스 키보드    끝: 오른쪽 Ctrl+Q
  hdos         도스 게임             처음엔 had dosbox
  netsurf         그림이 보이는 웹        처음엔 had netsurf
  hx firefox      Firefox              처음엔 had firefox
  nano 파일        텍스트 편집
  nnn             파일 관리              Enter 로 무엇이든 열기
  hv 파일          PDF, EPUB, 워드, 한글 보기
  yt 찾을말         유튜브
  rg 글자 / fd 이름  찾기

USB:   husb (연결, /media/usb)  ->  husb off (빼기 전에)
끄기:  poweroff     다시 켜기:  reboot
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/start.txt" <<'HANDOC'
처음 시작하기
=============

이 시스템은 그래픽 화면 없이 콘솔(글자 화면)에서 쓰는 리눅스입니다.
문서 작성, 메일, 웹, 음악, 도스 게임까지 콘솔 프로그램으로 합니다.

1. root 로 로그인합니다.
2. desk 를 입력하면 콘솔 데스크톱이 열립니다.
3. F1 을 누르면 프로그램 메뉴가 나옵니다.

꼭 알아 둘 키
  F1        프로그램 메뉴
  F2 / F3   이전 / 다음 창
  F4        새 셸 창
  F5        무선랜 (Wi-Fi)
  F6        화면 글 복사 (화살표, Space 시작, Enter 복사)
  F7        붙여넣기
  F8        블루투스 (헤드폰, 스피커, 키보드)
  F11       일하면서 옆에 책 펴기 (F10 다음, F9 앞, F11 닫기)
  F12       지금 프로그램의 키 요약 (다시 누르면 닫힘)
  Alt+G     AI 에게 묻기 (Alt+O 오가기, 다시 Alt+G 닫기)
  Alt+D     영어 단어 뜻: 단어 앞 글자를 입력하고 Enter
  Alt+N     뉴스 피드 (오른쪽 패널, 다시 누르면 숨김)
  Alt+P     팟캐스트 재생기
  Alt+V     재생 중인 영상으로 (영상에서 Tab 은 돌아오기)
  오른쪽 Alt  한글 / 영어 전환

안내서 사용법
  doc            주제 목록
  doc 주제이름    한 주제 바로 보기 (예: doc wifi)
  doc en         영어로 바꾸기
  q              안내서 화면 닫기

끄기:  poweroff    다시 켜기:  reboot
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/korean.txt" <<'HANDOC'
한글 입력
=========

오른쪽 Alt (또는 한/영 키)로 한글과 영어를 바꿉니다.
자판은 두벌식입니다.  예: dkssud -> 안녕

한글이 나오는 곳
  desk 와 han 안의 모든 프로그램  (콘솔 한글 입력기 ddakong)
  NetSurf 웹 브라우저           (자체 한글 입력, 오른쪽 Alt)
  Firefox (hx firefox)        (fcitx5, 오른쪽 Alt)

han 명령
  han              WordGrinder 문서 작성 (한글 입력)
  wg               WordGrinder (desk 안에서도. 밖이면 han 으로 켭니다)
  han -s           한글이 되는 셸
  han -l           글꼴 목록 (크기별)
  han -d           글꼴 견본 보기
  han 글꼴이름      그 글꼴로 시작  (예: han neodgm32)

화면이 큰 노트북은 큰 글꼴이 보기 좋습니다: han neodgm32
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/desk.txt" <<'HANDOC'
콘솔 데스크톱 (desk)
===================

desk 는 tmux 위에서 돕니다. 프로그램마다 창이 하나씩 열리고,
아래 상태 줄에 창 목록, 배터리, 네트워크, 남은 메모리, 시각이 보입니다.

  F1          프로그램 메뉴
  F2 / F3     이전 / 다음 창
  F4          새 셸 창
  F5          무선랜 목록
  F6          화면 글 복사: 화살표로 가서 Space, 끝까지 가서 Enter
  F7          복사한 글 붙여넣기
  F8          블루투스 기기
  F11         오른쪽에 책 펴기 (설명서나 hb 으로 넣은 책).
              왼쪽에서 하던 일은 그대로 계속합니다. 다시 누르면 닫힘
  F10 / F9    책 다음 쪽 / 앞 쪽
  F12         지금 창 프로그램의 키 요약 (오른쪽 패널, 다시 누르면 닫힘)
  Alt+G       AI 에게 묻기 (오른쪽 칸, 다시 누르면 닫힘)
  Alt+O       옆 칸으로 (쓰던 글 <-> AI 나 책)
  Alt+D       영어 단어 뜻 (단어 앞 글자 입력, Tab 다음, Enter)
  Alt+N       뉴스 피드 보기 / 숨기기 (오른쪽 패널)
  Alt+P       팟캐스트 재생기 보기 / 숨기기
  Alt+V       재생 중인 영상으로 (영상에서 Tab 은 돌아오기)
  Alt+W       (w3m 에서) 보는 페이지의 글을 WordGrinder 로
  Ctrl+b 다음 숫자   그 번호의 창으로
  Ctrl+b 다음 d      데스크톱에서 잠시 나가기 (다시 desk 로 돌아옴)
  메뉴의 Quit desktop   데스크톱 끝내기

프로그램을 끝내면 그 창도 닫힙니다.
메뉴 고치기: /etc/han/menu.tmux
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/wifi.txt" <<'HANDOC'
무선랜 (Wi-Fi)
==============

F5 를 누르거나 hwifi 를 입력합니다.
주변 무선랜이 신호가 센 순서로 나옵니다.

   1)   -42 dBm  WPA   우리집 WiFi
   2)   -71 dBm  open  Free Public

번호를 입력하면 연결하고, 비밀번호가 필요하면 묻습니다.
r 은 다시 찾기, q 는 닫기입니다.

한 번 연결한 무선랜은 다음부터 저절로 연결됩니다.
(USB 로 켠 라이브 상태에서는 끄면 잊습니다. doc save 를 보세요.)
유선 랜선은 꽂기만 하면 됩니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/bt.txt" <<'HANDOC'
블루투스 (Bluetooth)
==================

F8 을 누르거나 hbt 를 입력합니다.   (메뉴: Bluetooth)

새 기기 (헤드폰, 스피커, 키보드, 마우스)
  1. 기기를 '연결 대기(페어링)' 상태로 둡니다.
     (보통 전원 단추나 블루투스 단추를 길게 누르면 불빛이 깜박입니다)
  2. s 를 눌러 10초 동안 찾습니다.
  3. 나온 번호를 입력합니다. 짝을 맺고 연결합니다.
     키보드는 화면에 나온 숫자를 그 키보드로 치고 Enter.
     휴대폰이 숫자 확인을 물으면 yes.

한 번 짝을 맺은 기기는 목록에 남고, 다음에는 번호만 누르면 됩니다.
  번호      연결 / 끊기 (* 표시 = 연결됨)
  x번호     지우기 (예: x2)
  q         닫기

소리: 헤드폰이나 스피커가 연결되어 있는 동안 소리가 저절로 그리로 갑니다.
끊으면 노트북 스피커로 돌아옵니다. 이미 틀어 둔 음악, 영상은 다시 시작하세요.
소리 크기: alsamixer

폰 키보드: hkb  (root, 메뉴: System, Phone keyboard)
  이 노트북이 폰의 블루투스 키보드가 됩니다. 폰의 AI 챗(제미나이 등)에
  노트북 키보드로 씁니다. 처음 한 번: 폰의 블루투스에서 "Aneuu keyboard".
  한글은 폰이 만듭니다: 폰 설정의 물리(실제/하드웨어) 키보드를 한국어
  두벌식으로. 안드로이드: 오른쪽 Alt 가 한/영. 아이폰: Caps Lock.
  명령 키: 오른쪽 Ctrl (또는 한자 키) 을 누른 채로. 폰으로는 안 갑니다.
  오른쪽 Ctrl+Tab  키를 노트북(데스크)으로, 다시 누르면 폰으로 (연결은 그대로)
  오른쪽 Ctrl+V  데스크에서 F6 로 복사한 글을 폰에 입력 (한글도)
    천천히 칩니다 (300 글자에 30 초쯤). Esc: 멈춤. 글자가 빠지면 hkb -d 40
    줄 바꿈은 Shift+Enter 로 (Enter 는 챗에서 보내기라서)
  폰 → 노트북: 같은 와이파이에서 폰 브라우저로 화면에 나온 주소를 열고
    (오른쪽 Ctrl+U 가 그 주소를 폰에 입력), 글을 붙여넣고 보내기.
    오른쪽 Ctrl+Tab 으로 노트북에 와서 F7. 그 쪽에는 노트북 글도 나옵니다.
  끝내기: 오른쪽 Ctrl+Q.  쓰는 동안 블루투스 헤드폰은 끊깁니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/setup.txt" <<'HANDOC'
처음 설정
=========

root 비밀번호 정하기 (꼭 하세요)
  passwd            새 비밀번호를 두 번 입력 (화면에 안 보입니다)

시각
  시간대는 처음부터 서울(Asia/Seoul)입니다.
  인터넷이 연결되면 시각이 저절로 맞춰집니다.
  틀리면:  date            지금 시각 보기
           setup-timezone  시간대 다시 고르기

화면 글자 크기
  han -l            글꼴 목록 (크기별)
  han neodgm32      큰 글꼴로 시작 (큰 화면에 좋음)

소리
  alsamixer         화살표로 크기, M 으로 음소거 풀기, Esc 닫기

화면 밝기 (노트북)
  Fn 키로 안 되면:  brightnessctl set 50%
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/save.txt" <<'HANDOC'
저장과 설치
===========

USB 로 켜면 시스템 전체가 메모리(RAM)에서 돕니다.
끄면 만든 파일과 바꾼 설정이 모두 사라집니다.

파일 지키기
  만든 파일은 USB 메모리에 복사해 두세요:  doc files

오래 쓸 노트북이면 하드디스크(SSD)에 설치하세요
  !! 그 디스크의 모든 것(윈도우 포함)이 지워집니다 !!
  1. hinst 입력
  2. 디스크 번호를 고르고, yes 입력
  3. root 비밀번호를 아직 안 정했으면 지금 정합니다
  4. 끝나면 poweroff, USB 를 뽑고 다시 켜기
  설치하면 무선랜 비밀번호, 파일, 설정이 그대로 남습니다.
  (설치 전에 만든 파일도 함께 옮겨집니다: /root 아래)

설치한 뒤 프로그램 새로 받기
  apk update && apk upgrade
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/files.txt" <<'HANDOC'
파일 관리: nnn
==============

시작: nnn   (메뉴: Files)

  화살표, Enter   이동, 열기
  ← (왼쪽)        위 폴더로
  /              이름으로 거르기
  Space          파일 선택
  p              선택한 파일을 여기로 복사
  v              선택한 파일을 여기로 이동
  ?              모든 키 보기
  q              끝내기

USB 메모리에 저장하기
  husb                  연결 (/media/usb 에 열림)
  cp 문서.odt /media/usb/   복사 (nnn 으로 해도 됨)
  husb off              빼기 전에 꼭!
  한글 파일 이름도 그대로 보입니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/write.txt" <<'HANDOC'
문서 작성: WordGrinder
=====================

시작: wg   (또는 wg 문서.wg. han 도 같습니다)

  Esc       메뉴 (파일, 편집, 스타일 ...)
  Ctrl+S    저장
  Ctrl+Q    끝내기

저장하면 같은 이름의 .odt 도 함께 저장됩니다 (편지.wg -> 편지.odt).
.odt 는 LibreOffice 와 한글(HWP) 프로그램에서 열립니다.
영어로 쓸 때 i 하나는 저절로 I 가 됩니다 (i'm -> I'm).

웹 글 가져와 쓰기
  wg 주소        웹 페이지의 글만 (메뉴, 광고 없이) 새 문서로 (~/web/)
  w3m 에서 Alt+W  보고 있는 페이지를 바로 그렇게
  bib            이번 주일 성서정과 본문과 주일 이름 (bib +1, bib 2027-01-03)
  bibt           오늘 읽을 말씀 (일년 일독). < > 날, a 장 전체, c 장 고르기
  bibr           성경 읽기 (책, 장 골라서 읽던 곳부터). < > 장, c 고르기
                 ~/bible/날짜.wg 와 .odt. 본문 줄 사이에 묵상을 쓰세요.

영어 단어 뜻: Alt+D, 단어 앞 글자를 입력하고 Enter  (또는 dic 단어)
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/edit.txt" <<'HANDOC'
텍스트 편집: nano
================

시작: nano 파일이름   (메뉴: Edit)

화면 아래 두 줄에 쓸 수 있는 키가 나옵니다 (^ 는 Ctrl, M- 는 Alt).
  Ctrl+O    저장 (Enter 로 이름 확인)   Ctrl+X    끝내기
  Ctrl+W    찾기                        Ctrl+\    바꾸기
  Ctrl+K    줄 잘라내기                 Ctrl+U    붙여넣기
  Alt+6     줄 복사                     Alt+U     되돌리기
  Ctrl+G    도움말
여러 줄을 옮기려면 Ctrl+K 를 여러 번 누른 뒤 한 번에 Ctrl+U.
콘솔에서는 마우스를 쓸 수 없으니, 화면의 글은 F6 (복사)과 F7 (붙여넣기).

vim 도 들어 있습니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/web.txt" <<'HANDOC'
웹 브라우저 세 가지
=================

w3m  - 가볍고 빠른 글자 브라우저   (메뉴: Web)
  U         주소 입력
  Enter     링크 따라가기     Tab   다음 링크
  B         뒤로
  /         페이지에서 찾기
  q         끝내기

chawan  - 더 많은 사이트가 열리는 글자 브라우저 (CSS, 자바스크립트 일부)
  시작: cha 주소      키는 w3m 과 비슷합니다.

NetSurf  - 그림이 보이는 브라우저   (메뉴: Web, pictures)
  처음 한 번 설치: had netsurf  (root, 메모리 약 250 MB: doc add)
  마우스(터치패드)로 씁니다. 위쪽 주소 칸을 누르고 주소를 입력.
  오른쪽 Alt 로 한글 입력.   닫기: Ctrl+Q, 또는 도구 막대 왼쪽 끝의 X.
  시작 쪽은 DuckDuckGo (구글은 NetSurf 에서 안 됩니다).

광고와 추적은 모든 프로그램에서 막혀 있습니다 (noad, 주소 7만 개 남짓).
  사이트가 이상하면 root 로  noad off,  다시 막기  noad on.

모든 사이트가 필요하면 Firefox: doc x
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/mail.txt" <<'HANDOC'
메일: aerc
==========

시작: aerc   (메뉴: Mail)
처음 실행하면 계정 설정 도우미가 나옵니다.
메일 주소, 비밀번호, 받는/보내는 서버를 묻습니다.
(Gmail, Naver 등은 "앱 비밀번호"를 따로 만들어야 할 수 있습니다.)

  j / k, 화살표   메일 고르기
  Enter          열기
  c              새 메일 쓰기
  rr             전체 답장
  d              지우기 (묻고 지움)
  q              뒤로 / 끝내기

메일을 다 쓰고 편집기를 닫으면:  y 보내기,  n 그만두기
주소록: abook (a 추가, e 고치기, q 끝내기)
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/feeds.txt" <<'HANDOC'
뉴스 피드: newsboat
==================

시작: Alt+N  (오른쪽 패널, 다시 Alt+N 숨기기)   또는 명령 newsboat

처음부터 이름난 뉴스 피드가 들어 있습니다 (한국 신문, BBC, NPR, 기술 소식 등).
빼거나 더하려면 (한 줄에 주소 하나):
  nano ~/.newsboat/urls

  R         모두 새로 받기
  Enter     열기
  o         브라우저로 열기
  n         다음 안 읽은 글
  q         뒤로 / 끝내기

팟캐스트: pod   (메뉴: Podcasts)
  pod 이름     찾아서 구독   (예: pod this american life)
  pod          구독 목록 → 번호 → 회차 번호 → 듣기 시작
  듣는 동안 다른 일을 해도 됩니다.  Alt+P 로 보기/숨기기
  (Space 멈춤, ← → 10초, 9 0 소리, s 빠르게, q 끝). 들은 곳을 기억합니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/cal.txt" <<'HANDOC'
일정과 할 일: calcurse
=====================

시작: calcurse   (메뉴: Calendar)

화면에 달력, 일정, 할 일 세 칸이 있습니다.
  Tab         칸 바꾸기
  화살표       날짜 옮기기
  a           일정이나 할 일 더하기
  e           고치기
  d           지우기
  q           끝내기
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/sheet.txt" <<'HANDOC'
스프레드시트: sc-im
==================

시작: sc-im 파일.sc   (메뉴: Spreadsheet)

  화살표          칸 옮기기
  =              숫자나 수식 넣기   (예: =A1+A2,  =@sum(A1:A9))
  <              글자 넣기 (왼쪽 맞춤)
  x              칸 지우기
  :w 파일.sc     저장
  :q             끝내기

엑셀과 주고받기:  :w 파일.csv  로 저장하면 CSV 파일이 됩니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/music.txt" <<'HANDOC'
음악: cmus
==========

시작: cmus   (메뉴: Music)

음악 폴더 넣기:  :add ~/music   (콜론부터 입력하고 Enter)
  숫자 1~7     화면 바꾸기 (2 가 음악 목록)
  Enter       재생
  c           일시정지
  b / z       다음 곡 / 이전 곡
  + / -       소리 크게 / 작게
  q           끝내기

소리가 안 나면: alsamixer (M 으로 음소거 풀기)
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/video.txt" <<'HANDOC'
동영상과 사진
=============

동영상: mpv
  mpv 영상.mp4
  Space     일시정지        ← / →   5초 뒤로 / 앞으로
  9 / 0     소리 작게 / 크게   q       끝내기

사진: fbi
  fbi 사진.jpg
  Space, PgDn   다음 사진     + / -   크게 / 작게
  b, PgUp       앞 사진       q       끝내기

그림을 그리는 프로그램(mpv, fbi, netsurf, scummvm)은 화면 전체를
쓰므로, 빈 콘솔에서 저절로 열리고 끝나면 데스크톱으로 돌아옵니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/chat.txt" <<'HANDOC'
채팅 (IRC): irssi
=================

시작: irssi   (메뉴: Chat)

  /connect irc.libera.chat     서버에 접속
  /join #채널이름                방에 들어가기
  Alt+숫자                     창 바꾸기
  /part                        방에서 나가기
  /quit                        끝내기

텔레그램 콘솔 프로그램은 아직 Alpine 에 없습니다.
텔레그램은 Firefox 로 web.telegram.org 를 쓰세요 (doc x).
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/down.txt" <<'HANDOC'
내려받기
========

aria2: 파일, 토렌트, 마그넷 링크
  aria2c 주소                  내려받기
  aria2c -x4 주소              4개 연결로 더 빨리
  aria2c 파일.torrent          토렌트
  aria2c "magnet:?xt=..."      마그넷 링크 (따옴표로 감싸기)
  Ctrl+C                       멈추기 (다시 실행하면 이어 받음)

rtorrent: 토렌트 전용 화면   (메뉴: Torrents)
  Backspace     토렌트 파일이나 마그넷 넣기
  Ctrl+S        시작        Ctrl+D   멈추기 / 지우기
  Ctrl+Q        끝내기
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/sys.txt" <<'HANDOC'
시스템 살펴보기
==============

btop: CPU, 메모리, 디스크, 네트워크, 배터리   (메뉴: System)
  화살표      프로그램 고르기
  k          고른 프로그램 끝내기
  Esc        메뉴      q   끝내기

ncdu: 무엇이 디스크를 차지하나   (메뉴: Disk usage)
  화살표, Enter   폴더 들어가기
  d              지우기 (묻고 지움)
  q              끝내기

그 밖에:  acpi -b  배터리,   lsblk  디스크,   free -m  메모리
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/search.txt" <<'HANDOC'
찾기
====

fd: 파일 이름으로 찾기
  fd 보고서              이름에 '보고서'가 든 파일
  fd -e odt              .odt 파일 모두
  fd 사진 /media/usb      USB 안에서 찾기

rg (ripgrep): 파일 안의 글자로 찾기
  rg 회의                 '회의'가 들어 있는 줄
  rg -i hello            대소문자 무시
  rg -l 계약 ~/문서        들어 있는 파일 이름만
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/dos.txt" <<'HANDOC'
도스 게임: hdos
==================

DOSBox Staging 이 화면 가득 열립니다.   (메뉴: DOS games)
처음 한 번 설치: had dosbox  (root, 메모리 약 250 MB: doc add)

  hdos                  도스 화면, ~/dos 가 C: 드라이브
  hdos /media/usb/게임   그 폴더가 C:
  hdos ~/dos/게임/GAME.EXE   게임 바로 시작

게임은 ~/dos 폴더에 넣으세요. (USB 에서 복사: doc files)
옛날 어드벤처 게임은 ScummVM: had scummvm (메뉴: Adventure)
  Ctrl+F10    마우스 풀기
  Ctrl+F9     끝내기
  Alt+Enter   창 / 전체 화면

설정: /etc/han/dosbox.conf  (cpu_cycles 로 게임 속도 조절)
한글 도스 프로그램은 옛날처럼 도스 안에서 한글 프로그램(TSR)을 먼저
실행해야 할 수 있습니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/x.txt" <<'HANDOC'
Firefox: hx
===========

모든 사이트(유튜브, 은행, 웹메일)가 필요할 때만 씁니다.
메모리가 2 GB 이상이어야 하고, 4 GB 면 편합니다.

처음 한 번 설치 (인터넷 필요, root):
  had firefox

실행:
  hx firefox        화면 가득 Firefox. 끝내면 콘솔로 돌아옴
  오른쪽 Alt        한글 / 영어

hx 는 다른 그래픽 프로그램도 엽니다:  hx 프로그램이름
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/add.txt" <<'HANDOC'
더 설치하기: had
================

다시 리눅스는 USB 로 켜면 모든 프로그램을 메모리에 올립니다.
그래서 무거운 프로그램은 처음에는 빼 두고, 필요할 때 한 번 설치합니다.

  had                 목록 ([v] = 설치됨)   (메뉴: System, Add more)
  had netsurf         그림이 보이는 웹 브라우저
  had dosbox          도스 프로그램 실행기 (hdos), 게임은 따로
  had scummvm         옛 어드벤처 게임 실행기, 게임은 따로
  had hwdec           영상을 그래픽 칩으로 풀기 (빠르고 조용함)
  had firefox         Firefox (인터넷, 메모리 2 GB 이상)
  had hwp / ocr       한글 .hwp 보기 / 스캔한 PDF 읽기 (인터넷)
  had yt              유튜브가 안 될 때 yt-dlp 새로 받기
  hadr 이름           다시 빼기 (예: hadr dosbox),  hadr 만: 설치된 것

root 로 실행합니다. netsurf, dosbox, scummvm, hwdec 는 USB 안에
들어 있어서 인터넷 없이 설치됩니다.

netsurf, dosbox, scummvm 은 그래픽 부분(Mesa, 약 230 MB)을 함께
씁니다. USB 로 켠 상태에서는 다시 켜면 없어지고 메모리를 차지합니다:
hinst 로 디스크에 설치한 뒤에 쓰면 좋습니다 (doc save).
han-add 는 had 의 옛 이름입니다.
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/read.txt" <<'HANDOC'
문서와 책 보기: hv (han-view)
=======================

hv 파일   알맞은 프로그램으로 엽니다. (긴 이름: han-view)
nnn 에서 파일을 고르고 Enter 를 눌러도 같습니다.

  PDF            화면 가득 (Space 다음 쪽, b 앞 쪽, + - 크기, q 끝)
  EPUB 전자책     책 읽기 (Space 다음 쪽, b 앞 쪽, q 끝)
                 그 뒤로 F11 패널에도 그 책이 나옵니다
  Word .docx/.doc, 한글 .hwpx, .odt, .rtf   글만 보기 (q 끝)
  한글 .hwp       먼저 한 번: had hwp
  엑셀 .xlsx/.csv  sc-im
  사진, 동영상, 음악, 웹 페이지(.html), 압축 파일(목록)

일하면서 옆에 책 펴기 (F11)
  화면 오른쪽에 책이 펴지고, 왼쪽에서는 하던 일을 계속합니다.
  F10 다음 쪽, F9 앞 쪽, F11 닫기. 읽던 쪽을 기억합니다.
  처음에는 이 배포판의 설명서가 들어 있습니다.
  hb 책.epub   다른 책 넣기      hb -r   설명서로 되돌리기
  hb 가 읽는 것: epub, pdf, docx, hwpx, hwp, odt, doc, rtf, txt, html
  스캔한 PDF (그림뿐) 를 글자로: had ocr (한 번, 느림)
  그 쪽을 AI 에게 보이기: Alt+G 에서 /pdf

고치려면: 글은 nano, 문서는 han (WordGrinder)
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/yt.txt" <<'HANDOC'
유튜브: yt
==============

yt 찾을말         (메뉴: YouTube)

찾은 영상 목록이 번호와 길이와 함께 나옵니다.
  3         3번 영상을 화면 가득 (가벼운 360p)
  3s        3번을 소리만 (음악, 강의)
  다른 말    새로 찾기
  q         끝내기

보는 동안:  Space 멈춤,  ← → 5초,  9 0 소리,  s 빠르게,  q 끝
  Tab 으로 데스크톱에 돌아가 다른 일을 해도 영상은 계속됩니다.
  데스크톱에서 Alt+V 를 누르면 영상으로 돌아옵니다.
한글로 찾았어도 q s v 가 됩니다 (ㅂ ㄴ ㅍ). 영상 동안은 EN 으로 바뀌었다가
끝나면 한으로 돌아옵니다.
유튜브가 "로봇이 아닌지 확인" 을 하면 VPN 을 끄거나 얼마 뒤 다시.
주소를 알면:  mpv https://www.youtube.com/watch?v=...
안 되면 yt-dlp 를 새로 받으세요:  had yt
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/more.txt" <<'HANDOC'
그 밖의 도구
============

번역 (인터넷 필요)
  trans :ko "good morning"      영어 -> 한국어
  trans ko:en "좋은 아침"        한국어 -> 영어
  trans -shell :ko              계속 번역 (끝: Ctrl+D)

날씨
  curl wttr.in/Seoul?lang=ko

화면 잠그기 (자리 비울 때)
  vlock -a          root 비밀번호로 풉니다 (메뉴: Lock screen)

계산기
  bc -l             예: 3*4500+1200   끝: quit

다른 컴퓨터에 접속
  ssh 사용자@주소

노트북 단추
  전원 단추          깔끔하게 끄기
  덮개 닫기          배터리로 쓸 때 잠자기
HANDOC
	cat > "$STAGE/usr/share/han/doc/ko/fix.txt" <<'HANDOC'
문제 해결
=========

한글이 네모(□)나 ?? 로 보여요
  desk 나 han 안에서 쓰세요. 그래도 안 되면 han -f

한글이 안 쳐져요
  오른쪽 Alt (또는 한/영 키)를 한 번 누르세요.
  NetSurf 와 Firefox 는 그 안에서 따로 바꿉니다.

무선랜 카드가 없다고 나와요
  리눅스가 모르는 카드입니다. 랜선을 쓰거나,
  USB 무선랜(동글)을 꽂아 보세요. 어떤 카드인지: lspci

NetSurf, 도스 게임이 안 열려요
  처음 한 번 설치했나요?  had  로 확인 ([v] = 설치됨).
  "EGL" 이 나오면 그래픽 칩의 드라이버가 없는 것입니다
  (가상 머신의 기본 VGA 도 그렇습니다). w3m 이나 chawan 을 쓰세요.

영상이 안 나와요
  인터넷 연결 뒤 root 로  had yt  (yt-dlp 새로 받기)

화면이 멈춘 것 같아요
  Ctrl+C          지금 프로그램 멈추기
  q 또는 Esc       대부분의 프로그램 닫기
  Alt+F2          다른 콘솔로 가서 root 로그인

USB 메모리 한글 파일 이름이 깨져요
  mount 대신 husb 로 연결하세요.

그래도 안 되면
  reboot          다시 켜기
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/index.txt" <<'HANDOC'
Guide - choose a topic

  1 cmds   Command summary              16 sheet  Spreadsheet (sc-im)
  2 start  Getting started              17 music  Music (cmus)
  3 korean Typing Korean                18 video  Video and pictures
  4 desk   The console desktop          19 chat   Chat (irssi)
  5 wifi   Wi-Fi                        20 down   Downloads (aria2, rtorrent)
  6 bt     Bluetooth                    21 sys    System (btop, ncdu)
  7 setup  First settings               22 search Searching (rg, fd)
  8 save   Saving and installing        23 dos    DOS games (hdos)
  9 files  Files (nnn)                  24 x      Firefox (hx)
 10 write  Writing (WordGrinder)        25 add    Add more (had)
 11 edit   Text editor (nano)           26 read   Reading documents and books
 12 web    Web (w3m, chawan, NetSurf)   27 yt     YouTube (yt)
 13 mail   Mail (aerc)                  28 more   More tools
 14 feeds  News, podcasts (newsboat)    29 fix    Troubleshooting
 15 cal    Calendar (calcurse)

Type a number or name, then Enter.  q = close,  doc ko = 한국어
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/cmds.txt" <<'HANDOC'
Command summary   (F12 opens and closes this)
===============

  desk            console desktop       F1 menu, F5 Wi-Fi
  doc             guide                 doc TOPIC, doc ko / doc en
  wg              word processor        wg FILE.wg, also inside desk
  han             Korean screen + wg    han -s shell, -l fonts, -d samples
  han FONT        with that font        e.g. han neodgm32
  hwifi        Wi-Fi list and connect
  hbt          Bluetooth devices     F8
  hinst        install to the disk   doc save
  had             add more programs     hadr NAME: remove again
  noad            ad blocking on/off    noad off, noad on
  hkb             phone's Bluetooth keyboard  quit: Right Ctrl+Q
  hdos         DOS games             first: had dosbox
  netsurf         web with pictures     first: had netsurf
  hx firefox      Firefox               first: had firefox
  nano FILE       text editor
  nnn             files                 Enter opens anything
  hv FILE         PDF, EPUB, Word, HWP
  yt WORDS        YouTube
  rg TEXT / fd NAME   search

USB:        husb (attach, /media/usb)  ->  husb off (before unplugging)
Power off:  poweroff     Restart:  reboot
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/start.txt" <<'HANDOC'
Getting started
===============

This is Linux used on the console (the text screen), without a
graphical desktop. Writing, mail, web, music and even DOS games are
done with console programs.

1. Log in as root.
2. Type  desk  to open the console desktop.
3. Press F1 for the program menu.

Keys to know
  F1         program menu
  F2 / F3    previous / next window
  F4         a new shell window
  F5         Wi-Fi
  F6         copy text from the screen (arrows, Space, Enter)
  F7         paste
  F8         Bluetooth (headphones, speakers, keyboards)
  F11        a book beside your work (F10 next, F9 back)
  F12        keys for the program on screen (press again to close)
  Alt+G      ask the AI (Alt+O switch sides, Alt+G again closes)
  Alt+D      English dictionary: type the start of a word, Enter
  Alt+N      news feeds (a panel on the right; again hides it)
  Alt+P      podcast player
  Alt+V      back to the playing video (Tab there comes back)
  Right Alt  switch Korean / English

Using this guide
  doc            list of topics
  doc TOPIC      one topic directly (e.g. doc wifi)
  doc ko         switch to Korean
  q              close a guide page

Power off:  poweroff     Restart:  reboot
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/korean.txt" <<'HANDOC'
Typing Korean
=============

Right Alt (or the Hangul key) switches Korean and English.
The layout is 2-beolsik.  Example: dkssud -> 안녕

Where Korean works
  every program inside desk and han   (console input: ddakong)
  the NetSurf web browser             (its own input, Right Alt)
  Firefox (hx firefox)                (fcitx5, Right Alt)

The han command
  han              WordGrinder word processor, with Korean
  wg               WordGrinder (also inside desk; outside it starts han)
  han -s           a shell with Korean
  han -l           list fonts, grouped by size
  han -d           look at each font
  han FONT         start with that font  (e.g. han neodgm32)

On large laptop screens a big font is easier to read: han neodgm32
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/desk.txt" <<'HANDOC'
The console desktop (desk)
==========================

desk runs on tmux. Each program opens in its own window; the status
line at the bottom lists the windows and shows battery, network, free
memory and the time.

  F1          program menu
  F2 / F3     previous / next window
  F4          a new shell window
  F5          Wi-Fi networks
  F6          copy from the screen: move, Space, move, Enter
  F7          paste what you copied
  F8          Bluetooth devices
  F11         a book on the right (the manual, or one set with hb)
              while you keep working on the left; again closes it
  F10 / F9    next / previous page of the book
  F12         keys for the program in this window (a panel on the
              right; press F12 again to close)
  Alt+G       ask the AI (a pane on the right; again closes it)
  Alt+O       over to the other pane (your work <-> AI or book)
  Alt+D       English dictionary (type a word's start, Tab, Enter)
  Alt+N       show / hide the news feeds (a panel on the right)
  Alt+P       show / hide the podcast player
  Alt+V       back to the playing video (Tab there comes back)
  Alt+W       (in w3m) the page's text into WordGrinder
  Ctrl+b then a number   go to that window
  Ctrl+b then d          leave the desktop for now (desk brings it back)
  Quit desktop (menu)    end the desktop

Quitting a program closes its window.
To change the menu: /etc/han/menu.tmux
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/wifi.txt" <<'HANDOC'
Wi-Fi
=====

Press F5, or type hwifi.
The networks in range are listed, strongest first.

   1)   -42 dBm  WPA   HomeWiFi
   2)   -71 dBm  open  Free Public

Type a number to connect; it asks for a password if one is needed.
r searches again, q closes.

Networks you have used are joined again by themselves. (Running live
from USB, they are forgotten at power off: see doc save.)
A network cable just works.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/bt.txt" <<'HANDOC'
Bluetooth
=========

Press F8, or type hbt.   (menu: Bluetooth)

A new device (headphones, speaker, keyboard, mouse)
  1. Put the device in pairing mode.
     (usually: hold its power or Bluetooth button until a light blinks)
  2. Press s to search for 10 seconds.
  3. Type its number. It is paired and connected.
     A keyboard: type the number shown on that keyboard, then Enter.
     A phone asking to confirm a number: yes.

Paired devices stay in the list; next time just type the number.
  number    connect / disconnect (* = connected)
  x+number  forget it (e.g. x2)
  q         close

Sound goes to headphones or a speaker by itself while they are connected,
and back to the laptop when they disconnect. Restart music or video that
was already playing.  Volume: alsamixer

Phone keyboard: hkb  (root; menu: System, Phone keyboard)
  This laptop becomes the phone's Bluetooth keyboard: type into the
  phone's AI chat (Gemini ...) on the laptop. Once: on the phone, pick
  "Aneuu keyboard" under Bluetooth. Korean is made by the phone: set its
  physical (hardware) keyboard to Korean 2-beolsik. Android: Right Alt
  switches. iPhone: Caps Lock.
  Command key: hold Right Ctrl (or the Hanja key); it never reaches the phone.
  Right Ctrl+Tab  keys to the laptop (desk) and back; the phone stays on
  Right Ctrl+V  types what F6 copied in desk into the phone (Korean too)
    It types slowly (300 letters: about 30 s). Esc stops. Letters missing:
    hkb -d 40. A line break goes as Shift+Enter (Enter sends a chat message).
  Phone to laptop: same Wi-Fi; open the address shown, in the phone's
    browser (Right Ctrl+U types it there), paste, send; Right Ctrl+Tab to
    the laptop, then F7. The page also shows what the laptop copied.
  Quit: Right Ctrl+Q. Bluetooth headphones drop while it runs.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/setup.txt" <<'HANDOC'
First settings
==============

Set a root password (do this)
  passwd            type the new password twice (it is not shown)

Time
  The time zone is Seoul (Asia/Seoul) from the start.
  Once online, the clock sets itself.
  If it is wrong:  date            show the time
                   setup-timezone  choose the time zone again

Text size
  han -l            fonts, by size
  han neodgm32      start with a big font (good on big screens)

Sound
  alsamixer         arrows for volume, M unmutes, Esc closes

Screen brightness (laptops)
  If the Fn keys do nothing:  brightnessctl set 50%
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/save.txt" <<'HANDOC'
Saving and installing
=====================

Started from USB, the whole system runs in memory (RAM).
At power off, your files and settings are gone.

Keep your files
  Copy them to a USB stick:  doc files

For a laptop you will keep using, install to its hard disk (SSD)
  !! Everything on that disk (Windows too) is erased !!
  1. Type hinst
  2. Pick the disk by number, type yes
  3. Set the root password now if you have not yet
  4. Then poweroff, unplug the USB stick, turn on again
  Installed, Wi-Fi passwords, files and settings stay.
  (Files you made before installing come along: under /root)

Updating programs after installing
  apk update && apk upgrade
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/files.txt" <<'HANDOC'
Files: nnn
==========

Start: nnn   (menu: Files)

  arrows, Enter   move, open
  Left            up to the parent folder
  /               filter by name
  Space           select a file
  p               copy the selection here
  v               move the selection here
  ?               all keys
  q               quit

Saving to a USB stick
  husb                  attach it (opens at /media/usb)
  cp letter.odt /media/usb/  copy (or use nnn)
  husb off              always, before pulling it out!
  Korean file names show correctly.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/write.txt" <<'HANDOC'
Writing: WordGrinder
====================

Start: wg   (or wg letter.wg; han does the same)

  Esc       menu (File, Edit, Style ...)
  Ctrl+S    save
  Ctrl+Q    quit

Saving also writes an .odt of the same name (letter.wg -> letter.odt),
for LibreOffice and most office programs.
In English, a lone i becomes I by itself (i'm -> I'm).

Writing from the web
  wg ADDRESS     a web page's text (no menus, ads) as a new document (~/web/)
  Alt+W in w3m   the same for the page you are looking at
  bib            this Sunday's lectionary readings (bib +1, bib 2027-01-03)
  bibt           today's readings (one-year plan): < > day, a whole, c chapters
  bibr           read a book of the Bible, where you stopped: < > chapter, c
                 ~/bible/DATE.wg and .odt; write your notes between the lines

English words: Alt+D, type the start of the word, Enter  (or: dic WORD)
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/edit.txt" <<'HANDOC'
Text editor: nano
=================

Start: nano FILE   (menu: Edit)

The two bottom lines show the keys (^ is Ctrl, M- is Alt).
  Ctrl+O    save (Enter confirms)       Ctrl+X    quit
  Ctrl+W    find                        Ctrl+\    replace
  Ctrl+K    cut line                    Ctrl+U    paste
  Alt+6     copy line                   Alt+U     undo
  Ctrl+G    help
To move several lines, press Ctrl+K on each, then Ctrl+U once.
The console has no mouse: for text on the screen use F6 (copy) and F7
(paste).

vim is installed too.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/web.txt" <<'HANDOC'
Three web browsers
==================

w3m  - light and fast text browser   (menu: Web)
  U         enter an address
  Enter     follow a link     Tab   next link
  B         back
  /         search the page
  q         quit

chawan  - a text browser that opens more sites (CSS, some JavaScript)
  Start: cha ADDRESS      Its keys are similar to w3m.

NetSurf  - a browser with pictures   (menu: Web, pictures)
  Install it once: had netsurf  (root, about 250 MB of memory: doc add)
  Use the mouse (touchpad): click the address bar at the top, type.
  Right Alt switches Korean.   Close: Ctrl+Q, or the X at the toolbar's left.
  It starts on DuckDuckGo (Google does not work in NetSurf).

Ads and trackers are blocked for every program (noad, about 70,000 names).
  A site that breaks: as root, noad off; block again: noad on.

For every site, use Firefox: doc x
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/mail.txt" <<'HANDOC'
Mail: aerc
==========

Start: aerc   (menu: Mail)
The first run starts an account wizard: it asks for your address,
password, and incoming and outgoing servers.
(Gmail and others may need a separate "app password".)

  j / k, arrows   pick a message
  Enter           open it
  c               write a new message
  rr              reply to all
  d               delete (asks first)
  q               back / quit

After writing, close the editor:  y sends,  n abandons
Address book: abook (a add, e edit, q quit)
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/feeds.txt" <<'HANDOC'
News feeds: newsboat
====================

Start: Alt+N  (a panel on the right; Alt+N again hides it)   or: newsboat

It starts with well-known feeds already in (Korean papers, BBC, NPR,
tech news and more). To remove or add some, one address per line:
  nano ~/.newsboat/urls

  R         reload all
  Enter     open
  o         open in the browser
  n         next unread
  q         back / quit

Podcasts: pod   (menu: Podcasts)
  pod NAME     find and subscribe   (e.g. pod this american life)
  pod          your podcasts -> number -> episode number -> it plays
  Go on working while it plays.  Alt+P shows or hides the player
  (Space pause, Left/Right 10 s, 9 0 volume, s faster, q stop). Keeps place.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/cal.txt" <<'HANDOC'
Calendar and to-do: calcurse
============================

Start: calcurse   (menu: Calendar)

The screen has three panels: calendar, appointments, to-do.
  Tab         switch panel
  arrows      move between days
  a           add an appointment or a to-do
  e           edit
  d           delete
  q           quit
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/sheet.txt" <<'HANDOC'
Spreadsheet: sc-im
==================

Start: sc-im FILE.sc   (menu: Spreadsheet)

  arrows         move between cells
  =              enter a number or formula (e.g. =A1+A2, =@sum(A1:A9))
  <              enter text (left aligned)
  x              clear a cell
  :w FILE.sc     save
  :q             quit

For Excel and others: save with  :w FILE.csv  to get a CSV file.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/music.txt" <<'HANDOC'
Music: cmus
===========

Start: cmus   (menu: Music)

Add your music folder:  :add ~/music   (type it with the colon, Enter)
  keys 1-7    switch views (2 is the library)
  Enter       play
  c           pause
  b / z       next / previous track
  + / -       louder / quieter
  q           quit

No sound? alsamixer (M unmutes)
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/video.txt" <<'HANDOC'
Video and pictures
==================

Video: mpv
  mpv film.mp4
  Space     pause            Left / Right   back / ahead 5 s
  9 / 0     quieter / louder q              quit

Pictures: fbi
  fbi photo.jpg
  Space, PgDn   next picture   + / -   zoom in / out
  b, PgUp       previous       q       quit

Programs that draw pictures (mpv, fbi, netsurf, scummvm) need the whole
screen, so they open on a free console by themselves and return to the
desktop when they end.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/chat.txt" <<'HANDOC'
Chat (IRC): irssi
=================

Start: irssi   (menu: Chat)

  /connect irc.libera.chat     connect to a server
  /join #channel               join a room
  Alt+number                   switch windows
  /part                        leave a room
  /quit                        quit

There is no console Telegram client in Alpine yet.
For Telegram, use web.telegram.org in Firefox (doc x).
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/down.txt" <<'HANDOC'
Downloads
=========

aria2: files, torrents, magnet links
  aria2c ADDRESS               download
  aria2c -x4 ADDRESS           faster, with 4 connections
  aria2c FILE.torrent          a torrent
  aria2c "magnet:?xt=..."      a magnet link (keep the quotes)
  Ctrl+C                       stop (run it again to resume)

rtorrent: a full torrent screen   (menu: Torrents)
  Backspace     add a torrent file or magnet link
  Ctrl+S        start       Ctrl+D   stop / remove
  Ctrl+Q        quit
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/sys.txt" <<'HANDOC'
Looking at the system
=====================

btop: CPU, memory, disks, network, battery   (menu: System)
  arrows     pick a process
  k          end the picked process
  Esc        menu      q   quit

ncdu: what fills the disk   (menu: Disk usage)
  arrows, Enter   go into a folder
  d               delete (asks first)
  q               quit

Also:  acpi -b  battery,   lsblk  disks,   free -m  memory
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/search.txt" <<'HANDOC'
Searching
=========

fd: find files by name
  fd report              files with 'report' in the name
  fd -e odt              all .odt files
  fd photo /media/usb    search a USB stick

rg (ripgrep): find text inside files
  rg meeting             lines containing 'meeting'
  rg -i hello            ignore upper/lower case
  rg -l contract ~/docs  only the names of matching files
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/dos.txt" <<'HANDOC'
DOS games: hdos
==================

DOSBox Staging opens full screen.   (menu: DOS games)
Install it once: had dosbox  (root, about 250 MB of memory: doc add)

  hdos                  DOS prompt, ~/dos is drive C:
  hdos /media/usb/games  that folder is C:
  hdos ~/dos/game/GAME.EXE   start a game directly

Put games in ~/dos. (Copying from USB: doc files)
Classic adventure games: ScummVM, had scummvm (menu: Adventure)
  Ctrl+F10    free the mouse
  Ctrl+F9     quit
  Alt+Enter   window / full screen

Settings: /etc/han/dosbox.conf  (cpu_cycles sets the game speed)
Korean DOS programs may need their Korean TSR loaded inside DOS
first, as on a PC back then.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/x.txt" <<'HANDOC'
Firefox: hx
===========

Use it only when you need every site (video, banking, web mail).
It needs 2 GB of memory; 4 GB is comfortable.

Install once (needs the internet, as root):
  had firefox

Run:
  hx firefox        Firefox full screen; quitting returns to the console
  Right Alt         Korean / English

hx opens other graphical programs too:  hx PROGRAM
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/add.txt" <<'HANDOC'
Add more: had
=============

Started from USB, Aneuu keeps every program in memory. So the heavy
programs are left out at first and installed once when wanted.

  had                 the list ([v] = installed)   (menu: System, Add more)
  had netsurf         web browser with pictures
  had dosbox          runs DOS programs (hdos); games not included
  had scummvm         runs old adventure games; games not included
  had hwdec           decode video on the graphics chip (faster, quieter)
  had firefox         Firefox (online; 2 GB of memory or more)
  had hwp / ocr       view Hangul .hwp / read scanned PDFs (online)
  had yt              update yt-dlp when YouTube stops working
  hadr NAME           remove it again (hadr alone: what is installed)

Run it as root. netsurf, dosbox, scummvm and hwdec are on the USB
stick itself and install without internet.

netsurf, dosbox and scummvm share one graphics part (Mesa, about
230 MB). Started from USB, they are gone after a reboot and use memory:
best after installing to the disk with hinst (doc save).
han-add is the old name of had.
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/read.txt" <<'HANDOC'
Reading documents and books: hv (han-view)
=====================================

hv FILE   opens it with the right program. (long name: han-view)
In nnn, pick a file and press Enter: the same.

  PDF            full screen (Space next page, b back, + - size, q quit)
  EPUB books     the book reader (Space next page, b back, q quit)
                 from then on the F11 panel shows that book too
  Word .docx/.doc, Hangul .hwpx, .odt, .rtf   text only (q quit)
  Hangul .hwp    first, once: had hwp
  Excel .xlsx/.csv  sc-im
  pictures, video, music, web pages (.html), archives (list)

A book beside your work (F11)
  The book opens on the right while you keep working on the left.
  F10 next page, F9 previous, F11 closes. It remembers your page.
  It starts with the manual (Korean).
  hb BOOK.epub  another book     hb -r   back to the manual
  hb reads: epub, pdf, docx, hwpx, hwp, odt, doc, rtf, txt, html
  Scanned PDFs (pictures only) as text: had ocr (once, slow)
  Show a page to the AI: /pdf in Alt+G

To change them: text in nano, documents in han (WordGrinder)
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/yt.txt" <<'HANDOC'
YouTube: yt
===============

yt WORDS         (menu: YouTube)

The videos found are listed with a number and their length.
  3         play number 3 full screen (light 360p)
  3s        number 3, sound only (music, talks)
  words     search again
  q         quit

While playing:  Space pause,  Left/Right 5 s,  9 0 volume,  s faster,  q stop
  Tab goes back to the desktop to do other things; the video goes on.
  Alt+V in the desktop returns to the video.
Searched in Korean? q s v still work (ㅂ ㄴ ㅍ too). Input shows EN while a
video plays and goes back to 한 afterwards.
If YouTube asks to "confirm you're not a bot": turn off a VPN, or wait.
With an address:  mpv https://www.youtube.com/watch?v=...
If it stops working, update yt-dlp:  had yt
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/more.txt" <<'HANDOC'
More tools
==========

Translation (online)
  trans :ko "good morning"      English -> Korean
  trans ko:en "좋은 아침"        Korean -> English
  trans -shell :ko              keep translating (end: Ctrl+D)

Weather
  curl wttr.in/Seoul

Lock the screen (when you step away)
  vlock -a          unlock with the root password (menu: Lock screen)

Calculator
  bc -l             e.g. 3*4500+1200   end: quit

Log in to another computer
  ssh user@address

Laptop buttons
  power button      clean power off
  closing the lid   on battery: suspend
HANDOC
	cat > "$STAGE/usr/share/han/doc/en/fix.txt" <<'HANDOC'
Troubleshooting
===============

Korean shows as boxes or ??
  Use it inside desk or han. If still wrong: han -f

Korean cannot be typed
  Press Right Alt (or the Hangul key) once.
  NetSurf and Firefox switch inside themselves.

"No Wi-Fi card found"
  Linux does not know this card. Use a cable, or plug in a
  USB Wi-Fi stick (dongle). Which card it is: lspci

NetSurf or DOS games do not open
  Installed them once?  had  shows it ([v] = installed).
  "EGL" in the message: no driver for the graphics chip
  (also a virtual machine's plain VGA). Use w3m or chawan.

Videos do not play
  When online, as root:  had yt  (updates yt-dlp)

The screen seems stuck
  Ctrl+C          stop the program
  q or Esc        closes most programs
  Alt+F2          another console; log in as root there

Korean file names on a USB stick look broken
  Attach it with husb instead of mount.

If nothing helps
  reboot          restart
HANDOC


	cat > "$STAGE/usr/local/bin/desk" <<'EOF'
#!/bin/sh
# The console desktop: tmux with a status line and a program menu (F1),
# with Korean input. Options and fonts as for han:  desk [FONT]
exec /usr/local/bin/han -t "$@"
EOF

	cat > "$STAGE/usr/local/bin/han-run" <<'EOF'
#!/bin/sh
# Start a program from the desktop menu, or say how to get it.
command -v "$1" >/dev/null 2>&1 || exec had --hint "$1"
exec "$@"
EOF

	cat > "$STAGE/usr/local/bin/han-status" <<'EOF'
#!/bin/sh
# One line for the desktop status bar: battery, network, free memory.
out=""
for b in /sys/class/power_supply/BAT*; do
	[ -r "$b/capacity" ] || continue
	case "$(cat "$b/status" 2>/dev/null)" in
		Charging) m="+" ;; Discharging) m="-" ;; *) m="=" ;;
	esac
	out="bat $(cat "$b/capacity")%$m  "
	break
done
dev="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p')"
if [ -n "$dev" ]; then
	ssid="$(iw dev "$dev" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')"
	if [ -n "$ssid" ]; then out="${out}wifi $(printf '%b' "$ssid")  "
	else out="${out}net $dev  "; fi
else
	out="${out}offline (F5 Wi-Fi)  "
fi
if [ -d /sys/class/bluetooth/hci0 ]; then
	bt="$(timeout 2 bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3- | cut -c1-16)"
	[ -n "$bt" ] && out="${out}bt $bt  "
fi
echo "${out}free $(awk '/MemAvailable/ { printf "%d", $2 / 1024 }' /proc/meminfo)M"
EOF

	cat > "$STAGE/etc/han/tmux.conf" <<'EOF'
# han console desktop. F1 menu, F2/F3 previous/next window, F4 new shell,
# F5 Wi-Fi networks, F6/F7 copy/paste, F8 Bluetooth, F9-F11 book pane,
# F12 key summary for the program on screen; Alt+G AI chat, Alt+O other
# pane, Alt+D dictionary, Alt+N news feeds, Alt+P podcast player, Alt+V back
# to the video.
set -g base-index 1
set -g renumber-windows on
set -g escape-time 20
set -g history-limit 5000
set -g status-interval 20
set -g status-style "bg=blue,fg=white"
# Korean input on or off (ddakong tells imestate): red 한 = Korean, EN = English
run-shell 'tmux set -gq @ime "$(cat /tmp/han-ime.$(id -u) 2>/dev/null)"'
set -g status-left "#[bold] han #[default]#{?#{==:#{@ime},ko},#[bg=red#,fg=white#,bold] 한 #[default] ,#{?#{==:#{@ime},en},#[bg=white#,fg=blue] EN #[default] ,}}"
set -g status-left-length 16
set -g status-right "#(/usr/local/bin/han-status)  %a %m-%d %H:%M "
set -g status-right-length 70
set -g window-status-current-style "bg=white,fg=blue,bold"
set -g display-time 3000
bind -n F1 source-file /etc/han/menu.tmux
bind -n F2 previous-window
bind -n F3 next-window
bind -n F4 new-window
bind -n F5 new-window -n wifi "hwifi"
# F6: copy text from the screen (arrows move, Space starts, Enter copies,
# q cancels); F7: paste it.  The console has no mouse for this.
setw -g mode-keys vi
bind -n F6 copy-mode
bind -n F7 paste-buffer -p
# F8: Bluetooth devices (headphones, speakers, keyboards, mice)
bind -n F8 new-window -n bt "hbt"
# Alt+V: back to the video playing on its own screen (Tab there returns)
bind -n M-v run-shell /usr/local/lib/han/vidshow
# Alt+N: the news feeds (newsboat) in a panel on the right, like F12;
# Alt+N again hides it (it keeps its place), q in the feed list quits it
bind -n M-n if -F "#{==:#{session_name},han-news}" "detach-client" "run-shell '/usr/local/lib/han/newsshow #{client_name}'"
# Alt+P: the podcast player (pod), shown or hidden
bind -n M-p run-shell "/usr/local/lib/han/podshow '#{client_name}'"
# Alt+G: the AI chat (gem) beside your work, Alt+G again closes it;
# Alt+O: over to the other side (your work / the chat)
bind -n M-g run-shell "/usr/local/lib/han/gempane '#{window_id}'"
bind -n M-o select-pane -t :.+
# Alt+D: the dictionary. Type the start of a word on the screen (it gets
# marked, Tab for the next), Enter: its meaning (WordNet, English). No mouse.
bind -n M-d display-popup -E -B -x 0 -y 0 -w 100% -h 100% "dic --pick"
# F11: the book (the manual, or the one set with hb FILE) in a pane on the
# right, titled with the book's name, while you go on typing on the left.
# F10 next page, F9 previous page (from anywhere), F11 again closes it.
bind -n F11 run-shell "/usr/local/lib/han/bookpane toggle '#{window_id}'"
bind -n F10 run-shell "/usr/local/lib/han/bookpane next '#{window_id}'"
bind -n F9  run-shell "/usr/local/lib/han/bookpane prev '#{window_id}'"
bind -T copy-mode-vi v send -X begin-selection
# F12: keys for the program in this window, in a panel on the right (a third
# of the screen; the start of each line you write stays visible);
# F12 again (or q) closes it
bind -n F12 display-popup -E -x R -y 0 -w 34% -h 100% -b rounded "han-cheat"
bind m source-file /etc/han/menu.tmux
# English keys only while a pane that reads single keys has focus (the
# window waiting beside a video, pod's player): enkeys switches ddakong.
# Fixed index [42]: reloading this file does not add the hook twice.
set-hook -g session-window-changed[42] 'run-shell -b "/usr/local/lib/han/enkeys #{pane_id}"'
set-hook -g window-pane-changed[42] 'run-shell -b "/usr/local/lib/han/enkeys #{pane_id}"'
EOF

	# F1 menu: short enough for a 25-line console (a menu taller than the
	# screen is not shown at all), with four submenus. Back = <.
	cat > "$STAGE/etc/han/menu.tmux" <<'EOF'
display-menu -T "#[align=centre] 다시 · Aneuu " -x C -y C \
  "글쓰기  Write      wg"          w "new-window -n write 'han-run wordgrinder'" \
  "편집    Edit text  nano"        e "new-window -n edit 'han-run nano'" \
  "파일    Files      nnn"         f "new-window -n files 'han-run nnn'" \
  "AI 묻기 Ask AI     Alt+G"       a "run-shell \"/usr/local/lib/han/gempane '#{window_id}'\"" \
  "" \
  "인터넷  Internet   >"           i "source-file /etc/han/menu-net.tmux" \
  "생활    Daily      >"           d "source-file /etc/han/menu-day.tmux" \
  "놀이    Fun        >"           p "source-file /etc/han/menu-fun.tmux" \
  "시스템  System     >"           s "source-file /etc/han/menu-sys.tmux" \
  "" \
  "새 셸   Shell"                  t "new-window" \
  "안내서  Guide      doc"         ? "new-window -n guide 'doc'" \
  "끝내기  Quit desktop"           q "confirm-before -p 'Quit the desktop? (y/n)' kill-session" \
  "닫기    Close menu         F1"  F1 ""
EOF
	cat > "$STAGE/etc/han/menu-net.tmux" <<'EOF'
display-menu -T "#[align=centre] 인터넷 · Internet " -x C -y C \
  "웹        Web            w3m"     w "new-window -n web 'han-run w3m https://lite.duckduckgo.com/lite'" \
  "웹 (더)   Web, more      chawan"  c "new-window -n cha 'han-run cha https://lite.duckduckgo.com/lite'" \
  "웹 (그림) Web, pictures  NetSurf" n "new-window -n netsurf 'netsurf'" \
  "메일      Mail           aerc"    m "new-window -n mail 'han-run aerc'" \
  "뉴스      News feeds     Alt+N"    r "run-shell '/usr/local/lib/han/newsshow #{client_name}'" \
  "팟캐스트  Podcasts       pod"      p "new-window -n pod 'pod'" \
  "채팅      Chat (IRC)     irssi"   i "new-window -n chat 'han-run irssi'" \
  "유튜브    YouTube        yt"      y "new-window -n youtube 'yt'" \
  "토렌트    Torrents       rtorrent" t "new-window -n torrent 'han-run rtorrent'" \
  "Firefox   Full browser   hx"      x "new-window -n x 'hx firefox'" \
  "" \
  ", 뒤로    Back"                   "," "source-file /etc/han/menu.tmux" \
  "닫기      Close menu     F1"      F1 ""
EOF
	cat > "$STAGE/etc/han/menu-day.tmux" <<'EOF'
display-menu -T "#[align=centre] 생활 · Daily " -x C -y C \
  "일정      Calendar       calcurse" c "new-window -n cal 'han-run calcurse'" \
  "표 계산   Spreadsheet    sc-im"    s "new-window -n sheet 'han-run sc-im'" \
  "주소록    Addresses      abook"    a "new-window -n abook 'han-run abook'" \
  "음악      Music          cmus"     m "new-window -n music 'han-run cmus'" \
  "책 읽기   Book           F11"      b "run-shell \"/usr/local/lib/han/bookpane toggle '#{window_id}'\"" \
  "사전      Dictionary     Alt+D"    d "display-popup -E -B -x 0 -y 0 -w 100% -h 100% 'dic --pick'" \
  "주일 성경 Sunday Bible   bib"      e "new-window -n bib 'han-run bib'" \
  "오늘 말씀 Daily Bible    bibt"     t "new-window -n bibt 'han-run bibt'" \
  "성경 읽기 Read Bible     bibr"     r "new-window -n bibr 'han-run bibr'" \
  "" \
  ", 뒤로    Back"                    "," "source-file /etc/han/menu.tmux" \
  "닫기      Close menu     F1"       F1 ""
EOF
	cat > "$STAGE/etc/han/menu-fun.tmux" <<'EOF'
display-menu -T "#[align=centre] 놀이 · Fun " -x C -y C \
  "도스 게임   DOS games    dosbox"  o "new-window -n dos 'hdos'" \
  "어드벤처    Adventure    scummvm" v "new-window -n scummvm 'scummvm'" \
  "던전        NetHack"              g "new-window -n game 'han-run nethack'" \
  "" \
  ", 뒤로      Back"                 "," "source-file /etc/han/menu.tmux" \
  "닫기        Close menu   F1"      F1 ""
EOF
	cat > "$STAGE/etc/han/menu-sys.tmux" <<'EOF'
display-menu -T "#[align=centre] 시스템 · System " -x C -y C \
  "무선랜      Wi-Fi          F5"    k "new-window -n wifi 'hwifi'" \
  "블루투스    Bluetooth      F8"    b "new-window -n bt 'hbt'" \
  "폰 키보드   Phone keyboard hkb"   p "new-window -n phone 'han-run hkb; printf \"Enter \"; read x'" \
  "USB 연결    USB stick"            u "new-window -n usb 'husb; printf \"Enter \"; read x'" \
  "시스템      System         btop"  h "new-window -n system 'han-run btop'" \
  "디스크      Disk usage     ncdu"  d "new-window -n disk 'han-run ncdu /'" \
  "화면 잠금   Lock screen    vlock" l "new-window -n lock 'vlock -a'" \
  "더 설치하기 Add more       had"   a "new-window -n add 'had; exec $SHELL'" \
  "" \
  ", 뒤로      Back"                 "," "source-file /etc/han/menu.tmux" \
  "닫기        Close menu   F1"      F1 ""
EOF

	cat > "$STAGE/usr/local/bin/had" <<'EOF'
#!/bin/sh
# had: add an optional program.   had          the list
#   had NAME       install it (offline from the ISO when it is there)
#   had --hint X   say how to get program X (used by the desktop)
#   hadr NAME      remove it again (hadr is a link to had)
# han-add is the old name of this command (han-add x = had firefox).
mem="$(awk '/MemTotal/ { printf "%d", $2 / 1024 }' /proc/meminfo)"
avail="$(awk '/MemAvailable/ { printf "%d", $2 / 1024 }' /proc/meminfo)"
MESA="mesa-egl mesa-gbm mesa-dri-gallium"

say() { printf '%s (%s)\n' "$1" "$2"; }
pause() { printf 'Enter 를 누르세요 (press Enter) '; read -r _; }
need_root() { [ "$(id -u)" = 0 ] || { say "root 로 실행하세요" "run as root"; exit 1; }; }
live() { awk '$2 == "/" && $3 == "tmpfs" { f = 1 } END { exit !f }' /proc/mounts; }
online() { # the USB stick only has what the ISO carries: add Alpine's mirror
	v="$(cut -d. -f1,2 /etc/alpine-release)"
	grep -q '^https\{0,1\}://' /etc/apk/repositories 2>/dev/null ||
		printf 'https://dl-cdn.alpinelinux.org/alpine/v%s/%s\n' \
			"$v" main "$v" community >> /etc/apk/repositories
	apk update >/dev/null 2>&1 ||
		{ say "인터넷에 연결되어 있지 않습니다. F5 로 무선랜을 켜세요" \
		      "no internet: F5 for Wi-Fi, or a cable"; exit 1; }
}
# install from the ISO's own repository first (no Wi-Fi needed), else online
get() {
	if apk add --no-network "$@" >/dev/null 2>&1; then :
	else
		online
		apk add "$@" >/dev/null 2>&1 ||
			{ say "설치하지 못했습니다: $*" "could not install"; exit 1; }
	fi
	# keep this ISO's own builds (r900, e.g. NetSurf with Korean) on upgrades
	[ -x /etc/local.d/han-kpin.start ] && /etc/local.d/han-kpin.start
	say "설치했습니다: $*" "installed"
}
# RAM check for the live USB: everything installed sits in memory
room() { # MB
	live || return 0
	say "라이브 USB: 다시 켜면 없어지고, 쓰는 동안 메모리를 차지합니다" \
	    "live USB: gone after a reboot, uses memory while there"
	say "hinst 로 디스크에 설치한 뒤에 쓰면 좋습니다" "best after hinst"
	# the live root is a RAM disk with its own size limit: the smaller counts
	free="$(df -Pm / | awk 'NR == 2 { print $4 }')"
	[ "${free:-0}" -lt "$avail" ] || free="$avail"
	if [ "$free" -lt "$(($1 + 50))" ] && [ "${FORCE:-}" != 1 ]; then
		say "자리가 모자랍니다: 남은 자리 ${free} MB, 필요 약 $1 MB" \
		    "not enough room: ${free} MB free, about $1 MB needed"
		say "그래도 하려면: FORCE=1 had $name" "to try anyway: FORCE=1 had $name"
		exit 1
	fi
}
# [v] when the real program is there (not just Aneuu's launcher of that name)
mark() { if [ -e "$1" ] || { [ "${1#/}" = "$1" ] && command -v "$1" >/dev/null 2>&1; }; then echo "[v]"; else echo "[ ]"; fi; }

list() {
	cat <<LIST
더 설치하기 (add more):  had 이름 (had NAME)          메모리 (memory)
$(mark /usr/bin/netsurf-framebuffer) netsurf   넷서프: 그림이 보이는 웹 브라우저               약 250 MB
              (NetSurf: web browser with pictures)
$(mark /usr/bin/dosbox) dosbox    도스박스: 옛 도스 프로그램 실행기, 게임은 따로  약 250 MB
              (DOSBox: runs old DOS programs; games not included)
$(mark /usr/bin/scummvm) scummvm   스컴브이엠: 어드벤처 게임 실행기, 게임은 따로   약 260 MB
              (ScummVM: old adventure games; games not included)
$(mark /usr/bin/firefox-esr) firefox   파이어폭스: X 화면과 함께, 무거움, 인터넷 필요  2 GB 이상
              (Firefox with X: heavy, needs internet)
$(mark /etc/mpv/mpv.conf) hwdec     영상 하드웨어 가속                              약 20 MB
              (hardware video decoding)
$(mark hwp5txt) hwp       한글(HWP) 문서 열기, 인터넷 필요
              (open HWP files; needs internet)
$(mark tesseract) ocr       스캔한 PDF 읽기, 인터넷 필요                    약 40 MB
              (read scanned PDFs; needs internet)
    yt        유튜브가 안 될 때 yt-dlp 새로 받기
              (update yt-dlp when YouTube stops working)
    net       알파인 온라인 저장소 쓰기 (Alpine's online packages)

netsurf, dosbox, scummvm 은 그래픽 부분(Mesa, 약 230 MB)을 함께 씁니다.
(They share one graphics part, Mesa: about 230 MB, counted once.)
메모리 (memory): ${mem} MB, 남음 (free): ${avail} MB.  [v] = 설치됨 (installed)
빼기 (remove):  hadr 이름 (hadr NAME)
LIST
}

name="${1:-}"
case "$name" in
	넷서프|브라우저) name=netsurf ;;
	도스박스|도스) name=dosbox ;;
	스컴브이엠|게임) name=scummvm ;;
	파이어폭스|x|X) name=firefox ;;
	한글문서) name=hwp ;;
esac

# hadr NAME: remove what had NAME installed. Mesa goes only when no other
# program that draws through SDL (netsurf, dosbox, scummvm) still needs it.
if [ "${0##*/}" = hadr ]; then
	inst() { apk info -e "$1" >/dev/null 2>&1; }
	del() { # only the parts that are installed
		_l=""
		for _p in "$@"; do inst "$_p" && _l="$_l $_p"; done
		[ -n "$_l" ] || return 0
		apk del $_l >/dev/null 2>&1 ||
			{ say "빼지 못했습니다:$_l" "could not remove"; exit 1; }
	}
	mesa_free() {
		inst netsurf-framebuffer || inst dosbox-staging || inst scummvm || del $MESA
	}
	case "$name" in
	"")
		say "빼기: hadr 이름" "remove: hadr NAME"
		for b in netsurf:netsurf-framebuffer dosbox:dosbox-staging scummvm:scummvm \
			firefox:firefox-esr hwdec:libva-intel-driver hwdec:mesa-va-gallium \
			hwp:py3-olefile ocr:tesseract-ocr; do
			inst "${b#*:}" && printf '  %s\n' "${b%%:*}"
		done | sort -u
		say "(위는 설치되어 있는 것)" "(the ones above are installed)"
		exit 0 ;;
	netsurf) need_root; del netsurf-framebuffer; mesa_free ;;
	dosbox)  need_root; del dosbox-staging; mesa_free ;;
	scummvm) need_root; del scummvm; mesa_free ;;
	hwdec)
		need_root
		del libva-intel-driver intel-media-driver mesa-va-gallium
		sed -i '/^hwdec=vaapi-copy$/d' /etc/mpv/mpv.conf 2>/dev/null
		[ -s /etc/mpv/mpv.conf ] || rm -f /etc/mpv/mpv.conf ;;
	firefox)
		need_root
		del firefox-esr xinit openbox setxkbmap xsetroot font-noto-cjk \
			fcitx5 fcitx5-hangul fcitx5-gtk ;;
	hwp)
		need_root
		pip uninstall -y --break-system-packages pyhwp >/dev/null 2>&1
		del py3-pip py3-lxml py3-olefile ;;
	ocr)
		need_root
		del tesseract-ocr tesseract-ocr-data-kor tesseract-ocr-data-eng ;;
	*)
		say "뺄 수 없는 이름: $name" "nothing to remove by that name"
		exit 1 ;;
	esac
	say "뺐습니다: $name" "removed"
	say "메모리 남음: $(awk '/MemAvailable/ { printf "%d", $2 / 1024 }' /proc/meminfo) MB" "free memory"
	exit 0
fi

case "$name" in
--hint)
	p="${2:-}"
	case "$p" in
		netsurf|netsurf-framebuffer) b=netsurf ;;
		dosbox) b=dosbox ;;
		scummvm) b=scummvm ;;
		firefox|firefox-esr|xinit) b=firefox ;;
		*) b="" ;;
	esac
	say "$p 은(는) 설치되어 있지 않습니다" "$p is not installed"
	if [ -n "$b" ]; then
		say "설치: root 로  had $b" "install: as root, had $b"
	else
		say "찾아보기: had   또는  apk add $p" "see: had, or apk add $p"
	fi
	pause
	exit 1 ;;
netsurf)
	need_root; room 250
	get netsurf-framebuffer $MESA
	say "F1 메뉴에서 열거나  netsurf  라고 치세요" "open it from F1, or type netsurf" ;;
dosbox)
	need_root; room 250
	get dosbox-staging $MESA
	say "시작: hdos  (~/dos 가 C: 드라이브)" "start: hdos (~/dos is drive C:)" ;;
scummvm)
	need_root; room 260
	get scummvm $MESA
	say "시작: F1 메뉴 또는 scummvm" "start: F1 menu, or scummvm"
	say "무료 게임: https://www.scummvm.org/games/" "free games: scummvm.org/games" ;;
hwdec)
	need_root
	v="$(cat /sys/class/drm/card0/device/vendor 2>/dev/null)"
	case "$v" in
		0x8086) room 20; get libva-intel-driver
		        apk add --no-network intel-media-driver >/dev/null 2>&1 ||
		        apk add intel-media-driver >/dev/null 2>&1 || true ;;
		0x1002) room 240; get mesa-va-gallium ;;
		*) say "이 그래픽 칩은 하드웨어 가속을 지원하지 않습니다 ($v)" \
		       "no hardware decoding for this graphics chip"; exit 1 ;;
	esac
	mkdir -p /etc/mpv
	grep -q '^hwdec=' /etc/mpv/mpv.conf 2>/dev/null ||
		echo 'hwdec=vaapi-copy' >> /etc/mpv/mpv.conf
	say "이제 영상 재생에 그래픽 칩을 씁니다 (mpv hwdec=vaapi-copy)" \
	    "videos now decode on the graphics chip" ;;
firefox)
	need_root
	online
	say "이 컴퓨터 메모리: $mem MB" "memory"
	if [ "$mem" -lt 1900 ] && [ "${2:-}" != --force ]; then
		say "파이어폭스는 2 GB 는 있어야 쓸 만합니다. 설치하지 않았습니다" \
		    "a full browser needs about 2 GB: not installed"
		say "w3m 이나 넷서프(had netsurf)를 쓰세요. 그래도 하려면: had firefox --force" \
		    "use w3m or NetSurf; to install anyway: had firefox --force"
		exit 1
	fi
	setup-xorg-base >/dev/null 2>&1 || say "setup-xorg-base 에 문제가 있었습니다" "setup-xorg-base reported a problem"
	# ESR: fewer updates and steadier memory use; Alpine builds it for x86 too
	get xinit openbox firefox-esr setxkbmap xsetroot font-noto-cjk \
		fcitx5 fcitx5-hangul fcitx5-gtk
	if [ "$mem" -lt 3900 ] && [ ! -x /etc/local.d/han-zram.start ]; then
		# Compressed swap in memory, half the RAM, at every boot
		cat > /etc/local.d/han-zram.start <<ZRAM
#!/bin/sh
modprobe zram 2>/dev/null || exit 0
[ -e /sys/block/zram0/disksize ] || exit 0
swapon 2>/dev/null | grep -q zram0 && exit 0
echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null
echo $((mem / 2))M > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null && swapon -p 100 /dev/zram0
ZRAM
		chmod 755 /etc/local.d/han-zram.start
		rc-update add local default >/dev/null 2>&1
		sh /etc/local.d/han-zram.start
		say "4 GB 아래: 압축 스왑을 켰습니다. 탭은 한두 개만" "under 4 GB: compressed swap is on; keep to one or two tabs"
	fi
	say "시작: hx firefox  (파이어폭스를 닫으면 콘솔로 돌아옵니다)" "start: hx firefox" ;;
hwp)
	need_root; online
	get py3-pip py3-lxml py3-olefile
	if pip install --break-system-packages pyhwp >/dev/null 2>&1; then
		say "HWP 파일 열기: hb FILE.hwp 또는 nnn 에서 Enter" "open HWP files: hb FILE.hwp"
	else
		say "pyhwp 를 설치하지 못했습니다" "could not install pyhwp"
	fi ;;
ocr)
	need_root; online
	get tesseract-ocr tesseract-ocr-data-kor tesseract-ocr-data-eng
	say "hb SCAN.pdf 로 스캔한 PDF 를 읽습니다 (옛 노트북에서는 느림)" "hb SCAN.pdf reads scanned PDFs (slow)" ;;
yt)
	need_root; online
	say "지금 yt-dlp: $(yt-dlp --version 2>/dev/null)" "yt-dlp now"
	apk upgrade yt-dlp >/dev/null 2>&1
	say "새 yt-dlp: $(yt-dlp --version 2>/dev/null)" "yt-dlp after the update" ;;
net)
	need_root; online
	say "알파인 온라인 저장소를 씁니다: apk search 이름, apk add 이름" \
	    "Alpine's online packages are ready: apk search NAME, apk add NAME" ;;
"")
	list ;;
*)
	say "모르는 이름: $name" "unknown name"
	list; exit 1 ;;
esac
EOF
	ln -sf had "$STAGE/usr/local/bin/han-add"   # the old name
	ln -sf had "$STAGE/usr/local/bin/hadr"      # hadr NAME: remove
	# the old, hyphenated names (hyphens are hard to type)
	for _o in dos wifi bt usb inst fb; do ln -sf "h$_o" "$STAGE/usr/local/bin/han-$_o"; done

	# Settings for every login: nnn opens files with han-view
	mkdir -p "$STAGE/etc/profile.d"
	cat > "$STAGE/etc/profile.d/han.sh" <<'EOF'
export EDITOR=nano VISUAL=nano PAGER=less LESSCHARSET=utf-8
export NNN_OPENER=/usr/local/bin/han-view NNN_OPTS=c
EOF

	# Laptop buttons: power button = clean power off (Alpine's default
	# would suspend); closing the lid on battery = suspend.
	mkdir -p "$STAGE/etc/acpi"
	cat > "$STAGE/etc/acpi/handler.sh" <<'EOF'
#!/bin/sh
PATH="/usr/share/acpid:$PATH"
case "$1:$2:$3:$4" in
button/power:*)          logger -t acpid 'Power button'; poweroff ;;
button/sleep:SLPB:*)     suspend ;;
button/lid:*:close:*)    power-supply-ac || suspend ;;
ac_adapter:*:*:*0)       lid-closed && suspend ;;
esac
exit 0
EOF
	chmod 755 "$STAGE/etc/acpi/handler.sh"

	cat > "$STAGE/usr/local/bin/han-view" <<'EOF'
#!/bin/sh
# Open any file with the right console program:  han-view FILE
# (nnn uses it for Enter). PDF, EPUB, Word, HWP(X), LibreOffice, pictures,
# video, music, web pages, archives, text.
f="${1:-}"
ko=no; [ -n "${HAN_ACTIVE:-}" ] && ko=yes
say() { if [ $ko = yes ]; then echo "$1"; else echo "$2"; fi; }
[ -n "$f" ] && [ -e "$f" ] || { say "쓰는 법: han-view 파일" "Usage: han-view FILE"; exit 1; }
[ -d "$f" ] && exec nnn "$f"
pager() { less -c -R -P "${f##*/}  (q $( [ $ko = yes ] && echo 닫기 || echo close))"; }
# Word-style XML inside a zip: a paragraph per line, tags removed
xmltext() { # zip-file member-pattern paragraph-end-tag
	unzip -p "$1" "$2" 2>/dev/null |
	sed -e "s#</$3>#\n#g" -e 's/<[^>]*>//g' -e 's/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&apos;/'"'"'/g; s/&amp;/\&/g'
}
ext="$(echo "${f##*.}" | tr 'A-Z' 'a-z')"
case "$ext" in
	pdf)              exec fbgs "$f" ;;
	epub)             exec hb "$f" ;;
	fb2|mobi|azw|azw3) exec epy "$f" ;;
	docx)             xmltext "$f" word/document.xml 'w:p' | pager ;;
	hwpx)             xmltext "$f" 'Contents/section*.xml' 'hp:p' | pager ;;
	hwp)
		if command -v hwp5txt >/dev/null 2>&1; then hwp5txt "$f" | pager
		else say "HWP 파일을 열려면 먼저: had hwp   (HWPX 는 바로 열립니다)" \
		         "For HWP files first run: had hwp"; read -r _; fi ;;
	odt|ods|odp|sxw)  odt2txt "$f" | pager ;;
	doc)              antiword "$f" | pager ;;
	rtf)              unrtf --text "$f" 2>/dev/null | pager ;;
	xlsx|xls|csv|sc)  exec sc-im "$f" ;;
	wg)               exec han "$f" ;;
	htm|html)         exec w3m "$f" ;;
	jpg|jpeg|png|gif|bmp|tif|tiff|webp) exec fbi "$f" ;;
	mp4|mkv|avi|webm|mov|wmv|flv|mpg|mpeg|m4v) exec mpv "$f" ;;
	mp3|ogg|oga|opus|flac|wav|m4a|aac|wma) exec /usr/bin/mpv --no-video "$f" ;;
	zip)              unzip -l "$f" | pager ;;
	7z|rar|tar|gz|xz|bz2|zst|tgz) 7z l "$f" | pager ;;
	*)
		case "$(file -b --mime-type "$f")" in
			text/*|*json|*xml|*empty) exec nano "$f" ;;
			image/*) exec fbi "$f" ;;
			video/*) exec mpv "$f" ;;
			audio/*) exec /usr/bin/mpv --no-video "$f" ;;
			*) say "이 파일은 열 수 없습니다: $(file -b "$f")" "Cannot open this file: $(file -b "$f")"
			   read -r _ ;;
		esac ;;
esac
EOF

	cat > "$STAGE/usr/local/bin/yt" <<'EOF'
#!/bin/sh
# yt: YouTube on the console:  yt WORDS   (search, pick a number, it plays)
#   number      video, full screen (360p: light for old laptops)
#   number + s  sound only, here (music, talks)   e.g. 3s
#   an address  play that video or live stream (yt https://youtu.be/...)
# Live streams show LIVE instead of a length and play as they go.
ko=no; [ -n "${HAN_ACTIVE:-}" ] && ko=yes
say() { if [ $ko = yes ]; then echo "$1"; else echo "$2"; fi; }
L="/tmp/han-yt.$$"; trap 'rm -f "$L"' EXIT
q="$*"
search() {
	while :; do
		if [ -z "$q" ]; then
			say "찾을 말 (q 끝내기):" "Search for (q quits):"; printf '> '; read -r q
			case "$q" in q|Q|ㅂ|ㅃ|"") exit 0 ;; esac   # q, also typed in Korean
		fi
		say "찾는 중..." "Searching..."
		case "$q" in http://*|https://*)      # an address: just that one
			yt-dlp --flat-playlist --print '%(id)s|%(duration_string)s|%(live_status)s|%(title)s' \
				"$q" 2>/dev/null | head -n 1 > "$L"
			[ -s "$L" ] || printf '%s|?|?|%s\n' "$q" "$q" > "$L"
			return ;;
		esac
		yt-dlp --flat-playlist --print '%(id)s|%(duration_string)s|%(live_status)s|%(title)s' \
			"ytsearch12:$q" > "$L" 2>/dev/null
		[ -s "$L" ] && return
		say "찾지 못했습니다 (인터넷 연결?)" "Nothing found (are you online?)"; q=""
	done
}
search
while :; do
	echo
	# number yellow, length cyan, title in the normal colour
	awk -F'|' '{ t = $0; sub(/^[^|]*\|[^|]*\|[^|]*\|/, "", t)
		if ($3 == "is_live") printf "\033[1;33m%3d)\033[0m \033[1;31m%8s\033[0m  %s\n", NR, "LIVE", t
		else printf "\033[1;33m%3d)\033[0m \033[36m%8s\033[0m  %s\n", NR, $2, t }' "$L"
	say "번호 = 영상, 번호s = 소리만 (예: 3s), 다른 말 = 새로 찾기, q = 끝" \
	    "number = video, numbers = sound only (e.g. 3s), words = new search, q = quit"
	printf '> '; read -r a
	case "$a" in   # Korean input on: q is ㅂ, 3s is 3ㄴ
		q|Q|ㅂ|ㅃ|"") exit 0 ;;
		*[0-9]s|*[0-9]S|*[0-9]ㄴ) n="${a%%[!0-9]*}"; snd=yes ;;
		*[!0-9]*) q="$a"; search
		          case "$q" in http://*|https://*) n=1; snd=no ;; *) continue ;; esac ;;
		*) n="$a"; snd=no ;;
	esac
	case "$n" in *[!0-9]*) q="$a"; search; continue ;; esac
	id="$(sed -n "${n}p" "$L" | cut -d'|' -f1)"
	live="$(sed -n "${n}p" "$L" | cut -d'|' -f3)"
	[ -n "$id" ] || continue
	case "$id" in http*) u="$id" ;; *) u="https://www.youtube.com/watch?v=$id" ;; esac
	# yt-dlp fetches the video itself and hands it to mpv: YouTube refuses
	# (403) when mpv fetches the address on its own
	E=/tmp/han-yt.err; : > "$E"; rm -f /tmp/han-yt.formats
	say "여는 중..." "Opening..."
	if [ $snd = yes ]; then
		say "소리만 재생: Space 멈춤, q 끝" "Sound only: Space pauses, q stops"
		if [ "$live" = is_live ]; then
			for f in 'ba/b' 'best*' 'bv*+ba'; do
				yt-dlp -q --no-warnings -g -f "$f" "$u" > /tmp/han-yt.url 2> /tmp/han-yt.try && [ -s /tmp/han-yt.url ] && break
			done
			if [ -s /tmp/han-yt.url ]; then
				/usr/bin/mpv --no-video --no-ytdl --really-quiet "$(tail -n 1 /tmp/han-yt.url)"
			else
				cat /tmp/han-yt.try >> "$E"
			fi
		else
			yt-dlp -q --no-warnings -f 'ba/b' -o - "$u" 2> "$E" | /usr/bin/mpv --no-video --no-ytdl --really-quiet -
		fi
	else
		say "영상: q 끝, Tab 데스크톱으로 (소리는 계속, 이 창에서 v 나 Alt+V 로 돌아옴)" \
		    "Video: q stops, Tab back to the desktop (sound goes on; v here or Alt+V returns)"
		sleep 1
		# 18: 360p with sound in one file, light enough for old laptops
		if [ "$live" = is_live ]; then          # live: the stream at up to 480p
			hfb /usr/local/lib/han/ytplay 'live:b[height<=480]/b' "$u"
		else
			hfb /usr/local/lib/han/ytplay '18/b[height<=480]/b' "$u"
		fi
	fi
	# When you stop a video, yt-dlp ends with "Broken pipe": that is no error
	sed -i -E '/[Bb]roken pipe|Errno 32|Interrupted/d' "$E" 2>/dev/null
	if grep -q 'not a bot' "$E" 2>/dev/null; then
		say "유튜브가 이 인터넷 주소를 잠시 막았습니다 (\"로봇이 아닌지 확인\")." \
		    "YouTube is blocking this internet address for now (\"confirm you're not a bot\")."
		say "VPN 을 쓰고 있으면 끄고, 아니면 얼마 뒤 다시 해 보세요." \
		    "If you use a VPN, turn it off; otherwise try again later."
		printf 'Enter '; read -r _
	elif grep -q 'ERROR' "$E" 2>/dev/null; then
		say "이 영상을 열지 못했습니다. yt-dlp 가 한 말:" "Could not open this video. yt-dlp said:"
		grep 'ERROR' "$E" | tail -n 4
		[ -s /tmp/han-yt.formats ] && say "이 방송이 내놓은 형식: less /tmp/han-yt.formats" \
		    "Formats this stream offers: less /tmp/han-yt.formats"
		say "모든 영상이 안 되면, 인터넷 연결 뒤 (root)  had yt" \
		    "If no video plays, when online (as root):  had yt"
		printf 'Enter '; read -r _
	fi
done
EOF
	chmod 755 "$STAGE/usr/local/bin/han-view" "$STAGE/usr/local/bin/yt"
	ln -sf yt "$STAGE/usr/local/bin/han-yt"      # the old, longer name
	ln -sf han-view "$STAGE/usr/local/bin/hv"   # short name
	cat > "$STAGE/usr/local/lib/han/ytplay" <<'EOF'
#!/bin/sh
# ytplay FORMAT URL: play a YouTube video full screen (used by yt)
# ytplay live:FORMAT URL: a live stream; mpv plays the stream's address itself
case "$1" in live:*)
	# A live stream's formats differ from video to video: try the asked one,
	# then any single stream, then picture and sound apart; an error is shown
	# only when none of them works.
	E=/tmp/han-yt.err; T=/tmp/han-yt.try
	for f in "${1#live:}" 'b' 'bv*[height<=480]+ba/bv*+ba' 'best*'; do
		yt-dlp -q --no-warnings -g -f "$f" "$2" > /tmp/han-yt.url 2> "$T" && [ -s /tmp/han-yt.url ] && break
	done
	v="$(sed -n 1p /tmp/han-yt.url)"; a="$(sed -n 2p /tmp/han-yt.url)"
	if [ -z "$v" ]; then
		cat "$T" >> "$E"
		yt-dlp -q --no-warnings -F "$2" > /tmp/han-yt.formats 2>&1
		exit 1
	fi
	exec /usr/bin/mpv --vo=drm --no-ytdl --really-quiet --log-file=/tmp/hfb.log \
		${a:+--audio-file="$a"} \
		${HAN_MPV_INPUT:+--input-conf="$HAN_MPV_INPUT"} \
		${HAN_MPV_SOCK:+--input-ipc-server="$HAN_MPV_SOCK"} "$v" ;;
esac
yt-dlp -q --no-warnings -f "$1" -o - "$2" 2>> /tmp/han-yt.err |
	exec /usr/bin/mpv --vo=drm --no-ytdl --really-quiet --log-file=/tmp/hfb.log \
		${HAN_MPV_INPUT:+--input-conf="$HAN_MPV_INPUT"} \
		${HAN_MPV_SOCK:+--input-ipc-server="$HAN_MPV_SOCK"} -
EOF
	chmod 755 "$STAGE/usr/local/lib/han/ytplay"
	# WordGrinder with Aneuu's settings: yes/no questions (like "save
	# before quitting?") also take the Hangul keys on Y and N, so Korean
	# input need not be switched off first. Your own startup.lua still loads.
	# cmus: no D-Bus session on the console, so its MPRIS part only gives
	# "error initializing MPRIS" at start. Turn it off in the user's rc.
	# Podcasts: pod finds a podcast by name, lists its episodes and plays one
	# in the background (mpv with a control socket); Alt+P shows the player.
	cat > "$STAGE/usr/local/bin/pod" <<'PODPY'
#!/usr/bin/env python3
# pod: podcasts, simply.
#   pod              your podcasts; pick a number, then an episode
#   pod WORDS        find a podcast by name and subscribe (e.g. pod this american life)
# The episode plays in the background and pod ends: go on working. Alt+P shows the
# player (Space pause, Left/Right 10 s, 9 0 volume, s faster, q stop); Alt+P or Esc
# hides it again. Where you stopped is remembered.
#   pod --player     the player panel (what Alt+P opens)
import curses, json, os, re, socket, subprocess, sys, time, urllib.parse, urllib.request
from xml.etree import ElementTree as ET

KO = bool(os.environ.get("HAN_ACTIVE"))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "han")
SUBS = os.path.join(CONF, "podcasts")
SOCK = "/tmp/han-pod.sock"
LOG = "/tmp/han-pod.log"
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) pod/1.0"}
Y, C, D, R = "\033[1;33m", "\033[36m", "\033[2m", "\033[0m"


def say(ko, en):
    return ko if KO else en


def get(url, timeout=20):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def load_subs():
    try:
        rows = [l.rstrip("\n").split("\t") for l in open(SUBS, encoding="utf-8")]
        return [(r[0], r[1]) for r in rows if len(r) >= 2]
    except OSError:
        return []


def save_subs(subs):
    os.makedirs(CONF, exist_ok=True)
    with open(SUBS, "w", encoding="utf-8") as f:
        for t, u in subs:
            f.write(f"{t}\t{u}\n")


def ask(prompt):
    try:
        return input(prompt).strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return "q"


def search(words):
    """Podcasts by name (Apple's podcast directory): [(title, author, feed)]"""
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"media": "podcast", "limit": 12, "term": words})
    data = json.loads(get(url))
    return [(r.get("collectionName", "?"), r.get("artistName", ""), r["feedUrl"])
            for r in data.get("results", []) if r.get("feedUrl")]


def subscribe(words, subs):
    print(say("찾는 중...", "Searching..."))
    try:
        found = search(words)
    except Exception as e:
        print(say(f"찾지 못했습니다 (인터넷 연결?): {e}", f"Search failed (online?): {e}"))
        return
    if not found:
        print(say("없습니다. 다른 말로 찾아 보세요.", "Nothing found. Try other words."))
        return
    print()
    for i, (t, a, _) in enumerate(found, 1):
        print(f"{Y}{i:3d}){R} {t}  {D}{a}{R}")
    a = ask(say("구독할 번호 (Enter 취소) > ", "Number to subscribe (Enter cancels) > "))
    if a.isdigit() and 1 <= int(a) <= len(found):
        t, _, u = found[int(a) - 1]
        if u not in (s[1] for s in subs):
            subs.append((t, u))
            save_subs(subs)
        print(say(f"구독했습니다: {t}", f"Subscribed: {t}"))


def episodes(feed):
    root = ET.fromstring(get(feed, 40))
    it = "{http://www.itunes.com/dtds/podcast-1.0.dtd}"
    out = []
    for item in root.iter("item"):
        enc = item.find("enclosure")
        if enc is None or not enc.get("url"):
            continue
        date = (item.findtext("pubDate") or "").strip()
        m = re.search(r"(\d{1,2}) (\w{3}) (\d{4})", date)
        mon = "JanFebMarAprMayJunJulAugSepOctNovDec"
        date = (f"{m.group(3)}-{mon.find(m.group(2)) // 3 + 1:02d}-{int(m.group(1)):02d}"
                if m and m.group(2) in mon else date[:10])
        dur = (item.findtext(it + "duration") or "").strip()
        if dur.isdigit():
            s = int(dur)
            dur = f"{s // 3600}:{s // 60 % 60:02d}:{s % 60:02d}" if s >= 3600 else f"{s // 60}:{s % 60:02d}"
        out.append(((item.findtext("title") or "?").strip(), date, dur, enc.get("url")))
    return out


def mpv(*cmd):
    """Send a command to the playing mpv; its answer, or None."""
    try:
        c = socket.socket(socket.AF_UNIX)
        c.settimeout(1)
        c.connect(SOCK)
        c.sendall(json.dumps({"command": list(cmd)}).encode() + b"\n")
        data = b""
        while not data.endswith(b"\n"):
            part = c.recv(4096)
            if not part:
                break
            data += part
        c.close()
        for line in data.decode("utf-8", "replace").splitlines():
            m = json.loads(line)
            if "error" in m:
                return m.get("data") if m["error"] == "success" else None
    except (OSError, ValueError):
        return None


def playing():
    return os.path.exists(SOCK) and mpv("get_property", "pid") is not None


def final_url(url):
    """Follow the episode's redirects (trackers) here, so mpv has one address."""
    for _ in range(2):
        try:
            req = urllib.request.Request(url, headers=UA, method="HEAD")
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.geturl()
        except Exception:
            time.sleep(1)
    return url


def play(title, url, again=True):
    if playing():
        mpv("quit-watch-later")
        time.sleep(0.5)
    try:
        os.remove(SOCK)
    except OSError:
        pass
    print(say("여는 중...", "Opening..."))
    real = final_url(url)
    cmd = ["/usr/bin/mpv", "--no-video", "--no-terminal", "--save-position-on-quit",
           "--input-ipc-server=" + SOCK, "--log-file=" + LOG,
           "--force-media-title=" + title, real]
    p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(40):                          # up to 20 s for the first sound
        time.sleep(0.5)
        if p.poll() is not None:
            break
        if mpv("get_property", "time-pos") is not None:
            print(say(f"듣는 중: {title}\n  다른 일을 해도 계속됩니다. Alt+P 로 보기 (멈춤, 넘기기, 끝)",
                      f"Playing: {title}\n  It goes on while you work. Alt+P shows it (pause, skip, stop)"))
            return True
    if p.poll() is None:
        print(say("아직 소리가 나지 않습니다 (느린 연결?). 잠시 기다리거나 Alt+P 로 보세요.",
                  "No sound yet (slow connection?). Wait a little, or look with Alt+P."))
        return True
    try:
        errs = [l.split("]", 2)[-1].strip() for l in open(LOG, encoding="utf-8", errors="replace")
                if "][e]" in l or "][f]" in l]
    except OSError:
        errs = []
    if again and any("resolve" in e or "Try again" in e for e in errs):
        print(say("인터넷 주소를 찾지 못했습니다. 한 번 더 해 봅니다...",
                  "Could not look up the address. Trying once more..."))
        time.sleep(2)
        return play(title, url, again=False)
    print(say("이 회차를 틀지 못했습니다. mpv 가 한 말:", "Could not play this episode. mpv said:"))
    for e in errs[-3:] or ["?"]:
        print("  " + (e if len(e) < 160 else e[:157] + "..."))


def clock(s):
    if s is None:
        return "--:--"
    s = int(s)
    return f"{s // 3600}:{s // 60 % 60:02d}:{s % 60:02d}" if s >= 3600 else f"{s // 60}:{s % 60:02d}"


def player(scr):
    """The panel Alt+P shows: what plays, where, and the keys."""
    curses.curs_set(0)
    scr.timeout(500)
    keys = say("Space 멈춤  ← → 10초  9 0 소리", "Space pause  Left/Right 10 s  9 0 volume")
    keys2 = say("s 빠르게 (1.1 ~ 1.8, 여섯 단계)  q 끝", "s faster (1.1 ... 1.8, 6 steps)  q stop")
    hide = say("Alt+P 나 Esc: 숨기기 (소리는 계속)", "Alt+P or Esc: hide (it keeps playing)")
    while True:
        if not playing():
            return
        title = mpv("get_property", "media-title") or ""
        pos, dur = mpv("get_property", "time-pos"), mpv("get_property", "duration")
        paused, vol = mpv("get_property", "pause"), mpv("get_property", "volume")
        state = say(" (멈춤)", " (paused)") if paused else ""
        speed = mpv("get_property", "speed") or 1
        if abs(speed - 1) > 0.01:
            state += f"  {speed:.2f}x"
        scr.erase()
        h, w = scr.getmaxyx()
        for y, text in enumerate([title, f"{clock(pos)} / {clock(dur)}{state}   vol {int(vol or 0)}%",
                                  keys, keys2, hide]):
            if y < h:
                try:
                    scr.addstr(y, 0, text[:max(1, w - 1)])
                except curses.error:
                    pass
        scr.refresh()
        k = scr.getch()
        if k == 0xE3:                     # Korean input on: ㅂ ㄴ arrive as 3 bytes
            b = bytes([k, scr.getch() & 0xFF, scr.getch() & 0xFF]).decode("utf-8", "replace")
            k = {"ㅂ": ord("q"), "ㄴ": ord("s")}.get(b, -1)
        if k == 27:
            scr.timeout(50)
            n = scr.getch()
            scr.timeout(500)
            if n in (-1, ord("p"), ord("P")):
                return
            k = {ord("[") : -1}.get(n, -1)
        if k == ord(" "):
            mpv("cycle", "pause")
        elif k in (curses.KEY_LEFT, ord("h")):
            mpv("seek", -10)
        elif k in (curses.KEY_RIGHT, ord("l")):
            mpv("seek", 10)
        elif k == ord("9"):
            mpv("add", "volume", -5)
        elif k == ord("0"):
            mpv("add", "volume", 5)
        elif k in (ord("s"), ord("S")):      # faster: 1.1 1.25 1.35 1.45 1.65 1.8, then normal
            mpv("cycle-values", "speed", "1.1", "1.25", "1.35", "1.45", "1.65", "1.8", "1")
        elif k in (ord("q"), ord("Q")):
            mpv("quit-watch-later")
            return


def show_episodes(title, feed):
    print(say("받는 중...", "Loading..."))
    try:
        eps = episodes(feed)
    except Exception as e:
        print(say(f"이 팟캐스트를 열지 못했습니다: {e}", f"Cannot open this podcast: {e}"))
        return
    eps = eps[:20]
    while True:
        print(f"\n{title}")
        for i, (t, d, du, _) in enumerate(eps, 1):
            print(f"{Y}{i:3d}){R} {C}{d}{R} {D}{du:>8}{R}  {t}")
        a = ask(say("들을 번호, , 뒤로, q 끝 > ", "Number to play, , back, q quit > "))
        if a in ("q", "Q"):
            sys.exit(0)
        if a in (",", "", "<"):
            return
        if a.isdigit() and 1 <= int(a) <= len(eps):
            t, _, _, u = eps[int(a) - 1]
            if play(t, u):                # playing: pod is done, the shell is yours again
                sys.exit(0)


def main():
    try:                                  # show as "pod" (F12 keys, window name)
        open("/proc/self/comm", "w").write("pod")
    except OSError:
        pass
    args = sys.argv[1:]
    if args and args[0] == "--player":
        if playing():
            # Korean input on: a lone ㅂ ㄴ would wait for the next key, so this
            # pane is marked for English keys while it has focus (enkeys)
            pane = os.environ.get("TMUX_PANE")
            enk = "/usr/local/lib/han/enkeys"
            if pane:
                subprocess.run(["tmux", "set", "-p", "-t", pane, "@enkeys", "1"], stderr=subprocess.DEVNULL)
            subprocess.run([enk, pane or "on"], stderr=subprocess.DEVNULL)
            try:
                curses.wrapper(player)
            finally:
                if pane:
                    subprocess.run(["tmux", "set", "-pu", "-t", pane, "@enkeys"], stderr=subprocess.DEVNULL)
                subprocess.run([enk] if pane else [enk, "off"], stderr=subprocess.DEVNULL)
        return
    if args and args[0] in ("-h", "--help"):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:9]), end="")
        return
    subs = load_subs()
    if args:
        subscribe(" ".join(args), subs)
    while True:
        print()
        if not subs:
            print(say("구독한 팟캐스트가 없습니다. 이름을 입력해 찾으세요 (예: this american life).",
                      "No podcasts yet. Type a name to find one (e.g. this american life)."))
        for i, (t, _) in enumerate(subs, 1):
            print(f"{Y}{i:3d}){R} {t}")
        a = ask(say("번호 = 열기, 이름 = 찾아서 구독, -번호 = 구독 끊기, q = 끝 > ",
                    "number = open, a name = find and subscribe, -number = remove, q = quit > "))
        if a in ("q", "Q", ""):
            return
        if a.isdigit() and 1 <= int(a) <= len(subs):
            show_episodes(*subs[int(a) - 1])
        elif a.startswith("-") and a[1:].isdigit() and 1 <= int(a[1:]) <= len(subs):
            t = subs.pop(int(a[1:]) - 1)[0]
            save_subs(subs)
            print(say(f"구독을 끊었습니다: {t}", f"Removed: {t}"))
        elif not a.isdigit():
            subscribe(a, subs)


if __name__ == "__main__":
    main()
PODPY
	chmod 755 "$STAGE/usr/local/bin/pod"
	cat > "$STAGE/usr/local/lib/han/podshow" <<'EOF'
#!/bin/sh
# Alt+P: show the podcast player (Alt+P or Esc hides it again)
if [ -S /tmp/han-pod.sock ]; then
	exec tmux display-popup ${1:+-c "$1"} -E -x R -y 0 -w 52 -h 7 -b rounded \
		-T " 팟캐스트 (Podcast) " "pod --player"
fi
tmux display-message "재생 중인 팟캐스트 없음 (no podcast playing)"
EOF
	chmod 755 "$STAGE/usr/local/lib/han/podshow"
	cat > "$STAGE/usr/local/lib/han/newsshow" <<'EOF'
#!/bin/sh
# Alt+N: the news feeds (newsboat) in a panel on the right, like F12.
# newsboat runs in its own tmux session (han-news), so Alt+N again only
# hides the panel and the next Alt+N is back where you were. q in the feed
# list quits newsboat (and closes the panel).
s=han-news
if [ "$1" = --in ]; then
	if ! tmux has-session -t "=$s" 2>/dev/null; then
		tmux new-session -d -s "$s" -x 50 -y 30 'han-run newsboat' || exit 1
		tmux set-option -t "$s" status off
	fi
	sock="${TMUX%%,*}"; unset TMUX       # the same tmux server, as its own client
	exec tmux ${sock:+-S "$sock"} attach-session -t "=$s"
fi
exec tmux display-popup ${1:+-c "$1"} -E -x R -y 0 -w 45% -h 100% -b rounded \
	-T " 뉴스 (News)  Alt+N 닫기 (close) " "/usr/local/lib/han/newsshow --in"
EOF
	chmod 755 "$STAGE/usr/local/lib/han/newsshow"
	# AI chat (gem): Groq first, Gemini as the fallback. Alt+G opens it in a
	# pane beside your work (Alt+G again closes), Alt+O switches sides.
	# >>> gem (generated by tools/embed.py: edit tools/gem)
	cat > "$STAGE/usr/local/bin/gem" <<'GEMPY'
#!/usr/bin/env python3
# gem: chat with an AI on the console: Groq (fast, free key) or Google Gemini.
# In the desktop Alt+G opens it in a panel on the right (like F12); close it
# and you are back in your work.
#   gem            chat (the conversation is kept until /new)
#   gem -k         set a key: Groq (https://console.groq.com/keys, tried first)
#                  or Gemini (https://aistudio.google.com/apikey, the fallback)
# In the chat: /copy  last answer to the paste buffer (F7 pastes it, e.g. in
# WordGrinder)   /new  new conversation   q or Ctrl+D  close
# Desktop: Alt+G opens and closes it beside your work, Alt+O moves between
# the two sides, F6 copies any text on the screen, F7 pastes it.
#   /pdf NAME [PAGE]  send that page (or a picture) with your next question;
#   NAME is part of the file name or a pattern (regular expression), e.g.
#   /pdf 계약 3   /pdf report.*2026 1   /pdf scan   (its text goes along;
#   a scanned page is read with OCR if installed, else sent as a picture)
import base64, json, os, re, subprocess, sys, time, textwrap, unicodedata, urllib.error, urllib.request
try:
    import readline  # noqa: F401  (line editing, history)
except ImportError:
    pass

KO = bool(os.environ.get("HAN_ACTIVE"))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "han")
KEYF = os.path.join(CONF, "gemini-key")
GKEYF = os.path.join(CONF, "groq-key")
HIST = os.path.join(CONF, "gemini-chat.json")
LASTM = os.path.join(CONF, "gemini-model")
API = os.environ.get("GEMINI_API_BASE", "https://generativelanguage.googleapis.com/v1beta")
GROQ = os.environ.get("GROQ_API_BASE", "https://api.groq.com/openai/v1")
SYSTEM = ("Answer in the language of the question. The answer is shown on a small text "
          "console: keep it short and plain, no tables, no emoji, little markdown.")
B, D, R = "\033[1;36m", "\033[2m", "\033[0m"


def say(ko, en):
    return ko if KO else en


def width(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else
               0 if unicodedata.combining(c) else 1 for c in s)


def page_out(lines, w):
    """Print an answer a screenful at a time: Space the next part, Enter one
    more line, q the rest skipped (it stays whole for /copy)."""
    import shutil, termios, tty
    rows = shutil.get_terminal_size().lines - 2
    if not sys.stdin.isatty() or rows < 4:
        print("\n".join(lines))
        return
    used, total = 0, len(lines)
    for i, line in enumerate(lines):
        need = max(1, -(-width(line) // max(1, w + 1)))   # rows this line takes
        if used + need > rows:
            msg = say(f"-- 계속: Space 다음, Enter 한 줄, q 그만 ({i}/{total}) --",
                      f"-- more: Space next, Enter one line, q stop ({i}/{total}) --")
            print(f"{D}{msg}{R}", end="", flush=True)
            fd = sys.stdin.fileno()
            old = termios.tcgetattr(fd)
            try:
                tty.setcbreak(fd)
                k = sys.stdin.read(1)
            finally:
                termios.tcsetattr(fd, termios.TCSADRAIN, old)
            print("\r\033[K", end="")
            if k in ("q", "Q", "\x1b"):
                print(D + say("(나머지는 건너뜀. /copy 는 답 전체)", "(rest skipped; /copy takes it all)") + R)
                return
            used = rows - 1 if k in ("\n", "\r") else 0
        print(line)
        used += need


def wrap(text, w):
    """Wrap to the panel, counting Korean as two columns. Inside the desktop
    tmux wraps the lines itself, so a sentence copied with F6 comes out whole."""
    if os.environ.get("TMUX"):
        return text.split("\n")
    out = []
    for para in text.split("\n"):
        line, cw = "", 0
        for word in re.split(r"(\s+)", para):
            n = width(word)
            if cw + n > w and line.strip():
                out.append(line.rstrip())
                line, cw = "", 0
                if word.isspace():
                    continue
            while n > w:                 # a very long word: cut it
                cut, k = "", 0
                for ch in word:
                    if k + width(ch) > w:
                        break
                    cut += ch
                    k += width(ch)
                out.append(cut)
                word = word[len(cut):]
                n = width(word)
            line += word
            cw += n
        out.append(line.rstrip())
    return out


FOLD = {
    "\u00b7": "-", "\u2022": "*", "\u25aa": "*", "\u25a0": "*", "\u25cf": "*",
    "\u25cb": "o", "\u25e6": "o", "\u203b": "*", "\u2219": "-", "\u30fb": "-",
    "\u201c": '"', "\u201d": '"', "\u2018": "'", "\u2019": "'", "\u2026": "...",
    "\u2013": "-", "\u2014": "--", "\u2015": "--", "\u2192": "->", "\u2190": "<-",
    "\u2191": "^", "\u2193": "v", "\u00d7": "x", "\u00b0": " deg",
    "\u2500": "-", "\u2501": "-", "\u2502": "|", "\u2503": "|",
    "\u250c": "+", "\u2510": "+", "\u2514": "+", "\u2518": "+",
    "\u251c": "+", "\u2524": "+", "\u252c": "+", "\u2534": "+", "\u253c": "+",
    "\u00a0": " ", "\u25a1": "[ ]", "\u2610": "[ ]", "\u2611": "[x]",
}


def console_safe(c):
    """True for characters fbterm draws as wide as the terminal counts them:
    plain letters and signs, Hangul, CJK. Emoji and other newer wide signs are
    counted differently and push the rest of the line out of its place."""
    o = ord(c)
    if o < 0x300 or 0xAC00 <= o <= 0xD7A3 or 0x1100 <= o <= 0x11FF or 0x3130 <= o <= 0x318F:
        return True
    if o > 0xFFFF or c in "\u200d\ufe0e\ufe0f":
        return False
    if unicodedata.east_asian_width(c) in "WF":
        return 0x2E80 <= o <= 0xA4CF or 0xF900 <= o <= 0xFAFF or 0xFE30 <= o <= 0xFE4F or 0xFF00 <= o <= 0xFFE6
    return True


def plain(md):
    """Markdown to plain console text, with only characters the console
    draws in their place (no emoji; curly quotes and bullets as ASCII)."""
    md = "".join(FOLD.get(c, c) for c in md if c in FOLD or c == "\n" or console_safe(c))
    md = re.sub(r"```\w*\n?", "", md)
    md = re.sub(r"\*\*(.+?)\*\*", r"\1", md)
    md = re.sub(r"(?m)^#+\s*", "", md)
    md = re.sub(r"(?m)^(\s*)[*-]\s+", r"\1- ", md)
    md = re.sub(r"`([^`]+)`", r"\1", md)
    return md.strip()


def read_key(env, path):
    k = os.environ.get(env, "")
    if not k:
        try:
            k = open(path).read().strip()
        except OSError:
            pass
    return k


def keys():
    """[(provider, key)], Groq first (fast); Gemini as the fallback."""
    out = []
    for name, env, path in (("groq", "GROQ_API_KEY", GKEYF), ("gemini", "GEMINI_API_KEY", KEYF)):
        k = read_key(env, path)
        if k:
            out.append((name, k))
    return out


def set_key():
    print(say("무료 API 키가 하나 필요합니다. 다른 컴퓨터나 휴대폰에서 만드세요:",
              "You need a free API key. Make one on another computer or a phone:"))
    print("  1) Groq   https://console.groq.com/keys   " + say("(빠름, 먼저 씀)", "(fast, used first)"))
    print("  2) Gemini https://aistudio.google.com/apikey   " + say("(Groq 가 안 될 때)", "(when Groq fails)"))
    print(say("키를 파일로 가져왔다면:  cp 파일 ~/.config/han/groq-key  (또는 gemini-key)",
              "If you brought the key as a file:  cp FILE ~/.config/han/groq-key  (or gemini-key)"))
    k = input(say("키 입력 (Enter 취소) > ", "Key (Enter cancels) > ")).strip()
    if not k:
        return ""
    path = GKEYF if k.startswith("gsk_") else KEYF if k.startswith("AIza") else None
    if path is None:
        a = input(say("어느 키입니까? 1 Groq, 2 Gemini > ", "Which key is it? 1 Groq, 2 Gemini > ")).strip()
        path = GKEYF if a == "1" else KEYF
    os.makedirs(CONF, exist_ok=True)
    with open(path, "w") as f:
        f.write(k + "\n")
    os.chmod(path, 0o600)
    print(say("저장했습니다.", "Saved."))
    return k


def call(path, k, body=None, timeout=45):
    url = f"{API}/{path}{'&' if '?' in path else '?'}key={k}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def models(k):
    """Models to try, best first: the newest plain "flash", then older flash,
    then the lighter flash-lite ones (when one is busy, the next may not be).
    GEMINI_MODEL puts that one first."""
    try:
        names = [m["name"].split("/", 1)[1] for m in call("models?pageSize=200", k, timeout=10).get("models", [])
                 if "generateContent" in m.get("supportedGenerationMethods", [])]
    except Exception:
        names = []
    def ver(n):
        return [int(x) for x in re.findall(r"\d+", n)]
    flash = sorted((n for n in names if re.fullmatch(r"gemini-[\d.]+-flash", n)), key=ver, reverse=True)
    lite = sorted((n for n in names if re.fullmatch(r"gemini-[\d.]+-flash-lite", n)), key=ver, reverse=True)
    order = (flash[:3] + lite[:2]) or ["gemini-2.5-flash", "gemini-2.5-flash-lite"]
    if os.environ.get("GEMINI_MODEL"):
        order.insert(0, os.environ["GEMINI_MODEL"])
    return order


GROQ_PREF = [r"moonshotai/kimi-k2", r"openai/gpt-oss-120b", r"llama-3\.3-70b",
             r"meta-llama/llama-4-maverick", r"qwen/qwen3", r"openai/gpt-oss-20b",
             r"meta-llama/llama-4-scout", r"llama-3\.1-8b"]
GROQ_VISION = r"llama-4-(scout|maverick)|vision"


def groq_call(path, k, body=None, timeout=45):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{GROQ}/{path}", data=data, headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + k,
        "User-Agent": "gem/2 (Aneuu)"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def groq_models(k):
    """Groq's chat models, best for Korean and general use first."""
    try:
        names = [m["id"] for m in groq_call("models", k, timeout=10).get("data", [])
                 if m.get("active", True)]
    except Exception:
        names = []
    names = [n for n in names if not re.search(r"whisper|tts|guard|playai|orpheus|compound", n)]
    order = []
    for pat in GROQ_PREF:
        order += sorted((n for n in names if re.search(pat, n) and n not in order), reverse=True)[:1]
    order += [n for n in names if n not in order][:2]
    return order or ["openai/gpt-oss-120b", "llama-3.3-70b-versatile", "llama-3.1-8b-instant"]


def to_openai(contents):
    msgs = [{"role": "system", "content": SYSTEM}]
    for t in contents:
        role = "assistant" if t["role"] == "model" else "user"
        if any("inline_data" in p for p in t["parts"]):
            c = []
            for p in t["parts"]:
                if "text" in p:
                    c.append({"type": "text", "text": p["text"]})
                else:
                    d = p["inline_data"]
                    c.append({"type": "image_url", "image_url": {
                        "url": f"data:{d['mime_type']};base64,{d['data']}"}})
        else:
            c = "\n".join(p.get("text", "") for p in t["parts"])
        msgs.append({"role": role, "content": c})
    return msgs


def ask_one(prov, m, k, contents):
    if prov == "groq":
        r = groq_call("chat/completions", k, {"model": m, "messages": to_openai(contents)})
        ans = r["choices"][0]["message"].get("content") or ""
        return re.sub(r"(?s)<think>.*?</think>\s*", "", ans)
    r = call(f"models/{m}:generateContent", k, {
        "contents": contents, "systemInstruction": {"parts": [{"text": SYSTEM}]}})
    return "".join(p.get("text", "") for p in r["candidates"][0]["content"]["parts"])


def ask_gemini(order, k, contents, note):
    """Ask; when a model is busy (503) or out of its free share (429), wait a
    moment and try the next one. Gives up after about two minutes.
    Returns (answer, model used)."""
    last, start = None, time.time()
    picture = any("inline_data" in p for p in contents[-1]["parts"])
    for i, (prov, m, k) in enumerate(order):
        if picture and prov == "groq" and not re.search(GROQ_VISION, m):
            continue                          # this one cannot see pictures
        for attempt in range(2 if i == 0 and prov == "gemini" else 1):
            if time.time() - start > 120:
                break
            try:
                return ask_one(prov, m, k, contents), (prov, m, k)
            except urllib.error.HTTPError as e:
                last = e
                if e.code == 400 and picture:
                    continue
                if e.code in (401, 403) and len({o[0] for o in order}) > 1:
                    note[0] = say(f"{prov} 키 문제, 다른 곳으로", f"{prov} key problem, trying the other")
                    continue
                if e.code not in (413, 429, 500, 502, 503, 504):
                    raise
                note[0] = say(f"{m} 바쁨, 다른 모델로", f"{m} busy, trying another")
                time.sleep(2)
            except OSError as e:              # timeout, connection reset
                last = e
                note[0] = say(f"{m} 응답 없음, 다른 모델로", f"{m} not answering, trying another")
    if last is None and picture:
        raise LookupError("picture")
    raise last if last else TimeoutError("no answer")


def ask_waiting(order, k, contents):
    """ask_gemini in the background; meanwhile show the seconds. Ctrl+C
    gives up on this question (the chat stays open)."""
    import threading
    box, note = {}, [""]
    def work():
        try:
            box["ok"] = ask_gemini(order, k, contents, note)
        except BaseException as e:            # noqa: B902 (hand it over)
            box["err"] = e
    t = threading.Thread(target=work, daemon=True)
    t.start()
    t0 = time.time()
    try:
        while t.is_alive():
            t.join(0.5)
            msg = say(f"생각 중... {int(time.time() - t0)}초  (Ctrl+C 취소)",
                      f"Thinking... {int(time.time() - t0)} s  (Ctrl+C cancels)")
            print(f"\r{D}{msg}  {note[0]}{R}\033[K", end="", flush=True)
    except KeyboardInterrupt:
        print("\r\033[K" + say("취소했습니다.", "Cancelled."))
        raise
    print("\r\033[K", end="")
    if "err" in box:
        raise box["err"]
    return box["ok"]


KINDS = {".pdf": "application/pdf", ".png": "image/png", ".jpg": "image/jpeg",
         ".jpeg": "image/jpeg", ".webp": "image/webp"}


def find_files(pattern):
    """Files whose name matches (regular expression, or plain text if that is
    not a valid expression), here, in the home folder and on USB sticks."""
    try:
        rx = re.compile(pattern, re.I)
        match = lambda n: rx.search(n)
    except re.error:
        match = lambda n: pattern.lower() in n.lower()
    roots = [(os.getcwd(), 2), (os.path.expanduser("~"), 4), ("/media", 4), ("/mnt", 3)]
    seen, out = set(), []
    for root, depth in roots:
        base = root.rstrip("/").count("/")
        for d, dirs, files in os.walk(root):
            if d.count("/") - base >= depth:
                dirs[:] = []
            dirs[:] = [x for x in dirs if not x.startswith(".")]
            for f in files:
                path = os.path.join(d, f)
                if os.path.splitext(f)[1].lower() in KINDS and match(f) and path not in seen:
                    seen.add(path)
                    out.append(path)
    return sorted(out, key=lambda p: (len(p), p))[:20]


def ocr(img_args):
    """Text from a picture with tesseract (had ocr), or ""."""
    try:
        langs = subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True).stdout.split()
    except OSError:
        return ""
    lang = "+".join(l for l in ("kor", "eng") if l in langs) or "eng"
    return subprocess.run(["tesseract", *img_args, "-", "-l", lang],
                          capture_output=True, text=True).stdout.strip()


def page_part(path, page):
    """The page's text (a scanned page: OCR if installed, else the page as a
    picture); a picture file: OCR text, else the picture."""
    ext = os.path.splitext(path)[1].lower()
    label = f"[{os.path.basename(path)}" + (f", page {page}]" if ext == ".pdf" else "]")
    if ext == ".pdf":
        text = subprocess.run(["pdftotext", "-f", str(page), "-l", str(page), "-layout", path, "-"],
                              capture_output=True, text=True).stdout.strip()
        if len(text) > 40:
            return {"text": f"{label}\n{text}"}
        print(say("글자가 없는 쪽 (스캔): 그림으로 읽는 중...", "No text on this page (scan): reading the picture..."))
        png = subprocess.run(["pdftoppm", "-r", "200", "-gray", "-png", "-f", str(page), "-l", str(page),
                              "-singlefile", path], capture_output=True).stdout
        if png:
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".png") as f:
                f.write(png)
                f.flush()
                text = ocr([f.name])
            if len(text) > 20:
                return {"text": f"{label} (OCR)\n{text}"}
        jpg = subprocess.run(["pdftoppm", "-r", "120", "-jpeg", "-jpegopt", "quality=80",
                              "-f", str(page), "-l", str(page), "-singlefile", path],
                             capture_output=True).stdout
        if not jpg:
            return None
        return {"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(jpg).decode()}}
    text = ocr([path])
    if len(text) > 20:
        return {"text": f"{label} (OCR)\n{text}"}
    data = open(path, "rb").read()
    return {"inline_data": {"mime_type": KINDS[ext], "data": base64.b64encode(data).decode()}}


def attach(arg):
    """/pdf NAME [PAGE]: the part to send with the next question, or None."""
    words = arg.split()
    page = 1
    if len(words) > 1 and words[-1].isdigit():
        page = int(words.pop())
    if not words:
        print(say("쓰는 법: /pdf 파일이름(일부) [쪽]   예: /pdf 계약 3",
                  "Usage: /pdf NAME [PAGE]   e.g. /pdf contract 3"))
        return None
    files = find_files(" ".join(words))
    if not files:
        print(say("그런 이름의 PDF 나 그림이 없습니다.", "No PDF or picture with that name."))
        return None
    path = files[0]
    if len(files) > 1:
        for i, f in enumerate(files, 1):
            print(f"{B}{i:3d}){R} {f.replace(os.path.expanduser('~'), '~', 1)}")
        a = input(say("번호 > ", "Number > ")).strip()
        if not (a.isdigit() and 1 <= int(a) <= len(files)):
            return None
        path = files[int(a) - 1]
    part = page_part(path, page)
    if part is None:
        print(say(f"{page}쪽을 읽지 못했습니다 (쪽 수를 넘었나요?)", f"Cannot read page {page} (past the end?)"))
        return None
    name = os.path.basename(path) + (f" {page}" + say("쪽", "") if path.lower().endswith(".pdf") else "")
    print(say(f"붙였습니다: {name}. 이제 물어보세요 (예: 이 쪽을 요약해 줘).",
              f"Attached: {name}. Now ask (e.g. summarize this page)."))
    return part, name


def show_help():
    """The key summary (the same one F12 shows): in the F12 panel in the
    desktop, printed here otherwise."""
    if os.environ.get("TMUX"):
        subprocess.run(["tmux", "display-popup", "-E", "-x", "R", "-y", "0", "-w", "34%",
                        "-h", "100%", "-b", "rounded", "han-cheat gem"])
        return
    lang = "ko" if KO else "en"
    for f in (f"/usr/share/han/cheat/{lang}/gem.txt", "/usr/share/han/cheat/en/gem.txt"):
        try:
            print(open(f, encoding="utf-8").read())
            return
        except OSError:
            pass


def tmux_copy(text):
    os.system("tmux set-buffer -- " + "'" + text.replace("'", "'\\''") + "' 2>/dev/null")


def main():
    if sys.argv[1:2] in (["-h"], ["--help"]):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:15]), end="")
        return
    if sys.argv[1:2] == ["-k"] or not keys():
        try:
            if not set_key():
                return
        except (EOFError, KeyboardInterrupt):
            return
    k = None
    try:
        hist = json.load(open(HIST, encoding="utf-8"))
    except (OSError, ValueError):
        hist = []
    import shutil
    w = max(20, shutil.get_terminal_size().columns - 1)
    order = []
    for prov, pk in keys():
        order += [(prov, x, pk) for x in (groq_models(pk) if prov == "groq" else models(pk))]
    try:                                  # the one that answered last time first
        good = open(LASTM).read().strip()
        order.sort(key=lambda o: f"{o[0]}:{o[1]}" != good)
    except OSError:
        pass
    m = order[0]
    print(D + say("F12 쓰는 법", "F12 how to") + R)
    for turn in hist[-4:]:                       # where you left off
        who = B + say("나", "me") + R if turn["role"] == "user" else B + "AI" + R
        print(who)
        print("\n".join(wrap(plain(turn["parts"][-1].get("text", "")), w)))
    last = next((t["parts"][0]["text"] for t in reversed(hist) if t["role"] == "model"), "")
    pending = None
    while True:
        try:
            q = input(f"\n\001{B}\002> \001{R}\002").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return
        if q in ("q", "/q", "/quit", "exit"):
            return
        if not q:
            continue
        if q in ("/help", "/h", "?", "/?", "/도움"):
            show_help()
            continue
        if q == "/new":
            hist, last = [], ""
            try:
                os.remove(HIST)
            except OSError:
                pass
            print(say("새 대화.", "New conversation."))
            continue
        if q.startswith("/pdf") or q.startswith("/img"):
            try:
                got = attach(q[4:].strip())
            except (EOFError, KeyboardInterrupt):
                got = None
            if got:
                pending = got
            continue
        if q == "/copy":
            tmux_copy(plain(last))
            print(say("복사했습니다. 쓰던 곳에서 F7 로 붙여 넣으세요.",
                      "Copied. Paste it with F7 where you write."))
            continue
        parts = [{"text": q}]
        if pending:
            parts.insert(0, pending[0])
        hist.append({"role": "user", "parts": parts})
        try:
            # only the newest page goes along again (smaller, faster requests)
            newest = max((i for i, t in enumerate(hist) if any("inline_data" in p for p in t["parts"])),
                         default=-1)
            send = [t if i == newest else {"role": t["role"],
                    "parts": [p for p in t["parts"] if "text" in p] or [{"text": "[page]"}]}
                    for i, t in enumerate(hist)]
            ans, used = ask_waiting(order, k, send[-40:])
            if used != m and not any("inline_data" in p for p in parts):  # a picture-only switch stays one-off
                # it answers from now on, and first next time too
                print(D + say(f"(답한 모델: {used[1]}, 이제부터 이 모델로)", f"(answered by {used[1]}; using it from now on)") + R)
                order = [used] + [x for x in order if x != used]
                m = used
                try:
                    os.makedirs(CONF, exist_ok=True)
                    open(LASTM, "w").write(f"{used[0]}:{used[1]}\n")
                except OSError:
                    pass
        except urllib.error.HTTPError as e:
            hist.pop()
            msg = e.read().decode("utf-8", "replace")
            if e.code in (400, 401, 403) and "key" in msg.lower():
                print(say("API 키가 맞지 않습니다. 다시 넣으려면: gem -k", "The API key is not valid. Set it again: gem -k"))
            elif e.code == 400 and pending:
                print(say("이 쪽(그림)을 읽을 수 있는 모델이 없습니다. had ocr 을 한 번 하면 글자로 보냅니다.",
                          "No model here can read this page (picture). After had ocr it goes as text."))
            elif e.code in (429, 500, 503, 504):
                print(say("지금은 모두 바쁘거나 무료 한도를 넘었습니다. 조금 뒤에 같은 질문을 다시 하세요 (위 화살표).",
                          "All busy, or the free limit is reached. Ask again in a while (Up arrow)."))
            else:
                print(f"{e.code} {msg[:200]}")
            continue
        except KeyboardInterrupt:
            hist.pop()
            continue
        except LookupError:
            hist.pop()
            print(say("이 쪽(그림)을 읽을 수 있는 모델이 없습니다. had ocr 을 한 번 하면 글자로 보냅니다.",
                      "No model here can read this page (picture). After had ocr it goes as text."))
            continue
        except Exception as e:
            hist.pop()
            print(say(f"닿지 못했습니다 (인터넷 연결?): {e}", f"Cannot reach it (online?): {e}"))
            continue
        hist.append({"role": "model", "parts": [{"text": ans}]})
        last = ans
        if pending:                           # keep the page for follow-ups in
            pending = None                    # this session, not on disk
        print(B + "AI" + R)
        page_out(wrap(plain(ans), w), w)
        try:
            os.makedirs(CONF, exist_ok=True)
            light = [{"role": t["role"], "parts": [p if "text" in p else {"text": "[page]"}
                                                    for p in t["parts"]]} for t in hist[-40:]]
            json.dump(light, open(HIST, "w", encoding="utf-8"), ensure_ascii=False)
        except OSError:
            pass


if __name__ == "__main__":
    try:
        open("/proc/self/comm", "w").write("gem")
    except OSError:
        pass
    main()
GEMPY
	chmod 755 "$STAGE/usr/local/bin/gem"
	# <<< gem
	cat > "$STAGE/usr/local/lib/han/gempane" <<'EOF'
#!/bin/sh
# Alt+G: the AI chat (gem) in a pane on the right of this desktop window;
# Alt+G again closes it.   gempane toggle WINDOW
# The keyboard goes to the chat; Alt+O goes back to your work (and over
# again), F6 copies text from either side, F7 pastes it.
w="${1:-}"
p="$(tmux list-panes -t "$w" -F '#{pane_id} #{@hangem}' 2>/dev/null | awk '$2 == 1 { print $1; exit }')"
if [ -n "$p" ]; then
	tmux kill-pane -t "$p"
	# keep the title line while the book pane (F11) is still open
	tmux list-panes -t "$w" -F '#{@title}' | grep -q . ||
		tmux set-option -w -u -t "$w" pane-border-status
	exit 0
fi
p="$(tmux split-window -t "$w" -h -l 45% -P -F '#{pane_id}' 'HAN_GEM_PANE=1 exec gem')" || exit 0
tmux set-option -p -t "$p" @hangem 1
tmux set-option -p -t "$p" @title "AI"
tmux set-option -w -t "$w" pane-border-status top
tmux set-option -w -t "$w" pane-border-format "#{?#{@title},#[bold] #{@title} ,}"
exit 0
EOF
	chmod 755 "$STAGE/usr/local/lib/han/gempane"
	cat > "$STAGE/usr/local/bin/cmus" <<'EOF'
#!/bin/sh
d="${XDG_CONFIG_HOME:-$HOME/.config}/cmus"
mkdir -p "$d" 2>/dev/null
grep -qs '^set mpris=' "$d/rc" || echo 'set mpris=false' >> "$d/rc"
exec /usr/bin/cmus "$@"
EOF
	chmod 755 "$STAGE/usr/local/bin/cmus"
	# newsboat: a starter list of well-known feeds (Korean and English, from
	# across the spectrum), given only to someone who has no feed list yet.
	# Delete lines you don't want: nano ~/.newsboat/urls
	cat > "$STAGE/usr/share/han/newsboat-urls" <<'EOF'
# One feed per line; text in quotes is a tag ("뉴스" etc.). Delete what you
# don't read, add your own. Lines starting with # are skipped.
# 한국 뉴스 (Korean news)
https://www.yna.co.kr/rss/news.xml "뉴스" "~연합뉴스"
https://feeds.bbci.co.uk/korean/rss.xml "뉴스" "~BBC 코리아"
https://www.hani.co.kr/rss/ "뉴스" "~한겨레"
https://www.khan.co.kr/rss/rssdata/total_news.xml "뉴스" "~경향신문"
https://www.chosun.com/arc/outboundfeeds/rss/?outputType=xml "뉴스" "~조선일보"
https://rss.donga.com/total.xml "뉴스" "~동아일보"
# World news
https://feeds.bbci.co.uk/news/world/rss.xml "news" "~BBC World"
https://feeds.npr.org/1001/rss.xml "news" "~NPR News"
https://www.theguardian.com/world/rss "news" "~The Guardian: World"
https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml "news" "~New York Times"
https://www.aljazeera.com/xml/rss/all.xml "news" "~Al Jazeera"
# Technology
https://hnrss.org/frontpage "tech" "~Hacker News"
https://feeds.arstechnica.com/arstechnica/index "tech" "~Ars Technica"
https://lwn.net/headlines/rss "tech" "~LWN.net"
# Faith
https://www.christianitytoday.com/feed/ "faith" "~Christianity Today"
EOF
	cat > "$STAGE/usr/share/han/newsboat-config" <<'EOF'
# Aneuu's newsboat settings (yours: ~/.newsboat/config)
refresh-on-startup yes
browser "w3m %u"
max-items 100
show-read-feeds yes
EOF
	# Lists with the title first (the panel is narrow): the rest at the right
	cat > "$STAGE/usr/share/han/newsboat-format" <<'EOF'
feedlist-format "%t%> %u"
articlelist-format "%t%> %f %D"
datetime-format "%m-%d"
EOF
	cat > "$STAGE/usr/local/bin/newsboat" <<'EOF'
#!/bin/sh
# newsboat with a starter feed list the first time (when you have none)
d="$HOME/.newsboat"
x="${XDG_CONFIG_HOME:-$HOME/.config}/newsboat"
if [ ! -s "$d/urls" ] && [ ! -s "$x/urls" ]; then
	mkdir -p "$d" && cp /usr/share/han/newsboat-urls "$d/urls"
	[ -e "$d/config" ] || [ -e "$x/config" ] || cp /usr/share/han/newsboat-config "$d/config"
fi
# title first in the lists, unless you set your own format
c="$d/config"; [ -e "$x/config" ] && [ ! -e "$c" ] && c="$x/config"
mkdir -p "$(dirname "$c")"
while read -r k v; do
	grep -qs "^$k " "$c" || printf '%s %s\n' "$k" "$v" >> "$c"
done < /usr/share/han/newsboat-format
exec /usr/bin/newsboat "$@"
EOF
	chmod 755 "$STAGE/usr/local/bin/newsboat"
	cat > "$STAGE/usr/local/bin/wordgrinder" <<'EOF'
#!/bin/sh
exec /usr/bin/wordgrinder --config /usr/share/han/wordgrinder.lua "$@"
EOF
	chmod 755 "$STAGE/usr/local/bin/wordgrinder"
	cat > "$STAGE/usr/local/bin/wg" <<'EOF'
#!/bin/sh
# wg: WordGrinder, the word processor. Inside han or desk it opens right
# here; outside, han starts it (the Korean screen and input come first).
#   wg ADDRESS   a web page's text, decluttered like a reader view, as a new
#                document (~/web/), saved also as .odt
#                (in w3m: Alt+W does this for the page on screen)
case "${1:-}" in http://*|https://*)
	d="$HOME/web"; mkdir -p "$d"
	f="$d/$(date +%Y-%m-%d-%H%M%S).wg"
	echo "페이지를 가져오는 중... (getting the page)"
	if ! /usr/local/lib/han/web2wg "$1" "$f" >/dev/null; then
		echo "가져오지 못했습니다 (could not get it): $1"
		printf 'Enter '; read -r _; exit 1
	fi
	# from w3m inside the desktop: a window of its own, w3m stays as it was
	if [ -n "${HAN_WG_NEWWIN:-}" ] && [ -n "${TMUX:-}" ]; then
		exec tmux new-window -n write "han-run wordgrinder '$f'"
	fi
	set -- "$f" ;;
esac
# wg NAME: a name without an extension is WordGrinder's NAME.wg (so every
# save also writes NAME.odt); a new name starts as an empty document
# instead of "no such file".
case "${1:-}" in -*|"") ;; *)
	f="$1"; shift
	case "${f##*/}" in *.*) ;; *) f="$f.wg" ;; esac
	case "$f" in *.wg)
		if [ ! -e "$f" ]; then
			t="/tmp/wg-new.$$.txt"; : > "$t"
			/usr/bin/wordgrinder --convert "$t" "$f" >/dev/null 2>&1
			rm -f "$t"
		fi ;;
	esac
	set -- "$f" "$@" ;;
esac
[ -n "${HAN_ACTIVE:-}" ] && exec wordgrinder "$@"
exec han "$@"
EOF
	chmod 755 "$STAGE/usr/local/bin/wg"
	# web2wg: a web page's text as a WordGrinder document (wg ADDRESS, bible,
	# Alt+W in w3m); bible: the day's reading-plan passages, for notes
	cat > "$STAGE/usr/local/lib/han/web2wg" <<'WEB2WG'
#!/usr/bin/env python3
# web2wg URL FILE.wg: a web page's text (no menus, ads, footnote marks) as a
# WordGrinder document, ready for your own notes under it. Used by "wg URL",
# by "bible" and by Alt+W in w3m.
#   web2wg --html URL FILE.html   only the cleaned page, as HTML (for checks)
import html, html.parser, json, os, re, subprocess, sys, tempfile, urllib.request

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
      "Accept-Language": "ko,en;q=0.8"}
VOID = {"br", "img", "hr", "meta", "link", "input", "source", "wbr", "area", "base", "col", "embed", "track"}
DROP_TAGS = {"script", "style", "noscript", "svg", "form", "nav", "header", "footer", "aside",
             "button", "select", "iframe", "template", "canvas", "video", "audio", "picture", "figure"}
# boxes that are never the text itself (class or id)
JUNK = re.compile(r"(^|[-_ ])(footnotes?|crossrefs?|crossreference|share|sharing|social|nav|navbar|"
                  r"menu|breadcrumbs?|banner|promo|advert|ads?|cookie|modal|login|signup|subscribe|"
                  r"newsletter|calendar|sidebar|toolbar|related|comments?|publisher-info-top|"
                  r"full-chap-link|passage-other-trans|audio|dropdown-menu|hidden|skip)($|[-_ ])", re.I)
TITLE = re.compile(r"passage-display|dropdown-display-text|(^| )bcv( |$)", re.I)
BODY = re.compile(r"(^| )((rp-)?passage-text|bible_read)( |$)", re.I)
RIGHTS = re.compile(r"publisher-info-bottom|copyright", re.I)


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag, self.parent, self.kids = tag, parent, []
        a = dict(attrs)
        self.cls = (a.get("class") or "") + " " + (a.get("id") or "")
        self.attrs = a

    def text(self):
        return "".join(k if isinstance(k, str) else k.text() for k in self.kids)


class Tree(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root", [], None)
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        n = Node(tag, attrs, self.cur)
        self.cur.kids.append(n)
        if tag not in VOID:
            self.cur = n

    def handle_startendtag(self, tag, attrs):
        self.cur.kids.append(Node(tag, attrs, self.cur))

    def handle_endtag(self, tag):
        n = self.cur
        while n is not self.root and n.tag != tag:
            n = n.parent
        if n is not self.root:
            self.cur = n.parent

    def handle_data(self, data):
        self.cur.kids.append(data)


def walk(n):
    yield n
    for k in n.kids:
        if not isinstance(k, str):
            yield from walk(k)


def linky(n):
    """A box that is mostly links (menus, lists of other articles)."""
    text = len(re.sub(r"\s+", "", n.text()))
    if text == 0:
        return True
    links = sum(len(re.sub(r"\s+", "", a.text())) for a in walk(n) if a.tag == "a")
    return links / text > 0.5


def junk(n):
    return n.tag in DROP_TAGS or (n.cls.strip() and JUNK.search(n.cls)) or \
        (n.tag == "sup" and re.search(r"footnote|crossreference", n.cls))


BLOCK = {"p", "div", "li", "tr", "blockquote", "pre", "dd", "dt", "section", "article", "main",
         "table", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "h6", "body"}


def emit(n, out):
    """Clean HTML: headings, paragraphs (one per line of poetry), bold, italic."""
    for k in n.kids:
        if isinstance(k, str):
            out.append(html.escape(k))
            continue
        if junk(k):
            continue
        t = k.tag
        if t in ("h1", "h2", "h3", "h4", "h5", "h6"):
            out.append(f"</p>\n<{t}>{html.escape(k.text().strip())}</{t}>\n<p>")
        elif t == "br":
            out.append("</p>\n<p>")
        elif t in ("b", "strong", "i", "em"):
            tag = "b" if t in ("b", "strong") else "i"
            out.append(f"<{tag}>")
            emit(k, out)
            out.append(f"</{tag}>")
        elif t in BLOCK:
            if t in ("ul", "ol", "div", "section", "table") and linky(k):
                continue
            out.append("</p>\n<p>")
            emit(k, out)
            out.append("</p>\n<p>")
        else:
            emit(k, out)


def tidy(s):
    s = re.sub(r"[ \t ]+", " ", s)
    s = re.sub(r"<p>\s*</p>", "", s)
    s = re.sub(r"<p>\s*</p>", "", s)
    s = re.sub(r"<p>\s+", "<p>", s)
    s = re.sub(r"\n{2,}", "\n", s)
    return s.strip()


def bskorea(raw):
    """대한성서공회 (bskorea.or.kr) chapter pages: headings as headings, one
    verse per line, the footnote marks and the hidden notes out."""
    raw = re.sub(r"<a class=comment[^>]*>.*?</a>", "", raw, flags=re.S)
    raw = re.sub(r"<div id='D_[^']*' class=D2.*?</div>", "", raw, flags=re.S)
    raw = re.sub(r'<font class="smallTitle">(.*?)</font>', r"<h3>\1</h3>", raw, flags=re.S)
    raw = re.sub(r'<font class="chapNum">.*?</font>', "", raw, flags=re.S)
    raw = re.sub(r"<div style='text-align:right'>.*?</div>", "", raw, flags=re.S)
    m = re.search(r'class="titleBg">\s*\[\s*(\S+)\s+(\d+):', raw)
    v = re.search(r'class="bible_read">.*?<b>(.*?)</b>', raw, re.S)
    raw = re.sub(r"<font style='display:none;'[^>]*>.*?</font>", "", raw, flags=re.S)
    if v:
        raw = raw.replace(f"<b>{v.group(1)}</b>", "", 1)
    if m:                                   # "창세기 1장 (표준새번역)" as the first heading
        head = f"{m.group(1)} {m.group(2)}장" + (f" ({v.group(1).strip()})" if v else "")
        raw = raw.replace('<div id="tdBible1" class="bible_read">',
                          '<div id="tdBible1" class="bible_read"><h1>' + html.escape(head) + "</h1>", 1)
    return raw


ESV_NOTE = ("Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard "
            "Version®), © 2001 by Crossway, a publishing ministry of Good News Publishers. "
            "Used by permission. All rights reserved.")


def clean(raw, url):
    if "bskorea.or.kr" in url or 'class="bible_read"' in raw:
        raw = bskorea(raw)
    esv1517 = "1517.org/bible" in url
    if esv1517:                              # 1517.org's Bible pages (ESV): each chapter's section
        raw = raw.replace('<section class="description">', '<section class="passage-text">')
        raw = re.sub(r'<small class="audio[^"]*">.*?</small>', "", raw, flags=re.S)
    t = Tree()
    t.feed(raw)
    t.close()
    nodes = list(walk(t.root))
    title = next((n.text().strip() for n in nodes if n.tag == "title"), "") or url
    parts, seen_titles, rights = [], set(), ""
    # Bible Gateway (and pages built like it): each passage's reference, then its text
    picked = []
    for n in nodes:
        if any(p is n or inside(n, p) for p in picked):
            continue
        if BODY.search(n.cls) or (TITLE.search(n.cls) and not any(BODY.search(a.cls) for a in up(n))):
            picked.append(n)
    if any(BODY.search(p.cls) for p in picked):
        for n in picked:
            if BODY.search(n.cls):
                out = ["<p>"]
                emit(n, out)
                parts.append(tidy("".join(out) + "</p>"))
            else:
                ref = re.sub(r"\s+", " ", n.text()).strip()
                if ref and ref not in seen_titles and len(ref) < 120:
                    seen_titles.add(ref)
                    parts.append(f"<h1>{html.escape(ref)}</h1>")
        # Bible Gateway's reading plans: the date and the day's readings on top
        m = re.search(r'"ref_display":"((?:[^"\\]|\\.)*)"', raw)
        head = []
        if m:                                 # the date, from "... - January 3, 2027"
            head.append(f"<p><b>{html.escape(title.rsplit(' - ', 1)[-1])}</b></p>")
        if m:
            refs = html.unescape(json.loads('"' + m.group(1) + '"'))
            head.append(f"<p>{html.escape(refs)}</p>")
        parts[:0] = head
        r = [n for n in nodes if RIGHTS.search(n.cls)]
        if r:
            rights = re.sub(r"\s+", " ", r[-1].text()).strip()
    else:
        # any other page, like a reader view: the box holding most of the
        # paragraphs' text, without menus, link lists and the boxes around
        score = {}
        for n in nodes:
            if n.tag == "p" and not any(junk(a) for a in up(n)):
                text = len(n.text().strip())
                if text < 25:
                    continue
                pts = text + 10 * n.text().count(",")
                for i, a in enumerate(up(n)):
                    if i > 2 or a is t.root:
                        break
                    score[id(a)] = score.get(id(a), 0) + pts / (i + 1)
        byid = {id(n): n for n in nodes}
        root = byid[max(score, key=score.get)] if score else \
            next((n for n in nodes if n.tag in ("article", "main")), None) or \
            next((n for n in nodes if n.tag == "body"), t.root)
        h1 = next((n for n in nodes if n.tag == "h1"), None)
        if h1 is not None and not inside(h1, root):
            parts.append(f"<h1>{html.escape(' '.join(h1.text().split()))}</h1>")
        out = ["<p>"]
        emit(root, out)
        parts.append(tidy("".join(out) + "</p>"))
    body = "\n".join(parts)
    if esv1517:
        rights = ESV_NOTE
    if rights:
        body += f"\n<p><i>{html.escape(rights[:600])}</i></p>"
    notes = os.environ.get("HAN_WG_NOTES", "")
    if notes:                                # your own writing goes under this
        body += f"\n<h2>{html.escape(notes)}</h2>"
    return title, (f"<html><head><meta charset='utf-8'><title>{html.escape(title)}</title></head><body>\n"
                   f"{body}\n<p>{html.escape(url)}</p>\n</body></html>\n")


def up(n):
    n = n.parent
    while n is not None:
        yield n
        n = n.parent


def inside(n, p):
    return any(a is p for a in up(n))


def fetch_direct(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        data = r.read()
        cs = r.headers.get_content_charset() or "utf-8"
    return data.decode(cs, "replace")


def fetch_w3m(url):
    """The page as w3m gets it (its own name and its cookies): some sites
    (news sites) refuse other programs but show w3m the article."""
    r = subprocess.run(["/usr/bin/w3m", "-o", "accept_encoding=identity", "-dump_source", url],
                       capture_output=True, timeout=60)
    data = r.stdout
    # -dump_source gives the bytes as sent: unpack them if the site packed them anyway
    import bz2, gzip, zlib
    for magic, unpack in ((b"\x1f\x8b", gzip.decompress), (b"BZh", bz2.decompress),
                          (b"\x78", zlib.decompress)):
        if data.startswith(magic):
            try:
                data = unpack(data)
            except Exception:
                pass
            break
    m = re.search(rb'charset=["\']?([\w-]+)', data[:4000])
    try:
        return data.decode(m.group(1).decode() if m else "utf-8", "replace")
    except LookupError:
        return data.decode("utf-8", "replace")


def readable(raw):
    """Does the page hold some text in paragraphs (not a refusal or an empty shell)?"""
    return raw and len(re.findall(r"<p[\s>]", raw, re.I)) >= 3


def fetch(url):
    """Directly first; when refused or empty, the way w3m does it."""
    err = None
    try:
        raw = fetch_direct(url)
        if readable(raw):
            return raw
    except Exception as e:
        err, raw = e, ""
    if os.path.exists("/usr/bin/w3m"):
        try:
            alt = fetch_w3m(url)
            if readable(alt) or not raw:
                return alt or raw
        except Exception:
            pass
    if err and not raw:
        raise err
    return raw


def main():
    a = sys.argv[1:]
    only_html = bool(a) and a[0] == "--html"
    if only_html:
        a = a[1:]
    if len(a) != 2:
        print("usage: web2wg URL FILE.wg   |   web2wg --html URL FILE.html", file=sys.stderr)
        return 2
    url, dest = a
    try:
        raw = fetch(url)
    except Exception as e:
        print(f"web2wg: cannot get {url}: {e}", file=sys.stderr)
        return 1
    title, page = clean(raw, url)
    if only_html:
        open(dest, "w", encoding="utf-8").write(page)
        return 0
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "page.html")
        open(src, "w", encoding="utf-8").write(page)
        r = subprocess.run(["/usr/bin/wordgrinder", "--convert", src, dest],
                           capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(dest):
        print("web2wg: WordGrinder could not convert the page: " + (r.stderr or r.stdout)[-300:],
              file=sys.stderr)
        return 1
    print(title)
    return 0


if __name__ == "__main__":
    sys.exit(main())
WEB2WG
	chmod 755 "$STAGE/usr/local/lib/han/web2wg"
	cat > "$STAGE/usr/local/bin/bib" <<'BIBPY'
#!/usr/bin/env python3
# bib [WHICH]  a Sunday's readings of the Revised Common Lectionary, in
# WordGrinder, to write your commentary between the lines. The Sunday's
# name and readings come from Vanderbilt's RCL calendar
# (lectionary.library.vanderbilt.edu), the texts from Bible Gateway.
#   bib               this coming Sunday (today, if it is Sunday)
#   bib +1 / -1       the Sunday after that / last Sunday (+2, -3 ...)
#   bib 2027-01-03    the Sunday of that date (that day, or the Sunday after)
#   bib 01-03         the same, this year
# Saved as ~/bible/DATE.wg and DATE.odt (for LibreOffice); a day you already
# started opens again as you left it.
# Settings, in ~/.config/han/bible (these are the defaults):
#   VERSION=NIV               (ESV, KJV, NRSVUE ...: see biblegateway.com/versions)
#   TRACK=complementary       (after Pentecost: or semicontinuous)
# Any book and chapter: bibr      The one-year plan: bibt
import datetime, html, os, re, subprocess, sys, urllib.parse

KO = bool(os.environ.get("HAN_ACTIVE"))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "han", "bible")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "han")
DIR = os.path.expanduser("~/bible")
CAL = "https://lectionary.library.vanderbilt.edu/calendar/{year}/?season=all"
WEB2WG = "/usr/local/lib/han/web2wg"


def say(ko, en):
    return ko if KO else en


def settings():
    s = {"VERSION": "NIV", "TRACK": "complementary"}
    try:
        for line in open(CONF, encoding="utf-8"):
            m = re.match(r"\s*([A-Z]+)=\s*['\"]?([^'\"#\s]*)", line)
            if m:
                s[m.group(1)] = m.group(2)
    except OSError:
        pass
    return s


def sunday_of(text):
    """The Sunday asked for: that date, or the Sunday after it."""
    today = datetime.date.today()
    coming = today + datetime.timedelta(days=(6 - today.weekday()) % 7)
    if not text:
        return coming
    if re.fullmatch(r"[+-]\d+", text):
        return coming + datetime.timedelta(weeks=int(text))
    if re.fullmatch(r"\d\d-\d\d", text):
        text = f"{today.year}-{text}"
    d = datetime.date.fromisoformat(text)
    return d + datetime.timedelta(days=(6 - d.weekday()) % 7)


def church_year(d):
    """Vanderbilt's calendar page for d: "2025-26" (from the First Sunday of Advent)."""
    def advent(y):
        nov27 = datetime.date(y, 11, 27)
        return nov27 + datetime.timedelta(days=(6 - nov27.weekday()) % 7)
    y = d.year if d >= advent(d.year) else d.year - 1
    return f"{y}-{(y + 1) % 100:02d}"


def web2wg():
    from importlib.machinery import SourceFileLoader
    return SourceFileLoader("web2wg", WEB2WG).load_module()


def calendar(year):
    """[(date, name, other name, [cell, ...] with [ref, ...] each)] of that church year."""
    os.makedirs(CACHE, exist_ok=True)
    cached = os.path.join(CACHE, f"rcl-{year}.html")
    if os.path.exists(cached) and os.path.getsize(cached) > 10000:
        raw = open(cached, encoding="utf-8", errors="replace").read()
    else:
        raw = web2wg().fetch(CAL.format(year=year))
        open(cached, "w", encoding="utf-8").write(raw)
    out = []
    for row in re.findall(r"(?s)<tr>(.*?)</tr>", raw):
        m = re.search(r'(?s)<a href="[^"]*texts/\?[^"]*">\s*(.*?)\s*</a>\s*<p>(.*?)</p>', row)
        if not m:
            continue
        info = [x.strip() for x in html.unescape(re.sub(r"<[^>]+>", "|", m.group(2))).split("|") if x.strip()]
        when = next((x for x in info if re.fullmatch(r"[A-Z][a-z]{2} \d\d, \d{4}", x)), None)
        if not when:
            continue
        date = datetime.datetime.strptime(when, "%b %d, %Y").date()
        other = next((x for x in info if x != when and not x.startswith("(")), "")
        cells = [[html.unescape(r.strip()) for r in re.findall(r'(?s)<span title="[^"]*">([^<]*)</span>', td)]
                 for td in re.findall(r"(?s)<td>(.*?)</td>", row)[1:]]
        out.append((date, html.unescape(m.group(1)).strip(), other, [c for c in cells if c]))
    return out


def readings(cells, track):
    """The day's references, in order. Seasons after Pentecost give two
    tracks first (semicontinuous: reading + psalm; complementary: the same)."""
    if len(cells) >= 4 and len(cells[0]) >= 2 and len(cells[1]) >= 2 and cells[1][-1].startswith("Psalm"):
        first = cells[1] if track.startswith("c") else cells[0]
        return first + [r for c in cells[2:] for r in c]
    return [r for c in cells for r in c]


def body(page):
    page = page.split("<body>", 1)[-1].split("</body>", 1)[0]
    return re.sub(r"<p>https?://[^<]*</p>\s*$", "", page.strip())


def make(day, st, dest):
    w = web2wg()
    year = church_year(day)
    try:
        days = calendar(year)
    except Exception as e:
        print(say(f"성서정과 달력을 가져오지 못했습니다: {e}", f"Could not get the lectionary calendar: {e}"))
        return False
    found = [x for x in days if x[0] == day]
    if not found:
        print(say(f"{day} 는 성서정과 달력에 없습니다 ({year}).", f"{day} is not in the lectionary calendar ({year})."))
        return False
    _, name, other, cells = found[0]
    refs = list(dict.fromkeys(readings(cells, st["TRACK"])))
    parts = [f"<h1>{day.isoformat()}  {html.escape(name)}</h1>"]
    if other:
        parts.append(f"<p><i>{html.escape(other)}</i></p>")
    parts.append("<p>" + html.escape("  /  ".join(refs)) + f"  ({html.escape(st['VERSION'])})</p>")
    url = "https://www.biblegateway.com/passage/?" + urllib.parse.urlencode(
        {"search": "; ".join(refs), "version": st["VERSION"]})
    try:
        parts.append(re.sub(r"<(/?)h1>", r"<\1h2>", body(w.clean(w.fetch(url), url)[1])))
    except Exception as e:
        parts.append(f"<p>{html.escape(say('본문을 가져오지 못함: ', 'texts not got: ') + str(e))}</p>")
    page = "<html><head><meta charset='utf-8'></head><body>\n" + "\n".join(parts) + "\n</body></html>"
    tmp = dest + ".tmp.html"
    open(tmp, "w", encoding="utf-8").write(page)
    subprocess.run(["/usr/bin/wordgrinder", "--convert", tmp, dest], capture_output=True)
    os.remove(tmp)
    if os.path.exists(dest):
        subprocess.run(["/usr/bin/wordgrinder", "--convert", dest, dest[:-3] + ".odt"], capture_output=True)
    return os.path.exists(dest)


def main():
    a = sys.argv[1:]
    if a[:1] in (["-h"], ["--help"]):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:16]), end="")
        return 0
    test = a[:1] == ["--test"]                 # bib --test [WHICH]: build it fresh, print the text
    if test:
        a = a[1:]
    try:
        day = sunday_of(a[0] if a else "")
    except ValueError:
        print(say(f"날짜를 모르겠습니다: {a[0]}   예: bib 2027-01-03", f"Unknown date: {a[0]}   e.g. bib 2027-01-03"))
        return 1
    if a and not re.fullmatch(r"[+-]\d+", a[0]) and day.isoformat() != sunday_of("").isoformat():
        print(say(f"주일: {day}", f"Sunday: {day}"))
    if test:
        f = "/tmp/bib-test.wg"
        ok = make(day, settings(), f)
        subprocess.run(["/usr/bin/wordgrinder", "--convert", f, "/tmp/bib-test.txt"], capture_output=True)
        print(open("/tmp/bib-test.txt", encoding="utf-8", errors="replace").read()[:3000] if ok else "FAILED")
        return 0
    os.makedirs(DIR, exist_ok=True)
    f = os.path.join(DIR, f"{day.isoformat()}.wg")
    if not os.path.exists(f) or os.path.getsize(f) == 0:
        print(say(f"{day} 주일 말씀을 가져오는 중...", f"Getting the readings for {day}..."))
        if not make(day, settings(), f):
            return 1
    os.execvp("wg", ["wg", f])


if __name__ == "__main__":
    sys.exit(main())
BIBPY
	chmod 755 "$STAGE/usr/local/bin/bib"
	ln -sf bib "$STAGE/usr/local/bin/bible"
	# bibr: any book and chapter (Bible Gateway in English, bskorea.or.kr in Korean)
	cat > "$STAGE/usr/local/bin/bibr" <<'BIBRPY'
#!/usr/bin/env python3
# bibr: read the Bible like a book (in hb), where you stopped: a book and
# chapter of your choice; < > previous / next chapter (into the next book).
# bibt: today's readings of the "Bible in One Year" plan (1517.org/oneyear:
# an Old and a New Testament reading each day); < > the day before / after,
# a: the whole chapters instead of the verses given (and back).
# Both: in the translation you choose (English ones from Bible Gateway,
# Korean ones from 대한성서공회 bskorea.or.kr), asked the first time and
# with c; Alt+W writes notes in WordGrinder (shown here when saved); F11
# shows the same text at the same place. Kept in ~/bible/ (.wg and .odt).
#   bibr                 go on where you stopped     bibr -c   choose
#   bibr john 3          John 3          bibr 요한복음 3
#   bibt                 today's readings             bibt 2026-12-24
#   bibr --check         try chapter 1 of every book in Korean (site check)
import datetime, html, json, os, re, subprocess, sys, urllib.parse

KO = bool(os.environ.get("HAN_ACTIVE"))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "han")
TOOL = "bibt" if os.path.basename(sys.argv[0]).startswith("bibt") else "bibr"
LAST = os.path.join(CONF, TOOL + ".json")
DIR = os.path.expanduser("~/bible/read")
DAILY = os.path.expanduser("~/bible/daily")
PLAN = "https://www.1517.org/oneyear?dates={ms}"
WEB2WG = "/usr/local/lib/han/web2wg"
Y, C, D, R = "\033[1;33m", "\033[36m", "\033[2m", "\033[0m"

ENGLISH = [("ESV", "English Standard Version"), ("NIV", "New International Version"),
           ("KJV", "King James Version"), ("NKJV", "New King James Version"),
           ("NRSVUE", "New Revised Standard Version Updated"), ("NASB", "New American Standard Bible"),
           ("NLT", "New Living Translation"), ("CSB", "Christian Standard Bible"),
           ("RSV", "Revised Standard Version"), ("MSG", "The Message")]
KOREAN = [("GAE", "개역개정"), ("HAN", "개역한글"), ("SAE", "표준새번역"), ("SAENEW", "새번역"),
          ("COG", "공동번역"), ("COGNEW", "공동번역 개정판")]

# English name, Korean name, bskorea code, chapters
BOOKS = [
    ("Genesis", "창세기", "gen", 50), ("Exodus", "출애굽기", "exo", 40), ("Leviticus", "레위기", "lev", 27),
    ("Numbers", "민수기", "num", 36), ("Deuteronomy", "신명기", "deu", 34), ("Joshua", "여호수아", "jos", 24),
    ("Judges", "사사기", "jdg", 21), ("Ruth", "룻기", "rut", 4), ("1 Samuel", "사무엘상", "1sa", 31),
    ("2 Samuel", "사무엘하", "2sa", 24), ("1 Kings", "열왕기상", "1ki", 22), ("2 Kings", "열왕기하", "2ki", 25),
    ("1 Chronicles", "역대상", "1ch", 29), ("2 Chronicles", "역대하", "2ch", 36), ("Ezra", "에스라", "ezr", 10),
    ("Nehemiah", "느헤미야", "neh", 13), ("Esther", "에스더", "est", 10), ("Job", "욥기", "job", 42),
    ("Psalms", "시편", "psa", 150), ("Proverbs", "잠언", "pro", 31), ("Ecclesiastes", "전도서", "ecc", 12),
    ("Song of Songs", "아가", "sng", 8), ("Isaiah", "이사야", "isa", 66), ("Jeremiah", "예레미야", "jer", 52),
    ("Lamentations", "예레미야애가", "lam", 5), ("Ezekiel", "에스겔", "ezk", 48), ("Daniel", "다니엘", "dan", 12),
    ("Hosea", "호세아", "hos", 14), ("Joel", "요엘", "jol", 3), ("Amos", "아모스", "amo", 9),
    ("Obadiah", "오바댜", "oba", 1), ("Jonah", "요나", "jnh", 4), ("Micah", "미가", "mic", 7),
    ("Nahum", "나훔", "nam", 3), ("Habakkuk", "하박국", "hab", 3), ("Zephaniah", "스바냐", "zep", 3),
    ("Haggai", "학개", "hag", 2), ("Zechariah", "스가랴", "zec", 14), ("Malachi", "말라기", "mal", 4),
    ("Matthew", "마태복음", "mat", 28), ("Mark", "마가복음", "mrk", 16), ("Luke", "누가복음", "luk", 24),
    ("John", "요한복음", "jhn", 21), ("Acts", "사도행전", "act", 28), ("Romans", "로마서", "rom", 16),
    ("1 Corinthians", "고린도전서", "1co", 16), ("2 Corinthians", "고린도후서", "2co", 13),
    ("Galatians", "갈라디아서", "gal", 6), ("Ephesians", "에베소서", "eph", 6), ("Philippians", "빌립보서", "php", 4),
    ("Colossians", "골로새서", "col", 4), ("1 Thessalonians", "데살로니가전서", "1th", 5),
    ("2 Thessalonians", "데살로니가후서", "2th", 3), ("1 Timothy", "디모데전서", "1ti", 6),
    ("2 Timothy", "디모데후서", "2ti", 4), ("Titus", "디도서", "tit", 3), ("Philemon", "빌레몬서", "phm", 1),
    ("Hebrews", "히브리서", "heb", 13), ("James", "야고보서", "jas", 5), ("1 Peter", "베드로전서", "1pe", 5),
    ("2 Peter", "베드로후서", "2pe", 3), ("1 John", "요한일서", "1jn", 5), ("2 John", "요한이서", "2jn", 1),
    ("3 John", "요한삼서", "3jn", 1), ("Jude", "유다서", "jud", 1), ("Revelation", "요한계시록", "rev", 22),
]


def say(ko, en):
    return ko if KO else en


def ask(prompt):
    try:
        return input(prompt).strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)


def korean(ver):
    return any(v == ver for v, _ in KOREAN)


def state():
    """What was read last: {"ver", "mode": "daily"|"book", "date", "book", "chap"}"""
    try:
        return json.load(open(LAST))
    except (OSError, ValueError):
        return {}


def save_state(st):
    os.makedirs(CONF, exist_ok=True)
    json.dump(st, open(LAST, "w"))


def last():
    """This tool's translation (bibt: ESV from 1517.org, like the plan)."""
    return state().get("ver") or ("ESV" if TOOL == "bibt" else "")


def save_ver(ver):
    pass                                         # kept with the state


def book_by(code):
    return next((b for b in BOOKS if b[2] == code), None)


KOF = os.path.join(CONF, "bible-korean")        # there: the Korean ones are listed too


def pick_version(english_only=False):
    """English translations; the Korean ones only once asked for (k)."""
    old = last()
    show_ko = not english_only and os.path.exists(KOF)
    vers = ENGLISH + (KOREAN if show_ko else [])
    print(say("번역 고르기", "Choose a translation"))
    for i, (v, name) in enumerate(vers, 1):
        if i == 1:
            print(f"  {D}English (Bible Gateway; bibt's ESV from 1517.org){R}")
        if i == len(ENGLISH) + 1:
            print(f"  {D}한국어 (대한성서공회){R}")
        mark = " *" if v == old else ""
        print(f"  {Y}{i:2d}){R} {C}{v:8}{R} {name}{mark}")
    if not english_only:
        print(f"  {Y} k){R} " + (say("한국어 번역 숨기기", "hide the Korean translations") if show_ko
                                 else say("한국어 번역도 보기 (대한성서공회)", "show Korean translations too")))
    dflt = old if old in [v for v, _ in vers] else "ESV"
    a = ask(say(f"번호 (Enter = {dflt}) > ", f"Number (Enter = {dflt}) > "))
    if not a:
        return dflt
    if a.lower() == "k" and not english_only:
        os.makedirs(CONF, exist_ok=True)
        if show_ko:
            os.remove(KOF)
        else:
            open(KOF, "w").close()
        print()
        return pick_version()
    if a.isdigit() and 1 <= int(a) <= len(vers):
        return vers[int(a) - 1][0]
    for v, name in vers:
        if a.lower() in (v.lower(), name.lower()):
            return v
    print(say("그런 번역이 없습니다.", "No such translation."))
    return pick_version(english_only)


def find_book(text):
    t = text.lower().replace(" ", "")
    if t.isdigit() and 1 <= int(t) <= len(BOOKS):
        return [BOOKS[int(t) - 1]]
    exact = [b for b in BOOKS if t in (b[0].lower().replace(" ", ""), b[1], b[2])]
    if exact:
        return exact
    return [b for b in BOOKS if b[0].lower().replace(" ", "").startswith(t) or b[1].startswith(text.replace(" ", ""))]


def pick_book(ver):
    ko = korean(ver)
    rows = [f"{Y}{i:2d}){R} {(b[1] if ko else b[0])}" for i, b in enumerate(BOOKS, 1)]
    width = max(len(re.sub(r"\033\[[0-9;]*m", "", r)) for r in rows) + 2
    cols = max(1, min(4, (os.get_terminal_size().columns if sys.stdout.isatty() else 80) // (width + (6 if ko else 0))))
    per = (len(rows) + cols - 1) // cols
    for r in range(per):
        line = ""
        for c in range(cols):
            k = c * per + r
            if k < len(rows):
                cell = rows[k]
                plain = re.sub(r"\033\[[0-9;]*m", "", cell)
                pad = width + (6 if ko else 0) - sum(2 if "가" <= ch <= "힣" else 1 for ch in plain)
                line += cell + " " * max(1, pad)
        print(line.rstrip())
    while True:
        a = ask(say("책 (번호나 이름, 예: 43, 요한복음, john) > ", "Book (number or name, e.g. 43, john) > "))
        found = find_book(a) if a else []
        if len(found) == 1:
            return found[0]
        if found:
            print("  " + ", ".join(b[1] if ko else b[0] for b in found[:10]))
        else:
            print(say("그런 책이 없습니다.", "No such book."))


def pick_chapter(book, ver):
    if book[3] == 1:
        return "1"
    ko = korean(ver)
    while True:
        a = ask(say(f"장 (1-{book[3]}. 여러 장: 1-4, 3-4,6) > ",
                    f"Chapter (1-{book[3]}; several: 1-4, 3-4,6" + ("; verses: 3:16-21" if not ko else "") + ") > "))
        t = tidy(a, book)
        if t and not (ko and ":" in t):
            if t != re.sub(r"\s+", "", a):
                print(say(f"  -> {t} ({book[3]}장까지 있습니다)", f"  -> {t} (it has {book[3]} chapters)"))
            return t


def url_for(ver, book, chap):
    if TOOL == "bibt" and ver == "ESV":           # bibt's ESV: 1517.org, as the plan
        return "https://www.1517.org/bible?" + urllib.parse.urlencode(
            {"search": "; ".join(f"{book[0]} {p}" for p in chap.split(",")), "version": "ESV"})
    if korean(ver):
        return ("https://www.bskorea.or.kr/bible/korbibReadpage.php?"
                + urllib.parse.urlencode({"version": ver, "book": book[2], "chap": chap}))
    return ("https://www.biblegateway.com/passage/?"
            + urllib.parse.urlencode({"search": f"{book[0]} {chap}", "version": ver}))


def check():
    """Every book's chapter 1 from bskorea: are the book codes right?"""
    import tempfile
    bad = []
    with tempfile.TemporaryDirectory() as d:
        for b in BOOKS:
            f = os.path.join(d, b[2] + ".html")
            r = subprocess.run(["/usr/local/lib/han/web2wg", "--html", url_for("GAE", b, "1"), f],
                               capture_output=True, text=True)
            ok = r.returncode == 0 and os.path.exists(f) and re.search(r"<p>\d+ ", open(f).read())
            print(f"  {b[2]:4} {b[1]:8} {'ok' if ok else 'FAILED'}", flush=True)
            if not ok:
                bad.append(b[2])
    print(say(f"안 되는 책: {' '.join(bad) or '없음'}", f"Failed: {' '.join(bad) or 'none'}"))


def chapters(spec, book):
    """'1-4' / '3-4,6' -> [1, 2, 3, 4] / [3, 4, 6]; a single chapter or a bad spec -> []"""
    if not re.fullmatch(r"\d+(-\d+)?(,\d+(-\d+)?)+|\d+-\d+", spec or ""):
        return []
    out = []
    for part in spec.split(","):
        a, _, b = part.partition("-")
        a, b = int(a), min(int(b or a), book[3])     # past the book's end: to its end
        if not (1 <= a <= b):
            return []
        out += [c for c in range(a, b + 1) if c not in out]
    return out


def tidy(spec, book):
    """The chapters as typed, with ranges past the book's end cut to its end
    (John 20-30 -> 20-21, John 30 -> 21); None if it makes no sense."""
    spec = re.sub(r"\s+", "", spec or "")
    m = re.fullmatch(r"(\d+)(:[\d\-,]+)?", spec)
    if m:
        n = int(m.group(1))
        if n < 1:
            return None
        return spec if n <= book[3] else str(book[3])
    parts = []
    for part in spec.split(","):
        a, _, b = part.partition("-")
        if not (a.isdigit() and (not b or b.isdigit())):
            return None
        a, b = min(int(a), book[3]), min(int(b or a), book[3])
        if a > b or a < 1:
            continue
        parts.append(str(a) if a == b else f"{a}-{b}")
    return ",".join(parts) if parts else None


def fetch(ver, book, chap):
    """The chapter's files (.wg for notes, .odt to read); its .odt, or None.
    Several chapters (1-4, 3-4,6) go into one document."""
    os.makedirs(DIR, exist_ok=True)
    name = (f"{book[1]} {chap}장" if korean(ver) else f"{book[0]} {chap}").replace(":", "_")
    base = os.path.join(DIR, f"{name} ({ver})")
    many = chapters(chap, book)
    if (not os.path.exists(base + ".wg") or os.path.getsize(base + ".wg") == 0) and many:
        print(say(f"{name} ({ver}) 가져오는 중...", f"Getting {name} ({ver})..."))
        w = web2wg()
        parts = []
        try:
            if korean(ver):                      # bskorea: a page per chapter
                for c in many:
                    url = url_for(ver, book, str(c))
                    parts.append(body(w.clean(w.fetch(url), url)[1]))
            else:                                # Bible Gateway (or 1517): all at once
                q = "; ".join(f"{book[0]} {p}" for p in chap.split(","))
                url = url_for(ver, book, chap) if TOOL == "bibt" and ver == "ESV" else \
                    "https://www.biblegateway.com/passage/?" + urllib.parse.urlencode({"search": q, "version": ver})
                parts.append(body(w.clean(w.fetch(url), url)[1]))
        except Exception as e:
            print(say("가져오지 못했습니다. 인터넷 연결을 확인하세요.", "Could not get it (online?)."))
            print("  " + str(e)[-200:])
            return None
        page = "<html><head><meta charset='utf-8'></head><body>\n" + "\n".join(parts) + "\n</body></html>"
        tmp = base + ".tmp.html"
        open(tmp, "w", encoding="utf-8").write(page)
        subprocess.run(["/usr/bin/wordgrinder", "--convert", tmp, base + ".wg"], capture_output=True)
        os.remove(tmp)
    if not os.path.exists(base + ".wg") or os.path.getsize(base + ".wg") == 0:
        print(say(f"{name} ({ver}) 가져오는 중...", f"Getting {name} ({ver})..."))
        r = subprocess.run(["/usr/local/lib/han/web2wg", url_for(ver, book, chap), base + ".wg"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print(say("가져오지 못했습니다. 인터넷 연결을 확인하세요.", "Could not get it (online?)."))
            print("  " + r.stderr.strip()[-200:])
            return None
    if not os.path.exists(base + ".odt") or os.path.getmtime(base + ".odt") < os.path.getmtime(base + ".wg"):
        subprocess.run(["/usr/bin/wordgrinder", "--convert", base + ".wg", base + ".odt"],
                       capture_output=True)
    return base + ".odt"


def step(book, chap, d):
    """The chapter after (d=1) or before (d=-1), into the next book; after
    several chapters (3-4,6), from the last (or the first) of them."""
    many = chapters(chap, book)
    n = (many[-1] if d > 0 else many[0]) + d if many else int(chap.split(":")[0]) + d
    k = BOOKS.index(book)
    if n < 1:
        if k == 0:
            return book, "1"
        book = BOOKS[k - 1]
        return book, str(book[3])
    if n > book[3]:
        return (BOOKS[k + 1], "1") if k + 1 < len(BOOKS) else (book, str(book[3]))
    return book, str(n)


def web2wg():
    from importlib.machinery import SourceFileLoader
    return SourceFileLoader("web2wg", WEB2WG).load_module()


def plan_refs(day):
    """The day's readings of the 1517 plan: ["1 Chronicles 22-24", "Luke 3"]"""
    w = web2wg()
    ms = int(datetime.datetime(day.year, day.month, day.day,
                               tzinfo=datetime.timezone.utc).timestamp() * 1000)
    raw = w.fetch(PLAN.format(ms=ms))
    refs = re.findall(r'data-date="%s"[^>]*title="([^"]+)"' % day.isoformat(), raw)
    return [html.unescape(r) for r in dict.fromkeys(refs)]


def split_ref(ref):
    """'1 Chronicles 22-24' -> (book, [22, 23, 24], ''); 'Psalm 119:1-88' -> (book, [119], ':1-88')"""
    m = re.fullmatch(r"(.+?)\s+(\d+)(?:-(\d+))?(:[\d\-,]+)?", ref.strip())
    if not m:
        return None, [], ""
    name = m.group(1).replace("Psalm", "Psalms").replace("Song of Solomon", "Song of Songs")
    found = find_book(name)
    if len(found) != 1:
        found = [b for b in BOOKS if b[0].lower() == name.lower()] or found[:1]
    a = int(m.group(2))
    b = int(m.group(3)) if m.group(3) and not m.group(4) else a
    return (found[0] if found else None), list(range(a, b + 1)), (m.group(4) or "")


def body(page):
    page = page.split("<body>", 1)[-1].split("</body>", 1)[0]
    return re.sub(r"<p>https?://[^<]*</p>\s*$", "", page.strip())


def daily(ver, day, whole=False):
    """The day's readings in one document (whole: the whole chapters, not
    only the verses the plan gives): its .odt, or None."""
    os.makedirs(DAILY, exist_ok=True)
    base = os.path.join(DAILY, f"{day.isoformat()} ({ver})" + (say(" 장 전체", " whole") if whole else ""))
    if not os.path.exists(base + ".wg") or os.path.getsize(base + ".wg") == 0:
        print(say(f"{day.isoformat()} 읽을 말씀 가져오는 중...", f"Getting the readings for {day.isoformat()}..."))
        w = web2wg()
        try:
            refs = plan_refs(day)
        except Exception as e:
            print(say(f"일년 일독표를 가져오지 못했습니다: {e}", f"Could not get the reading plan: {e}"))
            return None
        if not refs:
            print(say("그날 읽을 말씀이 표에 없습니다.", "The plan has no readings for that day."))
            return None
        json.dump(refs, open(os.path.join(DAILY, day.isoformat() + ".refs"), "w"))
        def shown(ref):
            book, chaps, _ = split_ref(ref)
            if not (korean(ver) and book):
                return ref
            return f"{book[1]} {chaps[0]}" + (f"-{chaps[-1]}" if len(chaps) > 1 else "") + "장"
        parts = [f"<h1>{day.isoformat()} ({ver})</h1>",
                 "<p>" + html.escape("  /  ".join(shown(r) for r in refs)) + "</p>"]
        for n, ref in enumerate(refs):
            book, chaps, verses = split_ref(ref)
            label = (say("구약", "Old Testament") if n == 0 else say("신약", "New Testament")) \
                if len(refs) == 2 else ""
            if book is None:
                parts.append(f"<h1>{html.escape(ref)}</h1><p>?</p>")
                continue
            name = shown(ref)
            parts.append(f"<h1>{html.escape((label + ': ' if label else '') + name)}</h1>")
            try:
                if korean(ver):                  # bskorea: one page per chapter
                    for c in chaps:
                        url = url_for(ver, book, str(c))
                        parts.append(re.sub(r"<(/?)h1>", r"<\1h2>", body(w.clean(w.fetch(url), url)[1])))
                else:                            # Bible Gateway or 1517: the whole reference at once
                    q = f"{book[0]} {chaps[0]}" + (f"-{chaps[-1]}" if len(chaps) > 1 else "") if whole else ref
                    url = ("https://www.1517.org/bible?" + urllib.parse.urlencode({"search": q, "version": "ESV"})
                           if ver == "ESV" else "https://www.biblegateway.com/passage/?"
                           + urllib.parse.urlencode({"search": q, "version": ver}))
                    parts.append(re.sub(r"<(/?)h1>", r"<\1h2>", body(w.clean(w.fetch(url), url)[1])))
            except Exception as e:
                parts.append(f"<p>{html.escape(say('가져오지 못함: ', 'not got: ') + str(e))}</p>")
        page = "<html><head><meta charset='utf-8'></head><body>\n" + "\n".join(parts) + "\n</body></html>"
        tmp = base + ".tmp.html"
        open(tmp, "w", encoding="utf-8").write(page)
        subprocess.run(["/usr/bin/wordgrinder", "--convert", tmp, base + ".wg"], capture_output=True)
        os.remove(tmp)
        if not os.path.exists(base + ".wg"):
            return None
    if not os.path.exists(base + ".odt") or os.path.getmtime(base + ".odt") < os.path.getmtime(base + ".wg"):
        subprocess.run(["/usr/bin/wordgrinder", "--convert", base + ".wg", base + ".odt"],
                       capture_output=True)
    return base + ".odt"


def day_books(date):
    """The books of that day's readings (for c in bibt)."""
    try:
        refs = json.load(open(os.path.join(DAILY, date + ".refs")))
    except (OSError, ValueError):
        try:
            refs = plan_refs(datetime.date.fromisoformat(date))
        except Exception:
            refs = []
    books = []
    for r in refs:
        b = split_ref(r)[0]
        if b and b not in books:
            books.append(b)
    return books


def pick_in_day(date, ver):
    """bibt c: chapters of your choice, in the books of the day's readings."""
    books = day_books(date)
    if not books:
        return None
    ko = korean(ver)
    book = books[0]
    if len(books) > 1:
        for i, b in enumerate(books, 1):
            print(f"  {Y}{i}){R} {b[1] if ko else b[0]}")
        a = ask(say("책 (Enter = 1) > ", "Book (Enter = 1) > "))
        if a.isdigit() and 1 <= int(a) <= len(books):
            book = books[int(a) - 1]
    print(f"{book[1] if ko else book[0]}")
    return {"book": book[2], "chap": pick_chapter(book, ver)}


def main():
    a = sys.argv[1:]
    if a[:1] in (["-h"], ["--help"]):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:15]), end="")
        return
    if a[:1] == ["--check"]:
        return check()
    st = state()
    ver = last()
    today = datetime.date.today().isoformat()
    if a[:1] == ["-c"] or not ver:
        ver = pick_version(english_only=TOOL == "bibt")
        if TOOL == "bibr":
            book = pick_book(ver)
            st.update(book=book[2], chap=pick_chapter(book, ver))
    if TOOL == "bibt":
        if a and re.fullmatch(r"\d{4}-\d\d-\d\d", a[0]):
            st.update(date=a[0], pick=None)
        elif st.get("date") != today:          # a new day: its readings, verses as given
            st.update(date=today, whole=False, pick=None)
    elif a and a[0] != "-c":                   # bibr john 3 / bibr 요한복음 3:16
        m = re.fullmatch(r"(.+?)\s*(\d+(?:\s*[-,]\s*\d+)*(:[\d\-,]+)?)?", " ".join(a))
        found = find_book(m.group(1)) if m else []
        if len(found) != 1:
            print(say("책 이름을 모르겠습니다: ", "Unknown book: ") + " ".join(a))
            return
        chap = tidy(m.group(2) or "1", found[0]) or "1"
        st.update(book=found[0][2], chap=chap.split(":")[0] if korean(ver) else chap)
    elif not book_by(st.get("book", "")):      # first time: which book
        book = pick_book(ver)
        st.update(book=book[2], chap=pick_chapter(book, ver))
    while True:                                # read; < > a c come back here
        st["ver"] = ver
        save_state(st)
        pick = st.get("pick") if TOOL == "bibt" else None
        if pick and book_by(pick.get("book", "")):
            f = fetch(ver, book_by(pick["book"]), pick["chap"])
        elif TOOL == "bibt":
            f = daily(ver, datetime.date.fromisoformat(st["date"]), st.get("whole", False))
        else:
            f = fetch(ver, book_by(st["book"]), st["chap"])
        if f is None:
            return
        env = dict(os.environ, HAN_HB_BIBR=TOOL + ("-pick" if pick else ""))
        r = subprocess.run(["hb", f], env=env).returncode
        if r in (11, 12) and pick:              # bibt, chosen chapters: within that book
            book = book_by(pick["book"])
            nb, chap = step(book, pick["chap"], 1 if r == 11 else -1)
            if nb is book:
                pick["chap"] = chap
        elif r == 15 and TOOL == "bibt":         # d: back to the day's readings
            st["pick"] = None
        elif r == 14 and TOOL == "bibt":         # v: another translation
            print("\033[2J\033[H", end="")
            ver = pick_version(english_only=True)
        elif r == 10 and TOOL == "bibt":         # c: chapters in the day's books
            print("\033[2J\033[H", end="")
            st["pick"] = pick_in_day(st["date"], ver) or st.get("pick")
        elif r in (11, 12):
            d = 1 if r == 11 else -1
            if TOOL == "bibt":
                st["date"] = (datetime.date.fromisoformat(st["date"]) + datetime.timedelta(days=d)).isoformat()
            else:
                book, chap = step(book_by(st["book"]), st["chap"], d)
                st.update(book=book[2], chap=chap)
        elif r == 13 and TOOL == "bibt" and not pick:
            st["whole"] = not st.get("whole", False)
        elif r == 10:
            print("\033[2J\033[H", end="")
            ver = pick_version(english_only=TOOL == "bibt")
            if TOOL == "bibr":
                book = pick_book(ver)
                st.update(book=book[2], chap=pick_chapter(book, ver))
        else:
            return


if __name__ == "__main__":
    main()
BIBRPY
	chmod 755 "$STAGE/usr/local/bin/bibr"
	ln -sf bibr "$STAGE/usr/local/bin/bibt"    # today's readings (the same program)
	# dic: the English dictionary (sdcv + WordNet); Alt+D looks up a word on screen
	cat > "$STAGE/usr/local/bin/dic" <<'DICPY'
#!/usr/bin/env python3
# dic: the English dictionary (WordNet 3.0), on the console.
#   dic WORD       look it up (ran, mice, cats, running: found as run, mouse...)
#   dic            ask for words, one after another
# In the desktop: Alt+D, then type the first letters of a word on the screen
# (in wg, hb, a web page...): it is marked; Enter shows its meaning.
#   dic --pick PANE  that word picker (what Alt+D runs)
#   dic --buffer     look up what tmux copied last (F6 ... Enter)
import json, os, re, subprocess, sys, unicodedata

KO = bool(os.environ.get("HAN_ACTIVE"))
B, D, R = "\033[1;36m", "\033[2m", "\033[0m"


def say(ko, en):
    return ko if KO else en


def sdcv(word):
    try:
        r = subprocess.run(["sdcv", "-n", "-e", "-j", "--utf8-output", "--utf8-input", word],
                           capture_output=True, text=True, timeout=10)
        return json.loads(r.stdout or "[]")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def forms(w):
    """The word, then its likely dictionary forms (cats -> cat, tried -> try)."""
    out = [w, w.lower()]
    lw = w.lower()
    rules = [("ies", "y"), ("ves", "f"), ("ves", "fe"), ("es", ""), ("s", ""),
             ("ied", "y"), ("ed", ""), ("ed", "e"), ("ing", ""), ("ing", "e"),
             ("ier", "y"), ("iest", "y"), ("er", ""), ("est", ""), ("er", "e"), ("est", "e"),
             ("ly", ""), ("'s", ""), ("s'", "s")]
    for end, new in rules:
        if lw.endswith(end) and len(lw) - len(end) >= 2:
            base = lw[: -len(end)] + new
            out.append(base)
            if end in ("ed", "ing", "er", "est") and len(base) > 3 and base[-1] == base[-2]:
                out.append(base[:-1])            # stopped -> stop, bigger -> big
    seen = []
    for x in out:
        if x not in seen:
            seen.append(x)
    return seen


def clean(text):
    """The word in a bit of copied text: letters, inner - and '."""
    m = re.search(r"[A-Za-z][A-Za-z'\-]*[A-Za-z]|[A-Za-z]", text or "")
    return m.group(0) if m else ""


def lookup(word):
    """(found word, definition text) or (None, suggestions text)"""
    import glob
    if not glob.glob("/usr/share/stardict/dic/*/*.ifo") and \
            not glob.glob(os.path.expanduser("~/.stardict/dic/*/*.ifo")):
        return None, say("사전 파일이 없습니다 (/usr/share/stardict/dic 에 WordNet 이 없음).",
                         "No dictionary files (WordNet is missing from /usr/share/stardict/dic).")
    found, defs = None, []
    for w in forms(word):                      # the word as typed, and its base form
        r = sdcv(w)                            # (tried: the adjective, then "try")
        if r is None:
            return None, say("사전이 없습니다 (sdcv 또는 WordNet 사전이 설치되지 않음).",
                             "No dictionary (sdcv or the WordNet dictionary is missing).")
        for x in r:
            d = x["definition"].strip("\n")
            if d not in defs:
                defs.append(d)
                found = found or w
        if len(defs) >= 2:
            break
    if defs:
        return found, "\n\n".join(defs)
    try:                                       # nothing exact: words that look alike
        r = subprocess.run(["sdcv", "-n", "--utf8-output", word], capture_output=True,
                           text=True, timeout=10).stdout
        alike = re.findall(r"^-->(.+)$", r, re.M)
        alike = [a for a in alike if not a.startswith("WordNet")][:12]
    except (OSError, subprocess.TimeoutExpired):
        alike = []
    msg = say(f"'{word}' 는 사전에 없습니다.", f"'{word}' is not in the dictionary.")
    if alike:
        msg += "\n" + say("비슷한 말: ", "Similar: ") + ", ".join(dict.fromkeys(alike))
    return None, msg


def show(word):
    found, text = lookup(word)
    if found is None:
        print(text)
        return
    lines = text.split("\n")                     # headwords and parts of speech in colour
    text = "\n".join(B + l + R if i == 0 or (l and not l.startswith(" ") and lines[i - 1] == "")
                     or re.fullmatch(r" (noun|verb|adj|adv)", l) else l
                     for i, l in enumerate(lines))
    rows = os.get_terminal_size().lines if sys.stdout.isatty() else 999
    if text.count("\n") + 3 < rows:
        print(text)
        return
    prompt = say("q 닫기, 화살표/Space 넘기기", "q close, arrows/Space scroll")
    subprocess.run(["less", "-R", "-c", "-P", prompt], input=text, text=True)


def wide(c):
    return 2 if unicodedata.east_asian_width(c) in "WF" else 0 if unicodedata.combining(c) else 1


def fold(text, width):
    """Wrap to width screen columns (Korean counts two)."""
    out = []
    for para in text.split("\n"):
        lead = re.match(r" *", para).group(0)
        line, cw = "", 0
        for word in re.split(r"( )", para):
            n = sum(wide(c) for c in word)
            if cw + n > width and line.strip():
                out.append(line.rstrip())
                line, cw = lead + "   " if lead else "", len(lead) + 3 if lead else 0
                if word == " ":
                    continue
            line += word
            cw += n
        out.append(line.rstrip())
    return out


def pick(pane=""):
    """Alt+D: the screen as it is. Type the first letters of a word you see:
    the words that start so are marked (nothing is covered); Tab moves to the
    next one, Enter shows its meaning in a box on the right. A word not on the
    screen: type all of it and press Enter. Keyboard only (no mouse)."""
    import curses, locale
    locale.setlocale(locale.LC_ALL, "")

    def tm(*a):
        return subprocess.run(["tmux", *a], capture_output=True, text=True).stdout

    if not re.fullmatch(r"%\d+", pane or ""):
        pane = tm("display-message", "-p", "#{pane_id}").strip()   # the pane under this panel
    geo = tm("display-message", "-p", "-t", pane, "#{pane_left} #{pane_top}").split()
    left, top = (int(geo[0]), int(geo[1])) if len(geo) == 2 else (0, 0)
    text = tm("capture-pane", "-p", "-t", pane).rstrip("\n").split("\n")

    def ui(scr):
        curses.curs_set(1)
        h, w = scr.getmaxyx()
        words = []                               # (row, col, word) on the screen
        for y, line in enumerate(text):
            col, i = 0, 0
            for m in re.finditer(r"[A-Za-z][A-Za-z'\-]*[A-Za-z]", line):
                col += sum(wide(c) for c in line[i:m.start()])
                i = m.start()
                words.append((top + y, left + col, m.group(0)))
        typed, sel, shown, defl, off = "", 0, "", [], 0
        bx = w // 2                              # the meaning box: right half
        bw = w - bx

        def meaning(word):
            found, t = lookup(word)
            return (found or word), fold(t, bw - 4)

        while True:
            hits = [k for k, (y, x, wd) in enumerate(words)
                    if typed and wd.lower().startswith(typed.lower())]
            if hits:
                sel %= len(hits)
            scr.erase()
            for y, line in enumerate(text):
                try:
                    scr.addstr(top + y, left, line)
                except curses.error:
                    pass
            for n, k in enumerate(hits):        # mark the matching words, letters kept
                y, x, wd = words[k]
                if shown and x + len(wd) > bx:
                    continue
                attr = curses.A_REVERSE | (curses.A_BOLD | curses.A_UNDERLINE if n == sel else 0)
                try:
                    scr.addstr(y, x, wd, attr)
                except curses.error:
                    pass
            win = None
            if shown:
                win = curses.newwin(h - 1, bw, 0, bx)
                win.erase()
                win.box()
                win.addstr(0, 2, f" {shown} "[:bw - 4], curses.A_BOLD)
                for r, l in enumerate(defl[off:off + h - 3]):
                    bold = r + off == 0 or re.fullmatch(r" ?(noun|verb|adj|adv)|\S.*", l)
                    try:
                        win.addstr(1 + r, 2, l, curses.A_BOLD if bold else 0)
                    except curses.error:
                        pass
            if typed:
                tip = say(f" 찾는 단어: {typed}_   Tab 다음   Enter 뜻   Esc 지우기",
                          f" Word: {typed}_   Tab next   Enter meaning   Esc clear")
            elif shown:
                tip = say(" 다른 단어: 첫 글자부터 입력   ↑↓ 넘기기   Esc 닫기",
                          " Another word: type its start   arrows scroll   Esc close")
            else:
                tip = say(" 찾을 단어의 첫 글자부터 입력하세요   Esc 닫기",
                          " Type the start of a word on the screen   Esc close")
            try:
                scr.addstr(h - 1, 0, tip[:w - 1].ljust(w - 1), curses.A_REVERSE)
            except curses.error:
                pass
            scr.noutrefresh()
            if win:
                win.noutrefresh()
            if hits:
                y, x, wd = words[hits[sel]]
                curses.setsyx(y, x)
            curses.doupdate()
            k = scr.getch()
            if k == 27:                          # Esc: clear the typing, close the box, leave
                if typed:
                    typed = ""
                elif shown:
                    shown = ""
                else:
                    return
            elif k in (10, 13, curses.KEY_ENTER):
                if typed:
                    word = words[hits[sel]][2] if hits else typed
                    shown, defl = meaning(clean(word))
                    typed, off = "", 0
                elif not shown:
                    return
            elif k in (9, curses.KEY_RIGHT) and hits:
                sel += 1
            elif k in (curses.KEY_BTAB, curses.KEY_LEFT) and hits:
                sel -= 1
            elif k in (curses.KEY_BACKSPACE, 127, 8):
                typed = typed[:-1]
            elif shown and not typed and k in (curses.KEY_DOWN, curses.KEY_NPAGE, ord(" ")):
                off = min(off + (1 if k == curses.KEY_DOWN else h - 4), max(0, len(defl) - (h - 3)))
            elif shown and not typed and k in (curses.KEY_UP, curses.KEY_PPAGE):
                off = max(0, off - (1 if k == curses.KEY_UP else h - 4))
            elif 0 < k < 256 and (chr(k).isalpha() or chr(k) in "'-"):
                typed += chr(k)
                sel = 0

    curses.wrapper(ui)


def main():
    a = sys.argv[1:]
    if a[:1] in (["-h"], ["--help"]):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:8]), end="")
        return
    first = None
    if a[:1] == ["--pick"]:
        pick(a[1] if len(a) > 1 else "")
        return
    if a[:1] == ["--buffer"]:
        try:
            first = subprocess.run(["tmux", "show-buffer"], capture_output=True,
                                   text=True).stdout
        except OSError:
            first = ""
        first = clean(first)
        if not first:
            print(say("화면에서 고른 단어가 없습니다.", "No word was picked on the screen."))
    elif a:
        first = clean(" ".join(a))
    if first:
        show(first)
        if a[:1] != ["--buffer"]:
            return
    while True:                                  # more words, until Enter alone
        try:
            w = input(f"\n{D}" + say("다른 단어 (Enter 닫기) > ", "Another word (Enter closes) > ") + R)
        except (EOFError, KeyboardInterrupt):
            print()
            return
        w = clean(w)
        if not w:
            return
        show(w)


if __name__ == "__main__":
    main()
DICPY
	chmod 755 "$STAGE/usr/local/bin/dic"
	# w3m: Alt+W sends the page on screen to WordGrinder (wg ADDRESS)
	cat > "$STAGE/usr/local/bin/w3m" <<'EOF'
#!/bin/sh
d="$HOME/.w3m"
mkdir -p "$d" 2>/dev/null
grep -qs 'HAN_WG_NEWWIN' "$d/keymap" ||
	echo 'keymap M-w EXTERN "HAN_WG_NEWWIN=1 wg"' >> "$d/keymap"
exec /usr/bin/w3m "$@"
EOF
	chmod 755 "$STAGE/usr/local/bin/w3m"
	cat > "$STAGE/usr/share/han/wordgrinder.lua" <<'EOF'
-- Aneuu: loaded by /usr/local/bin/wordgrinder (--config).
-- Yes/no questions: with Korean input on, Y types ㅛ and N types ㅜ;
-- take those as yes and no too.
function PromptForYesNo(title, message)
	local result = nil
	local function rtrue() result = true; return "confirm" end
	local function rfalse() result = false; return "confirm" end
	local dialogue = {
		title = title or "Message",
		width = Form.Large,
		height = 2,
		stretchy = true,
		["KEY_^C"] = "cancel",
		["n"] = rfalse, ["N"] = rfalse, ["ㅜ"] = rfalse,
		["y"] = rtrue, ["Y"] = rtrue, ["ㅛ"] = rtrue,
		Form.WrappedLabel {
			value = message,
			x1 = 1, y1 = 1, x2 = -1, y2 = -3,
		},
	}
	Form.Run(dialogue, RedrawScreen,
		"Y for yes, N for no, or CTRL+C to cancel")
	QueueRedraw()
	return result
end

-- English "i" on its own becomes "I" when the word ends (Space or Enter):
-- i -> I, i'm -> I'm, i'll -> I'll, i, -> I,  (not in RAW paragraphs)
do
	local function fix_i()
		local d = rawget(_G, "currentDocument") or rawget(_G, "Document")
		local cp, cw, co = d.cp, d.cw, d.co
		local para = d[cp]
		if not para or para.style == "RAW" then return end
		local word = para[cw]
		if not word then return end
		-- the word as it is left of the cursor (that part is split off)
		local plain = (word:sub(1, co - 1):gsub("%c", ""))
		if plain == "i" or plain:match("^i'%a+$") or plain:match("^i\226\128\153%a+$")
				or plain:match("^i[,.;:!?]+$") then
			local pos = word:find("i", 1, true)
			local new = word:sub(1, pos - 1) .. "I" .. word:sub(pos + 1)
			d[cp] = CreateParagraph(para.style, para:sub(1, cw - 1), new, para:sub(cw + 1))
		end
	end
	for _, name in ipairs({ "SplitCurrentWord", "SplitCurrentParagraph" }) do
		local orig = Cmd[name]
		if orig then
			Cmd[name] = function(...)
				pcall(fix_i)
				return orig(...)
			end
		end
	end
end

-- Every save also writes an .odt next to the .wg (same name), for LibreOffice
-- and for sending. A name typed with .odt is kept as WordGrinder's own .wg
-- (WordGrinder works in that) plus the .odt beside it.
do
	local saveas = Cmd.SaveCurrentDocumentAs
	local export = Cmd.ExportODTFile
	if saveas and export then
		Cmd.SaveCurrentDocumentAs = function(filename, ...)
			if type(filename) == "string" and filename:match("%.[oO][dD][tT]$") then
				filename = filename:gsub("%.[oO][dD][tT]$", ".wg")
			end
			local r = saveas(filename, ...)
			if r then
				local ds = rawget(_G, "documentSet") or rawget(_G, "DocumentSet")
				local name = ds and ds.name
				if type(name) == "string" and name:match("%.wg$") then
					local odt = (name:gsub("%.wg$", ".odt"))
					if pcall(export, odt) then
						NonmodalMessage("Saved: " .. name:match("[^/]*$") .. " + .odt")
					end
				end
			end
			return r
		end
	end
end

-- then your own settings, as WordGrinder would load them
do
	local name = CONFIGDIR .. "/startup.lua"
	local fp = io.open(name, "r")
	if fp then
		local f = load(fp:read("*a"), name)
		fp:close()
		if f then pcall(f) end
	end
end
EOF
	cat > "$STAGE/usr/local/lib/han/bookpop" <<'EOF'
#!/bin/sh
# F11: the book in a panel on the right, its name as the title
d="${XDG_DATA_HOME:-$HOME/.local/share}/han"
if [ -f "$d/book.txt" ]; then
	n="$(cat "$d/book.name" 2>/dev/null)"; n="${n%.*}"
fi
[ -n "${n:-}" ] || n="다시 리눅스 설명서"
n="$(printf '%s' "$n" | sed 's/#/##/g')"
exec tmux display-popup ${1:+-c "$1"} -E -x R -y 0 -w 34% -h 100% -b rounded \
	-T " $n " "HAN_BOOK_PANE=1 hb"
EOF
	chmod 755 "$STAGE/usr/local/lib/han/bookpop"
	# ddakong leaves its terminal half-cooked: Enter (^M) arrived as ^J and
	# Ctrl+Q/Ctrl+S were eaten as flow control (WordGrinder in han and desk),
	# and every line feed sent to the screen became CR+LF, so tmux's "one
	# line down" moved to the left edge too (F11/F12 text spilled left).
	cat > "$STAGE/usr/local/lib/han/ddk" <<'EOF'
#!/bin/sh
# ddakong on a half-cooked terminal (Enter as ^M, no Ctrl+S/Q flow
# control). The console's own settings come back however ddakong ends,
# or Enter on the plain console would show ^M afterwards.
old="$(stty -g 2>/dev/null)"
trap '[ -n "$old" ] && stty "$old" 2>/dev/null' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
stty -icrnl -inlcr -igncr -ixon -ixoff -opost 2>/dev/null
/usr/local/lib/han/imestate en          # ddakong starts in English
/usr/local/bin/ddakong "$@"
exit $?
EOF
	chmod 755 "$STAGE/usr/local/lib/han/ddk"
	# ddakong (patched) runs this on the Hangul key: ko or en. The desk's
	# status bar shows it at the bottom left (한 red / EN).
	cat > "$STAGE/usr/local/lib/han/enkeys" <<'EOF'
#!/bin/sh
# enkeys: English keys (ddakong) while a pane that reads single keys has
# focus; with Korean input on, a lone ㅍ ㄴ ㅂ would wait for the next key.
#   enkeys PANE    English if tmux pane PANE is marked @enkeys, else back
#   enkeys on|off  English now / back (no tmux: plain han)
# ddakong: SIGUSR1 English, SIGUSR2 back to the mode before (DDKENG patch).
case "${1:-}" in
	on)  s=USR1 ;;
	off) s=USR2 ;;
	*)   p="${1:-$(tmux display -p '#{pane_id}' 2>/dev/null)}"
	     if [ "$(tmux show -pqv -t "$p" @enkeys 2>/dev/null)" = 1 ]; then
		     s=USR1
	     else
		     s=USR2
	     fi ;;
esac
u="$(id -u)"
for d in $(pidof ddakong); do
	[ "$(awk '/^Uid:/ { print $2 }' "/proc/$d/status" 2>/dev/null)" = "$u" ] &&
		kill -"$s" "$d" 2>/dev/null
done
exit 0
EOF
	chmod 755 "$STAGE/usr/local/lib/han/enkeys"
	cat > "$STAGE/usr/local/lib/han/imestate" <<'EOF'
#!/bin/sh
echo "$1" > "/tmp/han-ime.$(id -u)" 2>/dev/null
tmux set -gq @ime "$1" 2>/dev/null
exit 0
EOF
	chmod 755 "$STAGE/usr/local/lib/han/imestate"
	cat > "$STAGE/usr/local/lib/han/vidback" <<'EOF'
#!/bin/sh
# Tab in a video: back to the desktop's console. The video goes on.
v="$(cat /tmp/han-desk-vt 2>/dev/null)"
[ -n "$v" ] || exit 0
chvt "$v"
stty -F "/dev/tty$v" -icrnl 2>/dev/null
exit 0
EOF
	cat > "$STAGE/usr/local/lib/han/vidshow" <<'EOF'
#!/bin/sh
# Alt+V in the desktop: back to the video's console
v="$(cat /tmp/han-video-vt 2>/dev/null)"
if [ -z "$v" ]; then
	tmux display-message "재생 중인 영상 없음 (no video playing)"
	exit 0
fi
chvt "$v"
exit 0
EOF
	chmod 755 "$STAGE/usr/local/lib/han/vidback" "$STAGE/usr/local/lib/han/vidshow"

	# For testing in QEMU: link this VM to "vx" on the host, which then
	# runs commands here (nothing to type or copy in the VM window).
	cat > "$STAGE/usr/local/bin/vxa" <<'EOF'
#!/bin/sh
# vxa: let the host's vx run commands in this VM.   vxa [PORT]
wget -qO- "10.0.2.2:${1:-8000}/a" | sh
EOF
	chmod 755 "$STAGE/usr/local/bin/vxa"

	cat > "$STAGE/usr/local/lib/han/bookpane" <<'EOF'
#!/bin/sh
# The book pane of a desktop window:  bookpane toggle|next|prev WINDOW
# A pane on the right running hb; the keyboard stays in your program.
w="${2:-}"
p="$(tmux list-panes -t "$w" -F '#{pane_id} #{@hanbook}' 2>/dev/null | awk '$2 == 1 { print $1; exit }')"
open() {
	p="$(tmux split-window -t "$w" -h -d -l 34% -P -F '#{pane_id}' \
		'HAN_BOOK_PANE=1 exec hb')" && tmux set-option -p -t "$p" @hanbook 1
	# a line above the panes, with the book's name as the title
	d="${XDG_DATA_HOME:-$HOME/.local/share}/han"
	n=""
	if [ -f "$d/book.txt" ]; then n="$(cat "$d/book.name" 2>/dev/null)"; n="${n%.*}"; fi
	[ -n "$n" ] || n="다시 리눅스 설명서"
	tmux set-option -p -t "$p" @title "$n"
	tmux set-option -w -t "$w" pane-border-status top
	tmux set-option -w -t "$w" pane-border-format "#{?#{@title},#[bold] #{@title} ,}"
}
shut() {
	tmux kill-pane -t "$p"
	# keep the title line while another titled pane (e.g. the AI chat) is open
	tmux list-panes -t "$w" -F '#{@title}' | grep -q . ||
		tmux set-option -w -u -t "$w" pane-border-status
}
case "${1:-toggle}" in
	toggle) if [ -n "$p" ]; then shut; else open; fi ;;
	next)   if [ -n "$p" ]; then tmux send-keys -t "$p" Space; else open; fi ;;
	prev)   if [ -n "$p" ]; then tmux send-keys -t "$p" b; else open; fi ;;
esac
exit 0
EOF
	chmod 755 "$STAGE/usr/local/lib/han/bookpane"

	# >>> han-book (generated by tools/embed.py: edit tools/han-book)
	cat > "$STAGE/usr/local/bin/hb" <<'HANBOOK'
#!/usr/bin/env python3
# hb: read a book, full screen or in the F11 panel of the desktop.
#   hb FILE    make FILE the current book and open it: epub, pdf, docx,
#              hwpx, hwp, odt, doc, rtf, fb2, html, txt, md
#   hb         open the current book where you stopped
#   hb -r      go back to the built-in Aneuu manual
# In the desktop, F11 shows the book in a panel on the right, titled with
# its name: F10 next page, F9 previous page, F11 again closes it.
# Keys here: Space/Enter/Right/PgDn next page, b/Left/PgUp previous page,
#       g first page, G last page, q/Esc close. The place is remembered.
#       Alt+W: write about it in WordGrinder (the book's own .wg if it has
#       one, as with bibr; else a new document in ~/web made from its text).
# hb FILE of the book already open keeps its place (and shows any changes).
import curses, html, html.parser, locale, os, re, sys, unicodedata, zipfile
from xml.etree import ElementTree as ET

HOME = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "han")
BOOK, POS, NAME, PATH = (os.path.join(HOME, n) for n in ("book.txt", "book.pos", "book.name",
                                                           "book.path"))
MANUAL = "/usr/share/han/book/aneuu.txt"
KO = bool(os.environ.get("HAN_ACTIVE"))


def say(ko, en):
    return ko if KO else en


class Text(html.parser.HTMLParser):
    """HTML to plain text: one paragraph per line, blank lines between blocks."""
    BLOCK = {"p", "div", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6",
             "blockquote", "pre", "dt", "dd", "section", "table", "ul", "ol"}

    def __init__(self):
        super().__init__()
        self.out, self.cur, self.skip, self.pre = [], [], 0, 0

    def flush(self, blank=False):
        t = "".join(self.cur)
        t = t if self.pre else " ".join(t.split())
        if t.strip():
            self.out.extend(t.split("\n") if self.pre else [t])
        if blank and self.out and self.out[-1] != "":
            self.out.append("")
        self.cur = []

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "head"):
            self.skip += 1
        elif tag == "br":
            self.flush()
        elif tag in ("td", "th"):
            if self.cur and "".join(self.cur).strip():
                self.cur.append("  |  ")
        elif tag in self.BLOCK:
            self.flush(tag not in ("li", "tr", "dd"))
            if tag == "pre":
                self.pre += 1
            elif tag in ("h1", "h2", "h3"):
                self.cur.append("■ " if tag == "h1" else "▪ ")
            elif tag == "li":
                self.cur.append("· ")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "head"):
            self.skip = max(0, self.skip - 1)
        elif tag in self.BLOCK:
            self.flush(tag not in ("li", "tr", "dt"))
            if tag == "pre":
                self.pre = max(0, self.pre - 1)

    def handle_data(self, data):
        if not self.skip:
            self.cur.append(data)


def html_text(data):
    p = Text()
    p.feed(data)
    p.flush()
    return p.out


def epub_text(path):
    lines = []
    with zipfile.ZipFile(path) as z:
        ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container",
              "o": "http://www.idpf.org/2007/opf"}
        opf = ET.fromstring(z.read("META-INF/container.xml")).find(".//c:rootfile", ns).get("full-path")
        root = ET.fromstring(z.read(opf))
        base = os.path.dirname(opf)
        items = {i.get("id"): i.get("href") for i in root.findall(".//o:manifest/o:item", ns)}
        for ref in root.findall(".//o:spine/o:itemref", ns):
            href = items.get(ref.get("idref"))
            if not href or "nav" in href.lower() or "cover" in href.lower():
                continue
            name = os.path.normpath(os.path.join(base, href)).replace("\\", "/")
            try:
                lines += html_text(z.read(name).decode("utf-8", "replace")) + [""]
            except KeyError:
                pass
    return lines


# Characters of "ambiguous" width (bullets, curly quotes, box lines...):
# the font draws them wide, the terminal counts them narrow, and the lines
# drift into the next pane. Plain ASCII stand-ins instead.
FOLD = {
    "\u00b7": "-", "\u2022": "*", "\u25aa": "*", "\u25a0": "*", "\u25cf": "*",
    "\u25cb": "o", "\u25e6": "o", "\u203b": "*", "\u2219": "-", "\u30fb": "-",
    "\u201c": '"', "\u201d": '"', "\u2018": "'", "\u2019": "'", "\u2026": "...",
    "\u2013": "-", "\u2014": "--", "\u2015": "--", "\u2192": "->", "\u2190": "<-",
    "\u2191": "^", "\u2193": "v", "\u00d7": "x", "\u00b0": " deg",
    "\u2500": "-", "\u2501": "-", "\u2502": "|", "\u2503": "|",
    "\u250c": "+", "\u2510": "+", "\u2514": "+", "\u2518": "+",
    "\u251c": "+", "\u2524": "+", "\u252c": "+", "\u2534": "+", "\u253c": "+",
    "\u00a0": " ", "\u25a1": "[ ]", "\u2610": "[ ]", "\u2611": "[x]",
}


def console_safe(c):
    """True for characters fbterm draws as wide as the terminal counts them:
    plain letters and signs, Hangul, CJK. Emoji and other newer wide signs are
    counted differently and push the rest of the line out of its place."""
    o = ord(c)
    if o < 0x300 or 0xAC00 <= o <= 0xD7A3 or 0x1100 <= o <= 0x11FF or 0x3130 <= o <= 0x318F:
        return True
    if o > 0xFFFF or c in "\u200d\ufe0e\ufe0f":
        return False
    if unicodedata.east_asian_width(c) in "WF":
        return 0x2E80 <= o <= 0xA4CF or 0xF900 <= o <= 0xFAFF or 0xFE30 <= o <= 0xFE4F or 0xFF00 <= o <= 0xFFE6
    return True


def fold(line):
    if line.isascii():
        return line
    return "".join(FOLD.get(c, c) for c in line if c in FOLD or console_safe(c))


def cmd_text(cmd):
    import subprocess
    out = subprocess.run(cmd, capture_output=True).stdout
    if not out.strip():
        raise ValueError(" ".join(cmd[:1]) + ": no text")
    return out.decode("utf-8", "replace").split("\n")


def ocr_pdf(path):
    """A scanned PDF (pictures only): read its text with Tesseract, if added
    (had ocr). Slow on old laptops: a few seconds or more per page."""
    import shutil, subprocess, tempfile
    if not shutil.which("tesseract"):
        raise ValueError(say("글자 없이 그림만 있는 PDF (스캔) 입니다. 보기: hv 파일, "
                             "글자로 읽기: had ocr (한 번)",
                             "this PDF has only pictures (a scan). View it: hv FILE; read its "
                             "text: had ocr (once)"))
    info = subprocess.run(["pdfinfo", path], capture_output=True, text=True).stdout
    m = re.search(r"Pages:\s+(\d+)", info)
    pages = int(m.group(1)) if m else 1
    have = subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True).stdout.split()
    langs = "+".join(l for l in ("kor", "eng") if l in have) or "eng"
    out = []
    with tempfile.TemporaryDirectory() as tmp:
        for n in range(1, pages + 1):
            print(say(f"\r글자 읽는 중 (OCR) {n}/{pages} 쪽 ...", f"\rReading text (OCR) page {n}/{pages} ..."),
                  end="", flush=True)
            img = os.path.join(tmp, "p")
            subprocess.run(["pdftoppm", "-r", "200", "-gray", "-png", "-f", str(n), "-l", str(n),
                            "-singlefile", path, img], capture_output=True)
            txt = subprocess.run(["tesseract", img + ".png", "-", "-l", langs],
                                 capture_output=True).stdout.decode("utf-8", "replace")
            out += txt.split("\n") + [""]
    print()
    if not any(l.strip() for l in out):
        raise ValueError(say("글자를 찾지 못했습니다", "no text found"))
    return out


def zip_xml(path, members, para):
    """Text of Word-style XML in a zip (docx, hwpx): a paragraph per line."""
    out = []
    with zipfile.ZipFile(path) as z:
        for name in sorted(n for n in z.namelist() if re.fullmatch(members, n)):
            x = z.read(name).decode("utf-8", "replace")
            x = re.sub(r"</%s>" % para, "\n", x)
            x = html.unescape(re.sub(r"<[^>]+>", "", x))
            out.extend(x.split("\n"))
    return out


def load(path):
    low = path.lower()
    ext = low.rsplit(".", 1)[-1] if "." in low else ""
    if ext == "epub":
        lines = epub_text(path)
    elif ext == "pdf":
        try:
            lines = cmd_text(["pdftotext", "-enc", "UTF-8", "-nopgbrk", path, "-"])
        except ValueError:
            lines = ocr_pdf(path)
    elif ext == "docx":
        lines = zip_xml(path, r"word/document\.xml", "w:p")
    elif ext == "hwpx":
        lines = zip_xml(path, r"Contents/section\d+\.xml", "hp:p")
    elif ext in ("odt", "sxw"):          # paragraphs and headings of content.xml
        x = zipfile.ZipFile(path).read("content.xml").decode("utf-8", "replace")
        x = re.sub(r"<text:(s|tab)\b[^>]*/>", " ", x)
        x = re.sub(r"<text:line-break/>", "\n", x)
        x = re.sub(r"</text:(p|h)>", "\n", x)
        x = re.sub(r"<office:body>|^.*?<office:text[^>]*>", "", x, count=1, flags=re.S)
        lines = [l.strip() for l in html.unescape(re.sub(r"<[^>]+>", "", x)).split("\n")]
        while lines and not lines[0]:
            lines.pop(0)
    elif ext == "doc":
        lines = cmd_text(["antiword", path])
    elif ext == "rtf":
        lines = cmd_text(["unrtf", "--text", path])
    elif ext == "hwp":
        lines = cmd_text(["hwp5txt", path])
    elif ext == "fb2":
        lines = html_text(open(path, encoding="utf-8", errors="replace").read())
    else:
        data = open(path, encoding="utf-8", errors="replace").read()
        if low.endswith((".html", ".htm", ".xhtml")):
            lines = html_text(data)
        else:
            lines = data.split("\n")
    return [fold(l) for l in lines]


def width(s):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else
               0 if unicodedata.combining(c) else 1 for c in s)


def wrap(line, w):
    """Break one line to display width w, at a space when there is one."""
    line = line.expandtabs(4).rstrip()
    if not line:
        return [""]
    out, cur, cw, last = [], "", 0, -1
    for ch in line:
        n = width(ch)
        if cw + n > w:
            if last > 0 and ch != " ":
                out.append(cur[:last].rstrip())
                cur = cur[last:].lstrip()
            else:
                out.append(cur.rstrip())
                cur = ""
            cw, last = width(cur), -1
            if ch == " " and not cur:
                continue
        if ch == " ":
            last = len(cur) + 1
        cur += ch
        cw += n
    out.append(cur.rstrip())
    return out


def to_wg(scr):
    """Alt+W: the book in WordGrinder, to write between its lines."""
    import subprocess
    path = ""
    try:
        path = open(PATH, encoding="utf-8").read().strip()
    except OSError:
        pass
    base = os.path.splitext(path)[0] if path else ""
    wg = base + ".wg" if base and os.path.exists(base + ".wg") else ""
    if not wg:                       # no .wg of its own: a new document from its text
        name = os.path.splitext(open(NAME, encoding="utf-8").read().strip())[0] \
            if os.path.isfile(NAME) else "aneuu"
        d = os.path.expanduser("~/web")
        os.makedirs(d, exist_ok=True)
        wg = os.path.join(d, re.sub(r"[/\\]", "_", name) + ".wg")
        if not os.path.exists(wg):
            text = open(BOOK if os.path.isfile(BOOK) else MANUAL, encoding="utf-8").read()
            page = "<html><head><meta charset='utf-8'></head><body>\n" + "\n".join(
                f"<p>{html.escape(l)}</p>" for l in text.split("\n") if l.strip()) + "\n</body></html>"
            tmp = wg[:-3] + ".tmp.html"
            open(tmp, "w", encoding="utf-8").write(page)
            subprocess.run(["/usr/bin/wordgrinder", "--convert", tmp, wg], capture_output=True)
            os.remove(tmp)
    if os.environ.get("TMUX"):       # a window of its own; the book stays here
        subprocess.run(["tmux", "new-window", "-n", "write", f"han-run wordgrinder '{wg}'"])
    else:
        curses.endwin()
        subprocess.run(["wordgrinder", wg])
        scr.refresh()


def run(scr, src, title, place, save, bible=False, reload=None):
    curses.curs_set(0)
    scr.keypad(True)
    try:
        curses.use_default_colors()
    except curses.error:
        pass

    def layout():
        h, w = scr.getmaxyx()
        rows, cols = max(1, h - 1), max(8, w - 1)
        lines, first = [], {}
        for i, s in enumerate(src):
            first.setdefault(i, len(lines))
            lines.extend((i, x) for x in wrap(s, cols))
        return rows, cols, lines, first

    # a place is (paragraph, line inside it), so it survives another width
    def find(pl):
        t = first.get(pl[0], 0) + pl[1]
        while t > 0 and (t >= len(lines) or lines[t][0] != pl[0]):
            t -= 1
        return t

    def here():
        return (lines[top][0], top - first[lines[top][0]]) if lines else (0, 0)

    rows, cols, lines, first = layout()
    top = find(place)
    while True:
        top = max(0, min(top, max(0, len(lines) - 1)))
        scr.erase()
        for y, (_, text) in enumerate(lines[top:top + rows]):
            try:
                scr.addstr(y, 0, text)
            except curses.error:
                pass
        page, pages = top // rows + 1, max(1, -(-len(lines) // rows))
        if os.environ.get("HAN_BOOK_PANE"):
            bar = say(f" {page}/{pages} F10 다음 F9 앞 F11 닫기",
                      f" {page}/{pages} F10 next F9 back F11 close")
        elif bible == "bibt":
            bar = say(f" {title}  {page}/{pages}  < > 날  a 장 전체  c 장 고르기  v 번역  Alt+W 쓰기",
                      f" {title}  {page}/{pages}  < > day  a whole  c chapters  v version  Alt+W write")
        elif bible == "bibt-pick":
            bar = say(f" {title}  {page}/{pages}  < > 장  c 장 고르기  d 오늘 말씀  Alt+W 쓰기",
                      f" {title}  {page}/{pages}  < > chapter  c chapters  d the day's  Alt+W write")
        elif bible:
            bar = say(f" {title}  {page}/{pages}  Space 다음  < > 장  c 고르기  Alt+W 쓰기  q",
                      f" {title}  {page}/{pages}  Space next  < > chapter  c choose  Alt+W write  q")
        else:
            bar = say(f" {page}/{pages}  Space 다음  b 앞  q 닫기",
                      f" {page}/{pages}  Space next  b back  q close")
        while width(bar) > cols:
            bar = bar[:-1]
        try:
            scr.addstr(rows, 0, bar + " " * (cols - width(bar)), curses.A_REVERSE)
        except curses.error:
            pass
        scr.refresh()
        save(here())                    # the panel can be closed at any moment

        k = scr.getch()
        if reload:                      # the file changed (notes written in wg): read it again
            new = reload()
            if new is not None:
                keep = here()
                src[:] = new
                rows, cols, lines, first = layout()
                top = find(keep)
        if k == 27:                     # Esc alone, or a key the terminal
            scr.nodelay(True)           # description does not know
            seq = ""
            while True:
                c = scr.getch()
                if c == -1:
                    break
                seq += chr(c) if 0 <= c < 256 else ""
            scr.nodelay(False)
            if seq in ("w", "W") and not os.environ.get("HAN_BOOK_PANE"):
                to_wg(scr)                  # Alt+W
                continue
            k = {"": ord("q"), "[23~": curses.KEY_F11, "[21~": curses.KEY_F10,
                 "[20~": curses.KEY_F9, "[6~": curses.KEY_NPAGE,
                 "[5~": curses.KEY_PPAGE, "[C": curses.KEY_RIGHT, "[D": curses.KEY_LEFT,
                 "[B": curses.KEY_DOWN, "[A": curses.KEY_UP, "OC": curses.KEY_RIGHT,
                 "OD": curses.KEY_LEFT}.get(seq, -1)
        if k in (ord("q"), ord("Q"), curses.KEY_F11):
            break
        if bible and k in (ord(">"), ord("."), ord("<"), ord(","), ord("c"), ord("C"),
                           ord("a"), ord("v"), ord("d")):
            if k == ord("a") and bible != "bibt" or k in (ord("v"), ord("d")) and not bible.startswith("bibt"):
                continue
            save(here())
            return {ord(">"): 11, ord("."): 11, ord("<"): 12, ord(","): 12, ord("a"): 13,
                    ord("v"): 14, ord("d"): 15}.get(k, 10)
        elif k in (ord(" "), 10, 13, ord("n"), ord("j"), curses.KEY_NPAGE, curses.KEY_F10,
                   curses.KEY_RIGHT, curses.KEY_DOWN, curses.KEY_ENTER):
            if top + rows < len(lines):
                top += rows
        elif k in (ord("b"), ord("p"), ord("k"), curses.KEY_PPAGE, curses.KEY_LEFT, curses.KEY_F9,
                   curses.KEY_UP, curses.KEY_BACKSPACE, 127):
            top -= rows
        elif k in (ord("g"), curses.KEY_HOME):
            top = 0
        elif k in (ord("G"), curses.KEY_END):
            top = (max(0, len(lines) - 1) // rows) * rows
        elif k == curses.KEY_RESIZE:
            keep = here()
            rows, cols, lines, first = layout()
            top = find(keep)
    return here()


def main():
    locale.setlocale(locale.LC_ALL, "")
    os.makedirs(HOME, exist_ok=True)
    args = sys.argv[1:]
    if args and args[0] in ("-h", "--help"):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:10]), end="")
        return 0
    if args and args[0] == "-r":
        for f in (BOOK, POS, NAME, PATH):
            if os.path.exists(f):
                os.remove(f)
        args = []
    if args:
        path = args[0]
        if not os.path.isfile(path):
            print(say(f"hb: 파일이 없습니다: {path}", f"hb: no such file: {path}"))
            return 1
        try:
            text = load(path)
        except Exception as e:
            print(say(f"hb: 이 파일을 읽지 못했습니다 ({e})", f"hb: cannot read this file ({e})"))
            return 1
        full = os.path.abspath(path)
        try:
            same = open(PATH, encoding="utf-8").read().strip() == full
        except OSError:
            same = False
        open(BOOK, "w", encoding="utf-8").write("\n".join(text))
        open(NAME, "w", encoding="utf-8").write(os.path.basename(path))
        open(PATH, "w", encoding="utf-8").write(full)
        if not same:                    # another book: from its start
            open(POS, "w").write("0 0")
    book = BOOK if os.path.isfile(BOOK) else MANUAL
    if not os.path.isfile(book):
        print(say("hb: 책이 없습니다.  hb 파일.epub", "hb: no book yet.  hb FILE.epub"))
        return 1
    src = [fold(l) for l in open(book, encoding="utf-8", errors="replace").read().split("\n")]
    posfile = POS if book == BOOK else POS + ".manual"
    try:
        a, b = open(posfile).read().split()
        pos = (int(a), int(b))
    except (OSError, ValueError):
        pos = (0, 0)
    title = open(NAME, encoding="utf-8").read() if book == BOOK and os.path.isfile(NAME) else "Aneuu"
    def save(pl):
        try:
            open(posfile, "w").write(f"{pl[0]} {pl[1]}")
        except OSError:
            pass

    # the book's file changed (notes saved from WordGrinder): show the new text
    reload = None
    try:
        srcpath = open(PATH, encoding="utf-8").read().strip() if book == BOOK else ""
    except OSError:
        srcpath = ""
    if srcpath and os.path.isfile(srcpath):
        seen = [os.path.getmtime(srcpath)]

        def reload():
            try:
                m = os.path.getmtime(srcpath)
            except OSError:
                return None
            if m == seen[0]:
                return None
            seen[0] = m
            try:
                text = load(srcpath)
            except Exception:
                return None
            open(BOOK, "w", encoding="utf-8").write("\n".join(text))
            return [fold(l) for l in text]
    bible = "" if os.environ.get("HAN_BOOK_PANE") else os.environ.get("HAN_HB_BIBR", "")
    if bible:
        title = os.path.splitext(title)[0]
    r = curses.wrapper(run, src, title, pos, save, bible, reload)
    if isinstance(r, int):              # bibr: 10 choose, 11 next chapter, 12 previous
        return r
    save(r)
    return 0


if __name__ == "__main__":
    sys.exit(main())
HANBOOK
	chmod 755 "$STAGE/usr/local/bin/hb"
	ln -sf hb "$STAGE/usr/local/bin/han-book"   # the old, longer name
	mkdir -p "$STAGE/usr/share/han/book"
	cat > "$STAGE/usr/share/han/book/aneuu.txt" <<'HANMANUAL'
* 다시 리눅스 사용 설명서

Aneuu Linux -- 헌 노트북을 다시 쓰는 한글 콘솔 리눅스 첫걸음

다시 리눅스 만든 사람들

2026년 11월 (0판)

자유롭게 복사하고 나눌 수 있습니다 (CC BY-SA 4.0)

* 이 책을 펴며

* 다시 리눅스란

다시(영어 이름 Aneuu)는 서랍 속에 잠든 옛날 노트북을 다시 쓸 수 있게 해 주는 작은 리눅스입니다. 이름처럼, 버려질 뻔한 노트북을 다시 꺼내 쓰자는 뜻입니다. 이 책에서는 헷갈리지 않도록 다시 리눅스라고 부릅니다.

윈도우처럼 창과 아이콘이 있는 그래픽 화면 대신, 검은 바탕에 글자로 된 콘솔(글자 화면)에서 씁니다. 그래서 메모리가 적고 느린 노트북에서도 빠릅니다. 글자 화면이지만 할 수 있는 일은 많습니다.

하고 싶은 일 | 쓰는 프로그램
문서 쓰기 | WordGrinder (wg)
메모, 텍스트 편집 | nano
파일 정리, USB 복사 | nnn, husb
PDF, 전자책(EPUB), 워드, 한글 파일 보기 | hv (han-view)
웹 보기 | w3m, chawan, NetSurf(그림 보임)
메일 | aerc
일정, 할 일 | calcurse
가계부, 표 계산 | sc-im
음악, 동영상, 사진 | cmus, mpv, fbi
유튜브 | yt
블루투스 헤드폰, 스피커, 키보드, 마우스 | hbt (F8)
번역 | trans
뉴스 구독 | newsboat
팟캐스트 | pod
채팅(IRC) | irssi
내려받기, 토렌트 | aria2, rtorrent
옛날 도스 게임 | DOSBox (hdos)
모든 웹사이트(유튜브, 은행) | Firefox (hx firefox, 메모리 2 GB 이상)

모든 곳에서 한글을 읽고 쓸 수 있습니다.

* 누구를 위한 책인가

리눅스를 처음 만지는 분을 위한 책입니다. 명령어를 몰라도 됩니다. 이 책에 나오는 대로 한 글자씩 따라 입력하면 됩니다.

이 책에서 이렇게 생긴 글자는 키보드로 입력하는 것입니다.

desk

입력한 뒤에는 늘 Enter 키를 누릅니다. 따로 말하지 않아도 그렇습니다.

F1, Ctrl+S 같은 것은 키를 누르라는 뜻입니다. Ctrl+S 는 Ctrl 키를 누른 채로 S 를 누르는 것입니다.

* 길을 잃었을 때

다시 리눅스 안에도 이 책의 요약이 들어 있습니다.

- doc -- 안내서 (주제를 고르면 그 설명이 나옵니다)
- F12 -- 지금 쓰고 있는 프로그램의 키 요약 (화면 오른쪽에 나왔다가, 다시 누르면 사라집니다)

이 판에 대해: 이 책은 다시 리눅스 0판(첫 판)에 맞춰 썼습니다. 지금 판 번호는 cat /etc/aneuu-release 로 볼 수 있습니다. 다시 리눅스는 아직 여러 노트북에서 시험하는 중이라, 어떤 노트북에서는 이 책과 조금 다르게 움직일 수 있습니다. 그럴 때는 문제 해결 장을 보세요.

* 준비하기

* 필요한 것

- 다시 쓸 노트북 -- 2005년 무렵 이후의 것이면 대부분 됩니다.
- USB 메모리 하나 -- 2 GB 이상. 안의 내용은 지워질 수 있으니 비워 두세요.
- USB 를 만들 다른 컴퓨터 -- 윈도우, 맥, 리눅스 무엇이든 됩니다.
- 다시 리눅스 ISO 파일 -- 다시 리눅스 설치 파일입니다. 64비트와 32비트 두 가지가 있습니다.

* 64비트와 32비트 고르기

ISO 파일은 두 가지입니다.

- aneuu-0-x86_64.iso -- 64비트
- aneuu-0-x86.iso -- 32비트

(가운데 0 은 판 번호입니다. 새 판이 나오면 숫자가 커집니다.)

노트북 | 고를 것
2008년 이후 대부분 (코어2 듀오, 코어 i3/i5/i7, AMD 애슬론64 이후) | 64비트
윈도우 7/10 64비트가 깔려 있던 노트북 | 64비트
넷북 (아톰 N270, N280), 펜티엄 M, 셀러론 M, 코어 듀오(코어2 아님) | 32비트
잘 모르겠다 | 64비트로 먼저 해 보고, 켜지지 않으면 32비트

64비트를 32비트 노트북에서 켜면 "x86-64 CPU 가 필요하다"는 영어 글이 나오고 멈춥니다. 고장이 아니니 걱정하지 말고 32비트로 다시 만드세요.

* 메모리(RAM)는 얼마나

다시 리눅스는 메모리가 2 GB 이상 있어야 합니다.

메모리 | 할 수 있는 것
2 GB | USB 로 켜서 바로 모든 콘솔 프로그램과 유튜브를 쓸 수 있습니다
4 GB 이상 | Firefox 까지 편하게 쓸 수 있습니다

노트북의 메모리 크기는 다시 리눅스를 켠 뒤 free -m 으로 볼 수 있습니다.

* 부팅 USB 만들기

ISO 파일은 그냥 USB 에 복사만 해서는 켜지지 않습니다. 아래 셋 가운데 하나로 만드세요.

* 방법 1: Ventoy (추천)

Ventoy 를 한 번 설치해 두면, 그다음부터는 ISO 파일을 USB 에 복사만 하면 됩니다. 다른 ISO 도 여러 개 넣어 두고 골라서 켤 수 있습니다.

- 다른 컴퓨터에서 ventoy.net 에 들어가 Ventoy 를 내려받습니다.
- 압축을 풀고 Ventoy2Disk.exe 를 실행합니다.
- 장치에서 USB 메모리를 고르고 설치(Install) 를 누릅니다. (USB 안의 내용이 모두 지워집니다.)
- 끝나면 USB 가 Ventoy 라는 이름으로 보입니다. 다시 리눅스 ISO 파일을 그 안에 복사합니다.

켤 때 Ventoy 메뉴가 나오면 다시 리눅스 ISO 를 고르고 Enter 를 누릅니다. "Boot in normal mode" 를 물으면 그것을 고릅니다.

* 방법 2: Rufus (윈도우)

- rufus.ie 에서 Rufus 를 내려받아 실행합니다.
- 장치에서 USB 메모리를, 부트 선택에서 다시 리눅스 ISO 파일을 고릅니다.
- 시작을 누릅니다.
- 쓰기 방식을 물으면 DD 이미지 모드를 고릅니다.

* 방법 3: 리눅스나 맥에서

USB 장치 이름을 정확히 확인한 뒤(잘못 고르면 그 디스크가 지워집니다):

sudo dd if=aneuu-0-x86_64.iso of=/dev/sdX bs=4M status=progress
sync

/dev/sdX 는 USB 의 이름(예: /dev/sdb)으로 바꾸세요.

* USB 로 켜기

* 부트 메뉴 열기

- 노트북을 끈 상태에서 USB 를 꽂습니다.
- 전원을 켜자마자 부트 메뉴 키를 여러 번 톡톡 누릅니다.
- 나온 목록에서 USB(이름에 USB, 또는 USB 회사 이름이 보입니다)를 고릅니다.

노트북 회사마다 키가 다릅니다. 흔한 예는 이렇습니다.

회사 | 부트 메뉴 | 바이오스(BIOS) 설정
삼성 | F10 | F2
LG | F10 | F2
레노버 (씽크패드 포함) | F12 | F1 또는 F2
HP | Esc 다음 F9 | Esc 다음 F10
델(Dell) | F12 | F2
에이수스(ASUS) | Esc | F2
에이서(Acer) | F12 | F2
도시바 | F12 | F2

안 되면 켤 때 화면 아래에 잠깐 나오는 영어 안내("Press F12 for boot menu" 같은)를 보거나, "노트북 모델명 부트 메뉴"로 찾아보세요.

* 시큐어 부트(Secure Boot) 끄기

2012년 이후의 노트북은 "보안 부팅" 때문에 USB 가 켜지지 않을 수 있습니다. 그러면 바이오스 설정에 들어가 Secure Boot 를 Disabled(끔) 로 바꾸고, F10 으로 저장하고 나옵니다. (메뉴 위치는 보통 Security 나 Boot 안에 있습니다.)

* 켜지는 동안

글자가 빠르게 지나가다가 다음과 같은 줄이 나오면 다 켜진 것입니다.

Aneuu 0 (Alpine Linux) tty1
Log in as root.  Then: desk = desktop, doc = guide / 안내서

aneuu login:

USB 로 켤 때는 모든 프로그램을 메모리로 옮기기 때문에 1~3분쯤 걸립니다.

* 처음 로그인

* 로그인하기

login: 옆에 root 를 입력하고 Enter 를 누릅니다. USB 로 처음 켰을 때는 비밀번호가 없어서 바로 들어가집니다.

aneuu login: root

들어가면 다시 리눅스의 짧은 안내가 나오고, 맨 아래에 이런 줄이 보입니다.

aneuu:~#

이것을 프롬프트라고 합니다. "이제 명령을 입력하세요"라는 뜻입니다.

root 는 이 컴퓨터의 관리자 이름입니다. 다시 리눅스는 한 사람이 쓰는 노트북을 위한 것이라 root 로 씁니다.

* 비밀번호 정하기

인터넷에 연결하기 전에, 그리고 하드디스크에 설치할 생각이면 꼭 비밀번호를 정하세요.

passwd

새 비밀번호를 두 번 묻습니다. 입력하는 동안 화면에 아무것도 나오지 않는데, 고장이 아니라 비밀번호를 숨기는 것입니다. 입력하고 Enter 를 누르면 됩니다.

* 첫 명령 해 보기

doc

안내서가 열립니다. 처음에는 언어를 묻습니다. 1 (한국어)을 고르세요. 주제 번호나 이름을 입력하면 그 설명이 나오고, q 를 누르면 닫힙니다.

* 한글 입력

* 한/영 바꾸기

오른쪽 Alt 키(한/영 키가 있으면 그 키도)를 누를 때마다 한글과 영어가 바뀝니다. 자판은 두벌식입니다. 윈도우에서 쓰던 그대로입니다.

연습해 보세요. 한글 상태에서 dkssudgktpdy 를 치면 안녕하세요가 됩니다.

* 한글이 되는 곳

어디에서 | 한글 입력
desk (콘솔 데스크톱) 안의 모든 프로그램 | 오른쪽 Alt
han (문서 작성), han -s (한글 셸) | 오른쪽 Alt
NetSurf (그림이 보이는 웹) | 그 안에서 오른쪽 Alt
Firefox (hx firefox) | 그 안에서 오른쪽 Alt

로그인한 바로 그 화면(프롬프트)에서는 한글이 보이기만 하고 입력은 안 됩니다. 한글을 입력하려면 desk 를 먼저 켜세요. 이 책에서는 늘 desk 안에서 쓴다고 생각하면 됩니다.

* 글꼴과 글자 크기

처음에는 영어는 Terminus, 한글은 도스 명조(myungjo) 글꼴로 나옵니다(16 픽셀). 로그인한 바로 그 화면(커널 콘솔)도 같은 두 글꼴을 씁니다. 그래서 desk 안과 밖의 글자 모양이 같습니다. 다른 한글 비트맵 글꼴도 여러 가지 들어 있습니다: 도스 시절 글꼴, 갈무리, 네오둥근모 등.

han -l

크기별 글꼴 목록이 나옵니다. 모양을 직접 보려면(한글 화면 밖, 로그인한 바로 그 화면에서):

han -d

글꼴을 하나씩 보여 줍니다(Enter 다음, q 그만). 마음에 드는 글꼴로 문서 작성을 시작하려면 이름을 붙입니다.

han gothic
han neodgm32

화면이 큰 노트북은 24, 32 픽셀 글꼴(miraero, neodgm32)이, 작은 넷북은 16 픽셀 글꼴이 보기 좋습니다. 글꼴은 han 을 새로 켤 때만 바뀝니다. 이미 한글 화면 안이라면 exit 로 나간 뒤 다시 켜세요.

영어 글자를 명조와 어울리는 세리프(삐침이 있는) 글꼴로 바꿀 수도 있습니다:

HAN_LATIN="Courier Bitmap" han

글꼴 | 모양
Courier Bitmap | 비트맵 쿠리어 (9x15). 16 픽셀 한글 글꼴과 잘 맞고 글자 사이가 촘촘합니다
Courier Prime | 깔끔한 쿠리어. 글자 칸이 넓어 사이가 조금 뜹니다
Libertinus Mono | 책 글꼴 느낌. 큰 글꼴(24 픽셀 이상)에 좋습니다
IBM Plex Mono | 획이 굵어 작은 글씨도 잘 보입니다

늘 그렇게 쓰려면 /etc/han.conf 에 LATIN="Courier Bitmap" 를 적습니다 (root). (한글이 보이는 커널 콘솔에서는 han -f 로 켜야 이 글꼴이 쓰입니다. 커널 콘솔의 글꼴은 도스 명조와 Terminus 로 정해져 있습니다.)

* 콘솔 데스크톱: desk

* 데스크톱 열기

desk

화면 아래에 파란 상태 줄이 생깁니다. 왼쪽에는 열려 있는 창의 목록, 오른쪽에는 배터리, 네트워크, 남은 메모리, 날짜와 시각이 보입니다.

데스크톱에서는 프로그램 하나가 창 하나를 차지합니다. 창은 겹치지 않고, 책장을 넘기듯 하나씩 바꿔 봅니다.

* 꼭 알아 둘 키

키 | 하는 일
F1 | 프로그램 메뉴
F2 / F3 | 이전 창 / 다음 창
F4 | 새 셸 창 (명령을 입력하는 창)
F5 | 무선랜 목록
F6 | 화면 글 복사 시작
F7 | 복사한 글 붙여넣기
F8 | 블루투스 기기
F11 | 일하면서 옆에 책 펴기 (다시 누르면 닫힘)
F10 / F9 | 책 다음 쪽 / 앞 쪽
F12 | 지금 프로그램의 키 요약 (다시 누르면 닫힘)
Alt+G | AI 에게 묻기 (다시 누르면 닫힘)
Alt+O | 옆 칸으로 (쓰던 글과 AI 칸, 책 사이)
Alt+D | 영어 단어 뜻 (단어 앞 글자 입력, Tab 다음, Enter)
Alt+N | 뉴스 피드 보기 / 숨기기 (오른쪽 패널)
Alt+P | 팟캐스트 재생기 보기 / 숨기기
Alt+V | 재생 중인 영상으로 (영상에서 Tab 은 데스크톱으로)
Alt+W | (w3m 에서) 보고 있는 페이지의 글을 WordGrinder 로
오른쪽 Alt | 한글 / 영어

* 프로그램 메뉴 (F1)

F1 을 누르면 화면 가운데에 메뉴가 나옵니다. 화살표로 고르고 Enter, 또는 오른쪽 괄호 안의 글자 키를 바로 누릅니다. > 가 붙은 줄은 하위 메뉴이고, 하위 메뉴에서 , (쉼표) 를 누르면 처음 메뉴로 돌아갑니다. F1 을 한 번 더 누르거나 Esc 를 누르면 메뉴가 닫힙니다.

처음 메뉴 | 키 | 안에 있는 것
글쓰기 Write | w | 문서 작성 (WordGrinder)
편집 Edit text | e | 텍스트 편집 (nano)
파일 Files | f | 파일 관리 (nnn)
인터넷 Internet > | i | 웹 (w3m, chawan, NetSurf), 메일, 뉴스, 팟캐스트, 채팅, 유튜브, 토렌트, Firefox
생활 Daily > | d | 일정, 표 계산, 주소록, 음악
놀이 Fun > | p | 도스 게임, 어드벤처 게임, NetHack
시스템 System > | s | 무선랜, 블루투스, USB 연결, 시스템 보기, 디스크 사용량, 화면 잠금
새 셸 Shell | t | 명령을 입력하는 새 창
안내서 Guide | ? | doc
끝내기 Quit | q | 데스크톱 끝내기

프로그램을 끝내면 그 창도 닫힙니다.

* 화면의 글 복사하고 붙여넣기 (F6, F7)

콘솔에서는 마우스를 쓸 수 없어서, 키보드로 글을 고릅니다.

- F6 을 누릅니다. 화면 오른쪽 위에 [0/120] 같은 표시가 나오면 복사 상태입니다.
- 화살표로 복사할 글의 처음으로 갑니다. Space 를 누릅니다.
- 화살표로 글의 끝으로 갑니다. 고른 부분이 색으로 보입니다.
- Enter 를 누르면 복사되고 복사 상태가 끝납니다. (그만두려면 q)
- 붙여넣을 곳으로 가서 F7 을 누릅니다.

예전에 지나간 글을 보고 싶을 때도 F6 을 누르고 PgUp 으로 올라가 보면 됩니다.

* 키 도움말 (F12)

어떤 프로그램에서든 F12 를 누르면 화면 오른쪽 3분의 1에 그 프로그램의 키 요약이 나옵니다. 보면서 일하다가 F12 를 다시 누르면 사라집니다.

* 일하면서 옆에 책 펴기 (F11)

F11 을 누르면 화면 오른쪽에 책이 펴지고, 위에 책 이름이 나옵니다. 키보드는 그대로 왼쪽에 있어서, 글을 쓰거나 명령을 입력하거나 웹을 보면서 옆의 책을 함께 볼 수 있습니다. 처음에는 바로 이 설명서가 들어 있습니다.

키 | 하는 일
F11 | 책 펴기 / 닫기
F10 | 다음 쪽
F9 | 앞 쪽

읽던 곳은 기억합니다. 닫았다가 다시 펴도, 다른 창에서 펴도 그 쪽이 나옵니다.

F12 는 다릅니다. F12 는 지금 쓰는 프로그램의 키 요약을 잠깐 보여 주는 것이고(다시 누르면 닫힘), F11 은 책이나 긴 글을 일하는 동안 옆에 계속 펴 두는 것입니다.

다른 책을 넣으려면 hb 를 씁니다. EPUB 전자책, PDF, 워드(.docx, .doc), 한글(.hwpx, .hwp), .odt, .rtf, 텍스트, 웹 페이지(.html)의 글을 읽습니다 (PDF 는 글자만, 그림은 빠집니다):

hb 소설.epub

스캔한 PDF 는 글자 없이 그림만 있어서 hb 가 그냥은 읽지 못합니다. 최근 노트북이라면 한 번 had ocr (root, 인터넷 필요, 약 40 MB) 를 하면 hb 가 쪽마다 글자를 읽어 냅니다(OCR, 쪽마다 몇 초). 오래된 노트북에서는 느리니, 그때는 hv 로 쪽 그림을 보세요.

그 책이 화면 가득 열리고(Space 다음 쪽, b 앞 쪽, q 닫기), 그다음부터 F11 은 그 책을 보여 줍니다. nnn 에서 EPUB 파일에 Enter 를 눌러도 같습니다. 다시 이 설명서로 돌아가려면 hb -r.

* 데스크톱에서 잠깐 나가기

Ctrl+b 를 누르고 손을 뗀 뒤 d 를 누르면 데스크톱에서 나옵니다. 열어 둔 프로그램은 그대로 돌고 있으니, desk 를 다시 입력하면 그대로 돌아옵니다. 완전히 끝내려면 F1 메뉴의 Quit desktop 을 고릅니다.

* 인터넷 연결

* 무선랜 (Wi-Fi)

데스크톱에서 F5 를 누릅니다. (데스크톱 밖이면 hwifi)

 Searching for networks on wlan0 ...

   1)   -42 dBm  WPA   우리집 WiFi
   2)   -71 dBm  open  카페 무료 WiFi

 Number to connect, r = search again, q = quit:

신호가 센 것부터 나옵니다(숫자가 0에 가까울수록 셉니다). 연결할 번호를 입력하고, 비밀번호를 물으면 입력합니다. Connected to ... 가 나오면 성공입니다.

한 번 연결한 무선랜은 다음부터 저절로 연결됩니다. (단, USB 로 켜서 쓰는 동안은 끄면 잊습니다. 저장과 설치를 보세요.)

* 유선 랜선

랜선을 꽂기만 하면 됩니다. 켜기 전에 꽂아 두면 가장 확실합니다.

* 연결되었나 확인하기

ping -c 3 naver.com

3 packets received 같은 줄이 나오면 인터넷이 됩니다.

* 블루투스: 헤드폰, 스피커, 키보드, 마우스

데스크톱에서 F8 을 누릅니다. (데스크톱 밖이면 hbt)

* 새 기기 연결하기

-

기기를 연결 대기(페어링) 상태로 둡니다. 보통 전원 단추나 블루투스 단추를 몇 초 길게 누르면 불빛이 빠르게 깜박입니다. (기기 설명서를 보세요.)

-

s 를 누릅니다. 10초 동안 주변 기기를 찾습니다.

-

목록에 기기가 나오면 그 번호를 입력합니다.

블루투스 기기
   1) 소니 WH-1000XM4        헤드폰
  -- 새로 찾은 기기 --
   2) JBL Flip 5               스피커

번호 = 연결/끊기,  s = 새 기기 찾기,  x번호 = 지우기 (예: x2),  q = 끝
> 2

-

짝을 맺고(페어링) 연결합니다. 연결됨 이 나오면 끝입니다.

- 키보드는 화면에 여섯 자리 숫자가 나옵니다. 그 숫자를 블루투스 키보드로 치고 Enter 를 누르세요.
- 휴대폰이 숫자가 같은지 물으면 yes 를 입력합니다.

* 다음부터는

한 번 짝을 맺은 기기는 목록에 늘 남습니다. 다음에는 F8 을 누르고 번호만 입력하면 연결됩니다. 기기에 따라서는 켜기만 해도 저절로 다시 연결됩니다.

입력 | 하는 일
번호 | 연결, 이미 연결되어 있으면(* 표시) 끊기
x 번호 (예: x2) | 목록에서 지우기 (다시 쓰려면 새로 짝 맺기)
s | 새 기기 찾기
q | 닫기

화면 아래 상태 줄에 bt 기기이름 이 보이면 연결되어 있는 것입니다.

* 블루투스로 소리 듣기

헤드폰이나 스피커가 연결되어 있는 동안 모든 소리(음악, 동영상, 유튜브, 도스 게임)가 저절로 그리로 갑니다. 끊으면 노트북 스피커로 돌아옵니다.

- 연결하기 전에 틀어 둔 음악이나 영상은 한 번 끄고 다시 틀어야 블루투스로 나옵니다.
- 소리 크기는 기기의 단추나 alsamixer 로 바꿉니다.

* 폰 키보드: hkb

이 노트북을 폰의 블루투스 키보드로 쓸 수 있습니다. 폰에서 제미나이 같은 AI 에게 물을 때, 작은 화면 대신 노트북 키보드로 길게 씁니다.

- root 로 hkb (또는 F1 -> 시스템 -> 폰 키보드).
- 폰의 블루투스 목록에서 Aneuu keyboard 를 고릅니다. 처음 한 번만 연결(페어링)하면 됩니다.
- "연결됨" 이 나오면 노트북의 모든 키가 폰으로 갑니다.
- 명령 키는 오른쪽 Ctrl 입니다 (한국 노트북에서는 흔히 한자 키, 둘 다 됩니다). 누른 채로 다른 키를 누릅니다. 이 키는 폰으로 가지 않습니다. 왼쪽 Ctrl 은 폰의 Ctrl 그대로입니다.
- 오른쪽 Ctrl+Tab 을 누르면 키가 노트북(데스크) 으로 갑니다. 폰은 연결된 채입니다. 창을 옮기고, F6 으로 복사하고, wg 에 쓸 수 있습니다. 한 번 더 누르면 다시 폰으로. 바뀔 때마다 아래 상태 줄에 "-> 폰" 이나 "-> 노트북" 이 잠깐 나옵니다.
- 끝낼 때는 오른쪽 Ctrl+Q (폰 쪽에서도, 노트북 쪽에서도).

Ctrl+Alt 를 쓰지 않는 까닭: 다른 컴퓨터의 가상 머신(VM)에서 돌리면 그 컴퓨터(Xfce, QEMU)가 Ctrl+Alt 키를 먼저 가져갑니다. Xfce 의 Ctrl+Alt+Esc 는 창을 죽이는 키입니다.

복사와 붙여넣기

- 노트북 -> 폰: 오른쪽 Ctrl+Tab 으로 노트북에 와서 F6 으로 글을 복사하고, 오른쪽 Ctrl+Tab 으로 폰에 돌아가 오른쪽 Ctrl+V 를 누르면 그 글을 폰에 입력해 줍니다. 한글도 됩니다 (폰의 한/영을 알아서 바꿉니다). 폰이 따라오도록 천천히 칩니다: 300 글자에 30 초쯤. 아래 상태 줄에 얼마나 쳤는지 나오고, Esc 로 멈춥니다. 그동안 다른 키는 폰으로 가지 않습니다. 글자가 빠지면 더 천천히: hkb -d 40 으로 시작하세요 (숫자가 클수록 느림, 처음은 20). 줄 바꿈은 Shift+Enter 로 보냅니다. 챗에서 Enter 는 보내기라서, 그냥 Enter 로 치면 첫 줄만 보내지고 나머지는 사라집니다.
- 폰 -> 노트북: 노트북과 폰이 같은 와이파이에 있으면 hkb 가 화면에 주소를 보여 줍니다 (예: http://192.168.0.5:8000/k3f9q). 폰의 브라우저에서 그 주소를 엽니다. 오른쪽 Ctrl+U 를 누르면 그 주소를 폰에 입력해 줍니다. 제미나이의 답을 길게 눌러 복사해서 상자에 붙여넣고 보내기. 오른쪽 Ctrl+Tab 으로 노트북에 와서 F7 로 붙여넣습니다 (예: wg 안에).
- 그 쪽에는 노트북에서 복사한 글도 보입니다. 길게 눌러 폰에서 복사할 수 있습니다.
- 주소 끝의 글자는 그때마다 바뀝니다. 같은 와이파이의 다른 사람이 쉽게 열지 못하게 하려는 것이고, hkb 를 끝내면 쪽도 닫힙니다.

한글은 폰이 만듭니다. 처음 한 번 폰 설정에서 물리 키보드(실제 키보드, 하드웨어 키보드)를 찾아 한국어 두벌식으로 정하세요. 메뉴 이름은 폰마다 조금 다릅니다.

폰 | 한/영 바꾸기
안드로이드 (삼성, Gboard) | 노트북의 오른쪽 Alt (폰에는 Shift+Space 로 갑니다)
아이폰 | Caps Lock

hkb 를 쓰는 동안은 블루투스가 이 일만 하므로 블루투스 헤드폰이 끊깁니다. 끝내면 다시 연결할 수 있습니다.

* 블루투스가 없다고 나올 때

노트북에 블루투스가 없거나 꺼져 있는 것입니다. 오래된 노트북은 블루투스가 없는 것이 많습니다. USB 블루투스 동글(몇천 원)을 꽂으면 됩니다. 노트북에 무선 스위치나 Fn 키가 있으면 켜 보세요.

* 파일과 USB 메모리

* 폴더와 파일

다시 리눅스에서 내 파일은 /root 폴더에 둡니다. 이것을 "홈 폴더"라고 하고 ~ 로 줄여 씁니다. 도스 게임은 ~/dos, 음악은 ~/music 처럼 폴더를 만들어 두면 편합니다.

mkdir ~/문서 ~/music ~/dos

* 파일 관리자 nnn

nnn

키 | 하는 일
화살표 위/아래 | 고르기
Enter 또는 -> | 열기 (PDF, 전자책, 사진, 영상... 무엇이든), 폴더 들어가기
<- | 위 폴더로
/ | 이름으로 거르기
Space | 파일 선택 (여러 개 가능)
p | 선택한 파일을 지금 폴더로 복사
v | 선택한 파일을 지금 폴더로 이동
? | 모든 키 보기
q | 끝내기

* USB 메모리 쓰기

-

USB 메모리를 꽂고 몇 초 기다립니다.

-

연결합니다.

husb

연결됨: /media/usb 가 나오면 USB 안이 /media/usb 폴더로 열린 것입니다.

-

파일을 복사합니다. nnn 으로 해도 되고, 명령으로 해도 됩니다.

cp ~/문서/편지.odt /media/usb/

-

빼기 전에 꼭 연결을 끊습니다.

husb off

이제 뽑아도 됩니다 가 나온 뒤에 뽑으세요. 그냥 뽑으면 파일이 망가질 수 있습니다.

한글 파일 이름도 그대로 보입니다. 윈도우에서 쓰던 USB(FAT32, exFAT, NTFS)를 모두 읽고 쓸 수 있습니다.

다시 리눅스를 켠 그 USB(특히 Ventoy USB)는 켜져 있는 동안 파일 저장용으로 쓰기 어렵습니다. 파일은 다른 USB 메모리에 담으세요.

* 저장과 설치

* 꼭 알아야 할 것: USB 로 켜면 끄는 순간 잊습니다

USB 로 켠 다시 리눅스는 시스템 전체가 메모리(RAM) 위에서 돕니다. 그래서 빠르고, 노트북의 하드디스크를 전혀 건드리지 않습니다. 하지만 끄면 그동안 만든 파일, 무선랜 비밀번호, 바꾼 설정이 모두 사라집니다.

그래서 두 가지 쓰는 법이 있습니다.

쓰는 법 | 좋은 점 | 할 일
USB 로 켜서 쓰기 | 노트북을 건드리지 않음. 시험해 보기 좋음 | 만든 파일은 꼭 다른 USB 에 복사
하드디스크에 설치 | 모든 것이 남음. 더 빨리 켜짐 | hinst 한 번

오래 쓸 노트북이면 설치를 권합니다.

* 하드디스크에 설치하기: hinst

주의: 고른 디스크의 모든 것이 지워집니다. 윈도우도, 사진도, 문서도. 남길 파일이 있으면 먼저 다른 곳에 옮겨 두세요. 윈도우와 함께 두고 골라 켜는 방식(듀얼 부팅)은 지원하지 않습니다.

-

USB 로 켜서 root 로 로그인하고, desk 를 엽니다.

-

입력합니다.

hinst

-

디스크 목록이 나옵니다. 크기를 보고 노트북 안의 디스크 번호를 입력합니다.

어느 디스크에 설치할까요?
  1)  /dev/sda 111.8G disk sata Samsung SSD
> 1

-

경고가 나오면 yes 를 입력합니다. (다른 글자를 입력하면 그만둡니다.)

-

root 비밀번호를 아직 정하지 않았으면 여기서 정합니다.

-

설치가 진행됩니다. 영어 글이 지나가는 동안 기다립니다.

-

끝났습니다 가 나오면:

poweroff

꺼지면 USB 를 뽑고 다시 켭니다.

설치한 뒤에는 켤 때마다 root 와 정한 비밀번호로 로그인합니다. USB 로 켰을 때 만든 파일(/root 안)과 무선랜, 설정은 함께 옮겨집니다.

* 설치한 뒤 새로 고치기 (업데이트)

한 달에 한 번쯤, 인터넷에 연결한 상태에서:

apk update
apk upgrade

보안 문제가 고쳐진 새 프로그램을 받습니다. 다시 리눅스만의 한글 커널과 한글 NetSurf 는 바뀌지 않도록 고정되어 있으니 그대로 두어도 됩니다.

* 더 설치하기: had

USB 로 켜면 모든 프로그램이 메모리에 올라갑니다. 그래서 무거운 프로그램은 처음에는 빠져 있고, 필요할 때 한 번 설치합니다. 목록을 봅니다 (F1 -> 시스템 -> 더 설치하기 도 같습니다):

had

이름 | 무엇 | 메모리
had netsurf | 그림이 보이는 웹 브라우저 | 약 250 MB
had dosbox | 도스 프로그램 실행기 (hdos), 게임은 따로 | 약 250 MB
had scummvm | 옛 어드벤처 게임 실행기, 게임은 따로 | 약 260 MB
had hwdec | 영상을 그래픽 칩으로 풀기 (빠르고 조용함) | 약 20 MB
had firefox | Firefox (인터넷 필요) | 2 GB 이상
had hwp / had ocr | 한글 .hwp 보기 / 스캔한 PDF 읽기 (인터넷 필요) |
had yt | 유튜브가 안 될 때 yt-dlp 새로 받기 (인터넷 필요) |

root 로 실행합니다. netsurf, dosbox, scummvm, hwdec 는 USB 안에 들어 있어서 인터넷 없이 설치됩니다. netsurf, dosbox, scummvm 은 그래픽 부분(Mesa, 약 230 MB)을 함께 씁니다. USB 로 켠 상태에서 설치한 것은 다시 켜면 없어지고, 쓰는 동안 메모리를 차지합니다. 그래서 하드디스크에 설치한 뒤에 쓰면 좋습니다. 설치되지 않은 프로그램을 켜면 어떻게 설치하는지 알려 줍니다. 다시 빼려면 hadr 이름 (예: hadr dosbox) 입니다. hadr 만 치면 설치된 것을 보여 줍니다. 같이 쓰는 그래픽 부분(Mesa)은 그것을 쓰는 프로그램이 모두 빠졌을 때만 함께 빠집니다.

그 밖의 알파인 프로그램은 apk 로 받습니다:

apk search 이름      (찾기)
apk add 이름         (설치)

USB 로 켜서 쓰는 중이라면 먼저 had net 을 한 번 입력해야 인터넷에서 받을 수 있습니다.

* 문서와 책 보기: hv

받은 파일을 열어 볼 때는 무엇이든 hv 하나로 됩니다 (긴 이름은 han-view).

hv 보고서.pdf

nnn 에서 파일을 고르고 Enter 를 눌러도 똑같이 열립니다.

파일 | 어떻게 열리나 | 키
PDF | 화면 가득, 쪽 그대로 | Space 다음 쪽, b 앞 쪽 (PgDn/PgUp 도 됨), +/- 크기, q 끝
EPUB 전자책 | 책 읽기 (hb); 그 뒤로 F11 로 옆에 펴는 책도 그 책 | Space 다음 쪽, b 앞 쪽, q 끝
워드 .docx .doc, 한글 .hwpx, .odt, .rtf | 글만 뽑아서 보기 | 화살표, q 끝
한글 .hwp | 글만 뽑아서 보기 (먼저 had hwp 한 번) | q 끝
엑셀 .xlsx, .csv | sc-im | :q 끝
사진, 동영상, 음악 | fbi, mpv | q 끝
웹 페이지 .html | w3m | q 끝
압축 파일 | 안에 든 파일 목록 | q 끝

워드와 한글 문서는 글만 보입니다. 표와 그림은 빠집니다. 고쳐서 보내야 하는 문서는 다른 컴퓨터에서 여는 것이 낫습니다.

.hwp 파일을 보려면 인터넷에 연결하고 한 번만:

had hwp

(.hwpx 는 이것 없이도 열립니다.)

* 문서 작성: WordGrinder

wg

한글 입력이 되는 문서 작성 프로그램 WordGrinder 가 열립니다. 바로 글을 쓰면 됩니다. 데스크톱(desk) 안에서도, 밖에서도 wg 입니다. 밖에서는 han 과 같습니다(한글 화면을 켜고 WordGrinder).

키 | 하는 일
Esc | 메뉴 (File 파일, Edit 편집, Style 스타일 ...)
Ctrl+S | 저장
Ctrl+Q | 끝내기

처음 저장하면 파일 이름을 묻습니다. 편지.wg 처럼 끝에 .wg 를 붙이세요. 저장해 둔 문서를 다시 열 때는 wg 편지.wg 입니다.

* 다른 컴퓨터로 보내기

.wg 파일은 WordGrinder 만 엽니다. 그래서 Ctrl+S 로 저장할 때마다 같은 이름의 .odt 파일도 함께 저장됩니다 (편지.wg 옆에 편지.odt). 다른 사람에게는 .odt 를 보내세요. .odt 파일은 LibreOffice, 한컴오피스, MS 워드에서 열립니다.

다른 형식(텍스트, HTML 등)이 필요하면: Esc -> File -> Export -> 형식 고르기.

영어로 쓸 때 i 하나만 쓰면 저절로 I 가 됩니다 (i'm -> I'm).

* 웹 글을 가져와 쓰기

웹에서 읽은 글을 옮겨 놓고 그 사이사이에 내 생각을 쓰고 싶을 때:

wg https://주소

메뉴, 광고, 댓글 같은 것은 빼고 본문만 새 문서로 엽니다 (~/web/ 에 저장). w3m 으로 보고 있다면 Alt+W 한 번이면 같은 일을 합니다. 새 창에 WordGrinder 가 열리고, w3m 은 그대로 있습니다.

페이지를 다시 받아 오므로 몇 초 걸립니다. 자바스크립트로 글을 그리는 사이트, 로그인해야 보이는 글은 잘 안 됩니다.

* 주일 성경 본문에 묵상 쓰기: bib

bib

이번 주일(일요일)의 개정 공동 성서정과(Revised Common Lectionary) 본문을 엽니다. 주일 이름과 본문 목록은 밴더빌트 대학의 성서정과 달력(lectionary.library.vanderbilt.edu)에서, 본문은 Bible Gateway 에서 가져옵니다. 맨 위에 그 주일의 이름이 나옵니다 (예: "2026-11-22 Reign of Christ - Proper 29 (34)", 그 아래 "Twenty-Sixth Sunday after Pentecost").

본문 줄 사이에 바로 묵상을 쓰면 됩니다. ~/bible/2026-11-22.wg 와 .odt 로 저장되고, 같은 날을 다시 부르면 쓰던 그대로 열립니다.

명령 | 하는 날
bib | 이번 주일 (오늘이 주일이면 오늘)
bib +1 / bib -1 | 다음 주일 / 지난 주일
bib 2027-01-05 | 그 날짜의 주일 (그 날이 주일이 아니면 다음 주일)

설정은 ~/.config/han/bible 파일에 씁니다: 번역 VERSION=ESV (기본 NIV), 성령강림절 뒤의 구약 본문 TRACK=semicontinuous (기본 complementary, 주제에 맞춘 본문).

* 오늘 읽을 말씀: bibt

bibt

"일년 일독" 읽기표(1517.org 의 Bible in One Year: 날마다 구약 한 부분과 신약 한 부분)에서 오늘 본문을 찾아, 고른 번역으로 엽니다. 같은 날 다시 열면 읽던 곳부터 이어집니다.

* 성경 읽기: bibr

bibr

처음에는 책과 장을 고르고, 그다음부터는 읽던 장, 읽던 곳부터 열립니다 (전자책처럼). 장은 여러 개도 됩니다: 1-4 (1장부터 4장), 3-4,6 (3, 4, 6장). 한 문서로 이어서 열립니다. 바로 열기: bibr 요한복음 3, bibr john 3-4. 다시 고르기: bibr -c.

* bibt, bibr 의 번역과 키

bibt 는 ESV 로 엽니다. 1517 읽기표가 연결해 둔 바로 그 본문(1517.org)입니다. c 로 다른 영어 번역. bibr 는 처음 한 번 번역을 묻습니다 (ESV, NIV, KJV, NRSVUE 등 영어 번역, Bible Gateway. Enter 는 ESV). 한국어 번역(개역개정, 개역한글, 표준새번역, 새번역, 공동번역, 공동번역 개정판, 대한성서공회)은 쓰고 싶을 때만: 번역 고르는 화면에서 k 를 누르면 목록에 나옵니다 (다시 k 는 숨기기).

키 | bibt | bibr
Space, b | 다음 쪽, 앞 쪽 | 다음 쪽, 앞 쪽
> / < | 다음 날 / 앞 날 (장을 골랐으면 다음 장 / 앞 장) | 다음 장 / 앞 장 (다음 책으로 이어짐)
a | 읽기표의 절만 / 장 전체 바꾸기 |
c | 오늘 본문의 책에서 장 고르기 (1-4,5 처럼) | 번역, 책, 장 고르기
v | 다른 영어 번역 |
d | 고른 장에서 오늘 말씀으로 돌아가기 |
Alt+W | WordGrinder 로 묵상 쓰기 | WordGrinder 로 묵상 쓰기
q | 끝내기 (읽던 곳 기억) | 끝내기 (읽던 곳 기억)

Alt+W 로 쓴 글은 저장(Ctrl+S)하면 읽던 화면에도 바로 보입니다. F11 의 옆 책도 같은 본문, 같은 곳을 보여 줍니다. 하루치는 ~/bible/daily/, 장은 ~/bible/read/ 에 .wg (쓰기) 와 .odt (LibreOffice) 로 남습니다. (한국어 본문은 대한성서공회 사이트가 장 단위라서 언제나 장 전체입니다.)

hb 로 읽는 다른 책에서도 Alt+W 를 누르면 그 책의 글이 새 WordGrinder 문서(~/web/)로 열립니다.

* 영어 단어 뜻: Alt+D

읽거나 쓰다가 모르는 영어 단어가 나오면 Alt+D 를 누르고, 그 단어의 앞 글자 몇 개를 입력합니다. 화면에서 그렇게 시작하는 단어들이 표시되고, 첫째 것에 커서가 갑니다. 다른 것이면 Tab 으로 옮기고, Enter 를 누르면 오른쪽에 뜻이 나옵니다 (WordNet 영영사전). 화면에 없는 단어는 끝까지 입력하고 Enter. Esc 는 입력 지우기, 뜻 닫기, 끝내기 순서입니다.

WordNet 에는 명사, 동사, 형용사, 부사만 있습니다. the, of, and, he 같은 짧은 기능어는 없습니다. went, mice, tried 처럼 바뀐 꼴도 원래 단어를 찾아 줍니다. q 나 Enter 로 닫습니다. 명령으로는 dic 단어.

WordGrinder, hb 로 읽는 책, w3m 웹 페이지 등 데스크톱 화면의 글이면 어디서나 됩니다. (hv 로 PDF 를 그림으로 볼 때는 안 됩니다. 글이 있는 PDF 는 hb 로 여세요.)

* AI 에게 묻기: gem

글을 쓰다가 막히면 옆에 AI 를 불러 물어볼 수 있습니다. 인터넷이 연결되어 있어야 합니다.

* 처음 한 번: 무료 키 넣기

- 휴대폰이나 다른 컴퓨터에서 https://console.groq.com/keys 를 엽니다 (Google 계정으로 로그인).
- Create API Key 를 눌러 키를 만듭니다. gsk_ 로 시작하는 긴 글자입니다.
- 다시 리눅스에서 gem -k 를 입력하고 키를 넣습니다.

(Google Gemini 키도 넣어 두면, Groq 가 안 될 때 대신 씁니다.)

* 쓰기

데스크톱에서 Alt+G 를 누르면 오른쪽에 AI 칸이 열립니다. 물어볼 것을 쓰고 Enter. Alt+G 를 다시 누르면 닫힙니다. 대화는 남아서 다음에 이어집니다.

키, 명령 | 하는 일
Alt+G | 열기 / 닫기
Alt+O | 쓰던 글과 AI 칸 사이를 오가기
/new | 새 대화
/copy | 마지막 답 전체 복사 (붙여넣기는 F7)
/pdf 이름 쪽 | PDF 한 쪽을 같이 보내기 (예: /pdf 계약 3). 이름은 일부만, 정규식도 됩니다
F12 또는 /help | 쓰는 법 요약

* 답의 한 문장을 글로 가져가기

- AI 칸에서 F6 (화면이 멈춥니다)
- 화살표로 문장의 첫 글자로 가서 Space
- 화살표로 문장 끝까지 가서 Enter
- Alt+O 로 WordGrinder 쪽으로 가서 F7

반대로 WordGrinder 의 글을 AI 에게 보낼 때도 같습니다: WordGrinder 에서 1-3, Alt+O 로 AI 칸에 와서 F7, 물어볼 말을 덧붙여 Enter.

AI 의 답은 틀릴 수 있습니다. 중요한 내용은 확인하세요.

* 텍스트 편집: nano

메모, 설정 파일, 간단한 글에는 nano 가 편합니다.

nano 메모.txt

화면 아래 두 줄에 지금 쓸 수 있는 키가 늘 나옵니다. ^ 는 Ctrl, M- 는 Alt 입니다.

키 | 하는 일 | 키 | 하는 일
Ctrl+O | 저장 (Enter 로 이름 확인) | Ctrl+X | 끝내기
Ctrl+W | 찾기 | Ctrl+\ | 바꾸기
Ctrl+K | 줄 잘라내기 | Ctrl+U | 붙여넣기
Alt+6 | 줄 복사 | Alt+U | 되돌리기
Ctrl+G | 도움말 | |

여러 줄을 옮기려면 줄마다 Ctrl+K 를 누른 뒤, 옮길 곳에서 Ctrl+U 를 한 번 누릅니다. 화면에 보이는 글은 F6/F7 로도 복사할 수 있습니다.

* 웹 보기

다시 리눅스에는 웹 브라우저가 세 가지(+Firefox) 있습니다. 가벼운 것부터 씁니다.

광고와 추적 주소(7만 개 남짓)는 처음부터 모든 프로그램에서 막혀 있습니다. 광고를 받지 않으니 오래된 노트북에서 웹이 더 빠릅니다. noad 를 치면 켜져 있는지 보여 줍니다. 어떤 사이트가 제대로 열리지 않으면 root 로 noad off 로 끄고, noad on 으로 다시 켭니다. 목록은 StevenBlack/hosts (MIT 라이선스) 이고, 이 ISO 를 만들 때 받은 것입니다.

* w3m: 가장 가벼운 글자 브라우저

F1 -> 인터넷 -> 웹. 또는:

w3m naver.com

키 | 하는 일
U | 주소 입력
Tab | 다음 링크로
Enter | 링크 열기
B | 뒤로
/ | 페이지에서 글자 찾기
q | 끝내기

뉴스, 위키백과, 블로그 글 읽기에 좋습니다.

* chawan: 조금 더 많은 사이트

cha 주소

키는 w3m 과 비슷합니다. w3m 에서 깨지는 사이트가 여기서는 열리기도 합니다.

* NetSurf: 그림이 보이는 브라우저

처음 한 번 설치합니다 (root, 인터넷 없이 됩니다): had netsurf. 그다음 F1 -> 인터넷 -> 웹 (그림). 또는 netsurf.

화면 전체를 쓰는 브라우저입니다. 마우스(터치패드) 로 씁니다. 위쪽 주소 칸을 누르고 주소를 입력합니다. 한글은 오른쪽 Alt 로 바꿉니다. 시작 쪽은 DuckDuckGo 검색입니다 (구글은 NetSurf 에서 열리지 않습니다). 끝내려면 Ctrl+Q 를 누르거나 도구 막대 왼쪽 끝의 닫기 단추(X)를 누릅니다. 끝나면 데스크톱으로 돌아옵니다.

유튜브, 인터넷 은행처럼 무거운 사이트는 열리지 않습니다. 그런 곳은 Firefox 를 쓰세요.

* 메일: aerc

F1 -> 인터넷 -> 메일. 또는 aerc.

* 처음 설정

처음 실행하면 설정 도우미가 영어로 하나씩 묻습니다. 대략 이런 것들입니다.

묻는 것 | 넣을 것
Name for this account | 아무 이름 (예: naver)
Full name | 받는 사람에게 보일 내 이름
Email address | 메일 주소
Username | 보통 메일 주소
Password | 비밀번호 (아래 "앱 비밀번호" 참고)

받는 서버와 보내는 서버를 물으면:

메일 | 받는 서버 (IMAP) | 보내는 서버 (SMTP)
네이버 | imap.naver.com | smtp.naver.com
Gmail | imap.gmail.com | smtp.gmail.com

- 네이버는 먼저 웹에서 메일 -> 환경설정 -> POP3/IMAP 설정 에서 IMAP 사용을 켜야 합니다. 2단계 인증을 쓰면 애플리케이션 비밀번호를 만들어 그것을 넣습니다.
- Gmail은 Google 계정의 2단계 인증을 켜고 앱 비밀번호를 만들어 넣습니다.

* 쓰는 법

키 | 하는 일
화살표 또는 j/k | 메일 고르기
Enter | 열기
c | 새 메일 쓰기
rr | 전체 답장
d | 지우기
q | 뒤로 / 끝내기

새 메일을 쓰면 편집기가 열립니다. 다 쓰고 편집기를 닫으면 y 로 보내고 n 으로 그만둡니다.

주소록은 abook 입니다. (a 추가, e 고치기, q 끝내기)

* 일상 도구들

* 일정과 할 일: calcurse

F1 -> 생활 -> 일정. 화면에 달력, 일정, 할 일 세 칸이 있습니다.

키 | 하는 일
Tab | 칸 바꾸기
화살표 | 날짜 옮기기
a | 일정이나 할 일 더하기
e / d | 고치기 / 지우기
q | 끝내기

* 표 계산(가계부): sc-im

sc-im 가계부.sc

키 | 하는 일
화살표 | 칸 옮기기
= | 숫자나 수식 넣기 (예: =A1+A2, =@sum(A1:A9))
< | 글자 넣기
x | 칸 지우기
:w 가계부.sc | 저장
:w 가계부.csv | 엑셀에서 열 수 있는 CSV 로 저장
:q | 끝내기

* 계산기

bc -l

3*4500+1200 처럼 입력하고 Enter. 끝낼 때는 quit.

* 뉴스 구독: newsboat

처음부터 이름난 뉴스 피드가 들어 있습니다: 연합뉴스, BBC 코리아, 한겨레, 경향, 조선, 동아, BBC World, NPR, Guardian, New York Times, Al Jazeera, Hacker News, Ars Technica, LWN, Christianity Today. 빼거나 더하려면 주소를 한 줄에 하나씩:

nano ~/.newsboat/urls

Alt+N 을 누르면 화면 오른쪽에 뉴스 패널이 나오고 바로 새 글을 받습니다. 다시 Alt+N 을 누르면 숨겨지고, 다음에 누르면 보던 곳 그대로 나옵니다. 데스크톱 밖에서는 명령 newsboat. R 모두 받기, Enter 열기, n 다음 안 읽은 글, q 끝내기.

* 팟캐스트 듣기: pod

이름으로 찾아서 구독합니다.

pod this american life

나온 목록에서 번호를 고르면 구독됩니다. 그다음부터는 pod (또는 F1 -> 인터넷 -> 팟캐스트) 를 열고, 팟캐스트 번호, 회차 번호를 고르면 바로 들립니다. 듣는 동안 다른 일을 해도 소리는 계속됩니다.

키 | 하는 일
Alt+P | 재생기 보기 / 숨기기 (어느 창에서나)
Space | 멈춤 / 계속
<- -> | 10초 뒤로 / 앞으로
9 0 | 소리 작게 / 크게
s | 빠르게: 누를 때마다 1.1, 1.25, 1.35, 1.45, 1.65, 1.8 배, 그다음 보통
q | 듣기 끝

들은 곳을 기억해서, 같은 회차를 다시 고르면 거기서부터 이어집니다. 구독을 끊으려면 목록에서 -번호.

* 번역

인터넷이 연결되어 있으면 Google 번역을 콘솔에서 씁니다.

trans :ko "good morning"      (영어 -> 한국어)
trans ko:en "좋은 아침"        (한국어 -> 영어)
trans -shell :ko              (계속 입력하며 번역, 끝: Ctrl+D)

* 날씨

curl wttr.in/Seoul?lang=ko

* 화면 잠그기

자리를 비울 때:

vlock -a

root 비밀번호를 입력해야 풀립니다. (F1 -> 시스템 -> 화면 잠금)

* 다른 컴퓨터에 접속

ssh 사용자@주소

* 찾기

fd 보고서          (이름에 '보고서'가 든 파일)
fd -e odt          (.odt 파일 모두)
rg 회의            (파일 안에 '회의'가 든 곳)

* 음악, 동영상, 사진

* 음악: cmus

F1 -> 생활 -> 음악. 처음에 음악 폴더를 넣습니다.

:add ~/music

(콜론 : 부터 그대로 입력하고 Enter)

키 | 하는 일
2 | 음악 목록 화면
Enter | 재생
c | 일시정지
b / z | 다음 곡 / 이전 곡
+ / - | 소리 크게 / 작게
q | 끝내기

* 소리가 안 날 때

alsamixer

화살표 위/아래로 크기를, M 으로 음소거(MM 표시)를 풀고, Esc 로 닫습니다.

* 동영상: mpv

mpv 영상.mp4

화면 전체에 재생되고, 끝나면 데스크톱으로 돌아옵니다. Space 일시정지, <-/-> 5초 뒤로/앞으로, 9/0 소리, q 끝내기.

* 사진: fbi

fbi 사진.jpg
fbi *.jpg          (폴더의 사진 모두)

Space 또는 PgDn 다음 사진, b 또는 PgUp 앞 사진, +/- 크게/작게, q 끝내기.

* 유튜브: yt

Firefox 없이도, 오래된 노트북에서 유튜브를 볼 수 있습니다. 인터넷에 연결하고:

yt 아이유

(F1 -> 인터넷 -> 유튜브 로 열어도 됩니다.)

찾은 영상이 번호, 길이와 함께 나옵니다.

  1)     3:45  ...
  2)  1:02:03  ...
번호 = 영상, 번호s = 소리만 (예: 3s), 다른 말 = 새로 찾기, q = 끝
>

입력 | 하는 일
3 | 3번 영상을 화면 가득 봅니다 (가벼운 360p 화질)
3s | 3번을 소리만 듣습니다 (음악, 강의). 노트북이 아주 느릴 때도 됩니다
다른 말 | 새로 찾기
q | 끝내기

보는 동안 키는 mpv 와 같습니다: Space 멈춤, <-/-> 5초, 9/0 소리, q 끝. s 는 빠르게: 누를 때마다 1.1, 1.25, 1.35, 1.45, 1.65, 1.8 배, 한 번 더 누르면 보통 속도 (느리게는 없습니다). 한글 입력이 켜져 있어도 q, v, s 가 됩니다 (목록에서는 ㅂ, 3ㄴ 도 됩니다). 영상을 보는 동안은 입력이 EN 으로 바뀌었다가, 영상이 끝나면 다시 한 으로 돌아옵니다. 영상이 끝나면 목록으로 돌아옵니다.

영상을 틀어 둔 채 다른 일을 하려면 Tab 을 누르세요. 데스크톱으로 돌아가고, 영상과 소리는 계속됩니다. F4 로 새 창을 열어 글을 쓰다가, Alt+V 를 누르면 다시 영상 화면으로 갑니다.

유튜브가 "로봇이 아닌지 확인(not a bot)" 하라며 막으면, 영상 탓이 아니라 인터넷 주소 탓입니다. VPN 을 쓰고 있으면 끄고, 아니면 얼마 뒤 다시 해 보세요.

유튜브가 바뀌어 갑자기 안 되면, 인터넷에 연결된 상태에서 had yt 로 yt-dlp 를 새로 받습니다.

* 채팅과 내려받기

* 채팅(IRC): irssi

irssi
/connect irc.libera.chat
/join #채널이름

Alt+숫자 로 창을 바꾸고, /quit 로 끝냅니다. 카카오톡과 텔레그램 콘솔 프로그램은 없습니다. 텔레그램은 Firefox 로 web.telegram.org 를 쓰세요.

* 내려받기: aria2

aria2c 주소                 (파일 받기)
aria2c -x4 주소             (4개 연결로 더 빨리)
aria2c 파일.torrent         (토렌트)
aria2c "magnet:?xt=..."     (마그넷 링크, 따옴표로 감싸기)

중간에 Ctrl+C 로 멈추고, 같은 명령을 다시 하면 이어서 받습니다.

토렌트를 여러 개 다루려면 F1 -> 인터넷 -> 토렌트 (rtorrent).

* 놀이: 도스 게임과 어드벤처

* 도스 게임: hdos

처음 한 번 도스박스를 설치합니다 (root, 인터넷 없이 됩니다): had dosbox. 도스박스가 열리지 않으면 hdos 가 까닭을 보여 줍니다. "EGL" 이 나오면 그래픽 칩의 드라이버가 없는 것입니다.

-

~/dos 폴더를 만들고 게임을 넣습니다. (USB 에서 복사: USB 메모리 쓰기)

-

F1 -> 놀이 -> 도스 게임, 또는:

hdos

도스 화면이 열리고 ~/dos 가 C: 드라이브가 됩니다. 옛날처럼 cd 게임폴더, 게임.EXE.

-

게임을 바로 시작할 수도 있습니다.

hdos ~/dos/게임/GAME.EXE

키 | 하는 일
Ctrl+F10 | 마우스 풀기
Ctrl+F9 | 도스 끝내기
Alt+Enter | 창 / 전체 화면

게임이 너무 빠르거나 느리면 /etc/han/dosbox.conf 의 cpu_cycles 값을 바꿉니다. 옛날 한글 도스 프로그램은 도스 안에서 한글 상주 프로그램(한글 TSR)을 먼저 실행해야 할 수 있습니다.

* 어드벤처 게임: ScummVM

원숭이 섬의 비밀 같은 옛날 어드벤처 게임을 돌립니다. 처음 한 번 설치합니다 (인터넷 없이 됩니다).

had scummvm

그다음 F1 -> 놀이 -> 어드벤처. Beneath a Steel Sky 같은 무료 게임은 scummvm.org 에서 받을 수 있습니다.

* 그 밖에

nethack (던전 탐험), cmatrix (영화 매트릭스 화면, q 끝내기).

* Firefox: 모든 웹사이트가 필요할 때

유튜브, 인터넷 은행, 웹메일처럼 무거운 사이트는 Firefox 로 봅니다. 메모리가 2 GB 이상 있어야 하고, 4 GB 면 편합니다.

* 처음 한 번 설치

인터넷에 연결하고:

had firefox

몇 분 걸립니다. 메모리가 2 GB 보다 적으면 설치하지 않고 알려 줍니다.

* 쓰기

hx firefox

화면 전체에 Firefox 가 열립니다. 마우스로 쓰고, 한글은 오른쪽 Alt 로 바꿉니다. Firefox 를 끝내면 콘솔로 돌아옵니다. 메모리가 4 GB 보다 적으면 탭은 한두 개만 여세요.

USB 로 켜서 쓰는 중이라면 Firefox 도 메모리에 설치되어 끄면 사라집니다. 자주 쓸 거라면 먼저 하드디스크에 설치하세요.

* 설정 바꾸기

* 시각

시간대는 처음부터 서울로 되어 있고, 인터넷에 연결되면 시각이 저절로 맞춰집니다.

date               (지금 시각 보기)
setup-timezone     (시간대 다시 고르기)

* 화면 밝기

노트북의 Fn 밝기 키가 안 되면:

brightnessctl set 50%

* 배터리, 메모리, 디스크

acpi -b            (배터리)
free -m            (메모리)
lsblk              (디스크)
btop               (모두 한눈에, q 끝내기)
ncdu /             (무엇이 디스크를 차지하나, q 끝내기)

* 메뉴 고치기

F1 메뉴는 /etc/han/menu.tmux 파일에 있습니다. 익숙해지면 nano 로 열어 고칠 수 있습니다. 하위 메뉴는 같은 곳의 menu-net.tmux 같은 파일입니다.

* 끄기와 다시 켜기

poweroff           (끄기)
reboot             (다시 켜기)

전원 단추를 길게 눌러 끄는 것은 화면이 완전히 멈췄을 때만 하세요.

노트북 단추는 이렇게 움직입니다.

단추 | 하는 일
전원 단추를 짧게 | 깔끔하게 끄기 (poweroff 와 같음)
덮개 닫기 | 배터리로 쓰고 있으면 잠자기, 전원선이 꽂혀 있으면 그대로

오래된 노트북은 잠자기에서 잘 깨어나지 못하기도 합니다. 가방에 오래 넣어 둘 때는 poweroff 로 끄는 것이 안전합니다.

* 문제 해결

* 64비트 USB 가 켜지지 않고 영어 글이 나오고 멈춰요

32비트 노트북입니다. 32비트 ISO(aneuu-0-x86.iso)로 USB 를 다시 만드세요.

* USB 로 켜지지 않고 윈도우가 켜져요

부트 메뉴 키를 다시 확인하고, 시큐어 부트를 끄세요. (USB 로 켜기) USB 를 Rufus 로 만들었다면 DD 이미지 모드로 다시 만들어 보세요.

* 한글이 네모([ ])나 물음표로 보여요

desk 안에서 쓰세요. 그래도 그렇다면 han -f 로 시작해 보세요.

* 한글이 안 쳐져요

오른쪽 Alt(또는 한/영 키)를 한 번 누르세요. 로그인한 바로 그 화면에서는 한글 입력이 안 됩니다. desk 를 먼저 켜세요.

* 무선랜 카드가 없다고 나와요 (No Wi-Fi card found)

리눅스가 모르는 무선랜 카드입니다. 랜선을 쓰거나, USB 무선랜(동글)을 꽂아 보세요. 어떤 카드인지는 lspci 로 볼 수 있습니다. 그 이름으로 찾아보면 도움이 됩니다.

* 무선랜 비밀번호가 맞는데 연결이 안 돼요

r 로 다시 찾은 뒤 한 번 더 해 보세요. 공유기와 너무 멀면 신호(dBm)가 -80 보다 작게 나옵니다.

* NetSurf, mpv, 도스 게임이 화면에 안 나와요

그래픽 칩이 너무 오래되었을 수 있습니다. 웹은 w3m 이나 chawan 을 쓰세요.

* 화면이 멈춘 것 같아요

해 볼 것 | 뜻
q 또는 Esc | 대부분의 프로그램 닫기
Ctrl+C | 지금 돌고 있는 명령 멈추기
Ctrl+Alt+F2 | 다른 콘솔로 가서 root 로 로그인 (돌아올 때 Ctrl+Alt+F1)
reboot | 다시 켜기

* USB 메모리의 한글 파일 이름이 깨져요

mount 대신 husb 로 연결하세요.

* 파일과 설정이 다 없어졌어요

USB 로 켜서 쓰면 끌 때 사라집니다. 파일은 다른 USB 에 복사해 두거나, 하드디스크에 설치하세요. (저장과 설치)

* 소리가 안 나요

alsamixer 에서 M 으로 음소거를 풀고 소리를 키우세요. 블루투스 헤드폰을 쓰다가 끊었다면 음악이나 영상을 다시 틀어 보세요.

* 블루투스 기기가 목록에 안 나와요

기기를 다시 연결 대기(페어링) 상태로 두고, 노트북 가까이 가져온 뒤 s 로 다시 찾으세요. 다른 휴대폰에 이미 연결되어 있으면 그쪽 블루투스를 먼저 끄세요.

* 시각이 9시간 틀려요

인터넷에 연결하면 몇 초 안에 맞춰집니다. 그래도 틀리면 setup-timezone 에서 Asia/Seoul 을 고르세요.

* 부록 1: 명령 한눈에

명령 | 하는 일
desk | 콘솔 데스크톱
doc | 안내서 (doc wifi 처럼 주제 바로 보기)
wg | 문서 작성 (WordGrinder, wg 편지.wg)
wg 주소 | 웹 페이지의 글만 새 문서로
bib | 이번 주일 성경 본문 (묵상 쓰기)
bibt | 오늘 읽을 말씀 (일년 일독)
bibr | 성경 읽기 (책, 장 골라서, 읽던 곳부터)
dic 단어 | 영어 단어 뜻 (Alt+D 도)
han | 한글 화면 + 문서 작성 (han -s 한글 셸, han -l 글꼴 목록, han -d 글꼴 견본)
hwifi | 무선랜 목록과 연결
hbt | 블루투스 기기 연결 (F8)
husb / husb off | USB 연결 / 빼기 전에
hinst | 하드디스크에 설치
hdos | 도스 게임
had / hadr | 더 설치하기: had netsurf, dosbox, scummvm, hwdec, firefox, hwp, ocr, yt, net / 다시 빼기: hadr 이름
hx firefox | Firefox 실행
nnn | 파일 관리 (Enter 로 무엇이든 열기)
hv 파일 | PDF, 전자책, 워드, 한글 파일 보기
hb 파일.epub | 책 읽기, 그리고 F11 로 옆에 펼 책으로 정하기
yt 찾을말 | 유튜브
trans :ko "글" | 번역
vlock -a | 화면 잠그기
nano 파일 | 텍스트 편집
w3m 주소, cha 주소, netsurf | 웹
aerc | 메일
mpv 영상, fbi 사진, cmus | 동영상, 사진, 음악
passwd | 비밀번호 바꾸기
apk update, apk upgrade | 업데이트 (설치한 뒤)
poweroff, reboot | 끄기, 다시 켜기

* 부록 2: 키 한눈에

키 | 어디서 | 하는 일
오른쪽 Alt | 어디서나 | 한글 / 영어
F1 | desk | 프로그램 메뉴
F2 / F3 | desk | 이전 / 다음 창
F4 | desk | 새 셸 창
F5 | desk | 무선랜
F6 / F7 | desk | 복사 / 붙여넣기
F8 | desk | 블루투스
F11 | desk | 옆에 책 펴기 / 닫기
F10 / F9 | desk | 책 다음 쪽 / 앞 쪽
F12 | desk | 지금 프로그램의 키 요약
Alt+G | desk | AI 에게 묻기 / 닫기
Alt+O | desk | 옆 칸으로 (AI, 책)
Alt+D | desk | 영어 단어 뜻
Alt+N | desk | 뉴스 피드 (오른쪽 패널)
Alt+P | desk | 팟캐스트 재생기
Alt+V / Tab | desk / 영상 | 영상으로 / 데스크톱으로
Alt+W | w3m | 페이지 글을 WordGrinder 로
Ctrl+S | WordGrinder | 저장 (.odt 도 함께)
Ctrl+b 다음 d | desk | 데스크톱에서 잠깐 나가기
q | 대부분의 프로그램 | 끝내기, 닫기
Ctrl+S / Ctrl+Q | WordGrinder (wg) | 저장 / 끝내기
Ctrl+O / Ctrl+X | nano | 저장 / 끝내기
Ctrl+C | 셸 | 지금 명령 멈추기
위 화살표 | 셸 | 방금 입력한 명령 다시 불러오기
Tab | 셸 | 파일 이름 자동 완성

* 부록 3: 낱말 풀이

콘솔
글자만 나오는 검은 화면. 다시 리눅스는 이 화면에서 씁니다.

셸, 프롬프트
명령을 입력받는 프로그램, 그리고 그 입력 자리(aneuu:~#).

root
컴퓨터의 관리자. 무엇이든 할 수 있으니 비밀번호를 꼭 정하세요.

부팅
컴퓨터가 켜지면서 운영체제를 불러오는 과정.

ISO 파일
CD 한 장을 통째로 담은 파일. 부팅 USB 를 만들 때 씁니다.

라이브(live)
설치하지 않고 USB 에서 바로 켜서 쓰는 방식. 끄면 바뀐 것이 사라집니다.

마운트(연결)
USB 같은 저장 장치를 폴더처럼 열어 쓰게 하는 일. 다시 리눅스에서는 husb.

패키지
설치할 수 있는 프로그램 묶음. apk 로 받고 지웁니다.

알파인 리눅스(Alpine Linux)
다시 리눅스의 바탕이 된 작고 가벼운 리눅스.

* 맺음말

다시 리눅스는 알파인 리눅스 위에, 한글 콘솔(cjktty, fbterm), 한글 입력기(ddakong), 그리고 여러 사람이 만든 자유 소프트웨어를 모아 만들었습니다. 글꼴은 도스 시절 글꼴(hurss), 갈무리, 네오둥근모, 미래로, 나눔 글꼴, Terminus, GNU Unifont 등 자유 글꼴을 썼습니다. 콘솔 프로그램 고르기는 K.Mandla 의 콘솔 데스크톱 글에서 많은 도움을 받았습니다.

헌 노트북이 다시 쓸모를 찾기를 바랍니다.
HANMANUAL
	# <<< han-book

	cat > "$STAGE/usr/local/bin/hbt" <<'EOF'
#!/bin/sh
# Bluetooth devices: headphones, speakers, keyboards, mice.   (F8 in desk)
# Lists the devices you paired and any new ones found; a number connects
# (or disconnects) it. Paired devices are trusted, so they come back by
# themselves. Sound goes to Bluetooth headphones while they are connected.
[ "$(id -u)" = 0 ] || { echo "hbt: run as root" >&2; exit 1; }
ko=no; [ -n "${HAN_ACTIVE:-}" ] && ko=yes
say() { if [ $ko = yes ]; then echo "$1"; else echo "$2"; fi; }
pause() { say "Enter 를 누르세요" "Press Enter"; read -r _; }
bt() { timeout "${T:-10}" bluetoothctl "$@" 2>/dev/null </dev/null; }
L="/tmp/hbt.$$"; trap 'rm -f "$L" "$L".*' EXIT

rfkill unblock bluetooth 2>/dev/null
rc-service -q bluetooth status >/dev/null 2>&1 || rc-service -q bluetooth start
rc-service -q bluealsa status >/dev/null 2>&1 || rc-service -q bluealsa start
sleep 1
if [ -z "$(bt list)" ]; then
	say "이 노트북에는 블루투스가 없습니다. USB 블루투스 동글을 꽂고 다시 하세요." \
	    "No Bluetooth on this laptop. Plug in a USB Bluetooth dongle and try again."
	pause; exit 1
fi
bt power on >/dev/null

kind() { # icon -> word
	case "$(bt info "$1" | sed -n 's/^[[:space:]]*Icon: //p')" in
		audio-headset|audio-headphones) say "헤드폰" "headphones" ;;
		audio-card|audio-speakers)      say "스피커" "speaker" ;;
		input-keyboard)                 say "키보드" "keyboard" ;;
		input-mouse|input-tablet)       say "마우스" "mouse" ;;
		input-gaming)                   say "게임패드" "gamepad" ;;
		phone)                          say "휴대폰" "phone" ;;
		computer)                       say "컴퓨터" "computer" ;;
		*)                              echo "" ;;
	esac
}
devs() { bt devices "$@" | sed -n 's/^Device \([0-9A-F:]\{17\}\) \(.*\)$/\1 \2/p'; }

found=no
while :; do
	devs Paired > "$L.p"
	devs Connected > "$L.c"
	: > "$L"
	while read -r mac name; do echo "$mac p $name" >> "$L"; done < "$L.p"
	if [ $found = yes ]; then
		devs | while read -r mac name; do
			grep -q "^$mac " "$L.p" && continue
			# skip nameless devices (the name is just the address)
			[ "$name" = "$(echo "$mac" | tr : -)" ] && continue
			echo "$mac n $name"
		done >> "$L"
	fi
	echo
	say "블루투스 기기" "Bluetooth devices"
	n=0; shown_new=no
	while read -r mac st name; do
		n=$((n + 1))
		if [ "$st" = n ] && [ $shown_new = no ]; then
			say "  -- 새로 찾은 기기 --" "  -- new devices --"; shown_new=yes
		fi
		on=" "; state=""
		if grep -q "^$mac " "$L.c"; then on="*"; state="$(say 연결됨 connected)"; fi
		printf ' %s%2d) %-24s %-8s %s\n' "$on" "$n" "$name" "$(kind "$mac")" "$state"
	done < "$L"
	[ "$n" = 0 ] && say "  (아직 없음: s 를 눌러 찾으세요)" "  (none yet: press s to search)"
	echo
	say "번호 = 연결/끊기,  s = 새 기기 찾기,  x번호 = 지우기 (예: x2),  q = 끝" \
	    "number = connect/disconnect,  s = search,  x+number = forget (e.g. x2),  q = quit"
	printf '> '; read -r a
	case "$a" in
		q|Q|"") break ;;
		s|S)
			say "기기를 '연결 대기(페어링)' 상태로 두세요. 10초 동안 찾습니다..." \
			    "Put the device in pairing mode. Searching for 10 seconds..."
			T=12 bluetoothctl --timeout 10 scan on >/dev/null 2>&1
			found=yes; continue ;;
		x[0-9]*|X[0-9]*) n="${a#?}"; act=forget ;;
		*[!0-9]*) continue ;;
		*) n="$a"; act=toggle ;;
	esac
	line="$(sed -n "${n}p" "$L")"; [ -n "$line" ] || continue
	mac="${line%% *}"; st="$(echo "$line" | cut -d' ' -f2)"; name="$(echo "$line" | cut -d' ' -f3-)"
	if [ $act = forget ]; then
		bt remove "$mac" >/dev/null && say "지웠습니다: $name" "Forgot $name"
		continue
	fi
	if grep -q "^$mac " "$L.c"; then
		bt disconnect "$mac" >/dev/null && say "끊었습니다: $name" "Disconnected $name"
		continue
	fi
	if [ "$st" = n ]; then
		say "짝 맺는 중: $name ... 키보드는 화면에 나오는 숫자를 그 키보드로 치고 Enter." \
		    "Pairing with $name... For a keyboard, type the number shown on it, then Enter."
		# not through bt(): a phone may ask to confirm a number (type yes)
		timeout 60 bluetoothctl pair "$mac"
		bt trust "$mac" >/dev/null
	fi
	say "연결하는 중..." "Connecting..."
	if T=20 bt connect "$mac" | grep -q "successful"; then
		say "연결됨: $name" "Connected: $name"
		case "$(kind "$mac")" in 헤드폰|스피커|headphones|speaker)
			say "이제 소리가 블루투스($name)로 나옵니다. (이미 켜 둔 음악/영상은 다시 시작하세요)" \
			    "Sound now plays on $name. (Restart music or video that was already playing)" ;;
		esac
	else
		say "연결하지 못했습니다. 기기를 켜고 가까이 둔 뒤 다시 하세요." \
		    "Could not connect. Turn the device on, bring it close, try again."
	fi
	found=no
done
EOF

	# Sound follows Bluetooth: while headphones or a speaker are connected
	# they are the default sound device; when they go, the laptop's own.
	cat > "$STAGE/usr/local/lib/han/btsound" <<'EOF'
#!/bin/sh
C=/etc/asound.conf
update() {
	d="$(bluealsa-cli list-pcms 2>/dev/null |
		sed -n 's#.*/dev_\([0-9A-F_]*\)/a2dpsrc/sink$#\1#p' | head -n1 | tr _ :)"
	if [ -n "$d" ]; then
		cat > "$C.new" <<CONF
# written by han: sound to the Bluetooth device $d
pcm.!default { type plug slave.pcm "bluealsa:DEV=$d,PROFILE=a2dp" }
ctl.!default { type bluealsa }
CONF
		cmp -s "$C.new" "$C" || mv "$C.new" "$C"; rm -f "$C.new"
	elif grep -q '^# written by han' "$C" 2>/dev/null; then
		rm -f "$C"
	fi
}
while :; do
	update
	bluealsa-cli monitor 2>/dev/null | while read -r ev _; do
		case "$ev" in PCM*|Service*) update ;; esac
	done
	sleep 5
done
EOF
	chmod 755 "$STAGE/usr/local/bin/hbt" "$STAGE/usr/local/lib/han/btsound"
	# hkb: this laptop as a Bluetooth keyboard for a phone (py3-evdev, py3-dbus-next)
	# >>> hkb (generated by tools/embed.py: edit tools/hkb)
	cat > "$STAGE/usr/local/bin/hkb" <<'HKB'
#!/usr/bin/env python3
# hkb: this laptop as a Bluetooth keyboard for a phone (or a tablet).
#   hkb      (as root) start; on the phone choose "Aneuu keyboard" once
#   hkb -d MS  typing speed for R.Ctrl+V/U: MS per key half (default 20);
#              larger if the phone drops letters (hkb -d 40)
# Hold Right Ctrl (on Korean laptops the 한자 key) and press:
#   Tab   keys to the laptop (desk) and back; the phone stays connected
#   V     type desk's copied text (F6) into the phone
#   U     type the address of the copy page into the phone
#   Q     quit
# Right Ctrl / 한자 never reaches the phone; Left Ctrl is the phone's Ctrl.
# (Ctrl+Alt keys are avoided: Xfce and QEMU on a host take them.)
# The copy page (same Wi-Fi, only while hkb runs): shows the laptop's
# copied text, and takes text from the phone into desk's clipboard (F7).
# Every key goes to the phone, which types Korean itself (set the phone's
# physical keyboard to Korean 2-beolsik). Typed text: a line break goes as
# Shift+Enter (Enter would send a chat message). Right Alt (or the Hangul key)
# sends Shift+Space, the phone's Korean/English switch.
# How: Bluetooth HID. bluetoothd runs without its input plugin (it would
# take the HID channels) and with the keyboard device class; this program
# publishes the HID service record, waits on L2CAP channels 17 (control)
# and 19 (interrupt), reads the keyboard with evdev (grabbed, so desk gets
# nothing) and sends 8-byte keyboard reports. At the end the normal
# Bluetooth service comes back (headphones too).
import asyncio
import html
import http.server
import os
import secrets
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.parse

NAME = "Aneuu keyboard"
HID_UUID = "00001124-0000-1000-8000-00805f9b34fb"
PSM_CTRL, PSM_INTR = 0x11, 0x13
CONF = "/run/hkb-main.conf"
BLUETOOTHD = "/usr/lib/bluetooth/bluetoothd"
KEY_MS = 20         # typed text: ms key down, ms key up (hkb -d MS)

# Keyboard report descriptor (boot keyboard, report ID 1, LEDs out)
DESCRIPTOR = (
    "05010906a1018501050719e029e7150025017501950881029501750881039505"
    "7501050819012905910295017503910395067508150025650507190029658100"
    "c0"
)

SDP_RECORD = """<?xml version="1.0" encoding="UTF-8" ?>
<record>
  <attribute id="0x0001"><sequence><uuid value="0x1124" /></sequence></attribute>
  <attribute id="0x0004">
    <sequence>
      <sequence><uuid value="0x0100" /><uint16 value="0x0011" /></sequence>
      <sequence><uuid value="0x0011" /></sequence>
    </sequence>
  </attribute>
  <attribute id="0x0005"><sequence><uuid value="0x1002" /></sequence></attribute>
  <attribute id="0x0006">
    <sequence><uint16 value="0x656e" /><uint16 value="0x006a" /><uint16 value="0x0100" /></sequence>
  </attribute>
  <attribute id="0x0009">
    <sequence><sequence><uuid value="0x1124" /><uint16 value="0x0100" /></sequence></sequence>
  </attribute>
  <attribute id="0x000d">
    <sequence>
      <sequence>
        <sequence><uuid value="0x0100" /><uint16 value="0x0013" /></sequence>
        <sequence><uuid value="0x0011" /></sequence>
      </sequence>
    </sequence>
  </attribute>
  <attribute id="0x0100"><text value="%(name)s" /></attribute>
  <attribute id="0x0101"><text value="Keyboard" /></attribute>
  <attribute id="0x0102"><text value="Aneuu" /></attribute>
  <attribute id="0x0200"><uint16 value="0x0100" /></attribute>
  <attribute id="0x0201"><uint16 value="0x0111" /></attribute>
  <attribute id="0x0202"><uint8 value="0x40" /></attribute>
  <attribute id="0x0203"><uint8 value="0x00" /></attribute>
  <attribute id="0x0204"><boolean value="true" /></attribute>
  <attribute id="0x0205"><boolean value="true" /></attribute>
  <attribute id="0x0206">
    <sequence><sequence><uint8 value="0x22" /><text encoding="hex" value="%(desc)s" /></sequence></sequence>
  </attribute>
  <attribute id="0x0207">
    <sequence><sequence><uint16 value="0x0409" /><uint16 value="0x0100" /></sequence></sequence>
  </attribute>
  <attribute id="0x020b"><uint16 value="0x0100" /></attribute>
  <attribute id="0x020c"><uint16 value="0x0c80" /></attribute>
  <attribute id="0x020d"><boolean value="false" /></attribute>
  <attribute id="0x020e"><boolean value="true" /></attribute>
</record>
""" % {"name": NAME, "desc": DESCRIPTOR}

# evdev key names -> HID usage IDs (keyboard page 0x07)
_HID = {
    **{f"KEY_{c}": 4 + i for i, c in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ")},
    **{f"KEY_{d}": 30 + i for i, d in enumerate("1234567890")},
    "KEY_ENTER": 40, "KEY_ESC": 41, "KEY_BACKSPACE": 42, "KEY_TAB": 43,
    "KEY_SPACE": 44, "KEY_MINUS": 45, "KEY_EQUAL": 46, "KEY_LEFTBRACE": 47,
    "KEY_RIGHTBRACE": 48, "KEY_BACKSLASH": 49, "KEY_SEMICOLON": 51,
    "KEY_APOSTROPHE": 52, "KEY_GRAVE": 53, "KEY_COMMA": 54, "KEY_DOT": 55,
    "KEY_SLASH": 56, "KEY_CAPSLOCK": 57,
    **{f"KEY_F{n}": 57 + n for n in range(1, 13)},
    "KEY_SYSRQ": 70, "KEY_SCROLLLOCK": 71, "KEY_PAUSE": 72, "KEY_INSERT": 73,
    "KEY_HOME": 74, "KEY_PAGEUP": 75, "KEY_DELETE": 76, "KEY_END": 77,
    "KEY_PAGEDOWN": 78, "KEY_RIGHT": 79, "KEY_LEFT": 80, "KEY_DOWN": 81,
    "KEY_UP": 82, "KEY_NUMLOCK": 83, "KEY_KPSLASH": 84, "KEY_KPASTERISK": 85,
    "KEY_KPMINUS": 86, "KEY_KPPLUS": 87, "KEY_KPENTER": 88,
    **{f"KEY_KP{d}": 89 + i for i, d in enumerate("123456789")},
    "KEY_KP0": 98, "KEY_KPDOT": 99, "KEY_102ND": 100, "KEY_COMPOSE": 101,
}
_MOD = {"KEY_LEFTCTRL": 0x01, "KEY_LEFTSHIFT": 0x02, "KEY_LEFTALT": 0x04,
        "KEY_LEFTMETA": 0x08, "KEY_RIGHTSHIFT": 0x20,
        "KEY_RIGHTMETA": 0x80}
# Right Alt and the Hangul key: the phone's Korean/English switch
_SWITCH = ("KEY_RIGHTALT", "KEY_HANGEUL")
# Right Ctrl and the Hanja key: hkb's command key, never sent to the phone
_CMD = ("KEY_RIGHTCTRL", "KEY_HANJA")
_CMD_KEYS = ("KEY_TAB", "KEY_V", "KEY_U", "KEY_Q")


def say(ko, en):
    print(f"{ko} ({en})", flush=True)


class Keys:
    """Pressed keys -> HID reports; also tracks the command key."""

    def __init__(self):
        self.mods = 0
        self.down = []          # HID usages, in the order pressed (max 6)
        self.held = set()       # evdev names held (for the command key)
        self.korean = False     # the phone's mode as far as we know

    def report(self):
        keys = (self.down + [0] * 6)[:6]
        return bytes([0xA1, 0x01, self.mods, 0] + keys)

    def event(self, name, value):
        """value 1 press, 0 release, 2 repeat. Returns a list of reports."""
        if value == 2:
            return []
        if value == 1:
            self.held.add(name)
        else:
            self.held.discard(name)
        if name in _CMD:
            return []
        if name in _SWITCH:
            if value != 1:
                return []
            # Shift down, Shift+Space, Space up, Shift up: the phone's 한/영
            self.korean = not self.korean
            return [self.report_with(None, shift=True),
                    self.report_with(44, shift=True),
                    self.report_with(None, shift=True),
                    self.report()]
        if name in _MOD:
            bit = _MOD[name]
            self.mods = self.mods | bit if value else self.mods & ~bit
            return [self.report()]
        usage = _HID.get(name)
        if usage is None:
            return []
        if value:
            if usage not in self.down:
                self.down.append(usage)
        elif usage in self.down:
            self.down.remove(usage)
        return [self.report()]

    def report_with(self, usage, shift=False):
        mods = self.mods | (0x02 if shift else 0)
        keys = self.down + ([usage] if usage else [])
        keys = (keys + [0] * 6)[:6]
        return bytes([0xA1, 0x01, mods, 0] + keys)

    def command(self):
        """Right Ctrl or the Hanja key is held."""
        return bool(set(_CMD) & self.held)


# 2-beolsik: initial, medial, final jamo as the keys a person types
CHO = "r R s e E f a q Q t T d w W c z x v g".split()
JUNG = "k o i O j p u P h hk ho hl y n nj np nl b m ml l".split()
JONG = [""] + "r R rt s sw sg e f fr fa fq ft fx fv fg a q qt t T d w c z x v g".split()
COMPAT = dict(zip(
    "ㄱㄲㄳㄴㄵㄶㄷㄸㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅃㅄㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
    "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ",
    "r R rt s sw sg e E f fr fa fq ft fx fv fg a q Q qt t T d w W c z x v g "
    "k o i O j p u P h hk ho hl y n nj np nl b m ml l".split()))
# US layout: character -> (evdev key name, shift)
_SHIFTED = dict(zip('!@#$%^&*()_+{}|:"<>?~', "1234567890-=[]\\;',./`"))
_PUNCT = {"-": "MINUS", "=": "EQUAL", "[": "LEFTBRACE", "]": "RIGHTBRACE",
          "\\": "BACKSLASH", ";": "SEMICOLON", "'": "APOSTROPHE", "`": "GRAVE",
          ",": "COMMA", ".": "DOT", "/": "SLASH", " ": "SPACE",
          "\n": "ENTER", "\t": "TAB"}


def ascii_key(ch):
    """(HID usage, shift) for a character on a US keyboard, or None."""
    if ch.isascii() and ch.isalpha():
        return _HID["KEY_" + ch.upper()], ch.isupper()
    if ch.isdigit() and ch.isascii():
        return _HID["KEY_" + ch], False
    if ch in _SHIFTED:
        return ascii_key(_SHIFTED[ch])[0], True
    if ch in _PUNCT:
        return _HID["KEY_" + _PUNCT[ch]], False
    return None


def hangul_keys(ch):
    """The 2-beolsik key letters for one Hangul syllable or jamo, or None."""
    c = ord(ch)
    if 0xAC00 <= c <= 0xD7A3:
        c -= 0xAC00
        return CHO[c // 588] + JUNG[c % 588 // 28] + JONG[c % 28]
    return COMPAT.get(ch)


def plan(text, korean):
    """Text -> [(usage, shift)] key presses; 'SWITCH' where the phone must
    change between English and Korean. korean: the phone's mode at the
    start. Returns (presses, mode at the end, characters skipped)."""
    out, skipped = [], 0
    # a line break is Shift+Enter: in chat apps (Gemini ...) Enter sends the
    # message and the rest would be lost; trailing line breaks are dropped
    text = text.replace("\r\n", "\n").rstrip("\n")
    for ch in text:
        if ch == "\n":
            out.append((40, True))
            continue
        keys = hangul_keys(ch)
        if keys is not None:
            if not korean:
                out.append("SWITCH"); korean = True
            out += [ascii_key(k) for k in keys]
            continue
        k = ascii_key(ch)
        if k is None:
            skipped += 1
            continue
        if ch.isascii() and ch.isalpha() and korean:
            out.append("SWITCH"); korean = False
        out.append(k)
    return out, korean, skipped


def tmux_get():
    r = subprocess.run(["tmux", "show-buffer"], capture_output=True)
    return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else ""


def tmux_put(text):
    subprocess.run(["tmux", "load-buffer", "-"], input=text.encode("utf-8"))


def my_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("192.0.2.1", 9))     # no packet is sent; picks the route
        return s.getsockname()[0]
    except OSError:
        return None
    finally:
        s.close()


PAGE = """<!doctype html><html lang="ko"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>다시 복사 (Aneuu copy)</title>
<style>body{font:18px sans-serif;margin:1em;max-width:40em}
textarea{width:100%%;font:16px monospace;box-sizing:border-box}
button{font-size:18px;padding:.4em 1.2em}</style>
<h2>노트북에 보내기 <small>(send to the laptop)</small></h2>
<form method="post"><textarea name="text" rows="8"></textarea><br>
<button>보내기 (send)</button></form>%(note)s
<h2>노트북에서 복사한 글 <small>(copied on the laptop)</small></h2>
<textarea rows="8" readonly>%(clip)s</textarea>
<p>위 글을 길게 눌러 복사하세요 (long-press to copy).</p>
"""


def serve(token, notify):
    """The copy page, http://IP:PORT/TOKEN, in a thread."""
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def page(self, note=""):
            body = PAGE % {"note": note, "clip": html.escape(tmux_get())}
            data = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path.rstrip("/") != "/" + token:
                self.send_error(404)
                return
            self.page()

        def do_POST(self):
            if self.path.rstrip("/") != "/" + token:
                self.send_error(404)
                return
            n = min(int(self.headers.get("Content-Length", 0)), 1 << 20)
            form = urllib.parse.parse_qs(self.rfile.read(n).decode("utf-8", "replace"))
            text = form.get("text", [""])[0]
            if text:
                tmux_put(text)
                notify(len(text))
            self.page("<p><b>받았습니다: %d 글자. 노트북에서 (R.Ctrl+Tab) F7 로 붙여넣기 "
                      "(received; R.Ctrl+Tab, then F7 pastes it on the laptop)</b></p>" % len(text))

    for port in (8000, 8001, 8080, 0):
        try:
            srv = http.server.ThreadingHTTPServer(("0.0.0.0", port), H)
            break
        except OSError:
            continue
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def keyboards():
    import evdev
    found = []
    for path in evdev.list_devices():
        try:
            d = evdev.InputDevice(path)
            caps = d.capabilities().get(evdev.ecodes.EV_KEY, [])
            if evdev.ecodes.KEY_A in caps and evdev.ecodes.KEY_ENTER in caps:
                found.append(d)
            else:
                d.close()
        except OSError:
            pass
    return found


def start_bluetoothd():
    subprocess.run(["rc-service", "bluetooth", "stop"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-x", "bluetoothd"], stderr=subprocess.DEVNULL)
    time.sleep(1)
    with open(CONF, "w") as f:
        f.write("[General]\nName = %s\nClass = 0x002540\n"
                "DiscoverableTimeout = 0\nPairableTimeout = 0\n"
                "JustWorksRepairing = always\n" % NAME)
    p = subprocess.Popen([BLUETOOTHD, "-n", "-P", "input", "-f", CONF],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2)
    return p


def stop_bluetoothd(p):
    if p and p.poll() is None:
        p.terminate()
        try:
            p.wait(5)
        except subprocess.TimeoutExpired:
            p.kill()
    try:
        os.remove(CONF)
    except OSError:
        pass
    subprocess.run(["rc-service", "bluetooth", "start"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


async def bluez_setup():
    """Adapter on and visible, an agent that accepts pairing, the HID record."""
    from dbus_next.aio import MessageBus
    from dbus_next.constants import BusType
    from dbus_next.service import ServiceInterface, method
    from dbus_next import Variant

    class Agent(ServiceInterface):
        def __init__(self):
            super().__init__("org.bluez.Agent1")

        @method()
        def Release(self):
            pass

        @method()
        def RequestConfirmation(self, device: "o", passkey: "u"):
            pass

        @method()
        def RequestAuthorization(self, device: "o"):
            pass

        @method()
        def AuthorizeService(self, device: "o", uuid: "s"):
            pass

        @method()
        def Cancel(self):
            pass

    class Profile(ServiceInterface):
        def __init__(self):
            super().__init__("org.bluez.Profile1")

        @method()
        def Release(self):
            pass

        @method()
        def RequestDisconnection(self, device: "o"):
            pass

    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    for _ in range(20):                       # wait for bluetoothd
        try:
            intro = await bus.introspect("org.bluez", "/org/bluez/hci0")
            break
        except Exception:
            await asyncio.sleep(0.5)
    else:
        raise RuntimeError("no Bluetooth adapter (hci0)")
    hci = bus.get_proxy_object("org.bluez", "/org/bluez/hci0", intro)
    props = hci.get_interface("org.freedesktop.DBus.Properties")
    for k, v in (("Powered", True), ("Alias", NAME),
                 ("Pairable", True), ("Discoverable", True)):
        await props.call_set("org.bluez.Adapter1", k,
                             Variant("b" if isinstance(v, bool) else "s", v))
    bus.export("/aneuu/hkb/agent", Agent())
    bus.export("/aneuu/hkb/profile", Profile())
    root = bus.get_proxy_object("org.bluez", "/org/bluez",
                                await bus.introspect("org.bluez", "/org/bluez"))
    am = root.get_interface("org.bluez.AgentManager1")
    await am.call_register_agent("/aneuu/hkb/agent", "NoInputNoOutput")
    await am.call_request_default_agent("/aneuu/hkb/agent")
    pm = root.get_interface("org.bluez.ProfileManager1")
    await pm.call_register_profile("/aneuu/hkb/profile", HID_UUID, {
        "ServiceRecord": Variant("s", SDP_RECORD),
        "Role": Variant("s", "server"),
        "RequireAuthentication": Variant("b", False),
        "RequireAuthorization": Variant("b", False),
    })
    return bus


def listen(psm):
    s = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET,
                      socket.BTPROTO_L2CAP)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((socket.BDADDR_ANY, psm))
    s.listen(1)
    return s


async def run():
    import evdev
    loop = asyncio.get_running_loop()
    kbs = keyboards()
    if not kbs:
        say("키보드를 찾지 못했습니다", "no keyboard found")
        return 1
    bt = start_bluetoothd()
    socks = []
    bus = None
    try:
        bus = await bluez_setup()
        ctrl_l, intr_l = listen(PSM_CTRL), listen(PSM_INTR)
        socks += [ctrl_l, intr_l]
        say(f"폰의 블루투스 목록에서 \"{NAME}\" 을 고르세요 (처음 한 번 연결)",
            f"on the phone, pick \"{NAME}\" under Bluetooth (pair once)")
        say("명령 키 R.Ctrl = 오른쪽 Ctrl 또는 한자 키, 폰으로는 안 갑니다",
            "command key R.Ctrl = Right Ctrl or the Hanja key; never sent to the phone")
        say("끝내기: 연결 전에는 Ctrl+C, 연결 뒤에는 R.Ctrl+Q",
            "quit: Ctrl+C before it connects, R.Ctrl+Q after")
        say("연결 뒤 R.Ctrl+Tab: 키를 노트북(데스크)으로, 다시 누르면 폰으로",
            "after connecting, R.Ctrl+Tab: keys to the laptop (desk) and back")
        ctrl, addr = await loop.run_in_executor(None, ctrl_l.accept)
        socks.append(ctrl)
        intr, _ = await loop.run_in_executor(None, intr_l.accept)
        socks.append(intr)
        say(f"연결됨: {addr[0]}. 이제 모든 키가 폰으로 갑니다",
            "connected: every key now goes to the phone")
        say("폰에서 한글: 물리 키보드를 '한국어 두벌식' 으로, 한/영 은 오른쪽 Alt",
            "Korean: set the phone's physical keyboard to Korean 2-beolsik; Right Alt switches")
        token = secrets.token_urlsafe(4).replace("-", "x").replace("_", "y")
        ip = my_ip()
        url = None
        if ip and os.environ.get("TMUX"):
            srv = serve(token, lambda n: say(f"폰에서 받음: {n} 글자, 노트북에서 F7",
                                             f"from the phone: {n} characters; F7 on the laptop"))
            url = f"http://{ip}:{srv.server_address[1]}/{token}"
            say(f"복사 쪽 (같은 와이파이): {url}", f"copy page (same Wi-Fi)")
            say("R.Ctrl+U: 이 주소를 폰에 입력,  R.Ctrl+V: 복사한 글을 폰에 입력",
                "R.Ctrl+U types this address on the phone, R.Ctrl+V types copied text")
        elif not os.environ.get("TMUX"):
            say("데스크 밖이라 복사/붙여넣기는 없습니다", "outside desk: no copy and paste")
        else:
            say("네트워크가 없어 복사 쪽은 없습니다 (R.Ctrl+V 는 됩니다)",
                "no network: no copy page (R.Ctrl+V still works)")
        for d in kbs:
            d.grab()
        keys = Keys()
        stop = asyncio.Event()
        state = {"phone": True, "typing": False, "cancel": False}

        def tell(ko, en):
            """On this screen and in desk's status line (when keys are on desk)."""
            say(ko, en)
            subprocess.run(["tmux", "display-message", "-d", "4000", f"{ko} ({en})"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        def to_phone(yes):
            state["phone"] = yes
            for d in kbs:
                try:
                    d.grab() if yes else d.ungrab()
                except OSError:
                    pass
            if yes:
                tell("→ 폰: 키가 폰으로 갑니다 (R.Ctrl+Tab: 노트북)",
                     "to the phone; R.Ctrl+Tab: laptop")
            else:
                try:                    # nothing stays pressed on the phone
                    intr.send(bytes([0xA1, 0x01, 0, 0, 0, 0, 0, 0, 0, 0]))
                except OSError:
                    pass
                tell("→ 노트북: 데스크를 씁니다, 폰은 연결된 채 (R.Ctrl+Tab: 폰)",
                     "to the laptop; the phone stays connected; R.Ctrl+Tab: phone")

        def type_text(text):
            """Type text into the phone, slowly enough that it keeps up.
            Returns (characters not typable, stopped by Esc)."""
            presses, _end, skipped = plan(text, keys.korean)
            # the phone's 한/영: Shift down, Shift+Space, Space up (then empty)
            switch = [bytes([0xA1, 0x01, 0x02, 0, 0, 0, 0, 0, 0, 0]),
                      bytes([0xA1, 0x01, 0x02, 0, 0x2C, 0, 0, 0, 0, 0]),
                      bytes([0xA1, 0x01, 0x02, 0, 0, 0, 0, 0, 0, 0])]
            empty = bytes([0xA1, 0x01, 0, 0, 0, 0, 0, 0, 0, 0])
            half = KEY_MS / 1000
            intr.send(empty)
            done, total = 0, sum(1 for p in presses if p != "SWITCH")
            for p in presses:
                if state["cancel"]:
                    break
                if p == "SWITCH":
                    for r in switch:
                        intr.send(r); time.sleep(half)
                    intr.send(empty); time.sleep(max(0.15, 4 * half))
                    keys.korean = not keys.korean   # known even if stopped
                    continue
                usage, shift = p
                intr.send(bytes([0xA1, 0x01, 0x02 if shift else 0, 0, usage, 0, 0, 0, 0, 0]))
                time.sleep(half)
                intr.send(empty)
                time.sleep(half)
                done += 1
                if done % 60 == 0 and done < total:
                    subprocess.run(["tmux", "display-message", "-d", "2000",
                                    f"폰에 입력 중 {100 * done // total}%, Esc: 멈춤 "
                                    f"(typing {100 * done // total}%, Esc stops)"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            intr.send(empty)               # the laptop's keys are ignored meanwhile
            return skipped, state["cancel"]

        async def read(dev):
            async for ev in dev.async_read_loop():
                if ev.type != evdev.ecodes.EV_KEY:
                    continue
                name = evdev.ecodes.KEY.get(ev.code)
                if isinstance(name, list):
                    name = name[0]
                name = name or ""
                if state["typing"]:
                    keys.event(name, ev.value)      # track, send nothing
                    if ev.value == 1 and (name == "KEY_ESC"
                                          or (name == "KEY_Q" and keys.command())):
                        state["cancel"] = True
                    continue
                if ev.value == 1 and name in _CMD_KEYS and keys.command():
                    if name == "KEY_TAB":
                        to_phone(not state["phone"])
                        continue
                    if name == "KEY_Q":
                        if state["phone"]:
                            try:
                                intr.send(bytes([0xA1, 0x01, 0, 0, 0, 0, 0, 0, 0, 0]))
                            except OSError:
                                pass
                        stop.set()
                        return
                    if not state["phone"]:
                        continue        # V and U type on the phone only
                    text = tmux_get() if name == "KEY_V" else (url or "")
                    if not text:
                        say("붙여넣을 글이 없습니다 (데스크에서 F6 로 복사)",
                            "nothing copied (F6 in desk copies)")
                    else:
                        state["typing"], state["cancel"] = True, False
                        tell(f"폰에 입력 중: {len(text)} 글자, Esc: 멈춤",
                             f"typing {len(text)} characters; Esc stops")
                        try:
                            n, stopped = await loop.run_in_executor(None, type_text, text)
                        except OSError:
                            say("폰과 연결이 끊겼습니다", "the phone disconnected")
                            stop.set()
                            return
                        finally:
                            state["typing"] = False
                        if stopped:
                            tell("입력을 멈췄습니다", "typing stopped")
                        else:
                            tell(f"폰에 보냄: {len(text) - n} 글자"
                                 + (f", 못 넣은 글자 {n} 개" if n else "")
                                 + " (빠지면 hkb -d 40)",
                                 "sent; if letters are missing: hkb -d 40")
                    continue
                if not state["phone"]:
                    # keys go to desk; only keep track, for the command key
                    keys.event(name, ev.value)
                    continue
                for r in keys.event(name, ev.value):
                    try:
                        intr.send(r)
                    except OSError:
                        say("폰과 연결이 끊겼습니다", "the phone disconnected")
                        stop.set()
                        return

        tasks = [asyncio.ensure_future(read(d)) for d in kbs]
        await stop.wait()
        for t in tasks:
            t.cancel()
        return 0
    finally:
        for d in kbs:
            try:
                d.ungrab()
            except OSError:
                pass
        for so in socks:
            try:
                so.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            so.close()
        if bus:
            bus.disconnect()
        stop_bluetoothd(bt)
        say("키보드가 다시 이 노트북으로 (블루투스 원래대로)",
            "keyboard back on this laptop (Bluetooth as before)")


def main():
    global KEY_MS
    args = sys.argv[1:]
    if args and args[0] in ("-h", "--help"):
        print("".join(l[2:] for l in open(__file__, encoding="utf-8").readlines()[1:12]), end="")
        return 0
    if args and args[0] == "-d":
        try:
            KEY_MS = max(5, min(200, int(args[1])))
        except (IndexError, ValueError):
            say("hkb -d 숫자 (밀리초, 예: hkb -d 40)", "hkb -d NUMBER (ms, e.g. hkb -d 40)")
            return 1
    if os.geteuid() != 0:
        say("root 로 실행하세요", "run as root")
        return 1
    if not os.path.exists(BLUETOOTHD):
        say("블루투스가 없습니다", "no Bluetooth on this system")
        return 1
    try:
        import evdev  # noqa: F401
        import dbus_next  # noqa: F401
    except ImportError:
        say("py3-evdev 또는 py3-dbus-next 가 없습니다", "py3-evdev or py3-dbus-next is missing")
        return 1
    def on_term(signo, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, on_term)
    try:
        return asyncio.run(run())
    except KeyboardInterrupt:
        return 130
    except Exception as e:      # say what went wrong, plainly
        say(f"멈췄습니다: {e}", "stopped")
        return 1


sys.exit(main())
HKB
	# <<< hkb
	chmod 755 "$STAGE/usr/local/bin/hkb"
	cat > "$STAGE/etc/local.d/han-btsound.start" <<'EOF'
#!/bin/sh
rm -f /etc/asound.conf.new
grep -q '^# written by han' /etc/asound.conf 2>/dev/null && rm -f /etc/asound.conf
start-stop-daemon -S -b -x /usr/local/lib/han/btsound
EOF
	chmod 755 "$STAGE/etc/local.d/han-btsound.start"

	cat > "$STAGE/usr/local/bin/husb" <<'EOF'
#!/bin/sh
# USB stick:  husb      attach it at /media/usb (Korean names work)
#             husb off  before pulling it out
M=/media/usb
[ "$(id -u)" = 0 ] || { echo "husb: run as root" >&2; exit 1; }
ko=no; [ -n "${HAN_ACTIVE:-}" ] && ko=yes
say() { if [ $ko = yes ]; then echo "$1"; else echo "$2"; fi; }

if [ "${1:-}" = off ]; then
	cd /
	if mountpoint -q "$M"; then
		sync
		if umount "$M"; then say "이제 뽑아도 됩니다." "Safe to unplug now."
		else say "아직 쓰는 프로그램이 있습니다. 그 프로그램을 닫고 다시 하세요." \
			"A program is still using it. Close it and try again."; exit 1; fi
	else
		say "연결된 USB 가 없습니다." "No USB stick is attached."
	fi
	exit 0
fi
if mountpoint -q "$M"; then
	say "이미 연결됨: $M   (빼기 전에: husb off)" "Already attached: $M   (before unplugging: husb off)"
	exit 0
fi

# partitions with a file system on USB disks, not already in use
: > /tmp/husb.list
for d in $(lsblk -dnpo NAME,TRAN | awk '$2 == "usb" { print $1 }'); do
	for p in $(lsblk -lnpo NAME "$d"); do
		grep -q "^$p " /proc/mounts && continue
		t="$(blkid "$p" 2>/dev/null | sed -n 's/.* TYPE="\([^"]*\)".*/\1/p')"
		[ -n "$t" ] || continue
		l="$(blkid "$p" 2>/dev/null | sed -n 's/.* LABEL="\([^"]*\)".*/\1/p')"
		echo "$p $t $(lsblk -dnpo SIZE "$p" | tr -d ' ') $l" >> /tmp/husb.list
	done
done
n="$(wc -l < /tmp/husb.list)"
if [ "$n" = 0 ]; then
	say "USB 메모리를 찾지 못했습니다. 꽂고 몇 초 뒤 다시 하세요." \
	    "No USB stick found. Plug it in, wait a few seconds, try again."
	exit 1
elif [ "$n" = 1 ]; then
	line="$(cat /tmp/husb.list)"
else
	say "어느 것을 연결할까요?" "Which one?"
	awk '{ printf "  %d)  %s\n", NR, $0 }' /tmp/husb.list
	printf '> '; read -r a
	line="$(sed -n "${a:-0}p" /tmp/husb.list 2>/dev/null)"
	[ -n "$line" ] || exit 1
fi
set -- $line
mkdir -p "$M"
case "$2" in
	vfat)  mount -o utf8,uid=0,gid=0 "$1" "$M" ;;
	ntfs)  mount -t ntfs-3g "$1" "$M" ;;
	*)     mount "$1" "$M" ;;
esac || { say "연결하지 못했습니다 ($2)." "Could not attach it ($2)."; exit 1; }
say "연결됨: $M   (nnn $M 로 열기, 빼기 전에: husb off)" \
    "Attached: $M   (open: nnn $M, before unplugging: husb off)"
EOF
	chmod 755 "$STAGE/usr/local/bin/husb"

	cat > "$STAGE/usr/local/bin/hinst" <<'EOF'
#!/bin/sh
# Install this system to the laptop's own disk, with everything on it.
# Asks which disk, erases it, installs; Korean kernel and patched programs
# are kept (pinned), and Alpine's online mirror is set for updates.
[ "$(id -u)" = 0 ] || { echo "hinst: run as root" >&2; exit 1; }
ko=no; [ -n "${HAN_ACTIVE:-}" ] && ko=yes
say() { if [ $ko = yes ]; then echo "$1"; else echo "$2"; fi; }

# the stick we booted from is not a choice
boot="$(awk '$2 ~ "^/media/" { print $1 }' /proc/mounts | sed 's/[0-9]*$//; s/p$//' | sed 's:^/dev/::' | sort -u | tr '\n' ' ')"
lsblk -dnpo NAME,SIZE,TYPE,TRAN,MODEL | awk '$3 == "disk"' |
	while read -r d rest; do
		n="${d#/dev/}"
		echo " $boot " | grep -q " $n " && continue
		case "$n" in zram*|loop*|sr*|fd*) continue ;; esac
		echo "$d $rest"
	done > /tmp/hinst.all
# USB sticks only when there is nothing else (Ventoy hides which one we use)
grep -v ' usb ' /tmp/hinst.all > /tmp/hinst.disks || cp /tmp/hinst.all /tmp/hinst.disks
if [ ! -s /tmp/hinst.disks ]; then
	say "설치할 디스크를 찾지 못했습니다." "No disk found to install to."; exit 1
fi
say "어느 디스크에 설치할까요?" "Install to which disk?"
awk '{ printf "  %d)  %s\n", NR, $0 }' /tmp/hinst.disks
printf '> '; read -r n
disk="$(sed -n "${n:-0}p" /tmp/hinst.disks 2>/dev/null | cut -d' ' -f1)"
[ -n "$disk" ] || { say "그만둡니다." "Stopped."; exit 1; }
echo
say "!! $disk 의 모든 것(윈도우, 사진, 문서)이 지워집니다 !!" \
    "!! Everything on $disk (Windows, photos, documents) is erased !!"
say "계속하려면 yes 를 입력하세요:" "Type yes to go on:"
printf '> '; read -r a
[ "$a" = yes ] || { say "그만둡니다." "Stopped."; exit 1; }

if grep -q '^root:[!*]\{0,1\}:' /etc/shadow; then
	say "먼저 root 비밀번호를 정합니다 (두 번 입력, 화면에 안 보임)." \
	    "First set a root password (twice; it is not shown)."
	until passwd root; do :; done
fi

# Install only from the USB stick, so that Alpine's own (newer) kernel
# cannot take the place of the Korean one.
cp /etc/apk/repositories /tmp/hinst.repos
grep '^/' /tmp/hinst.repos > /etc/apk/repositories
ERASE_DISKS="$disk" setup-disk -m sys "$disk"; rc=$?
cp /tmp/hinst.repos /etc/apk/repositories
[ $rc = 0 ] || { say "설치에 실패했습니다." "The install failed."; exit 1; }

# Root partition: the biggest ext4 one on that disk
root="$(lsblk -lnpbo NAME,FSTYPE,SIZE "$disk" | awk '$2 == "ext4"' | sort -k3,3n | tail -n1 | cut -d' ' -f1)"
mnt=/mnt/han-inst; mkdir -p "$mnt"
if [ -n "$root" ] && mount "$root" "$mnt"; then
	v="$(cut -d. -f1,2 /etc/alpine-release)"
	printf 'https://dl-cdn.alpinelinux.org/alpine/v%s/%s\n' \
		"$v" main "$v" community >> "$mnt/etc/apk/repositories"
	sh /etc/local.d/han-kpin.start "$mnt"
	umount "$mnt"
fi
echo
say "끝났습니다. poweroff 로 끄고, USB 를 뽑은 뒤 다시 켜세요." \
    "Done. Type poweroff, unplug the USB stick, then turn the laptop on."
EOF

	# Pin what this ISO built itself (release -r900: the Korean kernel,
	# NetSurf with Korean input, ...), so "apk upgrade" keeps them.
	# Runs at every boot; hinst also runs it on the new disk.
	cat > "$STAGE/etc/local.d/han-kpin.start" <<'EOF'
#!/bin/sh
r="${1:-}"
db="$r/lib/apk/db/installed"; [ -f "$db" ] || exit 0
awk '/^P:/ { p = substr($0, 3) } /^V:.*-r900$/ { print p "=" substr($0, 3) }' "$db" |
while IFS='=' read -r p v; do
	grep -qx "$p=$v" "$r/etc/apk/world" && continue
	sed -i "/^$p\([<>=~].*\)\{0,1\}\$/d" "$r/etc/apk/world"
	echo "$p=$v" >> "$r/etc/apk/world"
done
EOF
	chmod 755 "$STAGE/usr/local/bin/hinst" "$STAGE/etc/local.d/han-kpin.start"

	# Compressed swap in RAM (zram) under 4 GB: the live system keeps its
	# files on a RAM disk, and zram lets the kernel compress the rarely used
	# ones (zstd, often 2-3x), giving memory back to programs.
	mkdir -p "$STAGE/etc/local.d"
	cat > "$STAGE/etc/local.d/han-zram.start" <<'EOF'
#!/bin/sh
# han-zram: compressed swap in memory, half the RAM, when RAM < 4 GB
mem="$(awk '/MemTotal/ { printf "%d", $2 / 1024 }' /proc/meminfo)"
[ "$mem" -lt 3900 ] || exit 0
modprobe zram 2>/dev/null || exit 0
[ -e /sys/block/zram0/disksize ] || exit 0
swapon 2>/dev/null | grep -q zram0 && exit 0
echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null
echo "$((mem / 2))M" > /sys/block/zram0/disksize || exit 0
mkswap /dev/zram0 >/dev/null && swapon -p 100 /dev/zram0
EOF
	chmod 755 "$STAGE/etc/local.d/han-zram.start"

	# noad: ads and trackers blocked by name for every program (/etc/hosts)
	cat > "$STAGE/usr/local/bin/noad" <<'EOF'
#!/bin/sh
# noad: block ads and trackers for every program, by name (/etc/hosts)
#   noad        on or off, and how many names
#   noad off    turn it off (a site that breaks), as root;  noad on: back on
LIST=/etc/han/adblock.hosts OFF=/etc/han/noad.off H=/etc/hosts
say() { printf '%s (%s)\n' "$1" "$2"; }
count() { grep -c '^0\.0\.0\.0 ' "$LIST" 2>/dev/null || echo 0; }
apply() { # on|off: the system's own lines stay, the list goes between markers
	t="$(mktemp)" || exit 1
	sed '/^# >>> noad/,/^# <<< noad/d' "$H" > "$t"
	if [ "$1" = on ] && [ -s "$LIST" ]; then
		{ echo "# >>> noad: ads and trackers blocked (noad off: turn it off)"
		  cat "$LIST"; echo "# <<< noad"; } >> "$t"
	fi
	cat "$t" > "$H"; rm -f "$t"
}
case "${1:-}" in
"")
	if grep -q '^# >>> noad' "$H"; then
		say "광고 막기: 켜짐, 막는 주소 $(count) 개" "ad blocking: on, $(count) names"
	else
		say "광고 막기: 꺼짐" "ad blocking: off"
	fi
	say "끄기 noad off, 켜기 noad on (root)" "off: noad off, on: noad on (as root)" ;;
on|off)
	[ "$(id -u)" = 0 ] || { say "root 로 실행하세요" "run as root"; exit 1; }
	[ -s "$LIST" ] || { say "막을 주소 목록이 없습니다" "no list in this ISO"; exit 1; }
	if [ "$1" = on ]; then rm -f "$OFF"; else : > "$OFF"; fi
	apply "$1"; exec "$0" ;;
--boot)
	if [ -e "$OFF" ]; then apply off; else apply on; fi ;;
*)
	say "쓰는 법: noad, noad on, noad off" "usage: noad, noad on, noad off"; exit 1 ;;
esac
EOF
	chmod 755 "$STAGE/usr/local/bin/noad"
	printf '#!/bin/sh\n# noad: the ad blocking list into /etc/hosts at boot (unless noad off)\nexec /usr/local/bin/noad --boot\n' \
		> "$STAGE/etc/local.d/han-noad.start"
	chmod 755 "$STAGE/etc/local.d/han-noad.start"

	# yt-dlp: Deno does YouTube's JavaScript check (Alpine's default). 32-bit
	# Alpine has no Deno and gets QuickJS, which yt-dlp uses only when allowed:
	# allow it (Deno, when there, is still preferred).
	mkdir -p "$STAGE/etc/yt-dlp"
	printf '%s\n' '# Aneuu: Deno first; QuickJS allowed (32-bit has no Deno)' \
		'--js-runtimes quickjs' > "$STAGE/etc/yt-dlp/config"

	cat > "$STAGE/usr/local/bin/hx" <<'EOF'
#!/bin/sh
# X on demand: run one graphical program full screen, then return to the
# console.   hx [PROGRAM [ARGS]]   (default: firefox).  Set up: had firefox
command -v xinit >/dev/null 2>&1 || exec had --hint firefox
[ $# -gt 0 ] || set -- firefox
# had firefox installs Firefox ESR
if [ "$1" = firefox ] && ! command -v firefox >/dev/null 2>&1 &&
   command -v firefox-esr >/dev/null 2>&1; then
	shift; set -- firefox-esr "$@"
fi
exec xinit /usr/local/lib/han/xsession "$@" -- :0 vt7 -nolisten tcp
EOF

	cat > "$STAGE/usr/local/lib/han/xsession" <<'EOF'
#!/bin/sh
# One program, full screen, with Korean input (fcitx5-hangul).
# Right Alt and the Hangul key switch Korean/English, as on the console.
export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx
setxkbmap -option korean:ralt_hangul 2>/dev/null
xsetroot -solid black 2>/dev/null
p="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5"
if [ ! -e "$p/profile" ]; then
	mkdir -p "$p"
	cat > "$p/profile" <<PROFILE
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
PROFILE
fi
fcitx5 -d >/dev/null 2>&1
openbox --config-file /etc/han/openbox.xml >/dev/null 2>&1 &
"$@"
EOF

	# Every window full screen and without a frame.
	cat > "$STAGE/etc/han/openbox.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*" type="normal">
      <decor>no</decor>
      <maximized>yes</maximized>
      <focus>yes</focus>
    </application>
  </applications>
</openbox_config>
EOF

	mkdir -p "$STAGE/usr/share/han/cheat/ko" "$STAGE/usr/share/han/cheat/en"
	cat > "$STAGE/usr/share/han/cheat/ko/cmds.txt" <<'HANCHEAT'
명령 요약
desk      데스크톱
doc       안내서
wg        문서 작성
han       한글 화면
han -s    한글 셸
han -l    글꼴 목록
hwifi  무선랜
hdos   도스 게임
had       더 설치하기 (hadr 빼기)
hkb       폰 키보드
hinst  디스크에 설치
hx firefox  Firefox
nano 파일   편집
nnn       파일 관리
hv        파일 열기
yt        유튜브
rg 글자   파일 안 찾기
fd 이름   파일 찾기

F1 메뉴   F5 무선랜
F2/F3     이전/다음 창
F4        새 셸
F6 / F7   복사/붙여넣기
F8        블루투스
Alt+V     영상으로
Alt+N     뉴스
Alt+P     팟캐스트
Alt+G     AI 에게 묻기
Alt+O     옆 칸으로
Alt+D     단어 뜻 (사전)
F11       옆에 책 펴기
F10 / F9  책 다음/앞 쪽
오른쪽Alt 한/영

husb     USB 연결
husb off USB 빼기 전

poweroff  끄기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/cmds.txt" <<'HANCHEAT'
Commands
desk      desktop
doc       guide
wg        word processor
han       Korean screen
han -s    Korean shell
han -l    fonts
hwifi  Wi-Fi
hdos   DOS games
had       add programs (hadr: remove)
hkb       phone keyboard
hinst  install to disk
hx firefox  Firefox
nano FILE  edit file
nnn       files
hv        open a file
yt        YouTube
rg TEXT   search in files
fd NAME   find files

F1 menu   F5 Wi-Fi
F2/F3     prev/next win
F4        new shell
F6 / F7   copy / paste
F8        Bluetooth
Alt+V     back to video
Alt+N     news feeds
Alt+P     podcast player
Alt+G     ask the AI
Alt+O     other pane
Alt+D     dictionary
F11       book beside work
F10 / F9  book next/prev
Right Alt Korean/English

husb     attach USB
husb off before unplug

poweroff  power off
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/yt.txt" <<'HANCHEAT'
유튜브 yt
번호     영상
번호s    소리만 (예: 3s)
다른 말  새로 찾기
q        끝

영상 보는 중
Space    멈춤/계속
← →     5초 뒤/앞
9 / 0    소리 작게/크게
s        빠르게 1.1-1.8
Tab      데스크톱으로
         (영상은 계속)
q        영상 끝

데스크톱에서
Alt+V    영상으로 돌아가기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/yt.txt" <<'HANCHEAT'
YouTube yt
number   video
numbers  sound only (3s)
words    new search
q        quit

While a video plays
Space    pause/resume
← →     5 s back/ahead
9 / 0    volume down/up
s        faster 1.1-1.8
Tab      back to desktop
         (video keeps on)
q        stop video

In the desktop
Alt+V    back to the video
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/edit.txt" <<'HANCHEAT'
nano
^ 는 Ctrl, M- 는 Alt
Ctrl+O  저장
Ctrl+X  끝내기
Ctrl+W  찾기
Ctrl+\  바꾸기
Ctrl+K  줄 잘라내기
Ctrl+U  붙여넣기
Alt+6   줄 복사
Alt+U   되돌리기
Alt+E   다시 하기
Ctrl+G  도움말
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/edit.txt" <<'HANCHEAT'
nano
^ is Ctrl, M- is Alt
Ctrl+O  save
Ctrl+X  quit
Ctrl+W  find
Ctrl+\  replace
Ctrl+K  cut line
Ctrl+U  paste
Alt+6   copy line
Alt+U   undo
Alt+E   redo
Ctrl+G  help
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/write.txt" <<'HANCHEAT'
WordGrinder
Esc     메뉴
Ctrl+S  저장
Ctrl+Q  끝내기

저장하면 .odt 도 함께
 (LibreOffice 에서 열림)
i 는 저절로 I

Alt+D   단어 뜻 (사전)
bib     주일 성경 본문
bibt    오늘 읽을 말씀
bibr    성경 읽기
wg 주소 웹 글 가져오기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/write.txt" <<'HANCHEAT'
WordGrinder
Esc     menu
Ctrl+S  save
Ctrl+Q  quit

Saving also writes
 an .odt (LibreOffice)
i becomes I by itself

Alt+D   word meaning
bib     Sunday readings
bibt    today's readings
bibr    read the Bible
wg ADDR a web page's text
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/files.txt" <<'HANCHEAT'
nnn
화살표  이동
Enter   열기
←       위 폴더
/       이름 거르기
Space   선택
p       여기로 복사
v       여기로 이동
?       모든 키
q       끝내기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/files.txt" <<'HANCHEAT'
nnn
arrows  move
Enter   open
Left    parent folder
/       filter
Space   select
p       copy here
v       move here
?       all keys
q       quit
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/web.txt" <<'HANCHEAT'
w3m / chawan
U       주소 입력
Enter   링크 열기
Tab     다음 링크
B       뒤로
/       찾기
q       끝내기

Alt+W   이 페이지 글을
        wg 로 (w3m)
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/web.txt" <<'HANCHEAT'
w3m / chawan
U       go to address
Enter   follow link
Tab     next link
B       back
/       search
q       quit

Alt+W   page text to
        WordGrinder (w3m)
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/mail.txt" <<'HANCHEAT'
aerc
j k     위 아래
Enter   열기
c       새 메일
rr      전체 답장
d       지우기
q       뒤로/끝내기

다 쓰고 편집기 닫기
 y 보내기
 n 그만두기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/mail.txt" <<'HANCHEAT'
aerc
j k     up / down
Enter   open
c       compose
rr      reply all
d       delete
q       back / quit

After the editor
 y send
 n abandon
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/feeds.txt" <<'HANCHEAT'
newsboat
R       모두 받기
Enter   열기
o       브라우저로
n       다음 안 읽음
q       뒤로/끝내기
Alt+N   패널 숨기기/보기

주소 목록
 ~/.newsboat/urls
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/feeds.txt" <<'HANCHEAT'
newsboat
R       reload all
Enter   open
o       open in browser
n       next unread
q       back / quit
Alt+N   hide / show panel

Feed list
 ~/.newsboat/urls
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/pod.txt" <<'HANCHEAT'
pod 팟캐스트
번호    열기 / 듣기
이름    찾아서 구독
-번호   구독 끊기
,       뒤로
q       끝내기

듣는 동안
Alt+P   보기 / 숨기기
Space   멈춤
← →    10초
9 0     소리
s       빠르게 1.1-1.8
q       끝
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/pod.txt" <<'HANCHEAT'
pod podcasts
number  open / play
a name  find, subscribe
-number remove
,       back
q       quit

While it plays
Alt+P   show / hide
Space   pause
Left/Right 10 s
9 0     volume
s       faster 1.1-1.8
q       stop
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/cal.txt" <<'HANCHEAT'
calcurse
Tab     칸 바꾸기
화살표  날짜 이동
a       더하기
e       고치기
d       지우기
q       끝내기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/cal.txt" <<'HANCHEAT'
calcurse
Tab     switch panel
arrows  move days
a       add
e       edit
d       delete
q       quit
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/sheet.txt" <<'HANCHEAT'
sc-im
화살표  칸 이동
=       숫자, 수식
         =@sum(A1:A9)
<       글자
x       칸 지우기
:w F.sc 저장
:w F.csv CSV 저장
:q      끝내기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/sheet.txt" <<'HANCHEAT'
sc-im
arrows  move
=       number, formula
         =@sum(A1:A9)
<       text
x       clear cell
:w F.sc save
:w F.csv save as CSV
:q      quit
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/music.txt" <<'HANCHEAT'
cmus
:add ~/music
1 ~ 7   화면 바꾸기
Enter   재생
c       일시정지
b z     다음 / 이전
+ -     소리
q       끝내기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/music.txt" <<'HANCHEAT'
cmus
:add ~/music
1 - 7   views
Enter   play
c       pause
b z     next / prev
+ -     volume
q       quit
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/chat.txt" <<'HANCHEAT'
irssi
/connect 서버
/join #채널
Alt+숫자 창 바꾸기
/part   방 나가기
/quit   끝내기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/chat.txt" <<'HANCHEAT'
irssi
/connect SERVER
/join #channel
Alt+num switch window
/part   leave room
/quit   quit
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/down.txt" <<'HANCHEAT'
rtorrent
Backspace 토렌트 넣기
Ctrl+S  시작
Ctrl+D  멈춤/지우기
Ctrl+Q  끝내기

aria2c 주소
aria2c -x4 주소
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/down.txt" <<'HANCHEAT'
rtorrent
Backspace add torrent
Ctrl+S  start
Ctrl+D  stop / remove
Ctrl+Q  quit

aria2c URL
aria2c -x4 URL
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/sys.txt" <<'HANCHEAT'
btop
화살표  프로그램
k       끝내기(kill)
Esc     메뉴
q       나가기

ncdu
Enter   들어가기
d       지우기
q       나가기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/sys.txt" <<'HANCHEAT'
btop
arrows  pick process
k       kill it
Esc     menu
q       quit

ncdu
Enter   open folder
d       delete
q       quit
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/read.txt" <<'HANCHEAT'
옆에 책 펴기
F11     열기 / 닫기
F10     다음 쪽
F9      앞 쪽
hb 책.epub
        다른 책 넣기

PDF (hv)
Space   다음 쪽
b       앞 쪽
+ -     크게 작게
q       끝내기

Alt+D   단어 뜻 (사전)
 단어 앞 글자 입력,
 Tab 다음, Enter 뜻
Alt+W   WordGrinder 로
        (메모 쓰기)

bibt / bibr 에서
< >     앞 / 다음 날 (장)
a       장 전체 (bibt)
c       장 고르기
v       번역 (bibt)
d       오늘 말씀 (bibt)
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/read.txt" <<'HANCHEAT'
Book beside work
F11     open / close
F10     next page
F9      previous page
hb BOOK.epub
        another book

PDF (hv)
Space   next page
b       previous page
+ -     zoom
q       quit

Alt+D   word meaning
 type its start,
 Tab next, Enter
Alt+W   to WordGrinder
        (write notes)

In bibt / bibr
< >     prev/next day
a       whole chapters
c       choose chapters
v       version (bibt)
d       the day's (bibt)
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/bt.txt" <<'HANCHEAT'
블루투스
s       새 기기 찾기
번호    연결 / 끊기
x번호   지우기
q       닫기

새 기기는 먼저
연결 대기(페어링)
상태로 두기
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/bt.txt" <<'HANCHEAT'
Bluetooth
s       search
number  connect/disconnect
x+num   forget
q       close

Put a new device in
pairing mode first
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/wifi.txt" <<'HANCHEAT'
무선랜
번호    연결
r       다시 찾기
q       닫기
한 번 연결하면
다음엔 저절로
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/wifi.txt" <<'HANCHEAT'
Wi-Fi
number  connect
r       search again
q       close
Networks you used
reconnect by themselves
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/ko/gem.txt" <<'HANCHEAT'
AI 대화 (gem)
쓰고 Enter   묻기
Alt+G        닫기
Alt+O        옆 칸으로

한 문장 복사해 붙이기
1 F6      복사 시작
2 화살표  문장 첫 글자로
3 Space   여기부터
4 화살표  문장 끝까지
5 Enter   복사 (q 취소)
6 Alt+O   옆 칸으로
7 F7      붙여넣기
글 -> AI 도 똑같이

/new      새 대화
Space     긴 답 계속
/copy     답 전체 복사
/pdf 이름 쪽  PDF 보내기
위 화살표 앞 질문 다시
HANCHEAT
	cat > "$STAGE/usr/share/han/cheat/en/gem.txt" <<'HANCHEAT'
AI chat (gem)
type, Enter  ask
Alt+G        close
Alt+O        other side

Copy a sentence over
1 F6      start copying
2 arrows  to its start
3 Space   start here
4 arrows  to its end
5 Enter   copy (q cancels)
6 Alt+O   other side
7 F7      paste
Same: your text -> AI

/new      new chat
Space     more answer
/copy     copy all answer
/pdf NAME PG  send page
Up arrow  ask again
HANCHEAT

	cat > "$STAGE/usr/local/bin/han-cheat" <<'EOF'
#!/bin/sh
# han-cheat: key summary for the program in the current window, shown in
# the F12 side panel on the right. F12 again (or q) closes it.
D=/usr/share/han/cheat
C="${XDG_CONFIG_HOME:-$HOME/.config}/han"
lang="$(cat "$C/lang" 2>/dev/null)"
[ "$lang" = ko ] || [ "$lang" = en ] || lang=en
# The program in the window under the drop-down
cmd="${1:-$(tmux display-message -p '#{pane_current_command}' 2>/dev/null)}"
# Python programs (pod, gem) show up as "python3": look at what runs in
# front in that pane (same session, foreground process group).
case "$cmd" in python*)
	pp="$(tmux display-message -p '#{pane_pid}' 2>/dev/null)"
	for d in /proc/[0-9]*; do
		st="$(sed 's/.*) //' "$d/stat" 2>/dev/null)" || continue
		set -- $st
		[ "${4:-}" = "$pp" ] && [ "$3" = "${6:-}" ] || continue
		a="$(tr '\0' '\n' < "$d/cmdline" 2>/dev/null | sed -n 2p)"
		case "${a##*/}" in gem|pod) cmd="${a##*/}" ;; esac
	done ;;
esac
case "$cmd" in
	nano|micro|vim|vi)         t=edit ;;
	wordgrinder)               t=write ;;
	nnn)                       t=files ;;
	w3m|cha|chawan)            t=web ;;
	aerc|abook)                t=mail ;;
	newsboat)                  t=feeds ;;
	pod)                       t=pod ;;
	gem)                       t=gem ;;
	calcurse)                  t=cal ;;
	sc-im)                     t=sheet ;;
	cmus|mpg123|alsamixer)     t=music ;;
	irssi)                     t=chat ;;
	rtorrent|aria2c)           t=down ;;
	btop|ncdu|iftop)           t=sys ;;
	iwctl|hwifi)            t=wifi ;;
	epy|han-view|hv|hb|han-book|less) t=read ;;
	yt|han-yt|openvt|mpv|ytplay) t=yt ;;
	hbt|bluetoothctl)        t=bt ;;
	*)                         t=cmds ;;
esac
f="$D/$lang/$t.txt"
[ -f "$f" ] || f="$D/en/$t.txt"
[ -f "$f" ] || f="$D/$lang/cmds.txt"
if [ "$lang" = ko ]; then p='F12 닫기'; else p='F12 close'; fi
# F12 closes the drop-down, like q
k="${TMPDIR:-/tmp}/han-cheat-keys.$$"
printf '#command\n\\e[24~ quit\n' > "$k"
less -c -S -P "$p" --lesskey-src="$k" "$f"
rm -f "$k"
EOF
	chmod 755 "$STAGE/usr/local/bin/han-cheat"

	cat > "$STAGE/usr/local/bin/hdos" <<'EOF'
#!/bin/sh
# DOS games with DOSBox Staging, full screen on the console.
#   hdos              DOS prompt, with ~/dos mounted as C:
#   hdos GAME.EXE     run a program (its folder becomes C:)
#   hdos FOLDER       mount that folder as C:
# Escape from a game: Ctrl+F10 frees the mouse, Ctrl+F9 quits DOSBox.
command -v dosbox >/dev/null 2>&1 || exec had --hint dosbox
[ "$(id -u)" = 0 ] || { echo "hdos: run as root"; exit 1; }
mkdir -p "$HOME/dos"
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_VIDEO_DRIVER="${SDL_VIDEO_DRIVER:-kmsdrm}"
set -- ${1:+"$1"}
if [ $# -eq 0 ]; then
	set -- -c "mount c \"$HOME/dos\"" -c "c:"
elif [ -d "$1" ]; then
	set -- -c "mount c \"$1\"" -c "c:"
fi
# DOSBox's messages go to a log; if it stops with an error, show why here
# (otherwise its console would just flash and the window close)
log=/tmp/hdos.log
openvt -s -w -- sh -c 'dosbox "$@" > /tmp/hdos.log 2>&1; echo $? > /tmp/hdos.rc' \
	dosbox -conf /etc/han/dosbox.conf "$@"
rc="$(cat /tmp/hdos.rc 2>/dev/null)"
if [ "${rc:-0}" != 0 ]; then
	echo "도스박스가 멈췄습니다 (DOSBox stopped, error $rc):"
	grep -E 'ABORT|ERROR|error' "$log" | tail -n 5
	if grep -q 'EGL' "$log"; then
		echo "화면을 열 수 없습니다: 그래픽 칩의 드라이버가 필요합니다"
		echo "(cannot open the screen: needs a graphics driver; does not work"
		echo " in a virtual machine with plain VGA)"
	fi
	echo "자세히 (details): $log"
	printf 'Enter 를 누르세요 (press Enter) '; read -r _
	exit 1
fi
EOF

	# Settings for old laptops: full screen, light CPU core choice by DOSBox
	cat > "$STAGE/etc/han/dosbox.conf" <<'EOF'
[sdl]
fullscreen = true

[dosbox]
memsize = 16

[cpu]
core = auto
cputype = auto
cpu_cycles = 3000
EOF

	# Programs that draw on the screen, under their usual names: each one
	# opens on its own console (they need the whole screen) and returns.
	cat > "$STAGE/usr/local/lib/han/fbwrap" <<'EOF'
#!/bin/sh
name="${0##*/}"
case "$name" in
	netsurf) real=/usr/bin/netsurf-framebuffer ;;
	*)       real="/usr/bin/$name" ;;
esac
[ -x "$real" ] || exec had --hint "$name"
# Under X (hx) they run as usual
[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && exec "$real" "$@"
# Without a file they would only flash their usage text and come back
if [ $# -eq 0 ]; then
	case "$name" in
		mpv) echo "Usage:  mpv FILE   (video or music; q stops)" ;;
		fbi) echo "Usage:  fbi PICTURE...   (q closes, PgDn next)" ;;
		fbgs) echo "Usage:  fbgs FILE.pdf   (q closes, PgDn next page)" ;;
	esac
	case "$name" in mpv|fbi|fbgs) exit 1 ;; esac
fi
case "$name" in
	# video straight to the screen; its messages go to a log (not to the
	# screen's output: mpv only reads keys when that is the screen)
	mpv) set -- --vo=drm --log-file=/tmp/hfb.log "$@" ;;
	# NetSurf would try Wayland first and give up: draw through SDL
	# Start page: DuckDuckGo (Google does not work in NetSurf)
	# (c in the toolbar: a close button, first so the pointer reaches it;
	# --options must come first)
	netsurf) [ $# -gt 0 ] || set -- https://duckduckgo.com/
		set -- --fb_toolbar_layout=cblfsrut -f sdl "$@" ;;
	# fbgs calls fbi itself: the real one, not this wrapper
	fbgs) PATH=/usr/bin:/bin:/usr/sbin:/sbin; export PATH ;;
esac
exec /usr/local/bin/hfb "$real" "$@"
EOF
	chmod 755 "$STAGE/usr/local/lib/han/fbwrap"
	for _p in netsurf mpv fbi fbgs scummvm; do
		ln -sf ../lib/han/fbwrap "$STAGE/usr/local/bin/$_p"
	done

	cat > "$STAGE/usr/local/bin/hfb" <<'EOF'
#!/bin/sh
# Run a program that draws on the screen itself on a free virtual console,
# and come back when it ends.   hfb PROGRAM [ARGS]
# (netsurf, mpv, fbi and scummvm do this by themselves.)
command -v "$1" >/dev/null 2>&1 || exec had --hint "$1"
[ "$(id -u)" = 0 ] || { echo "hfb: run as root"; exit 1; }
# SDL programs draw on the console through KMSDRM (Mesa)
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_VIDEO_DRIVER="${SDL_VIDEO_DRIVER:-kmsdrm}"
# The program gets a console of its own; what it prints goes to a log. If
# it comes back within a few seconds it most likely failed to start: show
# why, instead of returning without a word.
log=/tmp/hfb.log
: > "$log"
t0="$(date +%s)"
# Videos keep playing while you go back to the desktop: Tab in mpv goes
# back, Alt+V in the desktop returns to the video (its console number is
# kept in /tmp/han-video-vt).
# Tab goes back to the desktop's console (the video goes on), Alt+V comes
# back to the video's console.
back="$(fgconsole 2>/dev/null)"
vt="$(fgconsole --next-available 2>/dev/null)"
[ -n "$back" ] && echo "$back" > /tmp/han-desk-vt
export HAN_MPV_INPUT=/tmp/han-mpv-input.conf HAN_MPV_SOCK=/tmp/han-mpv.sock
printf '%s\n' 'TAB run "/usr/local/lib/han/vidback"' \
	's cycle-values speed 1.1 1.25 1.35 1.45 1.65 1.8 1' > "$HAN_MPV_INPUT"
case "${1##*/}" in
	# mpv reads keys only when its output is the screen; it logs itself
	mpv|ytplay)
		[ -n "$vt" ] && echo "$vt" > /tmp/han-video-vt
		# Korean input on (search typed in Hangul): a lone ㅍ ㄴ ㅂ would wait
		# for the next key. So this window is marked for English keys: while
		# it has focus, ddakong types English (status bar EN); in any other
		# window (F4, wg) Korean comes back (tmux hooks + enkeys).
		enk_on() {
			if [ -n "${TMUX_PANE:-}" ]; then
				tmux set -p -t "$TMUX_PANE" @enkeys 1 2>/dev/null
				/usr/local/lib/han/enkeys "$TMUX_PANE"
			else
				/usr/local/lib/han/enkeys on
			fi
		}
		enk_off() {
			if [ -n "${TMUX_PANE:-}" ]; then
				tmux set -pu -t "$TMUX_PANE" @enkeys 2>/dev/null
				/usr/local/lib/han/enkeys
			else
				/usr/local/lib/han/enkeys off
			fi
		}
		enk_on
		trap 'enk_off' EXIT
		if [ "${1##*/}" = mpv ]; then
			real="$1"; shift
			set -- "$real" --input-conf="$HAN_MPV_INPUT" --input-ipc-server="$HAN_MPV_SOCK" "$@"
		fi
		openvt ${vt:+-c "$vt"} -s -w -- "$@" &
		op=$!
		# This window waits while the video plays. After Tab you land
		# here: q stops the video, v goes back to it.
		sleep 1
		printf '\n영상 재생 중 (video playing)   q 끝 (stop)   v 영상 보기 (show)   s 빠르게 (faster)\n'
		old="$(stty -g 2>/dev/null)"
		stty -icanon -echo min 0 time 10 2>/dev/null
		mpvsay() { python3 -c 'import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(2); s.connect("/tmp/han-mpv.sock")
s.sendall(json.dumps({"command": sys.argv[1:]}).encode() + b"\n")' "$@" 2>/dev/null; }
		while kill -0 "$op" 2>/dev/null; do
			k="$(dd bs=1 count=1 2>/dev/null)"
			# with Korean input on, q v s arrive as ㅂ ㅍ ㄴ (three bytes each)
			case "$k" in "$(printf '\343')") k="$k$(dd bs=1 count=2 2>/dev/null)" ;; esac
			case "$k" in
				q|Q|ㅂ|ㅃ) # ask mpv to quit; if it does not answer, stop it
					mpvsay quit || kill $(pidof mpv) 2>/dev/null
					echo "q: 끝내는 중 (stopping)" ;;
				v|V|ㅍ) /usr/local/lib/han/vidshow ;;
				s|S|ㄴ) # faster: 1.1, 1.25, 1.35, 1.45, 1.65, 1.8, then normal again
					mpvsay cycle-values speed 1.1 1.25 1.35 1.45 1.65 1.8 1
					sp="$(python3 -c 'import json, socket; s = socket.socket(socket.AF_UNIX); s.settimeout(2); s.connect("/tmp/han-mpv.sock"); s.sendall(b"{\"command\": [\"get_property\", \"speed\"]}\n"); print(round(json.loads(s.recv(4096).decode().splitlines()[0])["data"], 2))' 2>/dev/null)"
					echo "속도 (speed): ${sp:-?}x" ;;
			esac
		done
		[ -n "$old" ] && stty "$old" 2>/dev/null
		wait "$op" 2>/dev/null
		enk_off   # Korean again, if it was
		trap - EXIT
		rm -f /tmp/han-video-vt "$HAN_MPV_SOCK" ;;
	*) openvt ${vt:+-c "$vt"} -s -w -- sh -c 'exec "$@" 2> /tmp/hfb.log' hfb "$@" ;;
esac
# fbterm reads the keyboard raw; keep Enter as Enter (^M, not ^J) there
[ -n "$back" ] && stty -F "/dev/tty$back" -icrnl 2>/dev/null
case "${1##*/}" in
	ytplay) exit 0 ;;   # yt says what went wrong itself
	mpv) # mpv's own log: show its errors when the file did not play
		if grep -qE 'Errors when loading|No video or audio' "$log" 2>/dev/null; then
			echo "mpv could not play it. Its messages:"
			grep -E '\]\[(e|f)\]' "$log" | sed 's/^.*\]\[[ef]\]//' | tail -n 8
			printf 'Press Enter '; read -r _
		fi
		exit 0 ;;
esac
# (also its usage text, when it was started without a file)
if [ $(($(date +%s) - t0)) -lt 4 ] && [ -s "$log" ]; then
	echo "${1##*/} ended at once. Its last messages:"
	{ grep -iE 'error|fail|forbidden|unable|cannot|could not|no such|not found|usage' "$log" ||
		cat "$log"; } | tail -n 12
	echo "(all of it: $log)"
	printf 'Press Enter '; read -r _
fi
EOF

	cat > "$STAGE/usr/local/bin/hwifi" <<'EOF'
#!/bin/sh
# Wi-Fi: show the networks in range and connect to one.
# Networks you have used are joined again by themselves at boot.
[ "$(id -u)" = 0 ] || { echo "hwifi: run as root"; exit 1; }
pause() { printf 'Press Enter '; read -r _; }
LIST="/tmp/hwifi.$$"

dev="$(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2; exit }')"
if [ -z "$dev" ]; then
	echo "No Wi-Fi card found."
	echo "If the laptop has one, its firmware may be missing:"
	dmesg | grep -i -E 'firmware.*(fail|error|missing)' | tail -n 5
	pause; exit 1
fi
rc-service -q dbus status >/dev/null 2>&1 || rc-service -q dbus start
rc-service -q iwd status >/dev/null 2>&1 || { rc-service -q iwd start; sleep 2; }

# Reads "iw scan" output; prints signal|security|name, strongest first,
# one line per network name.
parse_scan() {
	awk '
		function flush() { if (ssid != "") print sig "|" sec "|" ssid }
		/^BSS /                 { flush(); ssid = ""; sig = -100; sec = "open" }
		/^[ \t]+signal:/        { sig = int($2) }
		/^[ \t]+SSID: /         { sub(/^[ \t]+SSID: /, ""); ssid = $0 }
		/^[ \t]+(RSN|WPA):/     { sec = "WPA" }
		/^[ \t]+capability:.*Privacy/ { if (sec == "open") sec = "WEP" }
		END                     { flush() }' |
		sort -t'|' -k1,1nr | awk -F'|' '!seen[$3]++'
}
[ "${1:-}" = --parse ] && { parse_scan; exit 0; }

while :; do
	echo "Searching for networks on $dev ..."
	iwctl station "$dev" scan >/dev/null 2>&1
	sleep 4
	iw dev "$dev" scan dump 2>/dev/null | parse_scan > "$LIST"
	now="$(iw dev "$dev" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p')"
	echo
	if [ ! -s "$LIST" ]; then
		echo "  No networks found."
	else
		n=0
		while IFS='|' read -r sig sec ssid; do
			n=$((n + 1))
			mark=" "; [ "$ssid" = "$now" ] && mark="*"
			printf ' %s%2d)  %4s dBm  %-4s  %b\n' "$mark" "$n" "$sig" "$sec" "$ssid"
		done < "$LIST"
		[ -n "$now" ] && echo "     (* = connected)"
	fi
	echo
	printf 'Number to connect, r = search again, q = quit: '
	read -r ans
	case "$ans" in
		q|Q|"") break ;;
		r|R) continue ;;
		*[!0-9]*) echo "Type a number, r or q."; continue ;;
	esac
	line="$(sed -n "${ans}p" "$LIST")"
	[ -n "$line" ] || { echo "No such number."; continue; }
	sec="$(echo "$line" | cut -d'|' -f2)"
	ssid="$(printf '%b' "$(echo "$line" | cut -d'|' -f3-)")"

	if [ "$sec" = open ] || [ -e "/var/lib/iwd/$ssid.psk" ]; then
		iwctl station "$dev" connect "$ssid"
	else
		printf 'Password for %s: ' "$ssid"
		stty -echo; read -r pw; stty echo; echo
		iwctl --passphrase "$pw" station "$dev" connect "$ssid"
	fi

	printf 'Connecting'
	ok=no
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
		if ip -4 addr show dev "$dev" 2>/dev/null | grep -q 'inet '; then ok=yes; break; fi
		printf '.'; sleep 1
	done
	echo
	if [ "$ok" = yes ]; then
		echo "Connected to $ssid: $(ip -4 addr show dev "$dev" | awk '/inet / { print $2; exit }')"
		pause; break
	fi
	echo "Could not connect to $ssid (wrong password, or weak signal)."
	rm -f "/var/lib/iwd/$ssid.psk"
done
rm -f "$LIST"
EOF

	# iwd gets the address and name servers itself
	mkdir -p "$STAGE/etc/iwd"
	cat > "$STAGE/etc/iwd/main.conf" <<'EOF'
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=resolvconf
EOF

	# A cable just works: ask for an address on every wired interface
	cat > "$STAGE/etc/local.d/han-net.start" <<'EOF'
#!/bin/sh
for d in /sys/class/net/e*; do
	[ -e "$d" ] || continue
	i="${d##*/}"
	ip link set "$i" up 2>/dev/null
	udhcpc -b -i "$i" >/dev/null 2>&1 &
done
EOF
	chmod 755 "$STAGE/etc/local.d/han-net.start" \
		"$STAGE/usr/local/bin/hfb" "$STAGE/usr/local/bin/hwifi" \
		"$STAGE/usr/local/bin/hdos"

	chmod 755 "$STAGE/usr/local/bin/desk" "$STAGE/usr/local/bin/han-run" \
		"$STAGE/usr/local/bin/han-status" "$STAGE/usr/local/bin/had" \
		"$STAGE/usr/local/bin/hx" "$STAGE/usr/local/lib/han/xsession"
}

# ---------------------------------------------------------------------------
# Overlay generator and mkimage profile (written into aports/scripts)
# ---------------------------------------------------------------------------
write_mkimage_files() {
	_dir="$1"

	cat > "$_dir/genapkovl-hangul.sh" <<EOF
#!/bin/sh -e
HOSTNAME="\$1"
[ -n "\$HOSTNAME" ] || { echo "usage: \$0 hostname"; exit 1; }

tmp="\$(mktemp -d)"
trap 'rm -rf "\$tmp"' EXIT

rc_add() {
	mkdir -p "\$tmp"/etc/runlevels/"\$2"
	ln -sf /etc/init.d/"\$1" "\$tmp"/etc/runlevels/"\$2"/"\$1"
}

cp -a "$STAGE"/. "\$tmp"/
chown -R root:root "\$tmp"

echo "\$HOSTNAME" > "\$tmp"/etc/hostname
echo "$ANEUU_VERSION" > "\$tmp"/etc/aneuu-release

mkdir -p "\$tmp"/etc/network
cat > "\$tmp"/etc/network/interfaces <<IFACES
auto lo
iface lo inet loopback
IFACES

# Korea: Seoul time; the clock chip keeps local time, as Windows left it
ln -sf /usr/share/zoneinfo/Asia/Seoul "\$tmp"/etc/localtime
mkdir -p "\$tmp"/etc/conf.d "\$tmp"/etc/chrony
echo 'clock="local"' > "\$tmp"/etc/conf.d/hwclock
# Set the clock as soon as we are online, however far off it is
cat > "\$tmp"/etc/chrony/chrony.conf <<CHRONY
pool pool.ntp.org iburst
makestep 1 -1
driftfile /var/lib/chrony/chrony.drift
CHRONY

mkdir -p "\$tmp"/etc/apk
cat > "\$tmp"/etc/apk/world <<WORLD
$(printf '%s\n' $BOOT_BASE $EXTRA_OK)
WORLD

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit

rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add local default
rc_add dbus default
rc_add iwd default
rc_add chronyd default
rc_add acpid default
rc_add bluetooth default
rc_add bluealsa default
rc_add alsa default

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "\$tmp" etc usr | gzip -9n > "\$HOSTNAME".apkovl.tar.gz
EOF
	chmod 755 "$_dir/genapkovl-hangul.sh"

	cat > "$_dir/mkimg.hangul.sh" <<EOF
profile_hangul() {
	profile_standard
	title="Aneuu $ANEUU_VERSION"
	hostname="aneuu"
	desc="Aneuu (다시): Alpine console desktop with Korean input."
	profile_abbrev="aneuu"
	arch="x86 x86_64"
	# no "kms" in the initramfs: it took every graphics driver and all their
	# firmware (128 + 137 MB unpacked, a 171 MB initramfs read before the
	# kernel starts). They load from the modloop a few seconds later, like
	# every other driver; the boot console needs none of them.
	initfs_features="\$(echo " \$initfs_features " | sed 's/ kms / /g')"
	# The live system's RAM disk may grow to 90% of the memory (Alpine's
	# default is half: 490 MB on 1 GB, too small for the boot set). A RAM
	# disk only uses what its files take; han-zram compresses the rest.
	kernel_cmdline="\$kernel_cmdline rootflags=size=90%"
	# no xtables-addons-lts: Alpine's build of it needs Alpine's exact kernel,
	# which made apk drop our Korean-console kernel for the stock one
	kernel_addons=
	apks="\$apks fontconfig font-terminus freetype kbd libstdc++
		mandoc ncurses-terminfo-base wordgrinder
		$(echo $EXTRA_OK) $(echo $OPT_OK)"
	apkovl="aports/scripts/genapkovl-hangul.sh"
}
EOF
}

# ---------------------------------------------------------------------------
# mpv without EGL/OpenGL/Vulkan/X11/Wayland. Aneuu plays video with
# --vo=drm (software, straight to the console), which needs none of them;
# Alpine's mpv links EGL, and that pulls in Mesa and LLVM: about 225 MB
# more RAM in the live system for nothing. VA-API stays (hardware decoding
# with --hwdec=vaapi-copy, once a driver is installed: no EGL needed).
# Mesa and the GPU/VA drivers stay in the ISO's repository for later.
# ---------------------------------------------------------------------------
build_mpv_drm() {
	_m=/home/build/aports/community/mpv
	echo ">> mpv for the console (drm, no Mesa/LLVM)"
	# meson options: what a console player needs on, the rest off
	_on="alsa drm vaapi vaapi-drm uchardet"
	_off="egl egl-drm egl-wayland egl-x11 gbm gl vulkan x11 wayland pulse
		pipewire jack sndio caca sixel cdda dvdnav libbluray vdpau
		rubberband shaderc spirv-cross"
	{
		for _o in $_on; do printf '\t\t-D%s=enabled \\\n' "$_o"; done
		for _o in $_off; do printf '\t\t-D%s=disabled \\\n' "$_o"; done
		printf '\t\t-Db_lto=true \\\n\t\t-Dbuild-date=false \\\n'
		printf '\t\t-Dlibmpv=true \\\n\t\t-Dtests=false \\\n'
	} > /home/build/mpv-opts
	awk -v opts=/home/build/mpv-opts '
		/abuild-meson \\$/ { print; while ((getline l < opts) > 0) print l; skip = 1; next }
		skip && /^[ \t]*\. output$/ { skip = 0 }
		!skip { print }
	' "$_m/APKBUILD" > "$_m/APKBUILD.new" &&
		mv "$_m/APKBUILD.new" "$_m/APKBUILD" || return 1
	sed -i 's/^pkgrel=.*/pkgrel=900/' "$_m/APKBUILD"
	grep -q -- '-Degl=disabled' "$_m/APKBUILD" ||
		{ echo "!! mpv: APKBUILD not as expected" >&2; return 1; }
	( cd "$_m" && abuild checksum && abuild -r ) || return 1
	ls /home/build/packages/community/"$ARCH"/mpv-[0-9]*.apk
}

# ---------------------------------------------------------------------------
# DOSBox Staging for 32-bit x86. Alpine skips x86 ("TEXTREL on x86"): the
# dyn-x86 CPU core pushes an absolute code address in inline assembly.
# The portable dynrec core has no such relocation, so x86 uses it.
# ---------------------------------------------------------------------------
build_dosbox_x86() {
	_d=/home/build/aports/community/dosbox-staging
	echo ">> dosbox-staging for x86 (dynrec core)"
	sed -i -e 's/^arch="all !x86".*/arch="all"/' \
	       -e 's/^pkgrel=.*/pkgrel=900/' \
	       -e '/^	abuild-meson \\/a\	-Ddynamic_core=$([ "$CARCH" = x86 ] \&\& echo dynrec || echo auto) \\' \
		"$_d/APKBUILD"
	( cd "$_d" && abuild -r ) || return 1
	ls /home/build/packages/community/"$ARCH"/dosbox-staging-[0-9]*.apk
}

# ---------------------------------------------------------------------------
# fbi (pictures, and PDF pages through fbgs): b goes back a page, as in less
# ---------------------------------------------------------------------------
build_fbida_keys() {
	_f=/home/build/aports/community/fbida
	echo ">> fbi with b = previous page"
	cat > "$_f/aneuu-b-key.patch" <<'FBIDAB'
--- a/fbi.c	2026-11-18 22:10:04.267994530 +0900
+++ b/fbi.c	2026-11-18 22:10:04.292252591 +0900
@@ -838,6 +838,7 @@
 
         case XKB_KEY_Page_Up:
         case XKB_KEY_K:
+        case XKB_KEY_B:		/* Aneuu: b = previous page, like less */
 	    if (textreading && f->top > 0) {
 		redraw = 1;
 		f->top -= f->text_steps;
FBIDAB
	sed -i -e '/^source="/a\	aneuu-b-key.patch' \
	       -e 's/^pkgrel=.*/pkgrel=900/' "$_f/APKBUILD"
	( cd "$_f" && abuild checksum && abuild -r ) || return 1
	ls /home/build/packages/community/"$ARCH"/fbida-fbi-[0-9]*.apk
}

# ---------------------------------------------------------------------------
# NetSurf framebuffer with Korean fonts and a built-in Hangul input method
# ---------------------------------------------------------------------------
build_netsurf_hangul() {
	_n=/home/build/aports/community/netsurf
	echo ">> netsurf-framebuffer with Korean fonts and Hangul input"
	cp /netsurf-fb-hangul.patch "$_n/hangul.patch" || return 1
	# Ctrl+Q quits NetSurf (the framebuffer version has no quit key)
	cat > "$_n/quit.patch" <<'NSQUIT'
--- a/netsurf/frontends/framebuffer/gui.c	2026-11-18 20:30:49.571138497 +0900
+++ b/netsurf/frontends/framebuffer/gui.c	2026-11-18 20:31:21.168117108 +0900
@@ -612,6 +612,24 @@
 	return true;
 }
 
+/* Aneuu: Ctrl+Q quits, wherever the keyboard focus is (on the console
+ * there is no window to close and no other way out) */
+static void aneuu_quit_key(nsfb_event_t *event)
+{
+	static bool ctrl = false;
+
+	if ((event->type != NSFB_EVENT_KEY_DOWN) &&
+	    (event->type != NSFB_EVENT_KEY_UP))
+		return;
+	if ((event->value.keycode == NSFB_KEY_LCTRL) ||
+	    (event->value.keycode == NSFB_KEY_RCTRL)) {
+		ctrl = (event->type == NSFB_EVENT_KEY_DOWN);
+	} else if (ctrl && (event->type == NSFB_EVENT_KEY_DOWN) &&
+		   (event->value.keycode == NSFB_KEY_q)) {
+		fb_complete = true;
+	}
+}
+
 static void framebuffer_run(void)
 {
 	nsfb_event_t event;
@@ -633,6 +651,7 @@
 			if ((event.type == NSFB_EVENT_CONTROL) &&
 			    (event.value.controlcode ==  NSFB_CONTROL_QUIT))
 				fb_complete = true;
+			aneuu_quit_key(&event);
 		}
 
 		fbtk_redraw(fbtk);
NSQUIT
	_fb="NETSURF_FB_FONTLIB=freetype NETSURF_FB_FONTPATH=/usr/share/fonts/nanum"
	for _v in SANS_SERIF SANS_SERIF_ITALIC SERIF CURSIVE FANTASY; do
		_fb="$_fb NETSURF_FB_FONT_$_v=NanumGothic-Regular.ttf"
	done
	for _v in SANS_SERIF_BOLD SANS_SERIF_ITALIC_BOLD SERIF_BOLD; do
		_fb="$_fb NETSURF_FB_FONT_$_v=NanumGothic-Bold.ttf"
	done
	for _v in MONOSPACE MONOSPACE_BOLD; do
		_fb="$_fb NETSURF_FB_FONT_$_v=NanumGothicCoding-Regular.ttf"
	done
	sed -i -e '/^source="/a\	hangul.patch' \
	       -e '/^source="/a\	quit.patch' \
	       -e 's/^pkgrel=.*/pkgrel=900/' \
	       -e 's/^makedepends="/makedepends="freetype-dev /' \
	       -e "s|TARGET=framebuffer |TARGET=framebuffer $_fb |" "$_n/APKBUILD"
	( cd "$_n" && abuild checksum && abuild -r ) || return 1
	ls /home/build/packages/community/"$ARCH"/netsurf-framebuffer-[0-9]*.apk
}

# ---------------------------------------------------------------------------
# linux-lts with the cjktty patch: Hangul (CJK) glyphs in the kernel console
# ---------------------------------------------------------------------------
build_cjktty_kernel() {
	_k=/home/build/aports/main/linux-lts
	_kver="$(sed -n 's/^pkgver=//p' "$_k/APKBUILD")"
	echo ">> linux-lts $_kver + cjktty: Korean on the plain console (about an hour)"
	xz -dc /cjktty.patch.xz > "$_k/cjktty.patch" || return 1
	# Aneuu's console font: Hangul from DOSMyungjo, English from Terminus
	# (both 16 px), the same pair han uses in fbterm.
	# If it fails, cjktty's own glyphs stay (VGA English, cjktty Hangul).
	# >>> kfont (generated by tools/embed.py: edit tools/kfont)
	cat > /tmp/kfont <<'KFONT'
#!/usr/bin/env python3
# kfont: put Aneuu's console font into the cjktty kernel patch, before the
# kernel is compiled. The patch carries lib/fonts/font_cjk_16x16.h, the
# kernel console's whole 16 px font table; this replaces glyphs in it:
#   English  0x20-0x7E, 0xA0-0xFF                from an 8x16 font (Terminus)
#   Hangul   AC00-D7A3, 1100-11FF, 3131-318E     from a 16x16 font (DOSMyungjo)
# Characters a font does not have keep cjktty's own glyph.
# Table layout: chars 0-255 one line of 16 bytes (16 rows, 8 px wide);
# every other char two lines: left half (16 rows), then right half.
# Only the byte values change, never the number of lines, so the patch's
# hunk header stays valid.
#   kfont PATCH LATIN-FONT KOREAN-FONT     (rewrites PATCH in place)
# Fonts: TTF/OTB (drawn at 16 px) or 16 px BDF.
import re
import sys
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

LATIN = list(range(0x20, 0x7F)) + list(range(0xA0, 0x100))
HANGUL = list(range(0xAC00, 0xD7A4)) + list(range(0x1100, 0x1200)) + list(range(0x3131, 0x318F))
TABLE = "+++ b/lib/fonts/font_cjk_16x16.h"


def bdf_glyphs(path, chars, width):
    """{char: rows} from a 16 px BDF font, placed by its own baseline."""
    asc = desc = None
    out = {}
    want = set(chars)
    c = bbx = bits = None
    for line in open(path, encoding="latin-1"):
        w = line.split()
        if not w:
            continue
        if w[0] == "FONT_ASCENT":
            asc = int(w[1])
        elif w[0] == "FONT_DESCENT":
            desc = int(w[1])
        elif w[0] == "ENCODING":
            c = int(w[1])
        elif w[0] == "BBX":
            bbx = [int(v) for v in w[1:5]]
        elif w[0] == "BITMAP":
            bits = []
        elif w[0] == "ENDCHAR":
            if c in want and bits is not None:
                out[c] = bdf_rows(asc, bbx, bits, width)
            c = bbx = bits = None
        elif bits is not None:
            bits.append(w[0])
    if asc is None or desc is None or asc + desc != 16:
        sys.exit(f"kfont: {path}: not a 16 px BDF font")
    return out


def bdf_rows(asc, bbx, bits, width):
    """One BDF glyph into 16 rows of WIDTH bits; the baseline is row ASC."""
    bw, bh, bx, by = bbx
    top = asc - by - bh
    rows = [0] * 16
    for r, hexrow in enumerate(bits):
        y = top + r
        if not 0 <= y < 16:
            continue
        v, n = int(hexrow, 16), len(hexrow) * 4
        for x in range(bw):
            if v >> (n - 1 - x) & 1 and 0 <= bx + x < width:
                rows[y] |= 1 << (width - 1 - bx - x)
    return rows


def glyphs(path, chars, width):
    """{char: list of rows as ints}, drawn without smoothing, top at row 0."""
    if path.endswith(".bdf"):
        return bdf_glyphs(path, chars, width)
    have = TTFont(path, fontNumber=0).getBestCmap()
    font = ImageFont.truetype(path, 16)
    asc, desc = font.getmetrics()
    if asc + desc != 16:
        sys.exit(f"kfont: {path}: {asc}+{desc} is not a 16 px font")
    out = {}
    for c in chars:
        if c not in have:
            continue
        im = Image.new("1", (width, 16), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        d.text((0, 0), chr(c), font=font, fill=1)
        out[c] = [sum(1 << (width - 1 - x) for x in range(width) if im.getpixel((x, y)))
                  for y in range(16)]
    return out


def line(values):
    return "+" + "".join(f"0x{v:02x}," for v in values)


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: kfont PATCH LATIN-FONT KOREAN-FONT")
    patch, latin, korean = sys.argv[1:]
    new = glyphs(latin, LATIN, 8)
    ko = glyphs(korean, HANGUL, 16)
    n_lat, n_ko = len(new), len(ko)
    new.update(ko)

    head = re.compile(r"^\+/\* (\d+) 0x")
    src = open(patch, encoding="utf-8", errors="surrogateescape").read().split("\n")
    i = src.index(TABLE)
    end = next(k for k in range(i + 1, len(src)) if src[k].startswith("diff --git "))
    done = 0
    k = i
    while k < end:
        m = head.match(src[k])
        if not m:
            k += 1
            continue
        c = int(m.group(1))
        rows = new.get(c)
        if rows is not None:
            if c < 256:
                assert src[k + 1].startswith("+0x"), (c, src[k + 1])
                src[k + 1] = line(rows)
            else:
                assert src[k + 1].startswith("+0x") and src[k + 2].startswith("+0x"), c
                src[k + 1] = line([r >> 8 for r in rows])
                src[k + 2] = line([r & 0xFF for r in rows])
            done += 1
        k += 1
    if done != len(new):
        sys.exit(f"kfont: replaced {done} of {len(new)} glyphs: table layout not as expected")
    open(patch, "w", encoding="utf-8", errors="surrogateescape").write("\n".join(src))
    print(f"kfont: {n_lat} English glyphs from {latin.rsplit('/', 1)[-1]}, "
          f"{n_ko} Hangul glyphs from {korean.rsplit('/', 1)[-1]}")


main()
KFONT
	# <<< kfont
	_kko=/home/build/kfont-src/DOSMyungjo-16.bdf
	_kter=/usr/share/fonts/misc/ter-u16n.otb
	if [ -s "$_kko" ] && [ -s "$_kter" ] &&
	   python3 /tmp/kfont "$_k/cjktty.patch" "$_kter" "$_kko"; then
		echo ">> kernel console font: DOSMyungjo + Terminus"
	else
		echo "!! kernel console font not replaced: cjktty's own glyphs (VGA English)" >&2
	fi
	sed -i -e '/^source="/a\	cjktty.patch' \
	       -e "/virt\\.$ARCH\\.config/d" \
	       -e 's/^pkgrel=.*/pkgrel=900/' "$_k/APKBUILD"
	printf '\n%s\n' CONFIG_FONT_8x16=y CONFIG_FONT_CJK_16x16=y CONFIG_FONT_CJK_32x32=y \
		>> "$_k/lts.$ARCH.config"
	( cd "$_k" && abuild checksum && abuild -r ) || return 1
	ls /home/build/packages/main/"$ARCH"/linux-lts-[0-9]*.apk
}

# ---------------------------------------------------------------------------
# Phase 3: inside the container, as user "build"
# ---------------------------------------------------------------------------
phase_build() {
	cd /home/build

	echo ">> fbterm"
	git clone --depth 1 https://github.com/gjedeer/fbterm
	( cd fbterm
	  ./configure --prefix=/usr/local --disable-gpm --disable-vesa
	  make
	  install -Dm755 src/fbterm "$STAGE/usr/local/bin/fbterm"
	  mkdir -p "$STAGE/usr/share/terminfo" &&
	  tic -x -o "$STAGE/usr/share/terminfo" terminfo/fbterm ||
		echo "!! tic failed: no fbterm terminfo (programs fall back to TERM=linux)" >&2
	  ls -l "$STAGE"/usr/share/terminfo/f/fbterm 2>/dev/null ||
		echo "!! fbterm terminfo missing after tic" >&2 )

	echo ">> ddakong $DDAKONG_TAG (toggle byte $TOGGLE_BYTE)"
	git clone --depth 1 --branch "$DDAKONG_TAG" https://github.com/ageldama/term-ddakong
	( cd term-ddakong
	  # Aneuu: run /usr/local/lib/han/imestate ko|en on the Hangul key
	  # (status bar shows the mode); a helper's end no longer ends ddakong
	  git apply <<'DDKIME' || echo "!! ddakong mode patch failed: no 한/EN in the status bar" >&2
--- a/src/im_handler.c
+++ b/src/im_handler.c
@@ -6,10 +6,52 @@
  * that can be found in the license file.
  */
 
+#define _POSIX_C_SOURCE 200809L /* Aneuu: sigprocmask, fork */
 #include "im_handler.h"
 #include "cc_nanny.h"
 
 #include <ctype.h>
+#include <fcntl.h>
+#include <signal.h>
+#include <sys/wait.h>
+#include <unistd.h>
+
+/* Aneuu: tell the desktop (tmux status bar) whether Korean is on, by
+   running /usr/local/lib/han/imestate ko|en.  Double fork with SIGCHLD
+   blocked, so ddakong's main loop never sees the helper end. */
+static void
+han_ime_notify (BOOL on)
+{
+  const char *hook = "/usr/local/lib/han/imestate";
+  sigset_t set, old;
+  if (access (hook, X_OK) != 0)
+    return;
+  sigemptyset (&set);
+  sigaddset (&set, SIGCHLD);
+  sigprocmask (SIG_BLOCK, &set, &old);
+  pid_t pid = fork ();
+  if (pid == 0)
+    {
+      sigprocmask (SIG_SETMASK, &old, NULL);
+      if (fork () != 0)
+        _exit (0);
+      int fd = open ("/dev/null", O_RDWR);
+      if (fd >= 0)
+        {
+          dup2 (fd, 0);
+          dup2 (fd, 1);
+          dup2 (fd, 2);
+        }
+      for (int i = 3; i < 256; i++)
+        close (i);
+      setsid ();
+      execl (hook, hook, on ? "ko" : "en", (char *)NULL);
+      _exit (127);
+    }
+  if (pid > 0)
+    waitpid (pid, NULL, 0);
+  sigprocmask (SIG_SETMASK, &old, NULL);
+}
 
 #include "hangeul.h"
 #include "im_handler_hangeul.h"
@@ -123,6 +165,7 @@
         {
           /* TOGGLE key */
           p_status->im_mode = ~(p_status->im_mode);
+          han_ime_notify (p_status->im_mode ? TRUE : FALSE);
 
           if (p_status->im_mode == FALSE)
             {
--- a/src/main_ddakong.c
+++ b/src/main_ddakong.c
@@ -128,15 +128,22 @@
 void
 trap_chld (const int signo UNUSED)
 {
-  pid_t pid;
-  int status, exitcode;
+  pid_t pid = -1;
+  int status = 0, st, exitcode;
 
   while (1)
     {
-      pid = waitpid (-1, &status, WNOHANG);
-      if (pid <= 0)
+      pid_t got = waitpid (-1, &st, WNOHANG);
+      if (got <= 0)
         break;
+      if (got == child_pid)  /* Aneuu: only the shell's end ends ddakong */
+        {
+          pid = got;
+          status = st;
+        }
     }
+  if (pid != child_pid)
+    return;
   exitcode = WEXITSTATUS (status);
 
   if (verbose_flag)
DDKIME
	  # Aneuu: a final ㄲ or ㅆ before a vowel moves whole (그러니까, 사싸),
	  # it was split like ㄺ (그러닉가)
	  git apply <<'DDKDBL' || echo "!! ddakong ㄲ/ㅆ patch failed: 그러니까 types as 그러닉가" >&2
--- a/src/hangeul.c
+++ b/src/hangeul.c
@@ -333,7 +333,9 @@
           int n_decomposed = hangeul_decompose_jongseong (
               p_status->jong, &jong_left, &jong_right);
 
-          if (n_decomposed == 2)
+          /* ㄲ, ㅆ (rr, tt) are one consonant: they move to the next
+             syllable whole (닊+ㅏ => 니까, 샀+ㅏ => 사싸), not split. */
+          if (n_decomposed == 2 && jong_left != jong_right)
             { /* 분리해서 분배. (eg) 밝+ㅏ => 발가. */
               p_status->jong = jong_left;
               hangeul_2beol_commit_1_and_flush (p_status, outbuf, outbuf_max,
@@ -344,7 +346,7 @@
                   = hangeul_remap_code (JONGSEONG, CHOSEONG, jong_right);
               p_status->jung = hangeul_2beol_find_code (JUNGSEONG, ch);
             }
-          else if (n_decomposed <= 1)
+          else
             {
               /* 분리가능한 종성이 아니라면, 다음 모음에 뺏김.
                *
DDKDBL
	  # Aneuu: SIGUSR1 switches to English, SIGUSR2 back (hfb, while a video
	  # plays: single keys like q v s are not held back as a syllable)
	  git apply <<'DDKENG' || echo "!! ddakong English-switch patch failed: q v s after Tab need English" >&2
diff --git a/src/im_handler.c b/src/im_handler.c
index 823f1f5..50eae01 100644
--- a/src/im_handler.c
+++ b/src/im_handler.c
@@ -137,6 +137,43 @@ handle_stdin_write_remain (const int fd_child)
     }
 }
 
+/* Aneuu: switch Korean input from outside. SIGUSR1: English now (a
+   syllable being typed is finished first); SIGUSR2: Korean again if it
+   was on before. hfb does this while a video plays, so that single keys
+   (q v s) arrive as typed, not held back as an unfinished syllable. */
+static BOOL han_forced = FALSE, han_was_on = FALSE;
+
+void
+han_ime_force (im_handler_status *p_status, const int fd_child,
+               const BOOL english)
+{
+  if (english)
+    {
+      /* the mode to come back to: the one before the first USR1 */
+      if (!han_forced)
+        han_was_on = p_status->im_mode ? TRUE : FALSE;
+      han_forced = TRUE;
+      if (p_status->im_mode)
+        {
+          handle_stdin_write_remain (fd_child);
+          p_status->im_mode = FALSE;
+          han_ime_notify (FALSE);
+        }
+    }
+  else
+    {
+      if (!han_forced)
+        return;
+      han_forced = FALSE;
+      if (han_was_on && !p_status->im_mode)
+        {
+          p_status->im_mode = ~((BOOL)FALSE);
+          han_ime_notify (TRUE);
+        }
+    }
+  p_status->toggle = IM_HANDLER_TOGGLE__OFF;
+}
+
 #ifndef im_handler__CONTROL_H /* C-h */
 #define im_handler__CONTROL_H 0x08
 #endif
@@ -165,6 +202,7 @@ handle_stdin (im_handler_status *p_status, const int fd_keyin,
         {
           /* TOGGLE key */
           p_status->im_mode = ~(p_status->im_mode);
+          han_forced = FALSE; /* Aneuu: the user's own choice wins over USR2 */
           han_ime_notify (p_status->im_mode ? TRUE : FALSE);
 
           if (p_status->im_mode == FALSE)
diff --git a/src/im_handler.h b/src/im_handler.h
index 4928436..902bc6e 100644
--- a/src/im_handler.h
+++ b/src/im_handler.h
@@ -104,6 +104,10 @@ EXTERN_ void set_current_handle_input_status (void *p_new_status);
 EXTERN_
 void im_handler_status__empty (im_handler_status *p_status);
 
+/* Aneuu: SIGUSR1/SIGUSR2 -> English / Korean again (see im_handler.c) */
+void han_ime_force (im_handler_status *p_status, const int fd_child,
+                    const BOOL english);
+
 /**
  * 표준입력 처리 함수
  *
diff --git a/src/main_ddakong.c b/src/main_ddakong.c
index 54fef44..d1cbfea 100644
--- a/src/main_ddakong.c
+++ b/src/main_ddakong.c
@@ -186,6 +186,16 @@ handle_stdin_written (const ssize_t n_written, const BYTE *buf, void *aux)
     }
 }
 
+/* Aneuu: SIGUSR1 = English, SIGUSR2 = Korean again; applied in the main
+   loop (the handler only notes it) */
+static volatile sig_atomic_t han_sig = 0;
+
+static void
+trap_usr (int signo)
+{
+  han_sig = (signo == SIGUSR1) ? 1 : 2;
+}
+
 int
 main (int argc, char **argv)
 {
@@ -247,6 +257,8 @@ main (int argc, char **argv)
   signal_trap_norecover (SIGCHLD, &trap_chld);
   signal_trap_norecover (SIGWINCH, &trap_winch);
   signal_trap_norecover (SIGTERM, &trap_term);
+  signal_trap_norecover (SIGUSR1, &trap_usr);
+  signal_trap_norecover (SIGUSR2, &trap_usr);
 
   /* terminal size, echo, control-keys */
   winsz_update (child_fd);
@@ -323,6 +335,12 @@ main (int argc, char **argv)
   while (1)
     {
       int nfds = pollfd_wait (p_pollfd, fds, MAX_EVTS);
+      if (han_sig)
+        {
+          int s = han_sig;
+          han_sig = 0;
+          han_ime_force (p_handle_input_status, child_fd, s == 1);
+        }
       if (nfds == -1)
         {
           continue;
DDKENG
	  # Aneuu: a signal (the USR1/USR2 above) interrupts epoll_wait; ddakong
	  # printed "epoll_wait: Interrupted system call" over the screen
	  git apply <<'DDKEINTR' || echo "!! ddakong epoll patch failed: an epoll_wait message may show" >&2
diff --git a/src/pollfd__linux_epoll.c b/src/pollfd__linux_epoll.c
index 1d1930b..af829e8 100644
--- a/src/pollfd__linux_epoll.c
+++ b/src/pollfd__linux_epoll.c
@@ -9,6 +9,7 @@
  */
 
 #include <assert.h>
+#include <errno.h>
 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
@@ -154,6 +155,8 @@ pollfd_wait (pollfd_t *p_pollfd, int *fds, const size_t fds_len)
   int nfds
       = epoll__wait (p_pollfd->epollfd, p_pollfd->epoll_evts,
                      p_pollfd->epoll_evts_len, p_pollfd->epoll_timeout_millis);
+  if (nfds < 0 && errno == EINTR)
+    return 0; /* a signal (Aneuu: SIGUSR1/2): not an error */
   if (nfds < 0)
     {
       perror ("epoll_wait");
DDKEINTR
	  ./configure --prefix=/usr/local --disable-lua --disable-random-phrase
	  make CFLAGS="$(sed -n 's/^CFLAGS = //p' Makefile) -Wno-error -Dim_handler__CONTROL_H=$TOGGLE_BYTE"
	  install -Dm755 src/ddakong "$STAGE/usr/local/bin/ddakong" )

	# Ad and tracker blocking for every program (NetSurf, w3m, chawan ...):
	# StevenBlack's unified hosts list (MIT), only its "0.0.0.0 name" lines;
	# noad puts it into /etc/hosts at boot (noad off: a site that breaks)
	echo ">> ad blocking list (noad)"
	mkdir -p "$STAGE/etc/han"
	if curl -fsSL --retry 3 -o /tmp/sb.hosts \
		https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts; then
		grep -E '^0\.0\.0\.0[[:space:]]+[^[:space:]#]+' /tmp/sb.hosts |
			awk '$2 != "0.0.0.0" { print "0.0.0.0", $2 }' | sort -u \
			> "$STAGE/etc/han/adblock.hosts"
		_n="$(wc -l < "$STAGE/etc/han/adblock.hosts")"
		if [ "$_n" -lt 20000 ]; then
			rm -f "$STAGE/etc/han/adblock.hosts"
			echo "!! ad blocking list too short ($_n names): no ad blocking" >&2
		else
			echo ">> ad blocking: $_n names"
			printf '%s\n' "Ad blocking list: StevenBlack/hosts (github.com/StevenBlack/hosts)," \
				"unified hosts file, MIT License; fetched when this ISO was built." \
				> "$STAGE/etc/han/adblock.LICENSE"
		fi
		rm -f /tmp/sb.hosts
	else
		echo "!! ad blocking list download failed: no ad blocking (noad)" >&2
	fi

	# English dictionary for sdcv / dic: Princeton WordNet 3.0 (WordNet
	# License), from NLTK's copy on GitHub, made into a StarDict dictionary
	echo ">> WordNet 3.0 dictionary (for dic, Alt+D)"
	cat > /tmp/wn2dict <<'WN2DICT'
#!/usr/bin/env python3
# wn2dict WORDNET_DIR OUT_DIR: Princeton WordNet 3.0 (its data.* and index.*
# files) as a StarDict dictionary for sdcv: OUT_DIR/wordnet.{ifo,idx,syn,dict}.
# Inflected forms from the *.exc lists (went, mice, better) lead to their word.
import os, re, struct, sys

POS = [("noun", "n"), ("verb", "v"), ("adj", "a"), ("adv", "r")]
NAMES = {"n": "noun", "v": "verb", "a": "adj", "r": "adv"}


def synsets(path):
    """offset -> (words, gloss)"""
    out = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("  "):
            continue
        head, _, gloss = line.partition(" | ")
        f = head.split()
        n = int(f[3], 16)
        words = [re.sub(r"\(.*\)$", "", f[4 + 2 * i]).replace("_", " ") for i in range(n)]
        out[f[0]] = (words, gloss.strip())
    return out


def dictzip(data, chunk=58315):
    """gzip with the dictzip "RA" field: chunks that unpack one by one."""
    import zlib
    z = zlib.compressobj(9, zlib.DEFLATED, -15)
    sizes, body = [], bytearray()
    for i in range(0, len(data), chunk):
        part = z.compress(data[i:i + chunk]) + z.flush(zlib.Z_FULL_FLUSH)
        sizes.append(len(part))
        body += part
    body += z.flush(zlib.Z_FINISH)
    ra = struct.pack("<HHH", 1, chunk, len(sizes)) + b"".join(struct.pack("<H", n) for n in sizes)
    extra = b"RA" + struct.pack("<H", len(ra)) + ra
    head = b"\x1f\x8b\x08\x04" + struct.pack("<I", 0) + b"\x02\x03" + struct.pack("<H", len(extra)) + extra
    tail = struct.pack("<II", zlib.crc32(data) & 0xffffffff, len(data) & 0xffffffff)
    return head + bytes(body) + tail


def main(src, dst):
    entries = {}                                   # word -> {pos: [(gloss, synonyms)]}
    for name, p in POS:
        data = synsets(os.path.join(src, "data." + name))
        for line in open(os.path.join(src, "index." + name), encoding="utf-8", errors="replace"):
            if line.startswith("  "):
                continue
            f = line.split()
            lemma, cnt, pcnt = f[0], int(f[2]), int(f[3])
            offsets = f[4 + pcnt + 2:4 + pcnt + 2 + cnt]
            word = lemma.replace("_", " ")
            senses = entries.setdefault(word, {}).setdefault(p, [])
            for o in offsets:
                words, gloss = data.get(o, ([], ""))
                syn = [w for w in words if w.lower() != word.lower()]
                senses.append((gloss, syn))
    os.makedirs(dst, exist_ok=True)
    words = sorted(entries, key=lambda w: (w.encode().lower(), w.encode()))
    index = {w: i for i, w in enumerate(words)}
    idx, dic, off = bytearray(), bytearray(), 0
    for w in words:
        lines = [w]
        for p in ("n", "v", "a", "r"):
            if p not in entries[w]:
                continue
            lines.append(" " + NAMES[p])
            for i, (gloss, syn) in enumerate(entries[w][p], 1):
                lines.append(f"  {i}. {gloss}")
                if syn:
                    lines.append("     = " + ", ".join(syn))
        body = "\n".join(lines).encode()
        dic += body
        idx += w.encode() + b"\0" + struct.pack(">II", off, len(body))
        off += len(body)
    # inflected forms: went -> go, children -> child
    syns = {}
    for name, p in POS:
        exc = os.path.join(src, f"{name}.exc")
        if not os.path.exists(exc):
            continue
        for line in open(exc, encoding="utf-8", errors="replace"):
            f = line.split()
            if len(f) >= 2:
                form = f[0].replace("_", " ")
                base = f[1].replace("_", " ")
                if base in index and form not in index:
                    syns.setdefault(form, index[base])
    syn = bytearray()
    for form in sorted(syns, key=lambda w: (w.encode().lower(), w.encode())):
        syn += form.encode() + b"\0" + struct.pack(">I", syns[form])
    for ext, data in (("idx", idx), ("syn", syn)):
        open(os.path.join(dst, "wordnet." + ext), "wb").write(data)
    # the text packed as dictzip (.dict.dz): a third of the size, and sdcv
    # still jumps straight to one word (on a live USB it all sits in RAM)
    open(os.path.join(dst, "wordnet.dict.dz"), "wb").write(dictzip(bytes(dic)))
    open(os.path.join(dst, "wordnet.ifo"), "w").write(
        "StarDict's dict ifo file\nversion=2.4.2\n"
        f"wordcount={len(words)}\nsynwordcount={len(syns)}\nidxfilesize={len(idx)}\n"
        "bookname=WordNet 3.0 (English)\nsametypesequence=m\n"
        "description=Princeton WordNet 3.0, wordnet.princeton.edu (WordNet License)\n")
    print(f"wordnet: {len(words)} words, {len(syns)} inflected forms, {len(dic) // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
WN2DICT
	rm -rf /tmp/wn && mkdir -p /tmp/wn
	if curl -fsSL --retry 3 -o /tmp/wn/wordnet.zip \
		https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip &&
	   unzip -q /tmp/wn/wordnet.zip -d /tmp/wn &&
	   python3 /tmp/wn2dict /tmp/wn/wordnet "$STAGE/usr/share/stardict/dic/wordnet"; then
		install -Dm644 /tmp/wn/wordnet/LICENSE "$STAGE/usr/share/stardict/dic/wordnet/LICENSE"
	else
		echo "!! WordNet dictionary not made: dic and Alt+D find nothing" >&2
	fi
	rm -rf /tmp/wn /tmp/wn2dict

	FONTDIR="$STAGE/usr/share/fonts/hangul-bitmap"
	mkdir -p "$FONTDIR"
	warn() { echo "!! $*" >&2; }

	echo ">> Korean bitmap fonts (MIT, github.com/hurss/fonts)"
	git clone --depth 1 https://github.com/hurss/fonts hurss-fonts
	for _f in MiraeroNormal-24 DOSMyungjo-16 DOSGothic-16 DOSSaemmul-16 Sam3KRFont-16; do
		install -Dm644 "hurss-fonts/bdf/$_f.bdf" "$FONTDIR/$_f.bdf"
	done
	# Unicode-encoded but labelled "Johab", which hides them from fontconfig:
	# relabel the header. DOSIyagi is a Reserved Font Name, so the modified
	# copy gets a new family name (IyagiBoldU); DOSPilgi is not reserved.
	sed -e 's/^CHARSET_REGISTRY "Johab"/CHARSET_REGISTRY "ISO10646"/' \
	    -e '/^FONT /s/-Johab-1$/-ISO10646-1/' \
	    -e '/^FONT /s/-DOSIyagiBoldface-/-IyagiBoldU-/' \
	    -e 's/^FAMILY_NAME "DOSIyagiBoldface"/FAMILY_NAME "IyagiBoldU"/' \
		hurss-fonts/bdf/DOSIyagiBoldface-16.bdf > "$FONTDIR/IyagiBoldU-16.bdf"
	sed -e 's/^CHARSET_REGISTRY "Johab"/CHARSET_REGISTRY "ISO10646"/' \
	    -e '/^FONT /s/-Johab-1$/-ISO10646-1/' \
		hurss-fonts/bdf/DOSPilgi-16.bdf > "$FONTDIR/DOSPilgi-16.bdf"
	install -Dm644 hurss-fonts/LICENSE.txt "$FONTDIR/LICENSE-hurss-fonts.txt"

	echo ">> Galmuri Mono $GALMURI_TAG (SIL OFL, github.com/quiple/galmuri)"
	_g="https://raw.githubusercontent.com/quiple/galmuri/$GALMURI_TAG/dist"
	for _f in GalmuriMono9 GalmuriMono11; do
		curl -fsSL "$_g/$_f.bdf" -o "$FONTDIR/$_f.bdf" ||
			{ warn "skipping $_f"; rm -f "$FONTDIR/$_f.bdf"; }
	done
	curl -fsSL "$_g/LICENSE.txt" -o "$FONTDIR/LICENSE-galmuri.txt" || true

	echo ">> Neo Dunggeunmo Code (SIL OFL, github.com/neodgm/neodgm)"
	mkdir -p /home/build/neodgm
	if curl -fsSL "https://registry.npmjs.org/@kfonts/neodgm-code/-/neodgm-code-$NEODGM_NPM.tgz" |
		tar xz -C /home/build/neodgm package/src/neodgm_code.ttf; then
		install -Dm644 /home/build/neodgm/package/src/neodgm_code.ttf "$FONTDIR/neodgm_code.ttf"
		curl -fsSL "https://raw.githubusercontent.com/neodgm/neodgm/$NEODGM_TAG/LICENSE.txt" \
			-o "$FONTDIR/LICENSE-neodgm.txt" || true
	else
		warn "skipping Neo Dunggeunmo Code"
	fi

	echo ">> Mulmaru Mono $MULMARU_TAG (SIL OFL, github.com/mushsooni/mulmaru)"
	mkdir -p /home/build/mulmaru && cd /home/build/mulmaru
	_urls="$(curl -fsSL "https://api.github.com/repos/mushsooni/mulmaru/releases/tags/$MULMARU_TAG" |
		grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)" || _urls=""
	_ttf="$(echo "$_urls" | grep -i mono | grep -i '\.ttf$' | head -n1)"
	_zip="$(echo "$_urls" | grep -i '\.zip$' | head -n1)"
	if [ -n "$_ttf" ]; then
		curl -fsSL "$_ttf" -o MulmaruMono.ttf || true
	elif [ -n "$_zip" ]; then
		curl -fsSL "$_zip" -o mulmaru.zip && unzip -oq mulmaru.zip -d z &&
		find z -iname '*mono*.ttf' | head -n1 | xargs -r -I{} cp {} MulmaruMono.ttf
	fi
	if [ -s MulmaruMono.ttf ]; then
		install -Dm644 MulmaruMono.ttf "$FONTDIR/MulmaruMono.ttf"
		curl -fsSL "https://raw.githubusercontent.com/mushsooni/mulmaru/$MULMARU_TAG/LICENSE" \
			-o "$FONTDIR/LICENSE-mulmaru.txt" || true
	else
		warn "skipping Mulmaru Mono (no Mono TTF in release $MULMARU_TAG)"
	fi
	cd /home/build

	echo ">> font table for han (by size)"
	TABLE="$STAGE/usr/share/han/fonts"
	mkdir -p "${TABLE%/*}"
	: > "$TABLE"
	# a missing font file must not stop the build (set -e)
	_fam() { fc-scan --format '%{family[0]}' "$1" 2>/dev/null || true; }
	_add() { # name px file family label
		[ -s "$FONTDIR/$3" ] && printf '%s|%s|%s|%s\n' "$1" "$2" "$4" "$5" >> "$TABLE"
		return 0
	}
	_nd="$(_fam "$FONTDIR/neodgm_code.ttf")"
	_mm="$(_fam "$FONTDIR/MulmaruMono.ttf")"
	_add galmuri9  12 GalmuriMono9.bdf     GalmuriMono9      "Galmuri Mono 9, modern pixel style"
	_add mulmaru   12 MulmaruMono.ttf      "$_mm"            "Mulmaru Mono, bold and rounded"
	_add myungjo   16 DOSMyungjo-16.bdf    DOSMyungjo        "DOSMyungjo, serif (default)"
	_add gothic    16 DOSGothic-16.bdf     DOSGothic         "DOSGothic, sans serif"
	_add saemmul   16 DOSSaemmul-16.bdf    DOSSaemmul        "DOSSaemmul"
	_add iyagi     16 IyagiBoldU-16.bdf    IyagiBoldU        "Iyagi bold (DOSIyagiBoldface, relabelled)"
	_add pilgi     16 DOSPilgi-16.bdf      DOSPilgi          "DOSPilgi, handwriting style"
	_add sam3      16 Sam3KRFont-16.bdf    Sam3KRFont        "Sam3KRFont"
	_add galmuri   16 GalmuriMono11.bdf    GalmuriMono11     "Galmuri Mono 11, modern pixel style"
	_add neodgm    16 neodgm_code.ttf      "$_nd"            "Neo Dunggeunmo Code, classic DOS look"
	printf 'unifont|16|Unifont|GNU Unifont, plain and complete\n' >> "$TABLE"
	_add miraero   24 MiraeroNormal-24.bdf MiraeroNormal     "Miraero Normal"
	_add mulmaru24 24 MulmaruMono.ttf      "$_mm"            "Mulmaru Mono at twice its size"
	_add neodgm32  32 neodgm_code.ttf      "$_nd"            "Neo Dunggeunmo Code at twice its size"
	cat "$TABLE"

	echo ">> Nanum fonts for the NetSurf browser (SIL OFL, Naver)"
	_nf="https://raw.githubusercontent.com/google/fonts/main/ofl"
	_nd="$STAGE/usr/share/fonts/nanum"
	mkdir -p "$_nd"
	for _f in nanumgothic/NanumGothic-Regular.ttf nanumgothic/NanumGothic-Bold.ttf \
		nanumgothiccoding/NanumGothicCoding-Regular.ttf; do
		curl -fsSL "$_nf/$_f" -o "$_nd/${_f##*/}" || warn "missing ${_f##*/}"
	done
	curl -fsSL "$_nf/nanumgothic/OFL.txt" -o "$_nd/LICENSE-nanum.txt" || true

	# Serif English letters, as options (han keeps Terminus by default):
	# HAN_LATIN="Courier Bitmap" han  (or LATIN= in /etc/han.conf).
	# Courier Bitmap: Adobe's 9x15 Courier from X11 (75dpi, 14 pt), renamed so
	# that fontconfig always picks exactly this one; fits the 16-pixel Korean fonts.
	echo ">> serif fonts for English letters (options)"
	_sd="$STAGE/usr/share/fonts/serif-mono"
	mkdir -p "$_sd"
	cat > "$_sd/CourierBitmap-Medium-15.bdf" <<'COURIERR'
STARTFONT 2.1
FONT -Adobe-Courier Bitmap-Medium-R-Normal--15-140-75-75-M-90-ISO10646-1
SIZE 14 75 75
FONTBOUNDINGBOX 9 15 0 -3
STARTPROPERTIES 10
FOUNDRY "Adobe"
FAMILY_NAME "Courier Bitmap"
WEIGHT_NAME "Medium"
PIXEL_SIZE 15
FONT_ASCENT 12
FONT_DESCENT 3
SPACING "M"
COPYRIGHT "Copyright (c) 1984, 1987 Adobe Systems Incorporated. All Rights Reserved. Copyright (c) 1988, 1991 Digital Equipment Corporation. All Rights Reserved."
CHARSET_REGISTRY "ISO10646"
CHARSET_ENCODING "1"
ENDPROPERTIES
CHARS 192
STARTCHAR U+0000
ENCODING 0
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 0 0
BITMAP
AA
00
82
00
82
00
82
00
AA
ENDCHAR
STARTCHAR U+0020
ENCODING 32
SWIDTH 600 0
DWIDTH 9 0
BBX 1 1 0 0
BITMAP
00
ENDCHAR
STARTCHAR U+0021
ENCODING 33
SWIDTH 600 0
DWIDTH 9 0
BBX 1 10 3 0
BITMAP
80
80
80
80
80
80
80
00
00
80
ENDCHAR
STARTCHAR U+0022
ENCODING 34
SWIDTH 600 0
DWIDTH 9 0
BBX 4 4 2 5
BITMAP
90
90
90
90
ENDCHAR
STARTCHAR U+0023
ENCODING 35
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 2 0
BITMAP
50
50
50
F8
50
F8
50
50
50
ENDCHAR
STARTCHAR U+0024
ENCODING 36
SWIDTH 600 0
DWIDTH 9 0
BBX 5 13 2 -2
BITMAP
20
20
78
88
80
C0
30
08
88
F0
20
20
20
ENDCHAR
STARTCHAR U+0025
ENCODING 37
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
60
90
90
66
18
30
CC
12
12
0C
ENDCHAR
STARTCHAR U+0026
ENCODING 38
SWIDTH 600 0
DWIDTH 9 0
BBX 6 8 1 0
BITMAP
38
48
40
40
A8
90
98
64
ENDCHAR
STARTCHAR U+0027
ENCODING 39
SWIDTH 600 0
DWIDTH 9 0
BBX 1 4 3 5
BITMAP
80
80
80
80
ENDCHAR
STARTCHAR U+0028
ENCODING 40
SWIDTH 600 0
DWIDTH 9 0
BBX 3 12 3 -2
BITMAP
20
40
40
80
80
80
80
80
80
40
40
20
ENDCHAR
STARTCHAR U+0029
ENCODING 41
SWIDTH 600 0
DWIDTH 9 0
BBX 3 12 2 -2
BITMAP
80
40
40
20
20
20
20
20
20
40
40
80
ENDCHAR
STARTCHAR U+002A
ENCODING 42
SWIDTH 600 0
DWIDTH 9 0
BBX 5 6 1 3
BITMAP
20
20
F8
20
50
88
ENDCHAR
STARTCHAR U+002B
ENCODING 43
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
10
10
10
FE
10
10
10
ENDCHAR
STARTCHAR U+002C
ENCODING 44
SWIDTH 600 0
DWIDTH 9 0
BBX 3 4 2 -2
BITMAP
60
60
C0
80
ENDCHAR
STARTCHAR U+002D
ENCODING 45
SWIDTH 600 0
DWIDTH 9 0
BBX 6 1 1 4
BITMAP
FC
ENDCHAR
STARTCHAR U+002E
ENCODING 46
SWIDTH 600 0
DWIDTH 9 0
BBX 2 2 3 0
BITMAP
C0
C0
ENDCHAR
STARTCHAR U+002F
ENCODING 47
SWIDTH 600 0
DWIDTH 9 0
BBX 6 11 1 -1
BITMAP
04
08
08
10
10
20
20
40
40
80
80
ENDCHAR
STARTCHAR U+0030
ENCODING 48
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
84
84
84
84
84
84
84
84
78
ENDCHAR
STARTCHAR U+0031
ENCODING 49
SWIDTH 600 0
DWIDTH 9 0
BBX 5 10 1 0
BITMAP
20
60
A0
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+0032
ENCODING 50
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
84
84
04
08
10
20
40
84
FC
ENDCHAR
STARTCHAR U+0033
ENCODING 51
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
84
04
04
38
04
04
04
84
78
ENDCHAR
STARTCHAR U+0034
ENCODING 52
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
18
28
28
48
48
88
88
FC
08
1C
ENDCHAR
STARTCHAR U+0035
ENCODING 53
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
7C
40
40
40
78
04
04
04
84
78
ENDCHAR
STARTCHAR U+0036
ENCODING 54
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
38
40
80
80
B8
C4
84
84
44
38
ENDCHAR
STARTCHAR U+0037
ENCODING 55
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
FC
84
04
08
08
08
10
10
10
10
ENDCHAR
STARTCHAR U+0038
ENCODING 56
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
84
84
84
78
84
84
84
84
78
ENDCHAR
STARTCHAR U+0039
ENCODING 57
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
70
88
84
84
8C
74
04
04
08
70
ENDCHAR
STARTCHAR U+003A
ENCODING 58
SWIDTH 600 0
DWIDTH 9 0
BBX 2 7 3 0
BITMAP
C0
C0
00
00
00
C0
C0
ENDCHAR
STARTCHAR U+003B
ENCODING 59
SWIDTH 600 0
DWIDTH 9 0
BBX 3 9 2 -2
BITMAP
60
60
00
00
00
60
60
C0
80
ENDCHAR
STARTCHAR U+003C
ENCODING 60
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
06
18
60
80
60
18
06
ENDCHAR
STARTCHAR U+003D
ENCODING 61
SWIDTH 600 0
DWIDTH 9 0
BBX 7 3 1 3
BITMAP
FE
00
FE
ENDCHAR
STARTCHAR U+003E
ENCODING 62
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
C0
30
0C
02
0C
30
C0
ENDCHAR
STARTCHAR U+003F
ENCODING 63
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 1 0
BITMAP
70
88
88
08
10
20
20
00
20
ENDCHAR
STARTCHAR U+0040
ENCODING 64
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 -1
BITMAP
38
44
84
9C
A4
A4
9E
80
40
38
ENDCHAR
STARTCHAR U+0041
ENCODING 65
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+0042
ENCODING 66
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
FC
42
42
42
7C
42
42
42
FC
ENDCHAR
STARTCHAR U+0043
ENCODING 67
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
3A
46
82
80
80
80
80
42
3C
ENDCHAR
STARTCHAR U+0044
ENCODING 68
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FC
42
41
41
41
41
41
42
FC
ENDCHAR
STARTCHAR U+0045
ENCODING 69
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
FE
42
42
48
78
48
42
42
FE
ENDCHAR
STARTCHAR U+0046
ENCODING 70
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
FE
42
42
48
78
48
40
40
F0
ENDCHAR
STARTCHAR U+0047
ENCODING 71
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
3A
46
82
80
80
8F
82
42
3C
ENDCHAR
STARTCHAR U+0048
ENCODING 72
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
E7
42
42
42
7E
42
42
42
E7
ENDCHAR
STARTCHAR U+0049
ENCODING 73
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 2 0
BITMAP
F8
20
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+004A
ENCODING 74
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
3E
08
08
08
08
88
88
88
70
ENDCHAR
STARTCHAR U+004B
ENCODING 75
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
EE
44
48
50
70
48
44
44
E3
ENDCHAR
STARTCHAR U+004C
ENCODING 76
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
F8
20
20
20
20
21
21
21
FF
ENDCHAR
STARTCHAR U+004D
ENCODING 77
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
E380
6300
5700
5500
4900
4900
4100
4100
E380
ENDCHAR
STARTCHAR U+004E
ENCODING 78
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
E7
62
52
52
4A
4A
46
46
E2
ENDCHAR
STARTCHAR U+004F
ENCODING 79
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
3C
42
81
81
81
81
81
42
3C
ENDCHAR
STARTCHAR U+0050
ENCODING 80
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
FC
42
42
42
42
7C
40
40
F0
ENDCHAR
STARTCHAR U+0051
ENCODING 81
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 -2
BITMAP
3C
42
81
81
81
81
81
42
3C
31
5E
ENDCHAR
STARTCHAR U+0052
ENCODING 82
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FC
42
42
42
44
78
44
42
E1
ENDCHAR
STARTCHAR U+0053
ENCODING 83
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 1 0
BITMAP
74
8C
84
80
78
04
84
C4
B8
ENDCHAR
STARTCHAR U+0054
ENCODING 84
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
FE
92
92
10
10
10
10
10
7C
ENDCHAR
STARTCHAR U+0055
ENCODING 85
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
E7
42
42
42
42
42
42
42
3C
ENDCHAR
STARTCHAR U+0056
ENCODING 86
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
E380
4100
4100
2200
2200
1400
1400
0800
0800
ENDCHAR
STARTCHAR U+0057
ENCODING 87
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
E380
4100
4900
4900
5500
5500
2200
2200
2200
ENDCHAR
STARTCHAR U+0058
ENCODING 88
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
E7
42
24
24
18
24
24
42
E7
ENDCHAR
STARTCHAR U+0059
ENCODING 89
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
EE
44
44
28
28
10
10
10
7C
ENDCHAR
STARTCHAR U+005A
ENCODING 90
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 1 0
BITMAP
FC
84
88
10
20
20
44
84
FC
ENDCHAR
STARTCHAR U+005B
ENCODING 91
SWIDTH 600 0
DWIDTH 9 0
BBX 3 12 3 -2
BITMAP
E0
80
80
80
80
80
80
80
80
80
80
E0
ENDCHAR
STARTCHAR U+005C
ENCODING 92
SWIDTH 600 0
DWIDTH 9 0
BBX 6 11 1 -1
BITMAP
80
40
40
20
20
10
10
08
08
04
04
ENDCHAR
STARTCHAR U+005D
ENCODING 93
SWIDTH 600 0
DWIDTH 9 0
BBX 3 12 2 -2
BITMAP
E0
20
20
20
20
20
20
20
20
20
20
E0
ENDCHAR
STARTCHAR U+005E
ENCODING 94
SWIDTH 600 0
DWIDTH 9 0
BBX 5 5 2 4
BITMAP
20
50
50
88
88
ENDCHAR
STARTCHAR U+005F
ENCODING 95
SWIDTH 600 0
DWIDTH 9 0
BBX 9 1 0 -3
BITMAP
FF80
ENDCHAR
STARTCHAR U+0060
ENCODING 96
SWIDTH 600 0
DWIDTH 9 0
BBX 4 2 2 8
BITMAP
C0
30
ENDCHAR
STARTCHAR U+0061
ENCODING 97
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+0062
ENCODING 98
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
C0
40
40
5C
62
41
41
41
62
DC
ENDCHAR
STARTCHAR U+0063
ENCODING 99
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
3A
46
82
80
80
42
3C
ENDCHAR
STARTCHAR U+0064
ENCODING 100
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
06
02
02
3A
46
82
82
82
46
3B
ENDCHAR
STARTCHAR U+0065
ENCODING 101
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
38
44
82
FE
80
42
3C
ENDCHAR
STARTCHAR U+0066
ENCODING 102
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
1E
20
20
FC
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+0067
ENCODING 103
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 -3
BITMAP
3B
46
82
82
82
46
3A
02
04
78
ENDCHAR
STARTCHAR U+0068
ENCODING 104
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
C0
40
40
5C
62
42
42
42
42
E7
ENDCHAR
STARTCHAR U+0069
ENCODING 105
SWIDTH 600 0
DWIDTH 9 0
BBX 5 10 2 0
BITMAP
20
20
00
E0
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+006A
ENCODING 106
SWIDTH 600 0
DWIDTH 9 0
BBX 5 13 1 -3
BITMAP
10
10
00
F8
08
08
08
08
08
08
08
10
E0
ENDCHAR
STARTCHAR U+006B
ENCODING 107
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
C0
40
4E
48
50
60
50
48
CE
ENDCHAR
STARTCHAR U+006C
ENCODING 108
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 2 0
BITMAP
E0
20
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+006D
ENCODING 109
SWIDTH 600 0
DWIDTH 9 0
BBX 9 7 0 0
BITMAP
DB00
6D00
4900
4900
4900
4900
ED80
ENDCHAR
STARTCHAR U+006E
ENCODING 110
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
DC
62
42
42
42
42
E7
ENDCHAR
STARTCHAR U+006F
ENCODING 111
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
3C
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+0070
ENCODING 112
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 -3
BITMAP
DC
62
41
41
41
62
5C
40
40
F0
ENDCHAR
STARTCHAR U+0071
ENCODING 113
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 -3
BITMAP
3B
46
82
82
82
46
3A
02
02
0F
ENDCHAR
STARTCHAR U+0072
ENCODING 114
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
CC
52
60
40
40
40
F0
ENDCHAR
STARTCHAR U+0073
ENCODING 115
SWIDTH 600 0
DWIDTH 9 0
BBX 6 7 1 0
BITMAP
7C
84
80
78
04
84
F8
ENDCHAR
STARTCHAR U+0074
ENCODING 116
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 1 0
BITMAP
40
40
F8
40
40
40
40
44
38
ENDCHAR
STARTCHAR U+0075
ENCODING 117
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
C6
42
42
42
42
46
3B
ENDCHAR
STARTCHAR U+0076
ENCODING 118
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
E7
42
42
24
24
18
18
ENDCHAR
STARTCHAR U+0077
ENCODING 119
SWIDTH 600 0
DWIDTH 9 0
BBX 9 7 0 0
BITMAP
E380
4100
4900
4900
2A00
3600
3600
ENDCHAR
STARTCHAR U+0078
ENCODING 120
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
EE
44
28
10
28
44
EE
ENDCHAR
STARTCHAR U+0079
ENCODING 121
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 -3
BITMAP
E7
42
42
24
24
18
08
10
10
78
ENDCHAR
STARTCHAR U+007A
ENCODING 122
SWIDTH 600 0
DWIDTH 9 0
BBX 5 7 1 0
BITMAP
F8
88
10
20
40
88
F8
ENDCHAR
STARTCHAR U+007B
ENCODING 123
SWIDTH 600 0
DWIDTH 9 0
BBX 3 12 3 -2
BITMAP
20
40
40
40
40
80
40
40
40
40
40
20
ENDCHAR
STARTCHAR U+007C
ENCODING 124
SWIDTH 600 0
DWIDTH 9 0
BBX 1 11 4 -2
BITMAP
80
80
80
80
80
80
80
80
80
80
80
ENDCHAR
STARTCHAR U+007D
ENCODING 125
SWIDTH 600 0
DWIDTH 9 0
BBX 3 12 2 -2
BITMAP
80
40
40
40
40
20
40
40
40
40
40
80
ENDCHAR
STARTCHAR U+007E
ENCODING 126
SWIDTH 600 0
DWIDTH 9 0
BBX 6 2 1 3
BITMAP
64
98
ENDCHAR
STARTCHAR U+00A0
ENCODING 160
SWIDTH 600 0
DWIDTH 9 0
BBX 1 1 0 0
BITMAP
00
ENDCHAR
STARTCHAR U+00A1
ENCODING 161
SWIDTH 600 0
DWIDTH 9 0
BBX 1 9 4 -2
BITMAP
80
00
00
80
80
80
80
80
80
ENDCHAR
STARTCHAR U+00A2
ENCODING 162
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 2 0
BITMAP
20
20
78
88
80
88
70
20
20
ENDCHAR
STARTCHAR U+00A3
ENCODING 163
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
18
24
20
20
78
20
20
42
FC
ENDCHAR
STARTCHAR U+00A4
ENCODING 164
SWIDTH 600 0
DWIDTH 9 0
BBX 6 6 1 1
BITMAP
B4
48
84
84
48
B4
ENDCHAR
STARTCHAR U+00A5
ENCODING 165
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
EE
44
44
28
7C
10
7C
10
38
ENDCHAR
STARTCHAR U+00A6
ENCODING 166
SWIDTH 600 0
DWIDTH 9 0
BBX 1 11 4 -2
BITMAP
80
80
80
80
80
00
80
80
80
80
80
ENDCHAR
STARTCHAR U+00A7
ENCODING 167
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 -1
BITMAP
3C
44
40
F0
88
44
3C
08
88
F0
ENDCHAR
STARTCHAR U+00A8
ENCODING 168
SWIDTH 600 0
DWIDTH 9 0
BBX 5 1 2 8
BITMAP
D8
ENDCHAR
STARTCHAR U+00A9
ENCODING 169
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
3C
42
99
A5
A1
A5
99
42
3C
ENDCHAR
STARTCHAR U+00AA
ENCODING 170
SWIDTH 600 0
DWIDTH 9 0
BBX 4 6 2 3
BITMAP
C0
20
E0
B0
00
F0
ENDCHAR
STARTCHAR U+00AB
ENCODING 171
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
11
22
44
CC
44
22
11
ENDCHAR
STARTCHAR U+00AC
ENCODING 172
SWIDTH 600 0
DWIDTH 9 0
BBX 7 3 1 3
BITMAP
FE
02
02
ENDCHAR
STARTCHAR U+00AD
ENCODING 173
SWIDTH 600 0
DWIDTH 9 0
BBX 6 1 1 4
BITMAP
FC
ENDCHAR
STARTCHAR U+00AE
ENCODING 174
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
3C
42
B9
A5
B9
A9
A5
42
3C
ENDCHAR
STARTCHAR U+00AF
ENCODING 175
SWIDTH 600 0
DWIDTH 9 0
BBX 4 1 2 7
BITMAP
F0
ENDCHAR
STARTCHAR U+00B0
ENCODING 176
SWIDTH 600 0
DWIDTH 9 0
BBX 4 4 2 6
BITMAP
60
90
90
60
ENDCHAR
STARTCHAR U+00B1
ENCODING 177
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
10
10
FE
10
10
00
FE
ENDCHAR
STARTCHAR U+00B2
ENCODING 178
SWIDTH 600 0
DWIDTH 9 0
BBX 4 6 2 4
BITMAP
60
90
10
20
40
F0
ENDCHAR
STARTCHAR U+00B3
ENCODING 179
SWIDTH 600 0
DWIDTH 9 0
BBX 4 6 2 4
BITMAP
E0
10
60
10
90
60
ENDCHAR
STARTCHAR U+00B4
ENCODING 180
SWIDTH 600 0
DWIDTH 9 0
BBX 4 2 2 8
BITMAP
30
C0
ENDCHAR
STARTCHAR U+00B5
ENCODING 181
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 -3
BITMAP
C6
42
42
42
42
46
7B
40
40
40
ENDCHAR
STARTCHAR U+00B6
ENCODING 182
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 -1
BITMAP
7E
94
94
94
74
14
14
14
14
36
ENDCHAR
STARTCHAR U+00B7
ENCODING 183
SWIDTH 600 0
DWIDTH 9 0
BBX 2 2 3 3
BITMAP
C0
C0
ENDCHAR
STARTCHAR U+00B8
ENCODING 184
SWIDTH 600 0
DWIDTH 9 0
BBX 3 3 2 -3
BITMAP
40
20
E0
ENDCHAR
STARTCHAR U+00B9
ENCODING 185
SWIDTH 600 0
DWIDTH 9 0
BBX 3 6 3 4
BITMAP
40
C0
40
40
40
E0
ENDCHAR
STARTCHAR U+00BA
ENCODING 186
SWIDTH 600 0
DWIDTH 9 0
BBX 4 6 2 3
BITMAP
60
90
90
60
00
F0
ENDCHAR
STARTCHAR U+00BB
ENCODING 187
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
88
44
22
33
22
44
88
ENDCHAR
STARTCHAR U+00BC
ENCODING 188
SWIDTH 600 0
DWIDTH 9 0
BBX 10 11 -1 -1
BITMAP
4000
C100
4200
4400
4400
E880
1180
1280
2480
47C0
0080
ENDCHAR
STARTCHAR U+00BD
ENCODING 189
SWIDTH 600 0
DWIDTH 9 0
BBX 10 11 -1 -1
BITMAP
4000
C100
4200
4400
4400
E980
1240
1040
2080
4100
03C0
ENDCHAR
STARTCHAR U+00BE
ENCODING 190
SWIDTH 600 0
DWIDTH 9 0
BBX 10 11 -1 -1
BITMAP
E000
1080
6100
1200
9200
6480
0980
0A80
1480
27C0
0080
ENDCHAR
STARTCHAR U+00BF
ENCODING 191
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 2 -2
BITMAP
20
00
00
20
60
80
80
88
70
ENDCHAR
STARTCHAR U+00C0
ENCODING 192
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
6000
1800
0000
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+00C1
ENCODING 193
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
0600
1800
0000
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+00C2
ENCODING 194
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
0800
1400
0000
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+00C3
ENCODING 195
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1A00
2C00
0000
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+00C4
ENCODING 196
SWIDTH 600 0
DWIDTH 9 0
BBX 9 11 0 0
BITMAP
3600
0000
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+00C5
ENCODING 197
SWIDTH 600 0
DWIDTH 9 0
BBX 9 13 0 0
BITMAP
1800
2400
1800
0000
3800
0800
1400
1400
2200
3E00
4100
4100
F780
ENDCHAR
STARTCHAR U+00C6
ENCODING 198
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 -1 0
BITMAP
1F80
0C80
1400
1480
2780
3C80
4400
4480
EF80
ENDCHAR
STARTCHAR U+00C7
ENCODING 199
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 1 -3
BITMAP
3A
46
82
80
80
80
80
42
3C
10
08
38
ENDCHAR
STARTCHAR U+00C8
ENCODING 200
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 1 0
BITMAP
60
18
00
FE
42
48
48
78
48
42
42
FE
ENDCHAR
STARTCHAR U+00C9
ENCODING 201
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 1 0
BITMAP
06
18
00
FE
42
48
48
78
48
42
42
FE
ENDCHAR
STARTCHAR U+00CA
ENCODING 202
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 1 0
BITMAP
10
28
00
FE
42
48
48
78
48
42
42
FE
ENDCHAR
STARTCHAR U+00CB
ENCODING 203
SWIDTH 600 0
DWIDTH 9 0
BBX 7 11 1 0
BITMAP
6C
00
FE
42
48
48
78
48
42
42
FE
ENDCHAR
STARTCHAR U+00CC
ENCODING 204
SWIDTH 600 0
DWIDTH 9 0
BBX 5 12 2 0
BITMAP
C0
30
00
F8
20
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00CD
ENCODING 205
SWIDTH 600 0
DWIDTH 9 0
BBX 5 12 2 0
BITMAP
18
60
00
F8
20
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00CE
ENCODING 206
SWIDTH 600 0
DWIDTH 9 0
BBX 5 12 2 0
BITMAP
20
50
00
F8
20
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00CF
ENCODING 207
SWIDTH 600 0
DWIDTH 9 0
BBX 5 11 2 0
BITMAP
D8
00
F8
20
20
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00D0
ENCODING 208
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FC
42
41
41
F1
41
41
42
FC
ENDCHAR
STARTCHAR U+00D1
ENCODING 209
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
1A
2C
00
E7
62
52
52
4A
4A
46
46
E2
ENDCHAR
STARTCHAR U+00D2
ENCODING 210
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
60
18
00
3C
42
81
81
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00D3
ENCODING 211
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
06
18
00
3C
42
81
81
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00D4
ENCODING 212
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
18
24
00
3C
42
81
81
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00D5
ENCODING 213
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
1A
2C
00
3C
42
81
81
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00D6
ENCODING 214
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
36
00
3C
42
81
81
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00D7
ENCODING 215
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
82
44
28
10
28
44
82
ENDCHAR
STARTCHAR U+00D8
ENCODING 216
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 -1 0
BITMAP
1E80
2100
4280
4480
4880
5080
6080
6100
9E00
ENDCHAR
STARTCHAR U+00D9
ENCODING 217
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
60
18
00
E7
42
42
42
42
42
42
42
3C
ENDCHAR
STARTCHAR U+00DA
ENCODING 218
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
06
18
00
E7
42
42
42
42
42
42
42
3C
ENDCHAR
STARTCHAR U+00DB
ENCODING 219
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
18
24
00
E7
42
42
42
42
42
42
42
3C
ENDCHAR
STARTCHAR U+00DC
ENCODING 220
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
66
00
E7
42
42
42
42
42
42
42
3C
ENDCHAR
STARTCHAR U+00DD
ENCODING 221
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 1 0
BITMAP
0C
30
00
EE
44
44
28
28
10
10
10
7C
ENDCHAR
STARTCHAR U+00DE
ENCODING 222
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
E0
40
7C
42
42
42
7C
40
E0
ENDCHAR
STARTCHAR U+00DF
ENCODING 223
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
38
44
44
44
58
44
42
42
52
CC
ENDCHAR
STARTCHAR U+00E0
ENCODING 224
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
60
18
00
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+00E1
ENCODING 225
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
18
60
00
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+00E2
ENCODING 226
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
10
28
00
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+00E3
ENCODING 227
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
34
58
00
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+00E4
ENCODING 228
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
6C
00
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+00E5
ENCODING 229
SWIDTH 600 0
DWIDTH 9 0
BBX 7 11 1 0
BITMAP
30
48
30
00
78
84
04
7C
84
8C
76
ENDCHAR
STARTCHAR U+00E6
ENCODING 230
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
76
99
11
7F
88
99
6E
ENDCHAR
STARTCHAR U+00E7
ENCODING 231
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 -3
BITMAP
3A
46
82
80
80
42
3C
10
08
38
ENDCHAR
STARTCHAR U+00E8
ENCODING 232
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
60
18
00
38
44
82
FE
80
42
3C
ENDCHAR
STARTCHAR U+00E9
ENCODING 233
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
0C
30
00
38
44
82
FE
80
42
3C
ENDCHAR
STARTCHAR U+00EA
ENCODING 234
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
10
28
00
38
44
82
FE
80
42
3C
ENDCHAR
STARTCHAR U+00EB
ENCODING 235
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
6C
00
38
44
82
FE
80
42
3C
ENDCHAR
STARTCHAR U+00EC
ENCODING 236
SWIDTH 600 0
DWIDTH 9 0
BBX 5 10 2 0
BITMAP
C0
30
00
E0
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00ED
ENCODING 237
SWIDTH 600 0
DWIDTH 9 0
BBX 5 10 2 0
BITMAP
30
C0
00
E0
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00EE
ENCODING 238
SWIDTH 600 0
DWIDTH 9 0
BBX 5 10 2 0
BITMAP
20
50
00
E0
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00EF
ENCODING 239
SWIDTH 600 0
DWIDTH 9 0
BBX 5 9 2 0
BITMAP
D8
00
E0
20
20
20
20
20
F8
ENDCHAR
STARTCHAR U+00F0
ENCODING 240
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
66
18
68
04
3E
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00F1
ENCODING 241
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
1A
2C
00
DC
62
42
42
42
42
E7
ENDCHAR
STARTCHAR U+00F2
ENCODING 242
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
30
0C
00
3C
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00F3
ENCODING 243
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
0C
30
00
3C
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00F4
ENCODING 244
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
10
28
00
3C
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00F5
ENCODING 245
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
1A
2C
00
3C
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00F6
ENCODING 246
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
66
00
3C
42
81
81
81
42
3C
ENDCHAR
STARTCHAR U+00F7
ENCODING 247
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 1
BITMAP
18
18
00
FF
00
18
18
ENDCHAR
STARTCHAR U+00F8
ENCODING 248
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
3D
46
89
91
A1
42
BC
ENDCHAR
STARTCHAR U+00F9
ENCODING 249
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
30
0C
00
C6
42
42
42
42
46
3B
ENDCHAR
STARTCHAR U+00FA
ENCODING 250
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
0C
30
00
C6
42
42
42
42
46
3B
ENDCHAR
STARTCHAR U+00FB
ENCODING 251
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
10
28
00
C6
42
42
42
42
46
3B
ENDCHAR
STARTCHAR U+00FC
ENCODING 252
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
6C
00
C6
42
42
42
42
46
3B
ENDCHAR
STARTCHAR U+00FD
ENCODING 253
SWIDTH 600 0
DWIDTH 9 0
BBX 8 13 0 -3
BITMAP
06
18
00
E7
42
42
24
24
18
08
10
10
78
ENDCHAR
STARTCHAR U+00FE
ENCODING 254
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 -3
BITMAP
C0
40
5C
62
41
41
41
62
5C
40
40
F0
ENDCHAR
STARTCHAR U+00FF
ENCODING 255
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 -3
BITMAP
36
00
E7
42
42
24
24
18
08
10
10
78
ENDCHAR
ENDFONT
COURIERR
	cat > "$_sd/CourierBitmap-Bold-15.bdf" <<'COURIERB'
STARTFONT 2.1
FONT -Adobe-Courier Bitmap-Bold-R-Normal--15-140-75-75-M-90-ISO10646-1
SIZE 14 75 75
FONTBOUNDINGBOX 9 15 0 -3
STARTPROPERTIES 10
FOUNDRY "Adobe"
FAMILY_NAME "Courier Bitmap"
WEIGHT_NAME "Bold"
PIXEL_SIZE 15
FONT_ASCENT 12
FONT_DESCENT 3
SPACING "M"
COPYRIGHT "Copyright (c) 1984, 1987 Adobe Systems Incorporated. All Rights Reserved. Copyright (c) 1988, 1991 Digital Equipment Corporation. All Rights Reserved."
CHARSET_REGISTRY "ISO10646"
CHARSET_ENCODING "1"
ENDPROPERTIES
CHARS 192
STARTCHAR U+0000
ENCODING 0
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
AA80
0000
8080
0000
8080
0000
8080
0000
AA80
ENDCHAR
STARTCHAR U+0020
ENCODING 32
SWIDTH 600 0
DWIDTH 9 0
BBX 1 1 0 0
BITMAP
00
ENDCHAR
STARTCHAR U+0021
ENCODING 33
SWIDTH 600 0
DWIDTH 9 0
BBX 2 10 3 0
BITMAP
C0
C0
C0
C0
C0
C0
80
00
C0
C0
ENDCHAR
STARTCHAR U+0022
ENCODING 34
SWIDTH 600 0
DWIDTH 9 0
BBX 5 4 2 5
BITMAP
D8
D8
D8
48
ENDCHAR
STARTCHAR U+0023
ENCODING 35
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 0 0
BITMAP
28
28
FE
28
28
FE
28
28
28
ENDCHAR
STARTCHAR U+0024
ENCODING 36
SWIDTH 600 0
DWIDTH 9 0
BBX 6 12 1 -1
BITMAP
30
30
7C
CC
C0
70
38
0C
CC
F8
30
30
ENDCHAR
STARTCHAR U+0025
ENCODING 37
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
60
90
90
60
0C
30
CC
12
12
0C
ENDCHAR
STARTCHAR U+0026
ENCODING 38
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 1 0
BITMAP
3C
6C
60
30
3A
6E
CC
DE
73
ENDCHAR
STARTCHAR U+0027
ENCODING 39
SWIDTH 600 0
DWIDTH 9 0
BBX 2 4 3 5
BITMAP
C0
C0
C0
40
ENDCHAR
STARTCHAR U+0028
ENCODING 40
SWIDTH 600 0
DWIDTH 9 0
BBX 4 12 3 -2
BITMAP
30
60
60
C0
C0
C0
C0
C0
C0
60
60
30
ENDCHAR
STARTCHAR U+0029
ENCODING 41
SWIDTH 600 0
DWIDTH 9 0
BBX 4 12 2 -2
BITMAP
C0
60
60
30
30
30
30
30
30
60
60
C0
ENDCHAR
STARTCHAR U+002A
ENCODING 42
SWIDTH 600 0
DWIDTH 9 0
BBX 5 5 2 4
BITMAP
20
A8
70
70
88
ENDCHAR
STARTCHAR U+002B
ENCODING 43
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
10
10
10
FE
10
10
10
ENDCHAR
STARTCHAR U+002C
ENCODING 44
SWIDTH 600 0
DWIDTH 9 0
BBX 3 4 2 -2
BITMAP
60
60
C0
80
ENDCHAR
STARTCHAR U+002D
ENCODING 45
SWIDTH 600 0
DWIDTH 9 0
BBX 6 1 1 4
BITMAP
FC
ENDCHAR
STARTCHAR U+002E
ENCODING 46
SWIDTH 600 0
DWIDTH 9 0
BBX 2 2 3 0
BITMAP
C0
C0
ENDCHAR
STARTCHAR U+002F
ENCODING 47
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 0 -2
BITMAP
06
06
0C
0C
18
18
30
30
60
60
C0
C0
ENDCHAR
STARTCHAR U+0030
ENCODING 48
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
38
6C
C6
C6
C6
C6
C6
C6
6C
38
ENDCHAR
STARTCHAR U+0031
ENCODING 49
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 2 0
BITMAP
30
F0
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+0032
ENCODING 50
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
CC
CC
0C
0C
18
30
60
C0
FC
ENDCHAR
STARTCHAR U+0033
ENCODING 51
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
CC
0C
0C
38
08
0C
0C
CC
78
ENDCHAR
STARTCHAR U+0034
ENCODING 52
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
0C
1C
3C
2C
6C
4C
CC
FE
0C
1E
ENDCHAR
STARTCHAR U+0035
ENCODING 53
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 2 0
BITMAP
FC
C0
C0
C0
F8
8C
0C
0C
CC
78
ENDCHAR
STARTCHAR U+0036
ENCODING 54
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 2 0
BITMAP
3C
60
C0
C0
D8
EC
CC
CC
CC
78
ENDCHAR
STARTCHAR U+0037
ENCODING 55
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
FC
8C
0C
18
18
18
18
30
30
30
ENDCHAR
STARTCHAR U+0038
ENCODING 56
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
CC
CC
CC
78
CC
CC
CC
CC
78
ENDCHAR
STARTCHAR U+0039
ENCODING 57
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
78
CC
CC
CC
CC
7C
0C
0C
18
F0
ENDCHAR
STARTCHAR U+003A
ENCODING 58
SWIDTH 600 0
DWIDTH 9 0
BBX 2 7 3 0
BITMAP
C0
C0
00
00
00
C0
C0
ENDCHAR
STARTCHAR U+003B
ENCODING 59
SWIDTH 600 0
DWIDTH 9 0
BBX 3 9 2 -2
BITMAP
60
60
00
00
00
60
60
C0
80
ENDCHAR
STARTCHAR U+003C
ENCODING 60
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 1
BITMAP
07
1C
70
C0
70
1C
07
ENDCHAR
STARTCHAR U+003D
ENCODING 61
SWIDTH 600 0
DWIDTH 9 0
BBX 7 4 1 2
BITMAP
FE
00
00
FE
ENDCHAR
STARTCHAR U+003E
ENCODING 62
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 1
BITMAP
E0
38
0E
03
0E
38
E0
ENDCHAR
STARTCHAR U+003F
ENCODING 63
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 2 0
BITMAP
F8
CC
8C
0C
38
30
00
30
30
ENDCHAR
STARTCHAR U+0040
ENCODING 64
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
78
C4
9C
B4
A4
B4
9E
C0
78
ENDCHAR
STARTCHAR U+0041
ENCODING 65
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+0042
ENCODING 66
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FE
63
63
63
7E
63
63
63
FE
ENDCHAR
STARTCHAR U+0043
ENCODING 67
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
3A
6E
C6
C0
C0
C0
C0
66
3C
ENDCHAR
STARTCHAR U+0044
ENCODING 68
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FC
66
63
63
63
63
63
66
FC
ENDCHAR
STARTCHAR U+0045
ENCODING 69
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FF
63
63
68
78
68
63
63
FF
ENDCHAR
STARTCHAR U+0046
ENCODING 70
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FF
63
63
68
78
68
60
60
F8
ENDCHAR
STARTCHAR U+0047
ENCODING 71
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
3D00
6700
C300
C000
C000
CF80
C300
6300
3F00
ENDCHAR
STARTCHAR U+0048
ENCODING 72
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
F780
6300
6300
6300
7F00
6300
6300
6300
F780
ENDCHAR
STARTCHAR U+0049
ENCODING 73
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 1 0
BITMAP
FC
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+004A
ENCODING 74
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
1F80
0600
0600
0600
0600
C600
C600
C600
7C00
ENDCHAR
STARTCHAR U+004B
ENCODING 75
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
F700
6600
6C00
7800
7C00
6600
6600
6300
F380
ENDCHAR
STARTCHAR U+004C
ENCODING 76
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
F8
60
60
60
60
63
63
63
FF
ENDCHAR
STARTCHAR U+004D
ENCODING 77
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
E380
6300
7700
7700
6B00
6B00
6300
6300
F780
ENDCHAR
STARTCHAR U+004E
ENCODING 78
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
E780
6300
7300
7300
6B00
6B00
6700
6700
F300
ENDCHAR
STARTCHAR U+004F
ENCODING 79
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
3C
66
C3
C3
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+0050
ENCODING 80
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FE
63
63
63
66
7C
60
60
F8
ENDCHAR
STARTCHAR U+0051
ENCODING 81
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 -2
BITMAP
3C
66
C3
C3
C3
C3
C3
66
3C
3D
6E
ENDCHAR
STARTCHAR U+0052
ENCODING 82
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
FE00
6300
6300
6300
6600
7C00
6600
6300
F380
ENDCHAR
STARTCHAR U+0053
ENCODING 83
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
7A
CE
C6
C0
7C
06
C6
E6
BC
ENDCHAR
STARTCHAR U+0054
ENCODING 84
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FF
DB
DB
18
18
18
18
18
3C
ENDCHAR
STARTCHAR U+0055
ENCODING 85
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
F780
6300
6300
6300
6300
6300
6300
6300
3E00
ENDCHAR
STARTCHAR U+0056
ENCODING 86
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
F780
6300
6300
6300
3600
3600
3600
1C00
1C00
ENDCHAR
STARTCHAR U+0057
ENCODING 87
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
F780
6300
6B00
6B00
6B00
7700
7700
6300
6300
ENDCHAR
STARTCHAR U+0058
ENCODING 88
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
E7
66
66
3C
18
3C
66
66
E7
ENDCHAR
STARTCHAR U+0059
ENCODING 89
SWIDTH 600 0
DWIDTH 9 0
BBX 10 9 -1 0
BITMAP
F3C0
6180
3300
3300
1E00
0C00
0C00
0C00
3F00
ENDCHAR
STARTCHAR U+005A
ENCODING 90
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
FE
C6
CC
18
18
30
66
C6
FE
ENDCHAR
STARTCHAR U+005B
ENCODING 91
SWIDTH 600 0
DWIDTH 9 0
BBX 4 12 3 -2
BITMAP
F0
C0
C0
C0
C0
C0
C0
C0
C0
C0
C0
F0
ENDCHAR
STARTCHAR U+005C
ENCODING 92
SWIDTH 600 0
DWIDTH 9 0
BBX 7 12 1 -2
BITMAP
C0
C0
60
60
30
30
18
18
0C
0C
06
06
ENDCHAR
STARTCHAR U+005D
ENCODING 93
SWIDTH 600 0
DWIDTH 9 0
BBX 4 12 2 -2
BITMAP
F0
30
30
30
30
30
30
30
30
30
30
F0
ENDCHAR
STARTCHAR U+005E
ENCODING 94
SWIDTH 600 0
DWIDTH 9 0
BBX 5 4 2 5
BITMAP
20
70
D8
88
ENDCHAR
STARTCHAR U+005F
ENCODING 95
SWIDTH 600 0
DWIDTH 9 0
BBX 9 1 0 -2
BITMAP
FF80
ENDCHAR
STARTCHAR U+0060
ENCODING 96
SWIDTH 600 0
DWIDTH 9 0
BBX 3 2 2 7
BITMAP
C0
60
ENDCHAR
STARTCHAR U+0061
ENCODING 97
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+0062
ENCODING 98
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
E0
60
60
6E
73
63
63
63
73
EE
ENDCHAR
STARTCHAR U+0063
ENCODING 99
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
3D
67
C3
C0
C0
63
3E
ENDCHAR
STARTCHAR U+0064
ENCODING 100
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 1 0
BITMAP
0E
06
06
76
CE
C6
C6
C6
CE
77
ENDCHAR
STARTCHAR U+0065
ENCODING 101
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
3C
66
C3
FF
C0
67
3E
ENDCHAR
STARTCHAR U+0066
ENCODING 102
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 2 0
BITMAP
3C
60
60
F8
60
60
60
60
60
F8
ENDCHAR
STARTCHAR U+0067
ENCODING 103
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 1 -3
BITMAP
77
CE
C6
C6
C6
CE
76
06
06
3C
ENDCHAR
STARTCHAR U+0068
ENCODING 104
SWIDTH 600 0
DWIDTH 9 0
BBX 9 10 0 0
BITMAP
E000
6000
6000
6E00
7300
6300
6300
6300
6300
F780
ENDCHAR
STARTCHAR U+0069
ENCODING 105
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 2 0
BITMAP
30
30
00
F0
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+006A
ENCODING 106
SWIDTH 600 0
DWIDTH 9 0
BBX 5 13 1 -3
BITMAP
18
18
00
F8
18
18
18
18
18
18
18
18
F0
ENDCHAR
STARTCHAR U+006B
ENCODING 107
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
E0
60
60
67
6C
78
78
6C
66
E7
ENDCHAR
STARTCHAR U+006C
ENCODING 108
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
F0
30
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+006D
ENCODING 109
SWIDTH 600 0
DWIDTH 9 0
BBX 10 7 -1 0
BITMAP
DB00
6D80
6D80
6D80
6D80
6D80
EDC0
ENDCHAR
STARTCHAR U+006E
ENCODING 110
SWIDTH 600 0
DWIDTH 9 0
BBX 9 7 0 0
BITMAP
EE00
7300
6300
6300
6300
6300
F780
ENDCHAR
STARTCHAR U+006F
ENCODING 111
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
3C
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+0070
ENCODING 112
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 -3
BITMAP
EE
73
63
63
63
73
6E
60
60
F0
ENDCHAR
STARTCHAR U+0071
ENCODING 113
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 1 -3
BITMAP
77
CE
C6
C6
C6
CE
76
06
06
0F
ENDCHAR
STARTCHAR U+0072
ENCODING 114
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
EE
70
60
60
60
60
FC
ENDCHAR
STARTCHAR U+0073
ENCODING 115
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 0
BITMAP
7E
C6
C0
7C
06
C6
FC
ENDCHAR
STARTCHAR U+0074
ENCODING 116
SWIDTH 600 0
DWIDTH 9 0
BBX 7 10 1 0
BITMAP
60
60
60
FC
60
60
60
60
66
3C
ENDCHAR
STARTCHAR U+0075
ENCODING 117
SWIDTH 600 0
DWIDTH 9 0
BBX 9 7 0 0
BITMAP
E700
6300
6300
6300
6300
6700
3B80
ENDCHAR
STARTCHAR U+0076
ENCODING 118
SWIDTH 600 0
DWIDTH 9 0
BBX 9 7 0 0
BITMAP
F780
6300
6300
3600
3600
1C00
1C00
ENDCHAR
STARTCHAR U+0077
ENCODING 119
SWIDTH 600 0
DWIDTH 9 0
BBX 10 7 -1 0
BITMAP
E1C0
6D80
6D80
6D80
3F00
3300
3300
ENDCHAR
STARTCHAR U+0078
ENCODING 120
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
E7
66
3C
18
3C
66
E7
ENDCHAR
STARTCHAR U+0079
ENCODING 121
SWIDTH 600 0
DWIDTH 9 0
BBX 9 10 0 -3
BITMAP
E380
6300
6300
3600
3600
1C00
1C00
1800
1800
7C00
ENDCHAR
STARTCHAR U+007A
ENCODING 122
SWIDTH 600 0
DWIDTH 9 0
BBX 6 7 1 0
BITMAP
FC
8C
18
30
60
C4
FC
ENDCHAR
STARTCHAR U+007B
ENCODING 123
SWIDTH 600 0
DWIDTH 9 0
BBX 4 12 3 -2
BITMAP
30
60
60
60
60
C0
60
60
60
60
60
30
ENDCHAR
STARTCHAR U+007C
ENCODING 124
SWIDTH 600 0
DWIDTH 9 0
BBX 2 12 3 -2
BITMAP
C0
C0
C0
C0
C0
C0
C0
C0
C0
C0
C0
C0
ENDCHAR
STARTCHAR U+007D
ENCODING 125
SWIDTH 600 0
DWIDTH 9 0
BBX 4 12 2 -2
BITMAP
C0
60
60
60
60
30
60
60
60
60
60
C0
ENDCHAR
STARTCHAR U+007E
ENCODING 126
SWIDTH 600 0
DWIDTH 9 0
BBX 6 3 1 3
BITMAP
64
FC
98
ENDCHAR
STARTCHAR U+00A0
ENCODING 160
SWIDTH 600 0
DWIDTH 9 0
BBX 1 1 0 0
BITMAP
00
ENDCHAR
STARTCHAR U+00A1
ENCODING 161
SWIDTH 600 0
DWIDTH 9 0
BBX 2 9 3 -2
BITMAP
C0
C0
00
80
C0
C0
C0
C0
C0
ENDCHAR
STARTCHAR U+00A2
ENCODING 162
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 -1
BITMAP
30
30
7C
CC
C0
C0
CC
78
30
30
ENDCHAR
STARTCHAR U+00A3
ENCODING 163
SWIDTH 600 0
DWIDTH 9 0
BBX 7 9 1 0
BITMAP
3C
66
60
60
F8
60
60
66
FC
ENDCHAR
STARTCHAR U+00A4
ENCODING 164
SWIDTH 600 0
DWIDTH 9 0
BBX 7 6 1 1
BITMAP
C6
7C
C6
C6
7C
C6
ENDCHAR
STARTCHAR U+00A5
ENCODING 165
SWIDTH 600 0
DWIDTH 9 0
BBX 10 9 0 0
BITMAP
F3C0
6180
3300
1E00
3F00
0C00
3F00
0C00
3F00
ENDCHAR
STARTCHAR U+00A6
ENCODING 166
SWIDTH 600 0
DWIDTH 9 0
BBX 2 12 3 -2
BITMAP
C0
C0
C0
C0
C0
00
00
C0
C0
C0
C0
C0
ENDCHAR
STARTCHAR U+00A7
ENCODING 167
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 -1
BITMAP
3E
62
60
F0
8C
E3
39
0F
06
46
7C
ENDCHAR
STARTCHAR U+00A8
ENCODING 168
SWIDTH 600 0
DWIDTH 9 0
BBX 5 1 2 8
BITMAP
D8
ENDCHAR
STARTCHAR U+00A9
ENCODING 169
SWIDTH 600 0
DWIDTH 9 0
BBX 9 8 0 1
BITMAP
1C00
6300
CD80
D180
D180
CD80
6300
1C00
ENDCHAR
STARTCHAR U+00AA
ENCODING 170
SWIDTH 600 0
DWIDTH 9 0
BBX 5 7 2 2
BITMAP
70
18
78
D8
E8
00
F8
ENDCHAR
STARTCHAR U+00AB
ENCODING 171
SWIDTH 600 0
DWIDTH 9 0
BBX 7 5 1 1
BITMAP
36
6C
D8
6C
36
ENDCHAR
STARTCHAR U+00AC
ENCODING 172
SWIDTH 600 0
DWIDTH 9 0
BBX 7 3 1 3
BITMAP
FE
02
02
ENDCHAR
STARTCHAR U+00AD
ENCODING 173
SWIDTH 600 0
DWIDTH 9 0
BBX 6 1 1 4
BITMAP
FC
ENDCHAR
STARTCHAR U+00AE
ENCODING 174
SWIDTH 600 0
DWIDTH 9 0
BBX 9 8 0 1
BITMAP
3E00
6300
D980
D580
D980
D580
6300
3E00
ENDCHAR
STARTCHAR U+00AF
ENCODING 175
SWIDTH 600 0
DWIDTH 9 0
BBX 4 1 2 8
BITMAP
F0
ENDCHAR
STARTCHAR U+00B0
ENCODING 176
SWIDTH 600 0
DWIDTH 9 0
BBX 5 5 2 5
BITMAP
70
88
88
88
70
ENDCHAR
STARTCHAR U+00B1
ENCODING 177
SWIDTH 600 0
DWIDTH 9 0
BBX 7 7 1 1
BITMAP
10
10
FE
10
10
00
FE
ENDCHAR
STARTCHAR U+00B2
ENCODING 178
SWIDTH 600 0
DWIDTH 9 0
BBX 5 6 2 3
BITMAP
70
98
18
30
60
F8
ENDCHAR
STARTCHAR U+00B3
ENCODING 179
SWIDTH 600 0
DWIDTH 9 0
BBX 5 6 2 3
BITMAP
70
98
30
18
98
70
ENDCHAR
STARTCHAR U+00B4
ENCODING 180
SWIDTH 600 0
DWIDTH 9 0
BBX 3 2 3 7
BITMAP
60
C0
ENDCHAR
STARTCHAR U+00B5
ENCODING 181
SWIDTH 600 0
DWIDTH 9 0
BBX 9 10 0 -3
BITMAP
E700
6300
6300
6300
6300
6700
7B80
6000
6000
6000
ENDCHAR
STARTCHAR U+00B6
ENCODING 182
SWIDTH 600 0
DWIDTH 9 0
BBX 7 11 1 -1
BITMAP
7E
D4
94
94
D4
74
14
14
14
14
3E
ENDCHAR
STARTCHAR U+00B7
ENCODING 183
SWIDTH 600 0
DWIDTH 9 0
BBX 2 2 3 3
BITMAP
C0
C0
ENDCHAR
STARTCHAR U+00B8
ENCODING 184
SWIDTH 600 0
DWIDTH 9 0
BBX 3 4 2 -3
BITMAP
40
60
20
E0
ENDCHAR
STARTCHAR U+00B9
ENCODING 185
SWIDTH 600 0
DWIDTH 9 0
BBX 4 6 3 3
BITMAP
60
E0
60
60
60
F0
ENDCHAR
STARTCHAR U+00BA
ENCODING 186
SWIDTH 600 0
DWIDTH 9 0
BBX 5 7 2 2
BITMAP
70
D8
D8
D8
70
00
F8
ENDCHAR
STARTCHAR U+00BB
ENCODING 187
SWIDTH 600 0
DWIDTH 9 0
BBX 7 5 1 1
BITMAP
D8
6C
36
6C
D8
ENDCHAR
STARTCHAR U+00BC
ENCODING 188
SWIDTH 600 0
DWIDTH 9 0
BBX 9 11 0 -1
BITMAP
6000
E080
6100
6200
6400
F900
1300
2700
4B00
8F80
0300
ENDCHAR
STARTCHAR U+00BD
ENCODING 189
SWIDTH 600 0
DWIDTH 9 0
BBX 9 11 0 -1
BITMAP
6000
E080
6100
6200
6400
FB00
1580
2180
4300
8600
0F80
ENDCHAR
STARTCHAR U+00BE
ENCODING 190
SWIDTH 600 0
DWIDTH 9 0
BBX 10 11 -1 -1
BITMAP
7000
9840
3080
1900
9A00
7480
0980
1380
2580
47C0
0180
ENDCHAR
STARTCHAR U+00BF
ENCODING 191
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 1 -2
BITMAP
30
30
00
30
70
C0
C4
CC
7C
ENDCHAR
STARTCHAR U+00C0
ENCODING 192
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1800
0C00
0000
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+00C1
ENCODING 193
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
0600
0C00
0000
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+00C2
ENCODING 194
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1C00
3600
0000
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+00C3
ENCODING 195
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1A00
2C00
0000
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+00C4
ENCODING 196
SWIDTH 600 0
DWIDTH 9 0
BBX 9 11 0 0
BITMAP
3600
0000
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+00C5
ENCODING 197
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1800
2400
1800
7C00
1C00
3600
3600
3600
6300
7F00
6300
F780
ENDCHAR
STARTCHAR U+00C6
ENCODING 198
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
3F80
1C80
1C00
3D00
2F00
6D00
7C00
4C80
DF80
ENDCHAR
STARTCHAR U+00C7
ENCODING 199
SWIDTH 600 0
DWIDTH 9 0
BBX 7 13 1 -4
BITMAP
3A
6E
C6
C0
C0
C0
C0
66
3C
10
18
08
38
ENDCHAR
STARTCHAR U+00C8
ENCODING 200
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
30
18
00
FF
63
63
68
78
68
63
63
FF
ENDCHAR
STARTCHAR U+00C9
ENCODING 201
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
0C
18
00
FF
63
63
68
78
68
63
63
FF
ENDCHAR
STARTCHAR U+00CA
ENCODING 202
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
1C
36
00
FF
63
63
68
78
68
63
63
FF
ENDCHAR
STARTCHAR U+00CB
ENCODING 203
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
36
00
FF
63
63
68
78
68
63
63
FF
ENDCHAR
STARTCHAR U+00CC
ENCODING 204
SWIDTH 600 0
DWIDTH 9 0
BBX 6 12 1 0
BITMAP
60
30
00
FC
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00CD
ENCODING 205
SWIDTH 600 0
DWIDTH 9 0
BBX 6 12 1 0
BITMAP
18
30
00
FC
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00CE
ENCODING 206
SWIDTH 600 0
DWIDTH 9 0
BBX 6 12 1 0
BITMAP
38
6C
00
FC
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00CF
ENCODING 207
SWIDTH 600 0
DWIDTH 9 0
BBX 6 11 1 0
BITMAP
CC
00
FC
30
30
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00D0
ENCODING 208
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
FC
66
63
63
F3
63
63
66
FC
ENDCHAR
STARTCHAR U+00D1
ENCODING 209
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1A00
2C00
0000
E780
6300
7300
7300
6B00
6B00
6700
6700
F300
ENDCHAR
STARTCHAR U+00D2
ENCODING 210
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
30
18
00
3C
66
C3
C3
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00D3
ENCODING 211
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
0C
18
00
3C
66
C3
C3
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00D4
ENCODING 212
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
1C
36
00
3C
66
C3
C3
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00D5
ENCODING 213
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 0
BITMAP
1A
2C
00
3C
66
C3
C3
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00D6
ENCODING 214
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
36
00
3C
66
C3
C3
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00D7
ENCODING 215
SWIDTH 600 0
DWIDTH 9 0
BBX 6 7 1 1
BITMAP
84
CC
78
30
78
CC
84
ENDCHAR
STARTCHAR U+00D8
ENCODING 216
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
01
3E
66
CB
CB
D3
D3
E3
66
BC
ENDCHAR
STARTCHAR U+00D9
ENCODING 217
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1800
0C00
0000
F780
6300
6300
6300
6300
6300
6300
6300
3E00
ENDCHAR
STARTCHAR U+00DA
ENCODING 218
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
0600
0C00
0000
F780
6300
6300
6300
6300
6300
6300
6300
3E00
ENDCHAR
STARTCHAR U+00DB
ENCODING 219
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 0
BITMAP
1C00
3600
0000
F780
6300
6300
6300
6300
6300
6300
6300
3E00
ENDCHAR
STARTCHAR U+00DC
ENCODING 220
SWIDTH 600 0
DWIDTH 9 0
BBX 9 11 0 0
BITMAP
3600
0000
F780
6300
6300
6300
6300
6300
6300
6300
3E00
ENDCHAR
STARTCHAR U+00DD
ENCODING 221
SWIDTH 600 0
DWIDTH 9 0
BBX 10 12 -1 0
BITMAP
0600
0C00
0000
F3C0
6180
3300
1E00
1E00
0C00
0C00
0C00
3F00
ENDCHAR
STARTCHAR U+00DE
ENCODING 222
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 1 0
BITMAP
F0
60
7E
63
63
66
7C
60
F0
ENDCHAR
STARTCHAR U+00DF
ENCODING 223
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
3C
66
66
66
6C
66
63
63
6B
EE
ENDCHAR
STARTCHAR U+00E0
ENCODING 224
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
30
18
00
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+00E1
ENCODING 225
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
0C
18
00
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+00E2
ENCODING 226
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
08
1C
36
00
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+00E3
ENCODING 227
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
1A
2C
00
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+00E4
ENCODING 228
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
36
00
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+00E5
ENCODING 229
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
18
24
18
00
7C
06
06
7E
C6
CE
77
ENDCHAR
STARTCHAR U+00E6
ENCODING 230
SWIDTH 600 0
DWIDTH 9 0
BBX 9 7 0 0
BITMAP
7700
1D80
0880
7F80
C800
CD80
7700
ENDCHAR
STARTCHAR U+00E7
ENCODING 231
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 -4
BITMAP
3D
67
C3
C0
C0
63
3E
10
18
08
38
ENDCHAR
STARTCHAR U+00E8
ENCODING 232
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
30
18
00
3C
66
C3
FF
C0
67
3E
ENDCHAR
STARTCHAR U+00E9
ENCODING 233
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
0C
18
00
3C
66
C3
FF
C0
67
3E
ENDCHAR
STARTCHAR U+00EA
ENCODING 234
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
08
1C
36
00
3C
66
C3
FF
C0
67
3E
ENDCHAR
STARTCHAR U+00EB
ENCODING 235
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
36
00
3C
66
C3
FF
C0
67
3E
ENDCHAR
STARTCHAR U+00EC
ENCODING 236
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
60
30
00
F0
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00ED
ENCODING 237
SWIDTH 600 0
DWIDTH 9 0
BBX 6 10 1 0
BITMAP
18
30
00
F0
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00EE
ENCODING 238
SWIDTH 600 0
DWIDTH 9 0
BBX 6 11 1 0
BITMAP
20
70
D8
00
F0
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00EF
ENCODING 239
SWIDTH 600 0
DWIDTH 9 0
BBX 6 9 1 0
BITMAP
CC
00
F0
30
30
30
30
30
FC
ENDCHAR
STARTCHAR U+00F0
ENCODING 240
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
C0
66
38
CC
3E
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00F1
ENCODING 241
SWIDTH 600 0
DWIDTH 9 0
BBX 9 10 0 0
BITMAP
1A00
2C00
0000
EE00
7300
6300
6300
6300
6300
F780
ENDCHAR
STARTCHAR U+00F2
ENCODING 242
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
30
18
00
3C
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00F3
ENCODING 243
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
0C
18
00
3C
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00F4
ENCODING 244
SWIDTH 600 0
DWIDTH 9 0
BBX 8 11 0 0
BITMAP
08
1C
36
00
3C
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00F5
ENCODING 245
SWIDTH 600 0
DWIDTH 9 0
BBX 8 10 0 0
BITMAP
1A
2C
00
3C
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00F6
ENCODING 246
SWIDTH 600 0
DWIDTH 9 0
BBX 8 9 0 0
BITMAP
36
00
3C
66
C3
C3
C3
66
3C
ENDCHAR
STARTCHAR U+00F7
ENCODING 247
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 1
BITMAP
18
18
00
FF
00
18
18
ENDCHAR
STARTCHAR U+00F8
ENCODING 248
SWIDTH 600 0
DWIDTH 9 0
BBX 8 7 0 0
BITMAP
3D
66
CF
DB
F3
66
BC
ENDCHAR
STARTCHAR U+00F9
ENCODING 249
SWIDTH 600 0
DWIDTH 9 0
BBX 9 10 0 0
BITMAP
1800
0C00
0000
E700
6300
6300
6300
6300
6700
3B80
ENDCHAR
STARTCHAR U+00FA
ENCODING 250
SWIDTH 600 0
DWIDTH 9 0
BBX 9 10 0 0
BITMAP
0C00
1800
0000
E700
6300
6300
6300
6300
6700
3B80
ENDCHAR
STARTCHAR U+00FB
ENCODING 251
SWIDTH 600 0
DWIDTH 9 0
BBX 9 11 0 0
BITMAP
0800
1C00
3600
0000
E700
6300
6300
6300
6300
6700
3B80
ENDCHAR
STARTCHAR U+00FC
ENCODING 252
SWIDTH 600 0
DWIDTH 9 0
BBX 9 9 0 0
BITMAP
3600
0000
E700
6300
6300
6300
6300
6700
3B80
ENDCHAR
STARTCHAR U+00FD
ENCODING 253
SWIDTH 600 0
DWIDTH 9 0
BBX 9 13 0 -3
BITMAP
0600
0C00
0000
E380
6300
6300
3600
3600
1C00
1C00
1800
1800
7C00
ENDCHAR
STARTCHAR U+00FE
ENCODING 254
SWIDTH 600 0
DWIDTH 9 0
BBX 8 12 0 -3
BITMAP
E0
60
6E
73
63
63
63
73
6E
60
60
F0
ENDCHAR
STARTCHAR U+00FF
ENCODING 255
SWIDTH 600 0
DWIDTH 9 0
BBX 9 12 0 -3
BITMAP
1200
0000
E380
6300
6300
3600
3600
1C00
1C00
1800
1800
7C00
ENDCHAR
ENDFONT
COURIERB
	printf '%s\n' "Courier Bitmap: Adobe Courier 14 pt, 75 dpi, from X.Org's font-adobe-75dpi." \
		"Copyright (c) 1984, 1987 Adobe Systems Incorporated. Copyright (c) 1988, 1991" \
		"Digital Equipment Corporation. Permission to use, copy, modify and distribute" \
		"this font for any purpose and without fee is hereby granted (X11 licence)." \
		> "$_sd/LICENSE-courier-bitmap.txt"
	# Outline serif monospace fonts (SIL OFL): wider letter boxes on the console
	for _f in courierprime/CourierPrime-Regular.ttf ibmplexmono/IBMPlexMono-Regular.ttf; do
		curl -fsSL "$_nf/$_f" -o "$_sd/${_f##*/}" || warn "missing ${_f##*/}"
	done
	curl -fsSL "$_nf/courierprime/OFL.txt" -o "$_sd/LICENSE-CourierPrime.txt" || true
	curl -fsSL "$_nf/ibmplexmono/OFL.txt" -o "$_sd/LICENSE-IBMPlexMono.txt" || true
	if curl -fsSL -o /tmp/libertinus.zip \
		https://github.com/alerque/libertinus/releases/download/v7.051/Libertinus-7.051.zip; then
		unzip -o -j -q /tmp/libertinus.zip '*LibertinusMono-Regular.otf' '*OFL.txt' -d "$_sd" &&
			mv "$_sd/OFL.txt" "$_sd/LICENSE-Libertinus.txt" 2>/dev/null
		rm -f /tmp/libertinus.zip
	else
		warn "missing LibertinusMono-Regular.otf"
	fi

	# Unifont, the last fallback font: only unifont.otf (5 MB). Alpine's
	# font-unifont package has nine OTFs and X11 copies (about 50 MB).
	if [ -s /usr/share/fonts/opentype/unifont/unifont.otf ]; then
		install -Dm644 /usr/share/fonts/opentype/unifont/unifont.otf \
			"$STAGE/usr/share/fonts/unifont/unifont.otf"
		printf '%s\n' "GNU Unifont (unifoundry.com): SIL Open Font License 1.1 and" \
			"GNU GPL 2 or later with the GNU font embedding exception." \
			> "$STAGE/usr/share/fonts/unifont/LICENSE-unifont.txt"
	else
		warn "no unifont.otf: Unifont is missing (fbterm's last fallback)"
	fi
	# Bitmap fonts as compressed PCF: several times smaller than BDF text,
	# and the live system keeps every file in RAM. fontconfig and fbterm
	# read PCF the same way. kfont (kernel font) reads its BDF copy.
	mkdir -p /home/build/kfont-src
	cp "$FONTDIR/DOSMyungjo-16.bdf" /home/build/kfont-src/ 2>/dev/null
	if command -v bdftopcf >/dev/null; then
		for _b in "$STAGE"/usr/share/fonts/*/*.bdf; do
			[ -e "$_b" ] || continue
			if bdftopcf -t "$_b" | gzip -9n > "${_b%.bdf}.pcf.gz" &&
			   [ -s "${_b%.bdf}.pcf.gz" ]; then
				rm -f "$_b"
			else
				rm -f "${_b%.bdf}.pcf.gz"; warn "kept as BDF: ${_b##*/}"
			fi
		done
	else
		warn "no bdftopcf: bitmap fonts stay BDF (larger in RAM)"
	fi

	stage_files

	echo ">> aports ($VER-stable) and ISO"
	# Only the parts used here are fetched (scripts, and the packages built
	# from source). GitLab
	# sometimes drops the connection ("RPC failed", "early EOF"): try again.
	_ok=no
	# (the last two tries use Alpine's copy on GitHub)
	for _try in 1 2 3 4 5; do
		rm -rf aports
		_url=https://gitlab.alpinelinux.org/alpine/aports.git
		[ $_try -ge 4 ] && _url=https://github.com/alpinelinux/aports.git
		if git -c http.version=HTTP/1.1 clone --depth 1 --filter=blob:none --sparse \
			--branch "$VER-stable" "$_url" &&
		   git -C aports sparse-checkout set scripts main/linux-lts community/netsurf community/dosbox-staging community/fbida community/mpv; then
			_ok=yes; break
		fi
		echo "!! aports download failed (try $_try of 5), again in 20 s" >&2
		sleep 20
	done
	[ $_ok = yes ] || { echo "!! could not download aports: check the internet connection" >&2; exit 1; }
	write_mkimage_files aports/scripts

	KREPO=""
	HAN_CONSOLE=fbterm
	if [ -e /cjktty.patch.xz ]; then
		if build_cjktty_kernel; then
			KREPO="/home/build/packages/main"
			HAN_CONSOLE=kernel
		else
			echo "!! cjktty kernel build failed: the ISO uses fbterm only" >&2
		fi
	fi
	echo "HAN_CONSOLE=$HAN_CONSOLE" > "$STAGE/etc/han.conf"

	NREPO=""
	if [ "$ARCH" = x86 ]; then
		if build_dosbox_x86; then
			NREPO="/home/build/packages/community"
			case " $OPT_OK " in *" dosbox-staging "*) ;;
				*) OPT_OK="$OPT_OK dosbox-staging"
				   write_mkimage_files aports/scripts ;;
			esac
		else
			echo "!! dosbox-staging for x86 failed: no DOSBox on this ISO" >&2
		fi
	fi
	if build_fbida_keys; then
		NREPO="/home/build/packages/community"
	else
		echo "!! fbi rebuild failed: b does not go back a page in hv" >&2
	fi
	if [ -e /netsurf-fb-hangul.patch ]; then
		if build_netsurf_hangul; then
			NREPO="/home/build/packages/community"
		else
			echo "!! NetSurf rebuild failed: the ISO has the stock one, without Korean" >&2
		fi
	fi
	if build_mpv_drm; then
		NREPO="/home/build/packages/community"
	else
		echo "!! mpv rebuild failed: the stock mpv pulls in Mesa + LLVM (about 225 MB more RAM)" >&2
	fi

	# The boot set must not pull in LLVM/Mesa again (about 225 MB of RAM):
	# list everything it needs, with our own packages (mpv) first in line.
	_heavy="$(apk fetch --simulate --recursive \
		${KREPO:+--repository "$KREPO"} ${NREPO:+--repository "$NREPO"} \
		$BOOT_BASE $EXTRA_OK 2>&1 | grep -o -E '(llvm[0-9]*-libs|mesa-[a-z-]*|mesa)-[0-9][^ ]*' | sort -u)"
	if [ -n "$_heavy" ]; then
		echo "!! the boot set pulls in:" $_heavy "(LLVM/Mesa, about 225 MB of RAM): see apk info -r" >&2
	else
		echo ">> boot set: no LLVM or Mesa"
	fi

	mkdir -p iso tmp
	export TMPDIR=/home/build/tmp
	sh aports/scripts/mkimage.sh --tag "v$VER" \
		--outdir /home/build/iso \
		--arch "$ARCH" \
		${KREPO:+--repository "$KREPO"} \
		${NREPO:+--repository "$NREPO"} \
		--repository "${ALPINE_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}/v$VER/main" \
		--repository "${ALPINE_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}/v$VER/community" \
		--profile hangul || return 1
	if [ -n "$KREPO" ]; then
		_iso="$(ls /home/build/iso/*.iso | head -n1)"
		xorriso -osirrox on -indev "$_iso" -extract /boot/vmlinuz-lts /home/build/tmp/vmlinuz >/dev/null 2>&1
		_off=$(od -An -tu2 -j526 -N2 /home/build/tmp/vmlinuz 2>/dev/null | tr -d ' ')
		_kv=$(dd if=/home/build/tmp/vmlinuz bs=1 skip=$((${_off:-0} + 512)) count=80 2>/dev/null | tr '\0' '\n' | head -n1 | cut -d' ' -f1)
		case "$_kv" in
		*-900-*) echo ">> ISO kernel: $_kv (ours: Korean on the console)" ;;
		*) echo "!! the ISO has kernel '$_kv', not ours (-900-): no Korean on the console. ISO removed, stopping." >&2
		   rm -f "$_iso"; return 1 ;;
		esac
	fi
	# the initramfs is read by the boot loader before the kernel starts:
	# keep it small (about 10-20 MB; with "kms" it was 171 MB)
	_iso="$(ls /home/build/iso/*.iso | head -n1)"
	rm -f /home/build/tmp/initramfs
	xorriso -osirrox on -indev "$_iso" -extract /boot/initramfs-lts /home/build/tmp/initramfs >/dev/null 2>&1
	_irs=$(( $(stat -c %s /home/build/tmp/initramfs 2>/dev/null || echo 0) / 1048576 ))
	if [ "$_irs" -gt 40 ]; then
		echo "!! initramfs is $_irs MB (expected 10-20): slow to boot; check initfs_features"
	else
		echo ">> initramfs: $_irs MB"
	fi
	rm -f /home/build/tmp/initramfs
}

# ---------------------------------------------------------------------------
# Phase 2: inside the container, as root
# ---------------------------------------------------------------------------
phase_root() {
	trap '_rc=$?; [ $_rc = 0 ] || echo "!! build stopped (error $_rc) right after the last >> step above" >&2' EXIT
	VER="$(cut -d. -f1,2 /etc/alpine-release)"
	ARCH="$(apk --print-arch)"
	echo ">> Alpine $VER build container, $ARCH"
	apk add --no-cache alpine-sdk alpine-conf fakeroot git xz \
		syslinux xorriso squashfs-tools grub mtools dosfstools \
		pkgconf linux-headers freetype-dev fontconfig-dev ncurses \
		curl fontconfig unzip findutils python3
	apk add --no-cache grub-efi || echo "!! no grub-efi on $ARCH: BIOS boot only" >&2
	# for kfont: the kernel console font (Terminus English + DOSMyungjo Hangul)
	apk add --no-cache font-terminus py3-pillow py3-fonttools ||
		echo "!! no font tools: the kernel console keeps cjktty's own font" >&2
	# bdftopcf: bitmap fonts packed small (RAM); font-unifont: its one
	# Unifont file is copied in (the package itself has nine big ones)
	apk add --no-cache bdftopcf font-unifont ||
		echo "!! no bdftopcf or font-unifont: fonts stay large / no Unifont" >&2
	adduser -D build
	addgroup build abuild
	# Signing key for the local kernel package, trusted by apk and mkimage
	su build -c "abuild-keygen -a -n"
	cp /home/build/.abuild/*.rsa.pub /etc/apk/keys/

	# The package list is needed to check names (apk add --no-cache keeps none)
	apk update >/dev/null || { echo "!! apk update failed: is the network up?" >&2; exit 1; }
	EXTRA_OK=""
	for _p in $EXTRA_APPS; do
		if apk fetch --simulate "$_p" >/dev/null 2>&1; then
			EXTRA_OK="$EXTRA_OK $_p"
		else
			echo "!! skipping '$_p': no such package in Alpine $VER" >&2
		fi
	done
	echo ">> console apps:$EXTRA_OK"
	[ -n "$EXTRA_OK" ] || { echo "!! no console apps found: stopping" >&2; exit 1; }
	OPT_OK=""
	for _p in $OPTIONAL_APPS; do
		if apk fetch --simulate "$_p" >/dev/null 2>&1; then
			OPT_OK="$OPT_OK $_p"
		else
			echo "!! skipping optional '$_p': no such package in Alpine $VER ($ARCH)" >&2
		fi
	done
	echo ">> optional (in the ISO, not installed at boot):$OPT_OK"
	[ -e /cjktty.patch.xz ] && echo ">> cjktty patch found: the kernel is built too"
	cp /build.sh /tmp/build.sh
	chmod 755 /tmp/build.sh
	su build -c "VER=$VER ARCH=$ARCH ALPINE_MIRROR='${ALPINE_MIRROR:-}' EXTRA_OK='$EXTRA_OK' OPT_OK='$OPT_OK' sh /tmp/build.sh --phase-build" ||
		{ echo "!! build failed: no ISO" >&2; exit 1; }
	_iso="$(ls /home/build/iso/*.iso | head -n1)"
	cp "$_iso" "/out/aneuu-$ANEUU_VERSION-$ARCH.iso"
	chown "${HOST_UID:-0}:${HOST_GID:-0}" "/out/aneuu-$ANEUU_VERSION-$ARCH.iso"
	echo ">> done:"
	ls -lh "/out/aneuu-$ANEUU_VERSION-$ARCH.iso"
}

# ---------------------------------------------------------------------------
# Phase 1: on the host
# ---------------------------------------------------------------------------
phase_host() {
	if command -v docker >/dev/null 2>&1; then ENGINE=docker
	elif command -v podman >/dev/null 2>&1; then ENGINE=podman
	else echo "Install docker first:  sudo apt install docker.io" >&2; exit 1
	fi
	SELF="$(readlink -f "$0")"
	OUT="$PWD/aneuu-out"
	mkdir -p "$OUT"
	PATCHARG=""
	PATCH="$(ls "${SELF%/*}"/cjktty-*.patch.xz 2>/dev/null | head -n1)" || true
	if [ "$HAN_KERNEL" != no ] && [ -n "$PATCH" ]; then
		echo ">> using $PATCH (kernel build: needs about 15 GB free for Docker)"
		PATCHARG="-v $PATCH:/cjktty.patch.xz:ro"
	else
		echo ">> no cjktty patch used: han will run in fbterm"
	fi
	NSARG=""
	if [ -e "${SELF%/*}/netsurf-fb-hangul.patch" ]; then
		echo ">> using netsurf-fb-hangul.patch (NetSurf with Korean)"
		NSARG="-v ${SELF%/*}/netsurf-fb-hangul.patch:/netsurf-fb-hangul.patch:ro"
	else
		echo ">> no netsurf-fb-hangul.patch: NetSurf will not show or take Korean"
	fi
	for _arch in $HAN_ARCH; do
		case "$_arch" in
			x86_64) _plat=linux/amd64 ;;
			x86)    _plat=linux/386 ;;
			*) echo "HAN_ARCH: unknown '$_arch' (x86_64 or x86)" >&2; exit 1 ;;
		esac
		echo ">> building the $_arch flavor"
		# Ctrl+C: Docker ignores it inside the build, so stop the build here
		"$ENGINE" rm -f aneuu-build >/dev/null 2>&1 || true
		trap 'echo; echo ">> stopping the build"; "$ENGINE" kill aneuu-build >/dev/null 2>&1; exit 130' INT
		"$ENGINE" run --rm --name aneuu-build --platform "$_plat" \
			-e HOST_UID="${SUDO_UID:-$(id -u)}" -e HOST_GID="${SUDO_GID:-$(id -g)}" \
			${ALPINE_MIRROR:+-e ALPINE_MIRROR="$ALPINE_MIRROR"} \
			-v "$SELF":/build.sh:ro -v "$OUT":/out $PATCHARG $NSARG \
			"$ALPINE_IMAGE" sh /build.sh --phase-root &
		wait $! || { _rc=$?; trap - INT; exit $_rc; }
		trap - INT
	done
	echo
	echo "ISOs are in $OUT"
	ls -lh "$OUT"/*.iso 2>/dev/null || true
}

case "${1:-}" in
	--phase-root)  phase_root ;;
	--phase-build) phase_build ;;
	--test-overlay) STAGE="$2/stage"; EXTRA_OK="$(echo $EXTRA_APPS)"; OPT_OK="$(echo $OPTIONAL_APPS)"; stage_files; write_mkimage_files "$2" ;;
	*)             phase_host ;;
esac
