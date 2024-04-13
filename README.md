# Photoscenary
Programs to generate and manipulate photoscenaries for FGFS.

The program is written entirely in JULIA and therefore requires JULIA to be installed on your system.
It is a command line program and currently has no GUI.

## Quick guide
Elaborate instructions in a complete manual can be found at the [FlightGear Wiki](https://wiki.flightgear.org/Julia_photoscenery_generator).

A list of changes / history can be found in [Versions.md](Versions.md).

### Installation
If you use Linux, chances are good your distribution already provides packages.
Otherwise, install manually:

- Install julia (version <=1.6 needed): https://julialang.org/downloads/
- Install ImageMagick: https://imagemagick.org/script/download.php
- Install photoscenary.jl (clone this repo, or download the [zipfile](https://github.com/abassign/Photoscenary/archive/refs/heads/main.zip))

### Usage
- `julia photoscenary.jl -h` (or `--help`) will print version and usage information.
- `julia photoscenary.jl --version` will print version and perform checks on needed programs.

#### Basic call
Running `julia photoscenary.jl` without arguments will run the program with the last commands.  
They are read from the `args.txt` file in the base directory.

##### Simple example using coordinates
The program, for basic example, you can run it with this command:

`julia -t 4 photoscenary.jl -p /home/user/photoscenery/Orthophotos --lat 45.66 --lon 9.7 -r 15 -s 3`

where:
```
-p      the path of photoscenery
--lat   the latitude of the central location of the area
--lon   the longitude of the central location of the area
-r      the radius of the area to be covered with the photoscenary
-s      Max size of image in pixels 0->512 1->1024 2->2048 3->4096 4->8192 5->16384 6->32768
```

##### Simple example using Airport ID
You may also download around a airport using its ICAO code (`-i <ICAO>`):
`julia -t 4 photoscenary.jl -p /home/user/photoscenery/Orthophotos -i LIMJ -r 15 -s 3`

##### Use SkyVector route
You can use a GPX route made by skyvector to download scenery along that path (`--route <file.gpx>`):
`julia -t 4 photoscenary.jl -p /home/user/photoscenery/Orthophotos --route https://wiki.flightgear.org/mySkyVectorRoute.gpx -r 15 -s 3`

### Using the tiles in FlightGear
To make FlightGear load the downloaded tiles, you need to tell it to:
- In the FGFS launcher, add the photoscenery folder as you would with "normal" addon scenery.
  Just add the folder that you specified with the `-p` option as Addon-scenery (hint: it contains a sufolder named `Orthophotos`).
- When FlightGear started, activate the option: _Menu > View > Rendering Options > Satellite Photoscenery_
