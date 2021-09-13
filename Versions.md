# Versioning

## 0.3.4 date 20210809

Correction of Unicode characters (Aa for example Chinese characters) in file names as https://docs.julialang.org/en/v1/manual/strings/#Unicode-and-UTF-8
Commons.jl in the getFileName function
The old code is: filename[1:fl-1]
the new code is: filename[1:prevind(filename,fl)]

## 0.3.5 date 20210816

Modified the common.jl module, the module has been reorganized with the structure:
module PhotoscenaryCommons and the file name is: PhotoscenaryCommons.jl

Various errors have been corrected in the management of the automatic variation of the file size according to the distance. Vertical distance has also been introduced in order to reduce the size of the tiles on the vertical. The calculation is inserted in the function: getSizePixelWidthByDistance and has this algorithm:
sizePixelFound = Int64 (size - round ((size-sizeDwn) * sqrt (distance ^ 2 + altitudeNm ^ 3.0) * 1.5 / radius))
The cubic exponent is used to increase the size reduction factor also as a function of the height with respect to the ground.

The function has been changed connector.getFGFSPositionSetTask introducing the radiusStepFactor parameter with value 0.5 This allows a more frequent update when the program is connected with FGFS and dynamically downloads the tiles images.

These changes allow to have a dynamic management of the images of the tiles during the flight and works well up to mach 0.9 with a fast ADSL connection (20 Mbit / s)

## 0.3.8 date 20210902

### Automatic path
The automatic path completion has been inserted if the program is connected to FGFS with the --connect parameter.
The path will be the one described in the parameter:
/sim/fg-scenery

### Autosave mode
The autosave mode is only active if the program is connected to FGFS or if it is following a route.
This mode allows you to define a save path (if not explicitly defined with the --save parameter), with the path of the Orthophotos followed by the sub-name '-saved'.
For example:
Path to locate the DDS/PNG orthophotos files: '/media/abassign/test/fgfs-scenery/photoscenery/Orthophotos'
Path to save the DDS/PNG orthophotos files: '/media/abassign/test/fgfs-scenery/photoscenery/Orthophotos-saved'

### --nosave parameter
If you want to inhibit the autosave mode, just enter the --nosave parameter in the command line.

### Automatic deletion of unreadable DDS or PNG files
The automatic deletion of the files takes place during the scanning of the files in the preparatory phase for the execution.

### End the program with CTRL-c
The support for closing the program with CTRL-C has been improved, but it is still not perfect as a result of an error in the case that the --connect option is active and the FGFS program is not yet active.

### TilesDatabase.jl
the createFilesListTypeDDSandPNG (...) function has been modified by inserting a mutithread search. In this way instead of taking for example 40 seconds to analyze all the images (about 8000 in the test computer) it takes 10 seconds with 6 threads.
This search function is essential for managing the automatic saving of images if their resolution is changed.

## 0.3.9 date 20210905

### Skyvector import route
Since version 0.3.9 the automatic conversion of files produced with Skyvector has been defined. The file in .gpx format is automatically converted to produce the equivalent route to the file produced by the FGFS route manager.

### More precise search of the route files
More precise search of the route files inserted with the --route parameter. The files are searched first if they are inside the directory containing the program, if they are not inside the directory, the scan is done inside the user's home directory.

### Module: Route.jl has been introduced
Continue to reorganize the code, now the module: Route.jl has been introduced which contains the functions used by the --route parameter and the airport database used with the --icao option.

### Program exit was reactivated
Program exit was reactivated after all processes were terminated. This feature did not work with version 0.3.8.

## 0.3.10 date 20210913

### Autimatic rebuild of the airports.jdb file
Upon a user recommendation, I have inserted the automatic rebuild of the airports.jdb database file if found corrupt. The database file takes the data from the airports.csv file always present in the directory that contains the photoscenary.ij program.

### Pkg.build("CodecZlib")
The CodecZlib module is sometimes problematic in version management if highly complex packages are installed. The only practical solution is to require the module to be recompiled with the Pkg.build function. Not being able to know the actual installation status of the files, I found it much more convenient to run this command anyway even if the CodecZlib module was well installed.
