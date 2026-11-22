import re, sys
from PIL import Image, ImageFont, ImageDraw
def load_h(path):
    lines=open(path).read().split('\n'); cur=None; d={}
    for l in lines:
        m=re.match(r'/\* (\d+) 0x',l)
        if m: cur=int(m.group(1)); d[cur]=[]; continue
        if cur is not None and l.startswith('0x'): d[cur]+= [int(x,16) for x in l.rstrip(',').split(',') if x]
    return d
def bdf(path):
    g={}; cur=None; bits=None
    for line in open(path,encoding='latin-1'):
        w=line.split()
        if not w: continue
        if w[0]=='ENCODING': cur={'e':int(w[1])}
        elif w[0]=='BBX' and cur is not None: cur['bbx']=list(map(int,w[1:5]))
        elif w[0]=='BITMAP': bits=[]
        elif w[0]=='ENDCHAR': cur['bits']=bits; g[cur['e']]=cur; cur=None; bits=None
        elif bits is not None: bits.append(int(w[0],16)<<(32-len(w[0])*4))
    return g
def ko_cell(gl):  # -> 16 rows of 16-bit ints
    bw,bh,bx,by=gl['bbx']; rows=[0]*16
    top=16-2-by-bh  # baseline guess: descent 2
    if bh==16: top=0
    for r,v in enumerate(gl['bits']):
        y=top+r
        if 0<=y<16: rows[y]=(v>>(16+bx)) & 0xffff if bx>=0 else (v>>16)&0xffff
    return rows
def ter_cells(otb):
    f=ImageFont.truetype(otb,16); out={}
    for c in list(range(0x20,0x7f))+list(range(0xa0,0x100)):
        im=Image.new('1',(8,16),0); d=ImageDraw.Draw(im); d.text((0,0),chr(c),font=f,fill=1)
        out[c]=[sum((1<<(7-x)) for x in range(8) if im.getpixel((x,y))) for y in range(16)]
    return out
