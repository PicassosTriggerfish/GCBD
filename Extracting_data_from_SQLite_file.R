## Extracting data from SQLite file (.db)
## scripts at https://github.com/InstituteForGlobalEcology/Coral-bleaching-a-global-analysis-of-the-past-two-decades/ 


library(RSQLite)
library(DBI)

con <- dbConnect(RSQLite::SQLite(), "E:/Global_Coral_Bleaching_Database_SQLite_11_24_21.db")

tables<-dbListTables(con)

dbListTables(con)


## Table with bleaching from all the different databases they used 
bltable<-dbGetQuery(conn=con, statement=paste("SELECT * FROM '", tables[[4]], "'", sep=""))

## 
query6<-dbGetQuery(conn=con, statement=paste("SELECT * FROM '", tables[[17]], "'", sep=""))


rcode<-dbGetQuery(conn=con, statement=paste("SELECT * FROM '", tables[[18]], "'", sep=""))
