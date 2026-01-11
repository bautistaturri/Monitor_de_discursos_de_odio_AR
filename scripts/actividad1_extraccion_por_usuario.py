import asyncio
import time
from datetime import datetime
import pandas as pd
from twscrape import API

# =========================
# Rango histórico pedido
# =========================
FECHA_INICIO = "2026-01-01"
FECHA_FIN_INCLUIDA = "2026-01-11"
UNTIL_EXCLUSIVO = "2026-01-11"  # until es exclusivo: para incluir 07/11 usás 08/11

# límites (ajustables)
LIM_RANGO_N1 = 500
LIM_RANGO_N2 = 400
LIM_EJEC_N1  = 300
LIM_EJEC_N2  = 200

def nombre_con_fecha(prefix: str, fecha_fin: str) -> str:
    dt = datetime.strptime(fecha_fin, "%Y-%m-%d")
    return f"{prefix}_{dt.strftime('%d_%m_%Y')}.csv"

async def recolectar(api: API, query: str, limit: int, usuario_objetivo: str, nivel: int, periodo: str):
    rows = []
    async for t in api.search(query, limit=limit):
        rows.append({
            "nivel": nivel,
            "usuario_objetivo": usuario_objetivo,
            "periodo": periodo,  # rango / ejecucion
            "id": getattr(t, "id", None),
            "date": getattr(t, "date", None),
            "text": getattr(t, "rawContent", None),
            "username": getattr(getattr(t, "user", None), "username", None),
            "user_displayname": getattr(getattr(t, "user", None), "displayname", None),
            "user_id": getattr(getattr(t, "user", None), "id", None),
            "reply_count": getattr(t, "replyCount", None),
            "retweet_count": getattr(t, "retweetCount", None),
            "like_count": getattr(t, "likeCount", None),
            "quote_count": getattr(t, "quoteCount", None),
            "views_count": getattr(t, "viewCount", None),
            "lang": getattr(t, "lang", None),
            "url": getattr(t, "url", None),
            "user_followers": getattr(getattr(t, "user", None), "followersCount", None),
            "user_verified": getattr(getattr(t, "user", None), "verified", None),
            "user_location": getattr(getattr(t, "user", None), "location", None),
        })
    return rows

async def correr(archivo_usuarios_csv: str, output_dir: str):
    api = API()

    usuarios = pd.read_csv(archivo_usuarios_csv)
    if "usuario" not in usuarios.columns:
        raise ValueError("El CSV debe tener una columna llamada 'usuario' (sin @).")

    all_rows = []
    log_rows = []

    for u in usuarios["usuario"].dropna().astype(str):
        u = u.strip().lstrip("@")
        if not u:
            continue

        print(f"\n==> Extrayendo: {u}")
        t0 = time.time()

        # --- rango histórico (N1 = from, N2 = to)
        q_n1_r = f"from:{u} since:{FECHA_INICIO} until:{UNTIL_EXCLUSIVO}"
        q_n2_r = f"to:{u} since:{FECHA_INICIO} until:{UNTIL_EXCLUSIVO}"
        n1_r = await recolectar(api, q_n1_r, LIM_RANGO_N1, u, 1, "rango")
        n2_r = await recolectar(api, q_n2_r, LIM_RANGO_N2, u, 2, "rango")

        # --- ejecución (lo más reciente al correr)
        q_n1_e = f"from:{u}"
        q_n2_e = f"to:{u}"
        n1_e = await recolectar(api, q_n1_e, LIM_EJEC_N1, u, 1, "ejecucion")
        n2_e = await recolectar(api, q_n2_e, LIM_EJEC_N2, u, 2, "ejecucion")

        all_rows += (n1_r + n2_r + n1_e + n2_e)

        t1 = time.time()
        log_rows.append({
            "usuario": u,
            "cant_tw_nivel1_7_11": len(n1_r),
            "cant_tw_nivel2_7_11": len(n2_r),
            "cant_tw_nivel1_ejecucion": len(n1_e),
            "cant_tw_nivel2_ejecucion": len(n2_e),
            "duracion_seg": round(t1 - t0, 2),
        })

        print(f"   rango N1={len(n1_r)} N2={len(n2_r)} | ejec N1={len(n1_e)} N2={len(n2_e)} | {round(t1-t0,2)}s")

    df_tw = pd.DataFrame(all_rows)
    df_log = pd.DataFrame(log_rows)

    out_tw  = f"{output_dir}/{nombre_con_fecha('usuarios_tw', FECHA_FIN_INCLUIDA)}"
    out_log = f"{output_dir}/{nombre_con_fecha('LOG_usuarios', FECHA_FIN_INCLUIDA)}"

    df_tw.to_csv(out_tw, index=False, encoding="utf-8-sig")
    df_log.to_csv(out_log, index=False, encoding="utf-8-sig")

    print("\n Guardado:", out_tw)
    print(" Guardado:", out_log)

if __name__ == "__main__":
    asyncio.run(correr("../insumos/usuarios.csv", "../data/usuarios_5"))
