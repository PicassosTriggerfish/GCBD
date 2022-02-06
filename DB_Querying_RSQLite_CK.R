library(RSQLite)
library(DBI)

new <- dbConnect(SQLite(), "E:/GCBD/Bleaching_SQL.db") #connect to the database
new <- dbConnect(SQLite(), "C:/Users/Chelsey/Desktop/Bleaching_SQL.db") #connect to the database
dbListTables(new) #shows all the tables in the database
dbListFields(new, "Site_Info_tbl") #shows all the fields in the specified table
dbListFields(new, "Sample_Event_tbl")#shows all the fields in the specified table

All_Sites <- dbSendQuery(new, "SELECT Site_Info_tbl.ID AS Site_ID, Data_Source_LUT.Data_Source, Site_Info_tbl.Latitude_Degrees, Site_Info_tbl.Longitude_Degrees
                         FROM Data_Source_LUT INNER JOIN Site_Info_tbl ON Data_Source_LUT.ID = Site_Info_tbl.Data_Source") #Queries for all the lat/longs and shows their data source
dbFetch(All_Sites) #shows results of query

Only_Reef_Check <- dbSendQuery(new, "SELECT Site_Info_tbl.ID AS Site_ID, Data_Source_LUT.Data_Source, Site_Info_tbl.Latitude_Degrees, Site_Info_tbl.Longitude_Degrees
                               FROM Data_Source_LUT INNER JOIN Site_Info_tbl ON Data_Source_LUT.ID = Site_Info_tbl.Data_Source WHERE Data_Source_LUT.Data_Source= 'Reef_Check'") #query specifying to only return Reef_Check results
dbFetch(Only_Reef_Check)

Sample_Events <- dbSendQuery(new, "SELECT Site_Info_tbl.ID AS Site_ID, Data_Source_LUT.Data_Source, Site_Info_tbl.Latitude_Degrees, Site_Info_tbl.Longitude_Degrees, Ecoregion_Name_LUT.Ecoregion_Name, Country_Name_LUT.Country_Name, Sample_Event_tbl.Date_Day, Sample_Event_tbl.Date_Month, Sample_Event_tbl.Date_Year, Sample_Event_tbl.Depth_m
                             FROM Country_Name_LUT INNER JOIN (Ecoregion_Name_LUT INNER JOIN ((Data_Source_LUT INNER JOIN Site_Info_tbl ON Data_Source_LUT.ID = Site_Info_tbl.Data_Source) INNER JOIN Sample_Event_tbl ON Site_Info_tbl.ID = Sample_Event_tbl.Site_ID) ON Ecoregion_Name_LUT.ID = Site_Info_tbl.Ecoregion_Name) ON Country_Name_LUT.ID = Site_Info_tbl.Country_Name") #query for all sampling events
dbFetch(Sample_Events)

Bleaching_population <- dbSendQuery(new, "SELECT Site_Info_tbl.ID AS Site_ID, Data_Source_LUT.Data_Source, Site_Info_tbl.Latitude_Degrees, Site_Info_tbl.Longitude_Degrees, Ecoregion_Name_LUT.Ecoregion_Name, Country_Name_LUT.Country_Name, Sample_Event_tbl.Date_Day, Sample_Event_tbl.Date_Month, Sample_Event_tbl.Date_Year, Sample_Event_tbl.Depth_m, Bleaching_Level_LUT.Bleaching_Level, Bleaching_tbl.S1, Bleaching_tbl.S2, Bleaching_tbl.S3, Bleaching_tbl.S4
                                    FROM Bleaching_Level_LUT INNER JOIN ((Country_Name_LUT INNER JOIN (Ecoregion_Name_LUT INNER JOIN ((Data_Source_LUT INNER JOIN Site_Info_tbl ON Data_Source_LUT.ID = Site_Info_tbl.Data_Source) INNER JOIN Sample_Event_tbl ON Site_Info_tbl.ID = Sample_Event_tbl.Site_ID) ON Ecoregion_Name_LUT.ID = Site_Info_tbl.Ecoregion_Name) ON Country_Name_LUT.ID = Site_Info_tbl.Country_Name) INNER JOIN Bleaching_tbl ON Sample_Event_tbl.ID = Bleaching_tbl.Sample_ID) ON Bleaching_Level_LUT.ID = Bleaching_tbl.Bleaching_Level
                                    WHERE Data_Source_LUT.Data_Source='Reef_Check'") #query for population bleaching data from Reef Check
dbFetch(Bleaching_population)

dbDisconnect(new) #closes connection to the database
