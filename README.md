# Photoscenary
Programs to generate and manipulate photoscenaries for FGFS

The program is written entirely in JULIA and therefore requires JULIA to be installed on your system.
The program, for example, you can run it with this command:

julia -t 10 photoscenary.jl --lat 45.66 --lon 9.7 -r 15 -s 3

where:

-p : the path of photoscenary
--lat : the latitude of the central location of the area
--lon : the longitude of the central location of the area
-r : the radius of the area to be covered with the photoscenary
-s : the resolution of the individual tiles (0 = 512x256 1 = 1024x512 2 = 2048x1024 3 = 4096x2048) 
     Two new resolutions are planned in the future: 4 = 8192.4096 and 5 = 16384x8192
     
The program has other options:
--latll --lonll : latitude and longitude of lower left corner of the area
--latur --lonur : latitude and longitude of upper right corner of the area
--over : Forces overwriting of scenario files. with a numerical value greater than or equal to 1. This option allows you to build variable size photoscenaries of the tiles, for example it is possible to create a low resolution photo scene in a large area, for example 100 nm, but then make a photo scene around an airport with a high resolution 10 nm radius
-d : with a numerical value greater than or equal to 1 the debug log is activate
