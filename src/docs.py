# Guide pages for the console desktop, in Korean (ko) and English (en).
# Each topic: (name, Korean title, English title, Korean text, English text)

TOPICS = [
("cmds", "명령 요약", "Command summary",
"""명령 요약   (F12 로 열고 닫기)
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
""",
"""Command summary   (F12 opens and closes this)
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
"""),

("start", "처음 시작하기", "Getting started",
"""처음 시작하기
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
""",
"""Getting started
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
"""),

("korean", "한글 입력", "Typing Korean",
"""한글 입력
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
""",
"""Typing Korean
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
"""),

("desk", "콘솔 데스크톱", "The console desktop",
"""콘솔 데스크톱 (desk)
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
""",
"""The console desktop (desk)
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
"""),

("wifi", "무선랜", "Wi-Fi",
"""무선랜 (Wi-Fi)
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
""",
"""Wi-Fi
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
"""),

("bt", "블루투스", "Bluetooth",
"""블루투스 (Bluetooth)
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
""",
"""Bluetooth
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
"""),

("setup", "처음 설정", "First settings",
"""처음 설정
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
""",
"""First settings
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
"""),

("save", "저장과 설치", "Saving and installing",
"""저장과 설치
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
""",
"""Saving and installing
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
"""),

("files", "파일 관리 (nnn)", "Files (nnn)",
"""파일 관리: nnn
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
""",
"""Files: nnn
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
"""),

("write", "문서 작성 (WordGrinder)", "Writing (WordGrinder)",
"""문서 작성: WordGrinder
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
""",
"""Writing: WordGrinder
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
"""),

("edit", "텍스트 편집 (nano)", "Text editor (nano)",
"""텍스트 편집: nano
================

시작: nano 파일이름   (메뉴: Edit)

화면 아래 두 줄에 쓸 수 있는 키가 나옵니다 (^ 는 Ctrl, M- 는 Alt).
  Ctrl+O    저장 (Enter 로 이름 확인)   Ctrl+X    끝내기
  Ctrl+W    찾기                        Ctrl+\\    바꾸기
  Ctrl+K    줄 잘라내기                 Ctrl+U    붙여넣기
  Alt+6     줄 복사                     Alt+U     되돌리기
  Ctrl+G    도움말
여러 줄을 옮기려면 Ctrl+K 를 여러 번 누른 뒤 한 번에 Ctrl+U.
콘솔에서는 마우스를 쓸 수 없으니, 화면의 글은 F6 (복사)과 F7 (붙여넣기).

vim 도 들어 있습니다.
""",
"""Text editor: nano
=================

Start: nano FILE   (menu: Edit)

The two bottom lines show the keys (^ is Ctrl, M- is Alt).
  Ctrl+O    save (Enter confirms)       Ctrl+X    quit
  Ctrl+W    find                        Ctrl+\\    replace
  Ctrl+K    cut line                    Ctrl+U    paste
  Alt+6     copy line                   Alt+U     undo
  Ctrl+G    help
To move several lines, press Ctrl+K on each, then Ctrl+U once.
The console has no mouse: for text on the screen use F6 (copy) and F7
(paste).

vim is installed too.
"""),
("web", "웹 (w3m, chawan, NetSurf)", "Web (w3m, chawan, NetSurf)",
"""웹 브라우저 세 가지
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
""",
"""Three web browsers
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
"""),

("mail", "메일 (aerc)", "Mail (aerc)",
"""메일: aerc
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
""",
"""Mail: aerc
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
"""),

("feeds", "뉴스, 팟캐스트 (newsboat)", "News, podcasts (newsboat)",
"""뉴스 피드: newsboat
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
""",
"""News feeds: newsboat
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
"""),

("cal", "일정 (calcurse)", "Calendar (calcurse)",
"""일정과 할 일: calcurse
=====================

시작: calcurse   (메뉴: Calendar)

화면에 달력, 일정, 할 일 세 칸이 있습니다.
  Tab         칸 바꾸기
  화살표       날짜 옮기기
  a           일정이나 할 일 더하기
  e           고치기
  d           지우기
  q           끝내기
""",
"""Calendar and to-do: calcurse
============================

Start: calcurse   (menu: Calendar)

The screen has three panels: calendar, appointments, to-do.
  Tab         switch panel
  arrows      move between days
  a           add an appointment or a to-do
  e           edit
  d           delete
  q           quit
"""),

("sheet", "스프레드시트 (sc-im)", "Spreadsheet (sc-im)",
"""스프레드시트: sc-im
==================

시작: sc-im 파일.sc   (메뉴: Spreadsheet)

  화살표          칸 옮기기
  =              숫자나 수식 넣기   (예: =A1+A2,  =@sum(A1:A9))
  <              글자 넣기 (왼쪽 맞춤)
  x              칸 지우기
  :w 파일.sc     저장
  :q             끝내기

엑셀과 주고받기:  :w 파일.csv  로 저장하면 CSV 파일이 됩니다.
""",
"""Spreadsheet: sc-im
==================

Start: sc-im FILE.sc   (menu: Spreadsheet)

  arrows         move between cells
  =              enter a number or formula (e.g. =A1+A2, =@sum(A1:A9))
  <              enter text (left aligned)
  x              clear a cell
  :w FILE.sc     save
  :q             quit

For Excel and others: save with  :w FILE.csv  to get a CSV file.
"""),

("music", "음악 (cmus)", "Music (cmus)",
"""음악: cmus
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
""",
"""Music: cmus
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
"""),

("video", "동영상과 사진", "Video and pictures",
"""동영상과 사진
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
""",
"""Video and pictures
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
"""),

("chat", "채팅 (irssi)", "Chat (irssi)",
"""채팅 (IRC): irssi
=================

시작: irssi   (메뉴: Chat)

  /connect irc.libera.chat     서버에 접속
  /join #채널이름                방에 들어가기
  Alt+숫자                     창 바꾸기
  /part                        방에서 나가기
  /quit                        끝내기

텔레그램 콘솔 프로그램은 아직 Alpine 에 없습니다.
텔레그램은 Firefox 로 web.telegram.org 를 쓰세요 (doc x).
""",
"""Chat (IRC): irssi
=================

Start: irssi   (menu: Chat)

  /connect irc.libera.chat     connect to a server
  /join #channel               join a room
  Alt+number                   switch windows
  /part                        leave a room
  /quit                        quit

There is no console Telegram client in Alpine yet.
For Telegram, use web.telegram.org in Firefox (doc x).
"""),

("down", "내려받기 (aria2, rtorrent)", "Downloads (aria2, rtorrent)",
"""내려받기
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
""",
"""Downloads
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
"""),

("sys", "시스템 (btop, ncdu)", "System (btop, ncdu)",
"""시스템 살펴보기
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
""",
"""Looking at the system
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
"""),

("search", "찾기 (rg, fd)", "Searching (rg, fd)",
"""찾기
====

fd: 파일 이름으로 찾기
  fd 보고서              이름에 '보고서'가 든 파일
  fd -e odt              .odt 파일 모두
  fd 사진 /media/usb      USB 안에서 찾기

rg (ripgrep): 파일 안의 글자로 찾기
  rg 회의                 '회의'가 들어 있는 줄
  rg -i hello            대소문자 무시
  rg -l 계약 ~/문서        들어 있는 파일 이름만
""",
"""Searching
=========

fd: find files by name
  fd report              files with 'report' in the name
  fd -e odt              all .odt files
  fd photo /media/usb    search a USB stick

rg (ripgrep): find text inside files
  rg meeting             lines containing 'meeting'
  rg -i hello            ignore upper/lower case
  rg -l contract ~/docs  only the names of matching files
"""),

("dos", "도스 게임 (hdos)", "DOS games (hdos)",
"""도스 게임: hdos
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
""",
"""DOS games: hdos
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
"""),

("x", "Firefox (hx)", "Firefox (hx)",
"""Firefox: hx
===========

모든 사이트(유튜브, 은행, 웹메일)가 필요할 때만 씁니다.
메모리가 2 GB 이상이어야 하고, 4 GB 면 편합니다.

처음 한 번 설치 (인터넷 필요, root):
  had firefox

실행:
  hx firefox        화면 가득 Firefox. 끝내면 콘솔로 돌아옴
  오른쪽 Alt        한글 / 영어

hx 는 다른 그래픽 프로그램도 엽니다:  hx 프로그램이름
""",
"""Firefox: hx
===========

Use it only when you need every site (video, banking, web mail).
It needs 2 GB of memory; 4 GB is comfortable.

Install once (needs the internet, as root):
  had firefox

Run:
  hx firefox        Firefox full screen; quitting returns to the console
  Right Alt         Korean / English

hx opens other graphical programs too:  hx PROGRAM
"""),
("add", "더 설치하기 (had)", "Add more (had)",
"""더 설치하기: had
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
""",
"""Add more: had
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
"""),

("read", "문서와 책 보기", "Reading documents and books",
"""문서와 책 보기: hv (han-view)
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
""",
"""Reading documents and books: hv (han-view)
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
"""),

("yt", "유튜브 (yt)", "YouTube (yt)",
"""유튜브: yt
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
""",
"""YouTube: yt
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
"""),

("more", "그 밖의 도구", "More tools",
"""그 밖의 도구
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
""",
"""More tools
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
"""),

("fix", "문제 해결", "Troubleshooting",
"""문제 해결
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
""",
"""Troubleshooting
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
"""),
]


def shell():
    """Shell code (for the build script) that writes the guide files."""
    out = ['	mkdir -p "$STAGE/usr/share/han/doc/ko" "$STAGE/usr/share/han/doc/en"']
    for lang, t_idx, e_idx in (("ko", 1, 3), ("en", 2, 4)):
        index = ["안내서 - 주제를 고르세요" if lang == "ko" else "Guide - choose a topic", ""]
        # two columns (1-14 left, 15-28 right) so the list fits one
        # 80x25 screen without scrolling
        import unicodedata
        width = lambda x: sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in x)
        cells = [f"{n:2d} {t[0]:<6} {t[t_idx]}" for n, t in enumerate(TOPICS, 1)]
        half = (len(cells) + 1) // 2
        for i in range(half):
            left = cells[i]
            row = " " + left
            if i + half < len(cells):
                row += " " * (39 - width(left)) + cells[i + half]
            index.append(row.rstrip())
        index.append("")
        index.append("번호나 이름을 입력하고 Enter.  q = 닫기,  doc en = English"
                     if lang == "ko" else
                     "Type a number or name, then Enter.  q = close,  doc ko = 한국어")
        out.append(f"	cat > \"$STAGE/usr/share/han/doc/{lang}/index.txt\" <<'HANDOC'")
        out.extend(index)
        out.append("HANDOC")
        for t in TOPICS:
            out.append(f"	cat > \"$STAGE/usr/share/han/doc/{lang}/{t[0]}.txt\" <<'HANDOC'")
            out.append(t[e_idx].rstrip("\n"))
            out.append("HANDOC")
    return "\n".join(out) + "\n"
