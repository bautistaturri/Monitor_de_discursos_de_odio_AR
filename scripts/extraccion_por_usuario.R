#############################################################
# 0) LIBRERÍAS
#############################################################

library(twscrapeR)
library(dplyr)
library(readr)
library(stringr)
library(glue)
library(tibble)

#############################################################
# 1) SETUP DE SCRAPER Y CUENTA
#############################################################

setup_twscraper()

# << COMPLETAR ACÁ TUS DATOS >>
add_account(
  username = "manfredulises",
  password = "hola1234T@",
  email = "turribautista551@gmail.com",
  email_password = "hola1234T",
  cookies = "auth_token=604424db8b2ef8a689c366c02148a4cf4c327091; ct0=2729ffa91e2d0d9f8c6d62117e951e443d2ae5f68268ba88bc7bda1a8dafc172a39ffa61bb020fe4ea7968a5fbed23b41e5024be04ef0e206ff3a10387f8930924ea34a909100c6f4d2e1a884ac1c070"
)
search_tweets("from:UNSAM_ECYT", n = 50)


#############################################################
# 2) FUNCIÓN PRINCIPAL: EXTRAER TWEETS POR USUARIOS
#############################################################

extraer_tweets_usuarios <- function(
    archivo_usuarios,
    fecha_inicio = "2025-11-01",
    fecha_fin    = "2025-11-07",
    output_dir   = "data/usuarios/"
) {
  
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  usuarios <- read_csv(archivo_usuarios, show_col_types = FALSE)
  
  resultados <- list()
  log_df <- tibble()
  
  nombre_con_fecha <- function(prefix) {
    paste0(prefix, "_", format(Sys.Date(), "%d_%m_%Y"), ".csv")
  }
  
  for (u in usuarios$usuario) {
    
    message("==> Extrayendo tweets de: ", u)
    t_ini <- Sys.time()
    
    #### NIVEL 1 - RANGO ####
    q1 <- glue("from:{u} since:{fecha_inicio} until:{fecha_fin}")
    n1_df <- to_dataframe(search_tweets(q1, n = 1000))
    n1_df$nivel <- 1
    n1_df$usuario_objetivo <- u
    n1_df$periodo <- "rango"
    
    #### NIVEL 2 - RANGO ####
    q2 <- glue("to:{u} since:{fecha_inicio} until:{fecha_fin}")
    n2_df <- to_dataframe(search_tweets(q2, n = 1000))
    n2_df$nivel <- 2
    n2_df$usuario_objetivo <- u
    n2_df$periodo <- "rango"
    
    #### NIVEL 1 - HOY ####
    n1_hoy <- to_dataframe(search_tweets(glue("from:{u}"), n = 200))
    n1_hoy$nivel <- 1
    n1_hoy$usuario_objetivo <- u
    n1_hoy$periodo <- "ejecucion"
    
    #### NIVEL 2 - HOY ####
    n2_hoy <- to_dataframe(search_tweets(glue("to:{u}"), n = 200))
    n2_hoy$nivel <- 2
    n2_hoy$usuario_objetivo <- u
    n2_hoy$periodo <- "ejecucion"
    
    #### COMBINAR ####
    df_usuario <- bind_rows(n1_df, n2_df, n1_hoy, n2_hoy)
    resultados[[u]] <- df_usuario
    
    #### LOG ####
    t_fin <- Sys.time()
    log_df <- bind_rows(
      log_df,
      tibble(
        usuario = u,
        cant_tw_nivel1_rango = nrow(n1_df),
        cant_tw_nivel2_rango = nrow(n2_df),
        cant_tw_nivel1_ejec  = nrow(n1_hoy),
        cant_tw_nivel2_ejec  = nrow(n2_hoy),
        duracion_segundos    = as.numeric(difftime(t_fin, t_ini, units = "secs"))
      )
    )
  }
  
  #### GUARDADO ####
  archivo_tw  <- file.path(output_dir, nombre_con_fecha("usuarios_tw"))
  archivo_log <- file.path(output_dir, nombre_con_fecha("LOG_usuarios"))
  
  write_csv(bind_rows(resultados), archivo_tw)
  write_csv(log_df, archivo_log)
  
  message("Tweets guardados en: ", archivo_tw)
  message("Log guardado en: ", archivo_log)
}

#############################################################
# FIN DE FUNCIÓN USUARIOS
#############################################################




#############################################################
# 3) FUNCIÓN PRINCIPAL: EXTRAER TWEETS POR PALABRAS (OR + INDIV)
#############################################################

extraer_tweets_palabras <- function(
    archivo_palabras,
    fecha_inicio = "2025-11-07",
    fecha_fin    = "2025-11-08",
    output_dir   = "data/palabras/"
) {
  
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  palabras <- read_csv(archivo_palabras, col_names = FALSE, show_col_types = FALSE)[[1]]
  
  resultados <- list()
  log_df <- tibble()
  
  nombre_con_fecha <- function(prefix) {
    paste0(prefix, "_", format(Sys.Date(), "%d_%m_%Y"), ".csv")
  }
  
  #############################################################
  # OR TODAS LAS PALABRAS
  #############################################################
  
  palabras_or <- paste0('"', palabras, '"', collapse = " OR ")
  query_or <- glue("({palabras_or}) lang:es since:{fecha_inicio} until:{fecha_fin}")
  
  message("==> OR ejecutado: ", query_or)
  
  t_ini <- Sys.time()
  df_or <- to_dataframe(search_tweets(query_or, n = 2000))
  
  posibles_reply <- c("in_reply_to_status_id", "in_reply_to_tweet_id")
  col_reply <- intersect(posibles_reply, names(df_or))
  
  if (length(col_reply) > 0) df_or <- df_or |> filter(is.na(.data[[col_reply[1]]]))
  if ("is_retweet" %in% names(df_or)) df_or <- df_or |> filter(!is_retweet)
  
  df_or$nivel <- 1
  df_or$tipo  <- "OR"
  
  t_fin <- Sys.time()
  
  log_df <- bind_rows(
    log_df,
    tibble(
      tipo = "OR",
      palabras = paste(palabras, collapse = ", "),
      cant_tw_nivel1 = nrow(df_or),
      duracion_segundos = as.numeric(difftime(t_fin, t_ini, units = "secs"))
    )
  )
  
  resultados[["OR"]] <- df_or
  
  #############################################################
  # INDIVIDUAL POR PALABRA
  #############################################################
  
  for (p in palabras) {
    
    message("==> Individual: ", p)
    
    t_ini <- Sys.time()
    
    query_p <- glue('"{p}" lang:es since:{fecha_inicio} until:{fecha_fin}')
    df_p <- to_dataframe(search_tweets(query_p, n = 2000))
    
    col_reply <- intersect(posibles_reply, names(df_p))
    if (length(col_reply) > 0) df_p <- df_p |> filter(is.na(.data[[col_reply[1]]]))
    if ("is_retweet" %in% names(df_p)) df_p <- df_p |> filter(!is_retweet)
    
    df_p$nivel <- 1
    df_p$palabra <- p
    df_p$tipo <- "individual"
    
    resultados[[p]] <- df_p
    
    t_fin <- Sys.time()
    
    log_df <- bind_rows(
      log_df,
      tibble(
        tipo = "individual",
        palabra = p,
        cant_tw_nivel1 = nrow(df_p),
        duracion_segundos = as.numeric(difftime(t_fin, t_ini, units = "secs"))
      )
    )
  }
  
  #### GUARDADO ####
  archivo_tw  <- file.path(output_dir, nombre_con_fecha("palabras_tw"))
  archivo_log <- file.path(output_dir, nombre_con_fecha("LOG_palabras"))
  
  write_csv(bind_rows(resultados), archivo_tw)
  write_csv(log_df, archivo_log)
  
  message("Tweets guardados en: ", archivo_tw)
  message("LOG guardado en: ", archivo_log)
}

#############################################################
# FIN DE FUNCIÓN PALABRAS
#############################################################




#############################################################
# 4) RESET DE BLOQUEO (por si aparece el error de timeout)
#############################################################

twscrape::reset_locks()

#############################################################
# FIN DEL SCRIPT
#############################################################



extraer_tweets_usuarios(
  archivo_usuarios = "insumos/usuarios.csv",
  fecha_inicio = "2025-11-01",
  fecha_fin = "2025-11-07",
  output_dir = "data/usuarios/"
)


extraer_tweets_palabras(
  archivo_palabras = "insumos/palabras.csv",
  fecha_inicio = "2025-11-07",
  fecha_fin = "2025-11-08",
  output_dir = "data/palabras/"
)

raw <- user_tweets("milei", n = 3)
to_dataframe(raw)


remotes::install_github("agusnieto77/twscrapeR", force = TRUE)

# 1. Actualizar reticulate desde CRAN
install.packages("reticulate")

# 2. Instalar remotes si no lo tenés
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

# 3. Reinstalar twscrapeR desde GitHub
remotes::install_github("agusnieto77/twscrapeR", force = TRUE)

