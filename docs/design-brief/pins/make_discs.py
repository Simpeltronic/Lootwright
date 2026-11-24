# Questie-style option: item icon on a small light disc. Backdrop textures + a mock on Simon's real map.
# Run from the scratchpad folder that holds map_crop.png and find_skulls.py.
from PIL import Image, ImageDraw, ImageFilter
import ast, subprocess, sys, os
P=os.path.dirname(os.path.abspath(__file__))+'/'
SS=8; N=64
DARK=(20,23,28)
TINT={'target':(236,214,160),'farm':(184,240,196)}   # light brass / light green, tints of #C9A24A and #4FD36A
def disc(tint,style):
  big=N*SS; im=Image.new('RGBA',(big,big)); d=ImageDraw.Draw(im)
  if style=='glow':      # soft feathered disc, like Questie's markers
    m=Image.new('L',(big,big),0); ImageDraw.Draw(m).ellipse((6*SS,6*SS,big-6*SS,big-6*SS),fill=255)
    m=m.filter(ImageFilter.GaussianBlur(5*SS)); im=Image.new('RGBA',(big,big),tint+(255,)); im.putalpha(m)
  else:                  # solid disc with a thin dark rim
    d.ellipse((2*SS,2*SS,big-2*SS,big-2*SS),fill=DARK+(255,)); d.ellipse((5*SS,5*SS,big-5*SS,big-5*SS),fill=tint+(255,))
  return im.resize((N,N),Image.LANCZOS)
def pin(icon,tint,style,square):
  im=disc(tint,style); s=34 if square else 40
  ic=icon.convert('RGBA').resize((s,s),Image.LANCZOS)
  if not square:
    m=Image.new('L',(s*SS,s*SS),0); ImageDraw.Draw(m).ellipse((0,0,s*SS-1,s*SS-1),fill=255); ic.putalpha(m.resize((s,s),Image.LANCZOS))
  im.alpha_composite(ic,((N-s)//2,(N-s)//2)); return im
opts=[('D1','glow',True,'soft glow, square icon (closest to Questie)'),
      ('D2','glow',False,'soft glow, round icon'),
      ('D3','rim',False,'light disc with dark rim, round icon')]
shot=Image.open(r'Z:/Blizzard/World of Warcraft/_forever_/Screenshots/WoWScrnShot_112426_103914.jpg')
silk=shot.crop((22,842,38,858))
herb=Image.new('RGB',(16,16),(60,150,50)); ore=Image.new('RGB',(16,16),(130,130,140))
for k,st,sq,_ in opts:
  for role in TINT:
    disc(TINT[role],st).save(P+f'disc_{role}_{k}.png')
base=Image.open('map_crop.png').convert('RGBA')
pts=ast.literal_eval(subprocess.check_output([sys.executable,'-I','find_skulls.py','map_crop.png'],text=True).splitlines()[1])
farm_pts=[p for p in pts if p[0]<560 and p[1]>60]; tgt_pts=[(140,95),(300,250),(420,190),(250,330),(470,265)]
W=1200; rows=[]
for k,st,sq,desc in opts:
  im=base.copy()
  for i,(x,y) in enumerate(farm_pts):
    ic=[silk,ore,herb][i%3]; p=pin(ic,TINT['farm'],st,sq).resize((14,14),Image.LANCZOS); im.alpha_composite(p,(x-7,y-7))
  for x,y in tgt_pts:
    p=pin(silk,TINT['target'],st,sq).resize((17,17),Image.LANCZOS); im.alpha_composite(p,(x-8,y-8))
  row=Image.new('RGBA',(W,420),DARK+(255,)); d=ImageDraw.Draw(row)
  d.text((10,6),f'{k}: {desc}   (target | farm at 64 px, then 14 / 12 px; right: your map at 2x)',fill=(232,228,216,255))
  for j,(ic,role) in enumerate([(silk,'target'),(silk,'farm'),(herb,'farm'),(ore,'farm')]):
    p=pin(ic,TINT[role],st,sq); row.alpha_composite(p,(10+(j%2)*80,40+(j//2)*150))
    row.alpha_composite(p.resize((14,14) if role=='target' else (12,12),Image.LANCZOS),(30+(j%2)*80,115+(j//2)*150))
  row.alpha_composite(im.crop((60,30,560,220)).resize((1000,380),Image.NEAREST),(190,32)); rows.append(row)
sheet=Image.new('RGB',(W,sum(r.height for r in rows)),DARK); y=0
for r in rows: sheet.paste(r,(0,y)); y+=r.height
sheet.save(P+'discs_on_map.png')
