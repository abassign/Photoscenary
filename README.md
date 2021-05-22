# Photoscenary
Programs to generate and manipulate photoscenaries for FGFS

The program is written entirely in JULIA and therefore requires JULIA to be installed on your system.
The program is run with the command:

julia -t 4 photoscenary.jl -p /home/user/photoscenery/Orthophotos --lat 45.66 --lon 9.7 -r 15 -s 3

where:

-p : the path of photoscenary
--lat : the latitude of the central location of the area
--lon : the longitude of the central location of the area
-r : the radius of the area to be covered with the photoscenary
-s : Max size of image in pixels 0->512 1->1024 2->2048 3->4096 4->8192 5->16384 6->3276
     
The program has other options:
--latll --lonll : latitude and longitude of lower left corner of the area
--latur --lonur : latitude and longitude of upper right corner of the area
--over : Forces overwriting of scenario files. with a numerical value greater than or equal to 1. This option allows you to build variable size photoscenaries of the tiles, for example it is possible to create a low resolution photo scene in a large area, for example 100 nm, but then make a photo scene around an airport with a high resolution 10 nm radius
-d : with a numerical value greater than or equal to 1 the debug log is activate

The complete manual has been posted on the Flightgear wiki:

https://wiki.flightgear.org/Julia_photoscenery_generator
