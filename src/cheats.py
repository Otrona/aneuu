# Short key summaries for the F12 side panel: at most 26 columns wide
# (a Korean character takes two). Name -> (Korean, English)

CHEATS = {
"cmds": ("""명령 요약
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
""", """Commands
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
"""),

"yt": ("""유튜브 yt
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
""", """YouTube yt
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
"""),

"edit": ("""nano
^ 는 Ctrl, M- 는 Alt
Ctrl+O  저장
Ctrl+X  끝내기
Ctrl+W  찾기
Ctrl+\\  바꾸기
Ctrl+K  줄 잘라내기
Ctrl+U  붙여넣기
Alt+6   줄 복사
Alt+U   되돌리기
Alt+E   다시 하기
Ctrl+G  도움말
""", """nano
^ is Ctrl, M- is Alt
Ctrl+O  save
Ctrl+X  quit
Ctrl+W  find
Ctrl+\\  replace
Ctrl+K  cut line
Ctrl+U  paste
Alt+6   copy line
Alt+U   undo
Alt+E   redo
Ctrl+G  help
"""),

"write": ("""WordGrinder
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
""", """WordGrinder
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
"""),

"files": ("""nnn
화살표  이동
Enter   열기
←       위 폴더
/       이름 거르기
Space   선택
p       여기로 복사
v       여기로 이동
?       모든 키
q       끝내기
""", """nnn
arrows  move
Enter   open
Left    parent folder
/       filter
Space   select
p       copy here
v       move here
?       all keys
q       quit
"""),

"web": ("""w3m / chawan
U       주소 입력
Enter   링크 열기
Tab     다음 링크
B       뒤로
/       찾기
q       끝내기

Alt+W   이 페이지 글을
        wg 로 (w3m)
""", """w3m / chawan
U       go to address
Enter   follow link
Tab     next link
B       back
/       search
q       quit

Alt+W   page text to
        WordGrinder (w3m)
"""),

"mail": ("""aerc
j k     위 아래
Enter   열기
c       새 메일
rr      전체 답장
d       지우기
q       뒤로/끝내기

다 쓰고 편집기 닫기
 y 보내기
 n 그만두기
""", """aerc
j k     up / down
Enter   open
c       compose
rr      reply all
d       delete
q       back / quit

After the editor
 y send
 n abandon
"""),

"feeds": ("""newsboat
R       모두 받기
Enter   열기
o       브라우저로
n       다음 안 읽음
q       뒤로/끝내기
Alt+N   패널 숨기기/보기

주소 목록
 ~/.newsboat/urls
""", """newsboat
R       reload all
Enter   open
o       open in browser
n       next unread
q       back / quit
Alt+N   hide / show panel

Feed list
 ~/.newsboat/urls
"""),

"pod": ("""pod 팟캐스트
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
""", """pod podcasts
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
"""),

"cal": ("""calcurse
Tab     칸 바꾸기
화살표  날짜 이동
a       더하기
e       고치기
d       지우기
q       끝내기
""", """calcurse
Tab     switch panel
arrows  move days
a       add
e       edit
d       delete
q       quit
"""),

"sheet": ("""sc-im
화살표  칸 이동
=       숫자, 수식
         =@sum(A1:A9)
<       글자
x       칸 지우기
:w F.sc 저장
:w F.csv CSV 저장
:q      끝내기
""", """sc-im
arrows  move
=       number, formula
         =@sum(A1:A9)
<       text
x       clear cell
:w F.sc save
:w F.csv save as CSV
:q      quit
"""),

"music": ("""cmus
:add ~/music
1 ~ 7   화면 바꾸기
Enter   재생
c       일시정지
b z     다음 / 이전
+ -     소리
q       끝내기
""", """cmus
:add ~/music
1 - 7   views
Enter   play
c       pause
b z     next / prev
+ -     volume
q       quit
"""),

"chat": ("""irssi
/connect 서버
/join #채널
Alt+숫자 창 바꾸기
/part   방 나가기
/quit   끝내기
""", """irssi
/connect SERVER
/join #channel
Alt+num switch window
/part   leave room
/quit   quit
"""),

"down": ("""rtorrent
Backspace 토렌트 넣기
Ctrl+S  시작
Ctrl+D  멈춤/지우기
Ctrl+Q  끝내기

aria2c 주소
aria2c -x4 주소
""", """rtorrent
Backspace add torrent
Ctrl+S  start
Ctrl+D  stop / remove
Ctrl+Q  quit

aria2c URL
aria2c -x4 URL
"""),

"sys": ("""btop
화살표  프로그램
k       끝내기(kill)
Esc     메뉴
q       나가기

ncdu
Enter   들어가기
d       지우기
q       나가기
""", """btop
arrows  pick process
k       kill it
Esc     menu
q       quit

ncdu
Enter   open folder
d       delete
q       quit
"""),

"read": ("""옆에 책 펴기
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
""", """Book beside work
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
"""),

"bt": ("""블루투스
s       새 기기 찾기
번호    연결 / 끊기
x번호   지우기
q       닫기

새 기기는 먼저
연결 대기(페어링)
상태로 두기
""", """Bluetooth
s       search
number  connect/disconnect
x+num   forget
q       close

Put a new device in
pairing mode first
"""),

"wifi": ("""무선랜
번호    연결
r       다시 찾기
q       닫기
한 번 연결하면
다음엔 저절로
""", """Wi-Fi
number  connect
r       search again
q       close
Networks you used
reconnect by themselves
"""),
"gem": ("""AI 대화 (gem)
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
""", """AI chat (gem)
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
"""),
}


def shell():
    out = ['	mkdir -p "$STAGE/usr/share/han/cheat/ko" "$STAGE/usr/share/han/cheat/en"']
    for name, (ko, en) in CHEATS.items():
        for lang, text in (("ko", ko), ("en", en)):
            out.append(f"	cat > \"$STAGE/usr/share/han/cheat/{lang}/{name}.txt\" <<'HANCHEAT'")
            out.append(text.rstrip("\n"))
            out.append("HANCHEAT")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    import unicodedata
    def width(s):
        return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
    worst = max((width(l), n, l) for n, p in CHEATS.items() for t in p for l in t.splitlines())
    print("widest line:", worst)
