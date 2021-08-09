# Photoscenary
Programs to generate and manipulate photoscenaries for FGFS

The program is written entirely in JULIA and therefore requires JULIA to be installed on your system.
The program, for basic example, you can run it with this command:

julia -t 4 photoscenary.jl -p /home/user/photoscenery/Orthophotos --lat 45.66 --lon 9.7 -r 15 -s 3

where:

-p : the path of photoscenary
--lat : the latitude of the central location of the area
--lon : the longitude of the central location of the area
-r : the radius of the area to be covered with the photoscenary
-s : Max size of image in pixels 0->512 1->1024 2->2048 3->4096 4->8192 5->16384 6->32768
     
The complete manual has been posted on the Flightgear wiki:

https://wiki.flightgear.org/Julia_photoscenery_generator
