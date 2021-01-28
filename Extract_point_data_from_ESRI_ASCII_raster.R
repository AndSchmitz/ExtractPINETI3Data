#init-----
rm(list=ls())
graphics.off()
options(warnPartialMatchDollar = T)

library(raster)
library(tidyverse)

WorkDir <- "/path/to/working/directory´"


#Prepare I/O
#InDir must contain the PointCoords.csv file (top-level) and the .asc raster files (potentially in subfolders) 
InDir <- file.path(WorkDir,"Input")
OutDir <- file.path(WorkDir,"Output")
dir.create(OutDir,showWarnings = F)


#Prepare point coordinates data------------

#_Sanity check point coords input file----
PointCoords <- read.table(
  file = file.path(InDir,"ExamplePointCoords.csv"),
  header = T,
  sep = ";",
  stringsAsFactors = F
)
#Check that all required columns are present
ExpectedCols <- c("LocationName","LatWGS84","LonWGS84")
MissCols <- ExpectedCols[!(ExpectedCols %in% colnames(PointCoords))]
if ( length(MissCols) > 0 ) {
  stop(paste("The following column(s) are missing in the PointCoords input file:",paste(MissCols,collapse = ",")))
}
#Drop unused cols
PointCoords <- PointCoords[,ExpectedCols]
#Convert LocationName to character in case it was imported as numeric
PointCoords$LocationName <- as.character(PointCoords$LocationName)
#Check that coords are numeric
if ( !is.numeric(PointCoords$LatWGS84) | !is.numeric(PointCoords$LonWGS84) ) {
  stop("All values in columns LatWGS84 and LonWGS84 must be numeric (. as decimal separator).")
}
#Check that LocationName is unique
Dups <- PointCoords$LocationName[duplicated(PointCoords$LocationName)]
if ( length(Dups) > 0 ) {
  stop(paste("The following values for LocationName appear multiple times in the PointCoords input file:",paste(Dups,collapse = ",")))  
}
PointCoords <- PointCoords %>%
  arrange(LocationName)
#Check that all coords where data should be extracted are in Germany
#https://de.wikipedia.org/wiki/Liste_der_Extrempunkte_Deutschlands
DEMaxNorth <- 55.0846
DEMinSouth <- 47.271679
DEMaxEast <- 15.043611
DEMinWest <- 5.866944
if ( any(PointCoords$LatWGS84 > DEMaxNorth) ) {
  stop(paste("Some requested coordinated are north of Germany (Lat > ",DEMaxNorth,")"))
}
if ( any(PointCoords$LatWGS84 < DEMinSouth) ) {
  stop(paste("Some requested coordinated are south of Germany (Lat < ",DEMinSouth,")"))
}
if ( any(PointCoords$LonWGS84 > DEMaxEast) ) {
  stop(paste("Some requested coordinated are east of Germany (Lat > ",DEMaxEast,")"))
}
if ( any(PointCoords$LonWGS84 < DEMinWest) ) {
  stop(paste("Some requested coordinated are west of Germany (Lat < ",DEMinWest,")"))
}
#Point coords input file seems to be OK

#_Convert point coords to spatial object------
#with projection WGS84 (EPSG4326)
#Change here if your point data comes in different format
PointDataCoordinates <- SpatialPoints(
  coords = PointCoords[,c("LonWGS84","LatWGS84")],
  proj4string = CRS(
    projargs  = "+init=EPSG:4326"
  )
)

#Convert this spatial points objects holding the coordinates
#to the same projection as the PINETI3 raster files
#(GK3 = EPSG31467)
suppressWarnings(
  PointDataCoordinatesGK3 <- sp::spTransform(
    x = PointDataCoordinates,
    CRSobj = CRS(
      projargs  = "+init=EPSG:31467"
    )
  )
)

#Prepare PINETI .asc-------- 
#List  files in all subfolders
FileList <- list.files(
  path = InDir,
  pattern = ".asc",
  full.names = T,
  recursive = T
)

#Check number of raster files
nFiles = length(FileList)
nFiles

#Check for uniqueness of raste file names accross folders
Basenames <- basename(FileList)
RasterDups <- Basenames[duplicated(Basenames)]
if ( length(RasterDups) > 0 ) {
  stop(paste("The following raster file names occur multiple times accross folders. Raster file names must be unique.",paste(RasterDups,collapse = ",")))
}


#Extract data------------
ExtractedData <- data.frame()

print(paste("Processing",length(FileList),"files..."))
pb <- txtProgressBar(min = 0, max = length(FileList), style = 3)
for ( iFile in 1:length(FileList) ) {
  setTxtProgressBar(pb, iFile)

  CurrentFilePath <- FileList[iFile]

  #PINETI3 raster files come in "ESRI ASCII Raster format"
  #http://resources.esri.com/help/9.3/arcgisdesktop/com/gp_toolref/spatial_analyst_tools/esri_ascii_raster_format.htm
  CurrentRaster = raster(
    x = CurrentFilePath
  )
  #Set projection to GK3
  suppressWarnings(
    projection(CurrentRaster) <- CRS(
      projargs  = "+init=EPSG:31467"
    )
  )
  
  #Extract data
  tmp <- raster::extract(
    x = CurrentRaster,
    y = PointDataCoordinatesGK3,
    method = "simple"
  )
  
  #Add information on StationName and RasterFileName
  CurrentExtractedData <- data.frame(
    LocationName = PointCoords$LocationName,
    RasterFileName = basename(CurrentFilePath),
    RasterValue = tmp
  )
  
  #Add data extracted from current file to overall results
  ExtractedData <- bind_rows(ExtractedData,CurrentExtractedData)

}
close(pb)


#Write results------
write.table(
  x = ExtractedData,
  file = file.path(OutDir,"ExtractedData.csv"),
  sep = ";",
  row.names = F
)



