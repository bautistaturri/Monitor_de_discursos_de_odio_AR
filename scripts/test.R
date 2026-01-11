library(twscrapeR)
library(dplyr)
library(readr)
library(tibble)
library(stringr)
library(glue)

check_setup()
setup_twscraper()

# << COMPLETAR ACÁ TUS DATOS >>
add_account(
  username = "MonitorModerado",
  password = "hola1234T@",
  email = "turribautista78@gmail.com",
  email_password = "hola1234T",
  cookies = "auth_token=6774f952ad619ca1a8c32276714b248b132acbe1; ct0=c0853a57d72c32e2f8dd262a8200f78257657e39145331c8ef7586511dce5f743ae451a80adab46a601fd140e61cc0c85ca533398722ea375952dea87ab2531e0f778e9ceeb31157cd7251f59d9d5cb0"
)
list_accounts()
delete_account("manfredulises")
tweets_raw <- search_tweets("eutanasia lang:es", n = 5)
tweets_df  <- to_dataframe(tweets_raw)
tweets_df
