import os, html
OUT=os.path.expanduser('~/cos/kit/docs/images/')
W=1200
def e(s): return html.escape(s, quote=True)
# columns: (x, w)
C={'req':(24,330),'bot':(394,140),'lane':(574,150),'eng':(764,190),'res':(994,182)}
ROWS=[
 dict(req="What's on my calendar tomorrow?", bot=('CHIEF','chief'), lane=None, eng=('Grok','grok'), res="Answer in chat. No Mac."),
 dict(req="Draft a reply to Greta about the shortlist", bot=('CHIEF','chief'), lane=None, eng=('Grok · cassidy-voice','grok'), res="Gmail draft. You send it."),
 dict(req="Which of my cards are stale?", bot=('CHIEF','chief'), lane=('quick','mac'), eng=('Cursor Agent','cursor'), res="Five lines citing make stale"),
 dict(req="What did David decide on golden sets, Nov 5?", bot=('CHIEF','chief'), lane=('investigate','mac'), eng=('Claude Code','claude'), res="Quotes with timestamps, checked"),
 dict(req="Draft a DADR for the Bedrock exception", bot=('CHIEF','chief'), lane=('draft','mac'), eng=('Claude Code','claude'), res="Own branch, PR staged for you"),
 dict(req="Daily capture onto the board", tag='SCHEDULED 16:00', bot=('STEWARD','steward'), lane=('investigate → apply','apply'), eng=('Claude Code, then none','claude'), res="Batch by sha256. You approve."),
 dict(req="Prototype the IQA low-confidence flag", bot=('BUILDER','builder'), lane=('pair · build','build'), eng=('Claude + verifier + Codex','claude'), res="Proven slice, draft PR to owner"),
 dict(req="STEWARD keeps miscounting stale cards", bot=('CHIEF → KEEPER','keeper'), lane=('note → eval','keeper'), eng=('Claude, judged by Codex','codex'), res="Tested fix. You apply it."),
 dict(req="Find the transcript for the OGD call", bot=('CHIEF','chief'), lane=('browser, not Mac','none'), eng=('Grok computer','grok'), res="Saved to the Mac, after your yes"),
]
TOP=150; RH=56; BH=36
parts=[]
P=parts.append
# group bands
bandY=TOP-46; bandH=len(ROWS)*RH+50
P(f'<rect class="band grok" x="{C["bot"][0]-12}" y="{bandY}" width="{C["bot"][1]+24}" height="{bandH}" rx="10"/>')
P(f'<rect class="band mac" x="{C["lane"][0]-12}" y="{bandY}" width="{C["eng"][0]+C["eng"][1]-C["lane"][0]+24}" height="{bandH}" rx="10"/>')
P(f'<text class="grp" x="{C["bot"][0]+C["bot"][1]/2}" y="{bandY+20}">GROK BOT · CLOUD</text>')
P(f'<text class="grp" x="{(C["lane"][0]+C["eng"][0]+C["eng"][1])/2}" y="{bandY+20}">YOUR MAC · cos-run · or the Bot\'s browser</text>')
for k,label in [('req','REQUEST'),('bot','WHO TAKES IT'),('lane','LANE'),('eng','ENGINE'),('res','RESULT')]:
    x,w=C[k]; anchor='start' if k in('req','res') else 'middle'; tx=x if anchor=='start' else x+w/2
    P(f'<text class="colh" x="{tx}" y="{TOP-8}" text-anchor="{anchor}">{label}</text>')
for i,r in enumerate(ROWS):
    y=TOP+i*RH; cy=y+BH/2
    if i: P(f'<line class="rule" x1="24" x2="{W-24}" y1="{y-10}" y2="{y-10}"/>')
    # request
    if r.get('tag'):
        P(f'<rect class="tag" x="{C["req"][0]}" y="{y+1}" width="{len(r["tag"])*6.6+14}" height="16" rx="8"/><text class="tagt" x="{C["req"][0]+7}" y="{y+13}">{e(r["tag"])}</text>')
        P(f'<text class="req" x="{C["req"][0]}" y="{y+33}">{e(r["req"])}</text>')
    else:
        P(f'<text class="req q" x="{C["req"][0]}" y="{cy+5}">“{e(r["req"])}”</text>')
    boxes=[]
    for k in ('bot','lane','eng'):
        x,w=C[k]; v=r[k]
        if v is None:
            P(f'<line class="skip" x1="{x+10}" x2="{x+w-10}" y1="{cy}" y2="{cy}"/><text class="none" x="{x+w/2}" y="{cy-6}">no Mac</text>')
            continue
        label,kind=v
        P(f'<g class="pill k-{kind}"><rect x="{x}" y="{y}" width="{w}" height="{BH}" rx="7"/><text x="{x+w/2}" y="{cy+5}">{e(label)}</text></g>')
        boxes.append((x,w))
    # arrows: request end -> first box, between boxes, last box -> result
    pts=[(C['req'][0]+C['req'][1]+4, None)]
    seq=[(C['req'][0]+C['req'][1]+2, C['req'][0]+C['req'][1]+2)]+[(x,x+w) for x,w in boxes]
    for a,b in zip(seq, seq[1:]+[(C['res'][0]-6,C['res'][0]-6)]):
        x1=a[1]+2; x2=b[0]-4
        if x2-x1>8: P(f'<line class="flow" x1="{x1}" x2="{x2}" y1="{cy}" y2="{cy}" marker-end="url(#arr)"/>')
    P(f'<text class="res" x="{C["res"][0]}" y="{cy+5}">{e(r["res"])}</text>')
# decision rule
DY=TOP+len(ROWS)*RH+40
P(f'<text class="h2" x="24" y="{DY}">How the Chief picks a lane</text>')
P(f'<text class="sub2" x="24" y="{DY+22}">Cheapest lane that can do the job. Every Claude job gets a checker. Every write needs your yes on its sha256.</text>')
qy=DY+48; qh=52; qw=196; gap=36
Q=[("Mail, Slack, calendar, web?",None),("One command answers it?",None),("A doc or repo change?",None),("Building software?",None)]
OUTS=[("Chief does it itself","Grok","grok"),("quick lane","Cursor Agent","cursor"),("draft lane","Claude Code","claude"),("BUILDER · pair or build","Claude + verifier + Codex","build")]
x=24
for i,(q,_) in enumerate(Q):
    P(f'<g class="q"><rect x="{x}" y="{qy}" width="{qw}" height="{qh}" rx="26"/><text x="{x+qw/2}" y="{qy+31}">{e(q)}</text></g>')
    # yes down
    ox=x; oy=qy+qh+46
    P(f'<line class="flow" x1="{x+qw/2}" x2="{x+qw/2}" y1="{qy+qh+2}" y2="{oy-4}" marker-end="url(#arr)"/><text class="yn" x="{x+qw/2+8}" y="{qy+qh+27}">yes</text>')
    t1,t2,k=OUTS[i]
    P(f'<g class="pill k-{k}"><rect x="{ox}" y="{oy}" width="{qw}" height="48" rx="7"/><text x="{ox+qw/2}" y="{oy+20}">{e(t1)}</text><text class="small" x="{ox+qw/2}" y="{oy+37}">{e(t2)}</text></g>')
    # no right
    nx=x+qw+gap
    P(f'<line class="flow" x1="{x+qw+2}" x2="{nx-4}" y1="{qy+qh/2}" y2="{qy+qh/2}" marker-end="url(#arr)"/><text class="yn" x="{x+qw+gap/2}" y="{qy+qh/2-7}" text-anchor="middle">no</text>')
    x=nx
P(f'<g class="pill k-claude"><rect x="{x}" y="{qy}" width="{W-24-x}" height="{qh}" rx="7"/><text x="{x+(W-24-x)/2}" y="{qy+22}">investigate lane</text><text class="small" x="{x+(W-24-x)/2}" y="{qy+40}">Claude Code, changes nothing</text></g>')
P(f'<text class="foot" x="24" y="{qy+qh+46+48+30}">Canon or label builds skip the Codex review (canon charter decision 14). Grok never runs a command on the Mac unattended: scheduled jobs start on the Mac and push receipts.</text>')
H=qy+qh+46+48+52
css='''text{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;fill:var(--ink)}
.bg{fill:var(--bg);stroke:var(--rule)}
.band{fill:var(--band);stroke:none}
.grp{font-size:11px;font-weight:700;letter-spacing:.08em;fill:var(--muted);text-anchor:middle}
.colh{font-size:11px;font-weight:700;letter-spacing:.08em;fill:var(--muted)}
.title{font-size:22px;font-weight:700}
.lede{font-size:13px;fill:var(--muted)}
.rule{stroke:var(--rule);stroke-width:1}
.req{font-size:13.5px;font-weight:500}
.req.q{font-style:italic}
.tag{fill:none;stroke:var(--steward);stroke-width:1.2}
.tagt{font-size:10px;font-weight:700;letter-spacing:.06em;fill:var(--steward)}
.pill rect{fill:var(--surface);stroke:var(--c);stroke-width:1.8}
.pill text{font-size:12.5px;font-weight:600;text-anchor:middle}
.pill text.small{font-size:11px;font-weight:400;fill:var(--muted)}
.k-chief{--c:var(--chief)}.k-steward{--c:var(--steward)}.k-builder{--c:var(--builder)}.k-keeper{--c:var(--keeper)}
.k-mac{--c:var(--mac)}.k-apply{--c:var(--amber)}.k-build{--c:var(--builder)}.k-grok{--c:var(--ink)}
.k-cursor{--c:var(--mac)}.k-claude{--c:var(--claude)}.k-codex{--c:var(--codex)}
.k-none rect{stroke-dasharray:4 3}.k-none{--c:var(--muted)}
.flow{stroke:var(--muted);stroke-width:1.3}
.skip{stroke:var(--rule);stroke-width:1.3;stroke-dasharray:3 4}
.none{font-size:10px;fill:var(--muted);text-anchor:middle;letter-spacing:.04em}
.res{font-size:12.5px;fill:var(--muted)}
.ah{fill:var(--muted)}
.h2{font-size:17px;font-weight:700}
.sub2{font-size:12.5px;fill:var(--muted)}
.q rect{fill:var(--band);stroke:var(--rule);stroke-width:1.2}
.q text{font-size:12px;font-weight:600;text-anchor:middle}
.yn{font-size:11px;fill:var(--muted);font-weight:600}
.foot{font-size:11.5px;fill:var(--muted)}'''
themes={
 'light':'--bg:#f6f7f9;--surface:#ffffff;--band:#eceef3;--ink:#15181e;--muted:#5a6170;--rule:#d3d7df;--amber:#b26a00;--chief:#2f55c8;--steward:#b26a00;--builder:#8a3fb5;--keeper:#c0392b;--mac:#3d4452;--claude:#c96442;--codex:#10a37f',
 'dark':'--bg:#161b22;--surface:#0d1117;--band:#1d232c;--ink:#e8eaf0;--muted:#9aa1b0;--rule:#30363d;--amber:#e9a23b;--chief:#7d9bff;--steward:#e9a23b;--builder:#c38bea;--keeper:#f07b6e;--mac:#aab2c2;--claude:#e8916f;--codex:#3ccfa0',
}
head=f'<text class="title" x="24" y="42">Who does what</text><text class="lede" x="24" y="66">Nine real requests, traced from the bot that takes them to the engine that does the work.</text><text class="lede" x="24" y="84">Grok handles conversation, mail and routing. Cursor answers one-command lookups. Claude Code does anything multi-step. Codex checks Claude.</text>'
for name,vars_ in themes.items():
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Routing: nine example requests traced through the Grok bot that takes them, the Mac lane, and the engine, with the Chief's decision rule for picking a lane.">
<style>svg{{{vars_}}}
{css}</style>
<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="ah" d="M0 0 L10 5 L0 10 z"/></marker></defs>
<rect class="bg" x="0.5" y="0.5" width="{W-1}" height="{H-1}" rx="14"/>
{head}
{chr(10).join(parts)}
</svg>
'''
    open(OUT+f'workflow-{name}.svg','w').write(svg)
print(H)
