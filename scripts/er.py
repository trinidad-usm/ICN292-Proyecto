"""Genera docs/img/er-3fn.dot/.png a partir de db/alimentos_emy.db (lee el esquema real con PRAGMA)."""
import sqlite3, subprocess, sys
from pathlib import Path
root = Path(__file__).resolve().parent.parent
con = sqlite3.connect(root / "db" / "alimentos_emy.db")
tablas = [r[0] for r in con.execute("select name from sqlite_master where type='table' and name not like 'stg_%' and name not like 'sqlite_%' and name<>'parametro' order by rowid")]
lines = ['digraph ER {', 'graph [rankdir=LR, splines=ortho, nodesep=0.5, ranksep=0.9, fontname="Helvetica", bgcolor="white"];',
         'node [shape=plain, fontname="Helvetica", fontsize=10];', 'edge [fontname="Helvetica", fontsize=9, color="#555555", dir=none, labelfontsize=11, labelfontcolor="#c00000"];']
for t in tablas:
    cols = con.execute(f"pragma table_info({t})").fetchall()
    fks = {r[3] for r in con.execute(f"pragma foreign_key_list({t})")}
    rows = ''.join(f'<tr><td align="left" port="{c[1]}">{"<b>PK</b> " if c[5] else ""}{"<i>FK</i> " if c[1] in fks else ""}{c[1]}</td><td align="left"><font color="#666666">{c[2] or ""}</font></td></tr>' for c in cols)
    lines.append(f'{t} [label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4"><tr><td colspan="2" bgcolor="#1f4e79"><font color="white"><b>{t}</b></font></td></tr>{rows}</table>>];')
seen=set()
for t in tablas:
    for r in con.execute(f"pragma foreign_key_list({t})"):
        key=(t,r[2])
        if key in seen: continue
        seen.add(key)
        lines.append(f'{r[2]} -> {t} [taillabel="1", headlabel="N"];')
lines.append('}')
(root/"docs"/"img"/"er-3fn.dot").write_text("\n".join(lines))
subprocess.run(["dot","-Tpng","-Gdpi=170",str(root/"docs/img/er-3fn.dot"),"-o",str(root/"docs/img/er-3fn.png")],check=True)
print("ok", len(tablas), "tablas")
