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

