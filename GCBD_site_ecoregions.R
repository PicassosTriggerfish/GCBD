library(heatwaveR)
library(pryr)
library(sf)
library(dplyr)
library("rnaturalearth")
library("rnaturalearthdata")
library(ggplot2)
library(lwgeom)
library(ncdf4)
library(raster)
library(rgeos)
library(rgdal)
library(maptools)

library(doParallel)
library(foreach)

source("C:/Users/genevilg/Google Drive/Function.r")

world <- ne_countries(scale = "small", returnclass = "sf")

path<-"D:/Global_MHWs/MEOWs/"
newpath<-"E:/GCBD/"
path4<-"C:/Users/GENEVILG/Google Drive/Global_MHWs/"

summaries<-readRDS(paste0(path4, "Ecoregion_climatology_summaries.rds"))

blsummary<-read.csv(paste0(newpath, "Query1_Summary_Bleaching_Cover.csv"))

########################################################################################
ncin = brick("C:/Users/GENEVILG/Google Drive/Global_MHWs/OSTIA-METOFFICE-GLO-SST-L4-NRT-OBS-SST-V2_20070101.nc", varname="analysed_sst")

MER<-st_read("C:/Users/GENEVILG/Google Drive/Coral bleaching/MEOW_FINAL/MEOW/meow_ecos.shp", stringsAsFactors=F)
mer <- st_transform(MER, "+proj=longlat +ellps=WGS84 +datum=WGS84 +init=epsg:4326")

### Refine them to those that contain coral reefs
# mer<- subset(MER, !REALM %in% c("Arctic", "Temperate Northern Atlantic", "Temperate South America", "Temperate Southern Africa", "Southern Ocean"))
# mer<- subset(mer, !ECO_CODE_X %in% c(73, 78, 79, 80, 81, 82, 83, 84, 85, 86, 53, 54, 55, 56, 57, 58, 59, 61, 164,  167, 162, 163, 
#                                      174, 172, 71,  50, 48, 49, 47, 45, 46, 53, 209, 208, 207, 206, 205, 204, 201, 200, 202, 199, 197, 171,  198 , 196, 195, 93))
mer$PROVINCE[mer$PROVINCE==levels(as.factor(mer$PROVINCE))[17]]<-"Somali_Arabian"
mer$PROVINCE[mer$PROVINCE=="Western Coral Triangle"]

##############################################################################################################################################################
### Get the Ecoregion
##############################################################################################################################################################

cb<-read.csv(paste0(newpath, "Query1_Summary_Bleaching_Cover.csv"))%>% rename(Lat=Latitude_Degrees, Long=Longitude_Degrees)

cb1<-cb %>% filter(Date_Year>=1985)  %>% mutate(Number=1)%>% group_by(Lat, Long, Site_ID) %>% 
  summarise(Number=sum(Number, na.rm=TRUE))
cb1<-st_as_sf(cb1, coords = c("Long", "Lat"), 
              crs = 4326, agr = "constant") %>% mutate(Ecoregion=as.character(NA), Province=as.character(NA), Realm=as.character(NA))

for (i in 1:nrow(cb1)) {
  test<-st_intersection(cb1[i,], mer)
  print(paste0(i/nrow(cb1)*100, " percent complete"))
  
  if(nrow(test)>0){
    cb1[i,]$Ecoregion<-test$ECOREGION
    cb1[i,]$Province<-test$PROVINCE
    cb1[i,]$Realm<-test$REALM
    
  }
}



cb2<-as.data.frame(cbind(cb1, st_coordinates(cb1))) %>% dplyr::select(-geometry) %>% rename(Lat=Y, Long=X)
cb3<-left_join(cb, cb2)

saveRDS(cb3, paste0(newpath, "/GCBD_sites_by_MEOWEcoregions.rds"))  
cb3<-readRDS(paste0(newpath, "/GCBD_sites_by_MEOWEcoregions.rds"))


##############################################################################################################################################################
### Look at the amount of severe bleaching records
##############################################################################################################################################################
data<-cb3 %>% filter(Percent_Bleached_Sum>=30)
nas<-cb3 %>% filter(is.na(Percent_Bleached_Sum))%>% filter()
severena<- nas %>% filter(Severity_Code=="Severe (>50% Bleached)" | Bleaching_Prevalence_Score==">50% Reef Area Bleached")
rcna<-nas %>% filter(Data_Source=="Reef_Check") ## a lot of reefcheck sites with only hard coral cover estimates and not bleaching 
data<-rbind(data, severena) 
data<- data %>% filter(Bleaching_Level!="Population") ## remove data of percent of colony populations bleached

eventsonly<-unique(data[,c("Sample_ID", "Data_Source", "Lat", "Long","Ecoregion", "Date_Day", "Date_Month", "Date_Year")])

ecoregionsummary<- eventsonly%>% mutate(n=1) %>% group_by(Ecoregion) %>% 
  summarise(Total_event=sum(n))


nobleaching<-cb3 %>% filter(Percent_Bleached_Sum==0)
noblsummary<- unique(nobleaching[,c("Sample_ID", "Data_Source", "Lat", "Long","Ecoregion", "Date_Day", "Date_Month", "Date_Year")])%>% mutate(n=1) %>% group_by(Ecoregion) %>% 
  summarise(No_bl_surveys=sum(n))

ecoregionsummary<- left_join(ecoregionsummary, noblsummary)
ecoregionsummary <- ecoregionsummary %>% filter(!is.na(No_bl_surveys), Total_event>=5, No_bl_surveys>=5)

data<-data[data$Ecoregion %in% ecoregionsummary$Ecoregion,] ## keep only the data with 10 bleaching records or more in an ecoregion
data<-rbind(data, nobleaching[nobleaching$Ecoregion %in% ecoregionsummary$Ecoregion,])

##############################################################################################################################################################
### Get the SST from existing data
##############################################################################################################################################################

data1<-unique(data[,c("Site_ID","Lat","Long","Ecoregion","Province")])
data1$Ecoregion<-gsub("\\/.*","",data1$Ecoregion)
data1<-left_join(data1, summaries[,c("Location","folder")], by=c("Ecoregion"="Location"))

datamissing<-data1[0,]

paths<-unique(data1[,c("Ecoregion","Province","folder")])

for (i in 2:nrow(paths)) {
  thisdata<-data1[data1$Ecoregion== paths$Ecoregion[i],]
  if(file.exists(paste0(path, paths$Province[i], "/", paths$folder[i], "/OSTIA_0.5.rds"))){
    sstcoords0<-readRDS(paste0(path, paths$Province[i], "/", paths$folder[i], "/OSTIA_0.5.rds"))
    sstcoords0<-sstcoords0[,c("lon", "lat")]
    sstcoords0<-unique(sstcoords0) 
    sstcoords<- sstcoords0 %>% mutate(Ecoregion=paths$Ecoregion[i])
    
    sstcoords<-left_join(thisdata[,c("Site_ID","Long","Lat", "Ecoregion")], sstcoords)  %>% rename(Lon=Long)
    
    sstcoords<-unique(sstcoords) %>% mutate(lon=round(lon, digits=3), lat=round(lat, digits=3))%>%
      mutate(AbslatDiff = abs(lat - Lat)) %>%
      mutate(AbslonDiff = abs(lon - Lon)) %>%
      mutate(AbsDiff = AbslatDiff+AbslonDiff) 
    sstcoords<-unique(sstcoords) %>% group_by(Site_ID, Lat, Lon) %>%
      mutate(AbsDiff_r = rank(AbsDiff, ties.method = 'first')) %>%
      filter(AbsDiff_r<=4) 
    sstcoords<-unique(sstcoords) %>% dplyr::select(-AbslatDiff, -AbslonDiff, -AbsDiff_r) 
    # sstcoords<-unique(sstcoords) %>% dplyr::select(-AbslatDiff, -AbslonDiff, -AbsDiff, -AbsDiff_r) 
    
    sstcoords$Site_ID<-gsub(",","",sstcoords$Site_ID)
    length<-sstcoords %>% mutate(nb=1) %>% group_by(Site_ID, Lon, Lat) %>% summarise(total=sum(nb)) 
    
    saveRDS(sstcoords, paste0(path, paths$Province[i],"/", paths$folder[i], "/Coordinates_GCBD_30andover_4closest_5minsurveyspereco.rds"))
    
    rm(sstcoords0)
    
  } else{
    datamissing<-rbind(datamissing, thisdata)
  }
  
  
}

test<-readRDS(paste0(path, paths$Province[i],"/", paths$folder[i], "/Coordinates_GCBD_30andover_4closest_5minsurveyspereco.rds"))
### Need to then verify the Absdiff to check whether they have the pixels (if they don't maybe remove??) 
## Need to add 2020 SST data to the OSTIA files -> then extract all SST data for these data 
## Also get SST from the missing ecoregion 




