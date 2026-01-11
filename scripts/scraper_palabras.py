import asyncio
from twscrape import API
import pandas as pd
from datetime import date, timedelta

# ============================
# fechas: ayer automáticamente
# ============================
hoy = date.today()
ayer = hoy - timedelta(days=1)

SINCE = ayer.strftime("%Y-%m-%d")
UNTIL = hoy.strftime("%Y-%m-%d")

async def buscar_y_guardar(palabra, limite=200):
    api = API()

    query = f'"{palabra}" lang:es since:{SINCE} until:{UNTIL}'
    print("Query:", query)

    resultados = []

    async for tweet in api.search(query, limit=limite):
        resultados.append({
            "id": tweet.id,
            "fecha": tweet.date,
            "usuario": tweet.user.username if tweet.user else None,
            "texto": tweet.rawContent.replace("\n", " "),
        })

    print(f"\nTweets obtenidos: {len(resultados)}")

    if len(resultados) == 0:
        print("No hubo resultados para esa búsqueda.")
        return

    # convertir a DataFrame
    df = pd.DataFrame(resultados)

    # nombre automático con fecha y palabra
    nombre_archivo = f"tweets_{palabra}_{SINCE}.csv"

    df.to_csv(nombre_archivo, index=False, encoding="utf-8-sig")

    print(f"\nCSV guardado como: {nombre_archivo}")

async def main():
    palabra = "maduro"   # 🔁 cambiá acá la palabra
    await buscar_y_guardar(palabra, limite=300)

if __name__ == "__main__":
    asyncio.run(main())
