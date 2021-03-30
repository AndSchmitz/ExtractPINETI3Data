# ExtractPINETI3Data

These R scripts extract data from raster files representing output of the "PINETI3" model at user-specified point coordinates. Data is provided on request by the German Environmet Agency (UBA). See the [UBA website](https://www.umweltbundesamt.de/themen/luft/wirkungen-von-luftschadstoffen/wirkungen-auf-oekosysteme/kartendienst-stickstoffdeposition-in-deutschland) or the [FAQ](https://gis.uba.de/website/depo1/download/Erlaeuterungen_DepoKartendienst_UBA_PINETI3.pdf) for more information. The workflow to extract data is split into two parts. 



## Extract_point_data_from_ESRI_ASCII_raster.R

Raster files provided by the UBA are regular [ESRI ASCII raster files.](
http://resources.esri.com/help/9.3/arcgisdesktop/com/gp_toolref/spatial_analyst_tools/esri_ascii_raster_format.htm) The script "Extract_point_data_from_ESRI_ASCII_raster.R" allows to extract point data from ESRI ASCII raster files (i.e. is not restricted to PINETI3 data).

Input:
 - A .csv file with point locations where to extract data. See ExamplePointCoords.csv for an example file. Column names, column separator and decimal separator must exactly match those in ExamplePointCoords.csv. Note that coordinates of point locations must come in WGS84 format (EPSG:4326) - or else the conversion of the projection must be adjusted in the script.
 - A folder storing the raster files (.asc files). Raster files might be distributed among several subfolders, but there must not be two raster files with the same name across all folders. See DummyRasters.zip for an example folder structure (this is dummy data with random integer values between 0 and 100). Note that raster files must come in DHDN / 3-degree Gauss-Kruger zone 3 (EPSG 31467) format (as the PINETI3 data provided by UBA) - or else the conversion of the projection must be adjusted in the script.

Output:

 - ExtractedData.csv with the following structure:
 
| LocationName | RasterFileName| RasterValue  |
| -------------|-------------| -----|
| Location_A | DummyData_2000_fluxdry_NH4_ara.asc | 5.2 |
| Location_B | DummyData_2015_fluxoccult_NH4_dec.asc |   4.2 |
| Location_C | DummyData_2015_fluxwet_NH4.asc | 1.3 |
    					
    

## Post_process_extracted_data.R

This R script processes the output of Extract_point_data_from_ESRI_ASCII_raster.R to yield data that is easier to work with. In particular, information stored in the RasterFileName column is extracted (e.g. FluxType (dry/wet/occult), land use type, etc.). This step depends on the exact information received from the UBA. Thus, it will be necessary to adjust the code for applying this script to other sets of raster files.

Input:

- The output of Extract_point_data_from_ESRI_ASCII_raster.R

Output:

- ExtractedDataWideFormat.csv with columns: "LocationName","Year","LandUseClass","dry_NH4","dry_NO3","occult_NH4","occult_NO3","wet_NH4","wet_NO3","dry","wet","occult","NH4","NO3","Ninorg","unit"


## Validation against data from UBA web map viewer

See Validation_against_data_from_UBA_web_map_viewer.pdf for information how the input raster files and the two R scripts described above have been validated against data from the [UBA web map viewer for N deposition](https://gis.uba.de/website/depo1/).


