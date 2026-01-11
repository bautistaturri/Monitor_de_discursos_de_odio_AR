import asyncio
from twscrape import API
import pandas as pd
from datetime import date, timedelta
import re


# fechas
hoy = date.today()
ayer = hoy - timedelta(days=1)

SINCE = ayer.strftime("%Y-%m-%d")
UNTIL = hoy.strftime("%Y-%m-%d")

# ============================
# palabras clave de Argentina
# ============================
ARGENTINA_KEYWORDS = [
    "argentina", "buenos aires", "bs as", "caba",
    "rosario", "cordoba", "córdoba", "mendoza", "tucuman",
    "neuquen", "santa fe", "mar del plata", "misiones",
    "salta", "jujuy", "chubut", "santa cruz", "entre rios"
]

def es_argentino(tweet):
    # 1) lugar explícito del tweet (cuando lo hay)
    if getattr(tweet, "place", None):
        if getattr(tweet.place, "countryCode", None) == "AR":
            return True

    
    if tweet.user and tweet.user.location:
        loc = tweet.user.location.lower()

        
        loc = re.sub(r"[^a-záéíóúüñ\s]", " ", loc)

        for k in ARGENTINA_KEYWORDS:
            if k in loc:
                return True

    return False


async def buscar_y_guardar(palabra, limite=300):
    api = API()

    query = f'"{palabra}" lang:es since:{SINCE} until:{UNTIL}'
    print("Query:", query)

    tweets = []  

    async for tweet in api.search(query, limit=limite):
        tweets.append(tweet)

    print(f"\nTweets obtenidos totales: {len(tweets)}")

    # ============================
    # filtrar argentinos estimados
    # ============================
    argentinos = [t for t in tweets if es_argentino(t)]
    print(f"Tweets estimados de Argentina: {len(argentinos)}")

    if len(argentinos) == 0:
        print("No se detectaron tweets de Argentina.")
        return

    # pasamos a dataframe
    resultados = []
    for t in argentinos:
        resultados.append({
            "id": t.id,
            "fecha": t.date,
            "usuario": t.user.username if t.user else None,
            "ubicacion_perfil": t.user.location if t.user else None,
            "texto": t.rawContent.replace("\n", " "),
        })

    df = pd.DataFrame(resultados)

    nombre_archivo = f"tweets_{palabra}_{SINCE}_ARG.csv"
    df.to_csv(nombre_archivo, index=False, encoding="utf-8-sig")

    print(f"\nCSV guardado como: {nombre_archivo}")


async def main():
    palabra = "Zurdo"
    await buscar_y_guardar(palabra, limite=500)

if __name__ == "__main__":
    asyncio.run(main())
