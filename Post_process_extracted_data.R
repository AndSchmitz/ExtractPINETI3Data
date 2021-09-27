#init-----
rm(list=ls())
graphics.off()
options(warnPartialMatchDollar = T)

library(tidyverse)

WorkDir <- "/path/to/working/directory´"


#Prepare I/O
IODir <- file.path(WorkDir,"Output")


#Read output from Extract_point_data_from_ESRI_ASCII_raster.R-------
ExtractedData <- read.table(
  file = file.path(IODir,"ExtractedData.csv"),
  header = T,
  sep = ";",
  stringsAsFactors = F
)


#Extract information from RasterFileName column-------
OutputLong <- ExtractedData %>%
  mutate(
    #Extract Year from RasterFileName
    Year = str_extract(
      string = RasterFileName,
      pattern = "\\d\\d\\d\\d" #sequence of 4 digits
    ),
    #Extract Substance from RasterFileName
    #if neither "NH4" nor "NO3" appear in RasterFileName,
    #set Substance to "ERROR"
    Substance = case_when(
      grepl(x = RasterFileName, pattern = "NH4") ~ "NH4",
      grepl(x = RasterFileName, pattern = "NO3") ~ "NO3",
      TRUE ~ "ERROR"
    ),
    #Extract FluxType from RasterFileName
    #if neither "wet" nor "dry" nor "occult" appear in RasterFileName,
    #set FluxType to "ERROR"
    FluxType = case_when(
      grepl(x = RasterFileName, pattern = "wet") ~ "wet",
      grepl(x = RasterFileName, pattern = "dry") ~ "dry",
      grepl(x = RasterFileName, pattern = "occult") ~ "occult",
      TRUE ~ "ERROR"
    ),
    #Extract LandUseClass from RasterFileName
    #if none of the LandUseClasss listed below are found in
    #RasterFileName, set LandUseClass to NA. This is e.g. the case for
    #wet deposition.
    LandUseClass = case_when(
      grepl(x = RasterFileName, pattern = "ara") ~ "ara",
      grepl(x = RasterFileName, pattern = "cnf") ~ "cnf",
      grepl(x = RasterFileName, pattern = "crp") ~ "crp",
      grepl(x = RasterFileName, pattern = "dec") ~ "dec",
      grepl(x = RasterFileName, pattern = "grs") ~ "grs",
      grepl(x = RasterFileName, pattern = "mix") ~ "mix",
      grepl(x = RasterFileName, pattern = "oth") ~ "oth",
      grepl(x = RasterFileName, pattern = "sem") ~ "sem",
      grepl(x = RasterFileName, pattern = "urb") ~ "urb",
      grepl(x = RasterFileName, pattern = "wat") ~ "wat",
      TRUE ~ NA_character_
    )
  )
#Some sanity checks
if ( any( OutputLong$Substance == "ERROR" ) ) {
  stop("Failed to extract the field Substance from RasterFileName. This should not happen.")
}
if ( any( OutputLong$FluxType == "ERROR" ) ) {
  stop("Failed to extract the field FluxType from RasterFileName. This should not happen.")
}
if ( any( is.na(OutputLong$LandUseClass) & (OutputLong$FluxType != "wet") ) ) {
  stop("NA land use type found for a non-wet deposition flux. This should not happen.")
}
if ( any( (OutputLong$FluxType == "occult") & !(OutputLong$LandUseClass %in% c("mix","cnf","dec")) ) ) {
  stop("Occult flux type present for a non-forest land use type. This should not happen.")
}
#Drop RasterFileName column after all relevant information has been extracted.
OutputLong <- OutputLong %>%
  dplyr::select(-RasterFileName)


#Create wet deposition fluxes for each land use class------
#(for consistency - they are bundled into land use class NA until here)
OutputLong <- OutputLong %>%
  #Recode land use class for wet deposition from NA to "all"
  replace_na(replace = list(LandUseClass = "all"))
#Add wet deposition for each land use class
for ( LUC in unique(OutputLong$LandUseClass) ) {
  if ( LUC == "all" ) next
  tmp <- OutputLong %>%
    filter(
      LandUseClass == "all"
    ) %>%
    mutate(
      LandUseClass = LUC
    )
  OutputLong <- bind_rows(OutputLong,tmp)
}
OutputLong <- OutputLong %>%
  filter(
    LandUseClass != "all"
  )


#Reshape from long to wide format-------
OutputWide <- OutputLong %>%
  mutate(
    #Create a string that becomes the new column names
    DepoString = paste(FluxType,Substance,sep="_"),
    #Convert from eqN/ha/yr to  to kgN/ha/yr
    #Adjust depending on what data is present in raster files
    RasterValue = round(RasterValue / 71.428,3)
  ) %>%
  dplyr::select(-FluxType,-Substance) %>%
  #Reshape table from long to wide
  pivot_wider(
    id_cols = c("LocationName","Year","LandUseClass"),
    names_from = DepoString,
    values_from = RasterValue
  ) %>%
  #Set occult deposition from NA to zero for non-forest land use types
  replace_na(
    replace = list(
      occult_NH4 = 0,
      occult_NO3 = 0
    )
  )


#Calculate some aggregated fluxes---------
#Adjust depending on what data is present in raster files
OutputWide <- OutputWide %>%
  mutate(
    dry = dry_NH4 + dry_NO3,
    wet = wet_NH4 + wet_NO3,
    occult = occult_NH4 + occult_NO3,
    NH4 = dry_NH4 + wet_NH4 + occult_NH4,
    NO3 = dry_NO3 + wet_NO3 + occult_NO3,
    Ninorg = dry + wet + occult,
    #Add a column indicating the unit of measurements
    unit = "kgN/ha/yr"
  )


#Write results------
write.table(
  x = OutputWide,
  file = file.path(IODir,"ExtractedDataWideFormat.csv"),
  sep = ";",
  row.names = F
)






