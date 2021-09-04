#=

Autor: Adriano Bassignana Bargamo 2021
Licence: GPL 2

Exite code:
0 - regular execution
1 - The version check did not pass

Performance:
On average with a 70 mbit connection (7-8 MB / s) the ArcGIS site from a flow of 1 MB / s (8 mbit) This places a limit on the download capacity,
I don't know if it can be amplified with multiple connections, but I think not, as it is related to the IP of the machine.
The only possibility is to parallelize with more sophisticated techniques.
However if the files are large it is not necessary to increase the number of threads too much julia -t 6 can be absolutely fine in these cases.
While if smaller formats are used (series -c 0,1,2) the advantage of many threads is considerable.

Behavior of the program:
Currently it does not leave logs during some activities, eg it can be quite depressing not to see anything when starting a
download with very large images (eg 8K or 16K) especially if you use a lot of threads.
In this case all the work takes place in the background and no messages are observed.
Don't worry, the program is doing its job. However, a more effective monitor will soon be added.

----------

Execution with thread and CPU

julia -t 10 -p 2 photoscenary.jl ...

it is possible to manage multithreaded and multi CPU processes with Julia through these two options:
-t m : The maximum number of threads that can be followed simultaneously.
-p n : The number of CPUs that can be used

----------

Search LAT and LON from Airport Tower Freq Radio

    using CSV
    using CSVFiles
    using DataFrames
    using DataFramesMeta

df = CSV.File("airports.csv"; normalizenames=true, delim=" ", select=["LAT","LON","ICAO","NAME"], decimal='.')
...
CSV.Row: (LAT = -17.9318, LON = 31.0928, ICAO = "FVHA")

Search airport ID

for r in df
    if cmp(r[3],"LIME") == 0 println(r) end
end

=#

using Pkg

if VERSION < v"1.5.4"
    println("The actiual Julia is ",VERSION, " The current version is too old!\nPlease upgrade Julia to version 1.5.0 but preferably install the 1.6.x or later (exit code 500)")
    ccall(:jl_exit, Cvoid, (Int32,), 500)
elseif VERSION >= v"1.6.0"
    println("The actiual Julia is ",VERSION, " The current version is correct in order to obtain the best performances")
else
    println("The actiual Julia is ",VERSION, " The current version is correct,\nIn order to obtain the best performancesy install the 1.6.x or later version")
end


versionProgram = "0.3.8"
versionProgramDate = "Testing 20210901"

homeProgramPath = pwd()
unCompletedTiles = Dict{Int64,Int64}()

println("\nPhotoscenary.jl ver: $versionProgram date: $versionProgramDate System prerequisite test\n")


begin

    local restartIsRequestCauseUpgrade = 0

    try
        ##using ImageView
        using JuliaDB
    catch
        restartIsRequestCauseUpgrade = 2
    end

    try
        import ImageMagick
        import Unicode: graphemes # To solve the problem of an error in extracting unicode characters from a string.
        using Dates
        using Unicode
        using Downloads
        using Logging
        using Distributed
        using LightXML
        using ArgParse
        using Printf
        using HTTP
        using FileIO
        using Images
        using ImageIO
        using DataFrames
        using DataFramesMeta
        using Geodesy
        using Parsers
        using Sockets
        using EzXML
        using ThreadSafeDicts
    catch
        if restartIsRequestCauseUpgrade == 0 restartIsRequestCauseUpgrade = 1 end
    end

    try
        if restartIsRequestCauseUpgrade >= 2
            ##Pkg.add("ImageView") # If this is execute is necessary to restart Julia
            Pkg.add("JuliaDB")
        end
        if restartIsRequestCauseUpgrade >= 1
            println("\nInstal the packeges necessary for photoscenary.jl execution")
            Pkg.add("Dates")
            Pkg.add("Unicode")
            Pkg.add("Downloads")
            Pkg.add("Logging")
            Pkg.add("Distributed")
            Pkg.add("LightXML")
            Pkg.add("ImageMagick")
            Pkg.add("ArgParse")
            Pkg.add("Printf")
            Pkg.add("HTTP")
            Pkg.add("FileIO")
            Pkg.add("Images")
            Pkg.add("ImageIO")
            Pkg.add("DataFrames")
            Pkg.add("DataFramesMeta")
            Pkg.add("Geodesy")
            Pkg.add("Parsers")
            Pkg.add("Sockets")
            Pkg.add("EzXML")
            Pkg.add("ThreadSafeDicts")
            println("\nThe Julia system has been updated")
        end
    catch err
        println("\nProblems loading library modules, program execution will now be interrupted\nError: $err (exit code 500)")
        ccall(:jl_exit, Cvoid, (Int32,), 500)
    end

    if restartIsRequestCauseUpgrade >= 2
        println("\nThe Julia packeges and extra packeges has been updateds!\n\n\tNote: Sometimes, especially on Windows machines,\n\tafter the restart, there may be print some orrors messages,\n\tnormally there is no problem if you wait a few tens of seconds, if the system seems to stop,\n\tyou can give a CTRL-C and restart the program execution operation again.\n\tThe package management system will solve any problems in the next restart of the program.\n\nNow the program ends and a re-execution is requested (exit code 100)")
        ccall(:jl_exit, Cvoid, (Int32,), 100)
    end

end

@everywhere using SharedArrays

try
    #include("commons.jl")
    include("./Commons.jl")
    include("./TilesDatabase.jl")
    include("./Connector.jl")
    include("./Geodesics.jl")
catch err
    println("\nError, the PhotoscenaryCommons.jl file or the tilesDatabase.jl file is missing\nCheck that the files are loaded in the same directory that contains the photoscenary.jl program.\n$err")
    ccall(:jl_exit, Cvoid, (Int32,), 500)
end


# Inizialize section

function inizializeParams()
    # Build the paramsXml
    paramsXml = nothing
    if isfile("params.xml")
        paramsXml = parse_file("params.xml")
        if "params" == lowercase(name(LightXML.root(paramsXml)))
            xroot = LightXML.root(paramsXml)
            ces = get_elements_by_tagname(xroot,"versioning")
            if ces != nothing && find_element(ces[1],"version") != nothing
                set_content(find_element(ces[1],"version"),versionProgram)
            end
        end
    end
    if (paramsXml == nothing)
        paramsXml = parse_string("<params><versioning><version>$versionProgram</version><autor>Adriano Bassignana</autor><year>2021</year><licence>GPL 2</licence></versioning></params>")
    end
    save_file(paramsXml,"params.xml")
end


function inizialize()
    versionFromParams = nothing
    imageMagickPath = nothing
    if isfile("params.xml")
        paramsXml = parse_file("params.xml")
        if "params" == lowercase(name(LightXML.root(paramsXml)))
            xroot = LightXML.root(paramsXml)
            ces = get_elements_by_tagname(xroot,"versioning")
            if ces != nothing && size(ces)[1] > 0 && find_element(ces[1],"version") != nothing
                versionFromParams = content(find_element(ces[1],"version"))
            end
            img = get_elements_by_tagname(xroot,"imageMagick")
            if img != nothing && size(img)[1] > 0 && find_element(img[1],"path") != nothing
                imageMagickPath = strip(content(find_element(img[1],"path")))
                if length(imageMagickPath) == 0 imageMagickPath = nothing end
            end
        end
    end
    if versionFromParams == nothing || versionFromParams != versionProgram
        println("\nThe program version is change old version is $versionFromParams the actual version is $versionProgram ($versionProgramDate)")
        inizializeParams()
    end
    println('\n',"Photoscenery generator by Julia compilator,\nProgram for uploading Orthophotos files\n")
    paramsXml = parse_file("params.xml")
    if "params" == lowercase(name(LightXML.root(paramsXml)))
        ces = get_elements_by_tagname(LightXML.root(paramsXml),"versioning")
    end
    return imageMagickPath
end



struct MapServer
    id::Int64
    webUrlBase::Union{String,Nothing}
    webUrlCommand::Union{String,Nothing}
    name::Union{String,Nothing}
    comment::Union{String,Nothing}
    proxy::Union{String,Nothing}
    errorCode::Int64

    function MapServer(id,aProxy=nothing)
        try
            serversRoot = get_elements_by_tagname(LightXML.root(parse_file("params.xml")),"servers")
            servers = get_elements_by_tagname(serversRoot[1], "server")
            for server in servers
                if server!= nothing
                    if strip(content(find_element(server,"id"))) == string(id)
                        webUrlBase = strip(content(find_element(server,"url-base")))
                        webUrlCommand = map(c -> c == '|' ? '&' : c, strip(content(find_element(server,"url-command"))))
                        name = strip(content(find_element(server,"name")))
                        comment = strip(content(find_element(server,"comment")))
                        proxy = aProxy
                        return new(id,webUrlBase,webUrlCommand,name,comment,proxy,0)
                    end
                end
            end
            return new(id,nothing,nothing,nothing,nothing,nothing,410)
        catch err
            return new(id,nothing,nothing,nothing,nothing,nothing,411)
        end
    end
end


struct MapCoordinates
    lat::Float64
    lon::Float64
    radius::Float64
    latLL::Float64
    lonLL::Float64
    latUR::Float64
    lonUR::Float64
    isDeclarePolar::Bool
    positionRoute::Union{FGFSPositionRoute,Nothing}

    function MapCoordinates(lat::Float64,lon::Float64,radius::Float64)
        (latLL,lonLL,latUR,lonUR) = PhotoscenaryCommons.latDegByCentralPoint(lat,lon,radius)
        return new(lat,lon,radius,latLL,lonLL,latUR,lonUR,true)
    end

    function MapCoordinates(latLL::Float64,lonLL::Float64,latUR::Float64,lonUR::Float64)
        lon = lonLL + (lonUR - lonLL) / 2.0
        lat = latLL + (latUR - latLL) / 2.0
        lonDist = abs(lonUR - lonLL) / 2.0
        latDist = abs(latUR - latLL) / 2.0
        posLL = LLA(latLL,lonLL, 0.0)
        posUR = LLA(latUR,lonUR, 0.0)
        radius = round(euclidean_distance(posUR,posLL) / 1852.0,digits=2)
        return new(lat,lon,radius,latLL,lonLL,latUR,lonUR,false)
    end

end


function getSizePixel(size)
    if size <= 0
        sizeWidth = 512
        cols = 1
    elseif size <= 1
        sizeWidth = 1024
        cols = 1
    elseif size <= 2
        sizeWidth = 2048
        cols = 1
    elseif size <= 3
        sizeWidth = 4096
        cols = 2
    elseif size <= 4
        sizeWidth = 8192
        cols = 4
    elseif size <= 5
        sizeWidth = 16384
        cols = 8
    else
        sizeWidth = 32768
        cols = 8
    end
    return sizeWidth, cols
end


function getSizePixelWidthByDistance(size,sizeDwn,radius,distance,positionRoute::Union{FGFSPositionRoute,Nothing},unCompletedTilesAttemps)
    if sizeDwn > size sizeDwn = size end
    if unCompletedTilesAttemps > 0
        size = size - unCompletedTilesAttemps
        if size > 2
            size = 2
        elseif size < 0
            size = 0
        end
        sizeDwn = sizeDwn - unCompletedTilesAttemps
        if sizeDwn > 2
            sizeDwn = 2
        elseif sizeDwn < 0
            sizeDwn = 0
        end
    end
    if positionRoute != nothing
        positionRoute.actual == nothing ? altitudeNm = 0.0 : altitudeNm = positionRoute.actual.altitudeFt * 0.000164579
    else
        altitudeNm = 0.0
    end
    sizePixelFound = Int64(round(size - (size-sizeDwn) * sqrt(distance^2.0 + altitudeNm^2.0) * 1.0 / radius))
    if sizePixelFound > size
        return getSizePixel(size)
    elseif sizePixelFound < sizeDwn
        return getSizePixel(sizeDwn)
    else
        return getSizePixel(sizePixelFound)
    end
end


# Coordinates matrix generator
function coordinateMatrixGenerator(m::MapCoordinates,whiteTileIndexListDict,size,sizeDwn,unCompletedTilesAttemps,positionRoute::Union{FGFSPositionRoute,Nothing},isDebug)
    numberOfTiles = 0
    # Normalization to 0.125 deg
    latLL = m.latLL - mod(m.latLL,0.125)
    latUR = m.latUR - mod(m.latUR,0.125) + 0.125
    lonLL = m.lonLL - mod(m.lonLL,PhotoscenaryCommons.tileWidth(m.lat))
    lonUR = m.lonUR - mod(m.lonUR,PhotoscenaryCommons.tileWidth(m.lat)) + PhotoscenaryCommons.tileWidth(m.lat)
    a = [(
            string(lon >= 0.0 ? "e" : "w", lon >= 0.0 ? @sprintf("%03d",floor(abs(lon),digits=-1)) : @sprintf("%03d",ceil(abs(lon),digits=-1)),
                lat >= 0.0 ? "n" : "s", lat >= 0.0 ? @sprintf("%02d",floor(abs(lat),digits=-1)) : @sprintf("%02d",ceil(abs(lat),digits=-1))),
            string(lon >= 0.0 ? "e" : "w", lon >= 0.0 ? @sprintf("%03d",floor(Int,abs(lon))) : @sprintf("%03d",ceil(Int,abs(lon))),
                lat >= 0.0 ? "n" : "s", lat >= 0.0 ? @sprintf("%02d",floor(Int,abs(lat))) : @sprintf("%02d",ceil(Int,abs(lat)))),
            lon,
            lat,
            lon + PhotoscenaryCommons.tileWidth(lat),
            lat + 0.125,
            floor(Int,lat*10),
            PhotoscenaryCommons.index(lat,lon),
            PhotoscenaryCommons.x(lat,lon),
            PhotoscenaryCommons.y(lat),
            PhotoscenaryCommons.tileWidth(lat),
            round(euclidean_distance(LLA(lat + (0.125/2.0),lon + PhotoscenaryCommons.tileWidth(lat)/2.0,0.0),LLA(m.lat,m.lon, 0.0)) / 1852.0 / 2.0,digits=3)
        )
        for lat in latLL:0.125:latUR for lon in lonLL:PhotoscenaryCommons.tileWidth(lat):lonUR
    ]
    # print data sort by tile index
    aSort = sort!(a,by = x -> x[12])
    c = nothing
    d = []
    precIndex = nothing
    counterIndex = 0
    for b in aSort
        if whiteTileIndexListDict == nothing || (whiteTileIndexListDict != nothing && haskey(whiteTileIndexListDict,b[8]))
            if precIndex == nothing || precIndex != b[8]
                if c != nothing push!(d,c) end
                c = []
                precIndex = b[8]
                counterIndex = 1
            else
                counterIndex += 1
            end
            (widthByDistance,colsByDistance) = getSizePixelWidthByDistance(size,sizeDwn,m.radius,b[12],positionRoute,unCompletedTilesAttemps)
            t = (b[1],b[2],b[3],b[5],b[4],b[6],b[8],counterIndex,b[11],0,b[12],widthByDistance,colsByDistance)
            push!(c,t)
            push!(c,0)
            numberOfTiles += 1
            if isDebug > 0 println("\nTile id: ",t[7]," coordinates: ",t[1]," ",t[2],
                " | lon: ",@sprintf("%03.6f ",t[3]),
                @sprintf("%03.6f ",t[4]),
                "lat: ",@sprintf("%03.6f ",t[5]),
                @sprintf("%03.6f ",t[6])," | Counter: ",t[8]," Width: ",@sprintf("%03.6f ",t[9]),
                "dist: $(t[11]) size: $(t[12]) | $(t[13])") end
        end
    end
    if c != nothing
        push!(d,c)
    end

    if isDebug > 0
        println("\n----------")
        println("CoordinateMatrix generator")
        println("latLL: ",latLL," lonLL ",lonLL," latUR: ",latUR," lonUR ",lonUR,'\n')
        println("Number of tiles to process: $numberOfTiles")
        println("----------\n")
    end

    return d,numberOfTiles
end



function getMapServerReplace(urlCmd,varString,varValue,errorCode)
    a = replace(urlCmd,varString => string(round(varValue,digits=6)))
    if a != urlCmd
        return a, errorCode
    else
        println("\nError: getMapServerReplace params.xml has problems in the servers section\n\tthe map server with id $id has the $varString value not correct or defined\n\t$webUrlCommand")
        return a, errorCode + 1
    end
end


function getMapServer(m::MapServer,latLL,lonLL,latUR,lonUR,szWidth,szHight)
    urlCmd = m.webUrlCommand
    errorCode = m.errorCode
    if errorCode == 0
        urlCmd,errorCode = getMapServerReplace(urlCmd,"{latLL}",latLL,0)
        urlCmd,errorCode = getMapServerReplace(urlCmd,"{lonLL}",lonLL,errorCode)
        urlCmd,errorCode = getMapServerReplace(urlCmd,"{latUR}",latUR,errorCode)
        urlCmd,errorCode = getMapServerReplace(urlCmd,"{lonUR}",lonUR,errorCode)
        urlCmd,errorCode = getMapServerReplace(urlCmd,"{szWidth}",szWidth,errorCode)
        urlCmd,errorCode = getMapServerReplace(urlCmd,"{szHight}",szHight,errorCode)
        return m.webUrlBase * urlCmd, errorCode > 0 ? 413 : 0
    else
        return "", 412
    end
end


function findFileOfRoute(fileName)
    date = 0.0
    fileId = 0
    route = nothing
    files = findFile(fileName)
    for file in files
        if file[3] > date
            # Test the file
            try
                route = get_elements_by_tagname(LightXML.root(parse_file(file[2])),"route")
                fileId = file[1]
                date = file[3]
            catch
            end
        end
    end
    if fileId > 0
        return route,files[fileId][2]
    else
        return nothing
    end
end


function loadRoute(fileOfRoute,centralPointRadiusDistance)
    routeList = Any[]
    route = findFileOfRoute(fileOfRoute)
    if route != nothing
        wps = get_elements_by_tagname(route[1][1], "wp")
        centralPointRadiusDistanceFactor = 1.5
        centralPointLatPrec = nothing
        centralPointLonPrec = nothing
        for wp in wps
            foundData = false
            if wp != nothing
                if find_element(wp,"icao") != nothing
                    icao = strip(content(find_element(wp,"icao")))
                    (centralPointLat, centralPointLon, errorCode) = selectIcao(icao,centralPointRadiusDistance)
                    if errorCode == 0 foundData = true end
                elseif find_element(wp,"lon") != nothing
                    centralPointLat = Base.parse(Float64, strip(content(find_element(wp,"lat"))))
                    centralPointLon = Base.parse(Float64, strip(content(find_element(wp,"lon"))))
                    foundData = true
                end
                if foundData
                    # Get the distance
                    if centralPointLatPrec != nothing && centralPointLonPrec != nothing
                        posPrec = LLA(centralPointLatPrec,centralPointLonPrec, 0.0)
                        pos = LLA(centralPointLat,centralPointLon, 0.0)
                        distanceNm = euclidean_distance(pos,posPrec) / 1852.0
                    else
                        distanceNm = 0.0
                    end
                    minDistance = centralPointRadiusDistance * centralPointRadiusDistanceFactor
                    if minDistance < distanceNm
                        numberTrunk = Int32(round(distanceNm / minDistance))
                        for i in 1:(numberTrunk - 1)
                            degLat = centralPointLatPrec + i * (centralPointLat - centralPointLatPrec) / numberTrunk
                            deglon = centralPointLonPrec + i * (centralPointLon - centralPointLonPrec) / numberTrunk
                            dist = euclidean_distance(LLA(degLat,deglon, 0.0),posPrec) / 1852.0
                            push!(routeList,(degLat, deglon, dist))
                            println("Load Route step $(size(routeList)[1]).$i coordinates lat: $(round(routeList[end][1],digits=4)) lon: $(round(routeList[end][2],digits=4)) distance: $(round(dist,digits=1))")
                        end
                    end
                    push!(routeList,(centralPointLat, centralPointLon, distanceNm))
                    println("Load Route step $(size(routeList)[1]).0 coordinates lat: $(round(routeList[end][1],digits=4)) lon: $(round(routeList[end][2],digits=4)) distance: $(round(distanceNm,digits=1))")
                    centralPointLatPrec = centralPointLat
                    centralPointLonPrec = centralPointLon
                end
            end
        end
    else
        println("\nError: loadRoute in the route file: $fileOfRoute")
    end
    #ccall(:jl_exit, Cvoid, (Int32,), 405)
    return routeList, size(routeList)[1]
end


#Testing image magick
function checkImageMagick(imageMagickPath)
    imageMagickTest = nothing
    if imageMagickPath != nothing
        println("\ncheckImageMagick - is define a path for imageMagick: $imageMagickPath")
        println("In the params.xml configuration file\n")
    end
    try
        if Base.Sys.iswindows()
            imageMagickStatus = run(`magick convert -version`)
        else
            imageMagickStatus = run(`convert -version`)
        end
        if imageMagickPath == nothing
            imageMagickTest = 1
        else
            imageMagickPath = nothing
            imageMagickTest = 2
        end
    catch err
        try
            if Base.Sys.iswindows()
                imageMagickTest = 4
            elseif imageMagickPath != nothing
                imageMagickWithPathUnix = normpath(imageMagickPath * "/" * "convert")
                imageMagickStatus = run(`$imageMagickWithPathUnix -version`)
                imageMagickTest = 3
            else
                imageMagickTest = 4
            end
            imageMagickPath = nothing
            println("checkImageMagick - ImageMagic is operative!")
        catch err
            imageMagickTest = 5
        end
    end
    if imageMagickTest == 1
        println("\nImageMagic is operative!")
        return true,imageMagickPath
    elseif imageMagickTest == 2
        println("\nImageMagic is operative!")
        if Base.Sys.iswindows() == false
            println("The path is: $imageMagickPath")
            println("This path is not necessary\nI recommend removing it by editing the file: 'params.xml'\ngetting this situation:")
            println("<imageMagick>")
            println("    <path></path>")
            println("</imageMagick>")
        end
        return true,imageMagickPath
    elseif imageMagickTest == 3
        println("\nImageMagic is operative!")
        println("The path is: $imageMagickPath")
        return true,imageMagickPath
    elseif imageMagickTest == 4
        println("\nError: The program, named: 'imageMagick' for converting files into .dds format (Error code 504)\nbut has not been well installed!")
        println("It has often been verified that ImageMagick on Windows should be installed\nonly after having previously uninstalled ImageMagick.")
        println("When installing imageMagick make sure you have at least flegged the following options:")
        println("#1 [x] Add application direcory to your system path")
        println("#2 [x] Install legacy utilities (e.g. convert)")
        println("\nNow this application is stopped waiting for these issues to be fixed")
        println("It is therefore necessary to install the program ImageMagick the home page is: https://imagemagick.org/")
        println("You can install the program at this link: https://imagemagick.org/script/download.php")
        println("If you are with the Windows operating system, absolutely remember, once ImageMagick is installed, to restart the PC!")
        return false,imageMagickPath
    elseif imageMagickTest == 5
        println("\nError: The program imageMagick with the path: $imageMagickPath")
        println("was not found, check if the path was written correctly or 'imageMagick' is installed on your system.")
        return false,imageMagickPath
    end
end


# Select lat lon by ICAO airport id or name or municipality
function selectIcao(icaoToSelect, centralPointRadiusDistance)
    centralPointLat = nothing
    centralPointLon = nothing
    errorCode = 0
    # Test the DB csv or jdb
    if stat("airports.csv").mtime > stat("airports.jdb").mtime
        println("\nThe airports database 'airports.csv' is loading for conversion in airports.jdb file")
        JuliaDB.save(JuliaDB.loadtable("airports.csv"),"airports.jdb")
    elseif stat("airports.jdb").mtime == 0.0
        println("\nError: The airports.jdb file and airports.csv file is unreachable!\nPlease, make sure it is present in the photoscenary.jl program directory")
        errorCode = 403
    end
    if errorCode == 0
        try
            db = JuliaDB.load("airports.jdb")
            # println("\nThe airports database 'airports.csv' is loading")
            searchString = Unicode.normalize(uppercase(icaoToSelect),stripmark=true)
            # Frist step try with ICAO ident
            foundDatas = filter(i -> (i.ident == searchString),db)
            if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] == 0
                foundDatas = filter(i -> occursin(searchString,Unicode.normalize(uppercase(i.municipality),stripmark=true)),db)
            end
            if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] == 0
                foundDatas = filter(i -> occursin(searchString,Unicode.normalize(uppercase(i.name),stripmark=true)),db)
            end
            if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] == 1
                if centralPointRadiusDistance == nothing || centralPointRadiusDistance <= 1.0 centralPointRadiusDistance = 10.0 end
                centralPointLat = foundDatas[1][:latitude_deg]
                centralPointLon = foundDatas[1][:longitude_deg]
                # Some airports have the location data multiplied by a thousand, in this case we proceed to the reduction
                if !(inValue(centralPointLat,90) && inValue(centralPointLon,180))
                    if abs(centralPointLat) > 1000.0 centralPointLat /= 1000.0 end
                    if abs(centralPointLon) > 1000.0 centralPointLon /= 1000.0 end
                end
                println("\nThe ICAO term $(icaoToSelect) is found in the database\n\tIdent: $(foundDatas[1][:ident])\n\tName: $(foundDatas[1][:name])\n\tCity: $(foundDatas[1][:municipality])\n\tCentral point lat: $(round(centralPointLat,digits=4)) lon: $(round(centralPointLon,digits=4)) radius: $centralPointRadiusDistance nm")
            else
                if JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1] > 1
                    errorCode = 401
                    println("\nError: The ICAO search term $(icaoToSelect) is ambiguous, there are $(JuliaDB.size(JuliaDB.select(foundDatas,:ident))[1]) airports with a similar term")
                    cycle = 0
                    for data in foundDatas
                        println("\tId: $(data[:ident])\tname: $(data[:name]) ($(data[:municipality]))")
                        cycle += 1
                        if cycle > 30 break end
                    end
                else
                    errorCode = 400
                    println("\nError: The ICAO search term $(icaoToSelect) is not found in the airports.csv database")
                end
            end
        catch err
            println("\nError: The airports.jdb file is corrupt\n\tPlease, make sure if airports.csv file is present in the program directory\n\tRemove the corrupt airports.jdb file and restart the program\nError code is $err")
            errorCode = 404
        end
    end
    return centralPointLat, centralPointLon, errorCode
end


function fileWithRootHomePath(fileName)
    return normpath(homeProgramPath * "/" * fileName)
end


function setPath(root,pathLiv1,pathLiv2)
    rootDirectoryIsOk = false
    path = root * "/" * pathLiv1 * "/" * pathLiv2
    try
        rootDirFiles = mkpath(path)
        rootDirectoryIsOk = true
        return path
    catch err
        println("The $root directory is inexistent, the directory will be is created")
        return nothing
    end
end


# Analyze the quality of the image
#  > 0  Image quality
# == 0  Image does not exist
#   -1  Image error
# Note: The algorithm does not work for DDS type files
function imageQuality(image, debugLevel)
    if isfile(image)
        try
            img = ImageView.load(image)
            sizeImg = size(img)[1]*size(img)[2]
            if debugLevel > 0 println("imageQuality - The file $image id downloaded the size is: $sizeImg") end
            return sizeImg
        catch err
            if debugLevel > 1 println("Error: imageQuality - The file $image is not downloaded") end
            return -2
        end
    else
        if debugLevel > 1 println("Error: imageQuality - The file $image is not present") end
        return -1
    end
end


function downloadImage(xy,lonLL,latLL,ΔLat,ΔLon,szWidth,szHight,sizeHight,imageWithPathTypePNG,task,mapServer::MapServer,debugLevel)
    # /World_Imagery/MapServer/export?bbox=16.0,38.0,16.125,38.0625&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
    x = xy[1]
    y = xy[2]
    imageMatrix = zeros(RGB{N0f8},szHight,szWidth)
    loLL = lonLL + (x - 1) * ΔLon
    loUR = lonLL + x * ΔLon
    laLL = latLL + (y - 1) * ΔLat
    laUR = latLL + y * ΔLat
    t0 = time()
    downloadPNGIsComplete = 0
    #servicesWebUrlBase = "http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export?"
    #servicesWebUrl = servicesWebUrlBase * "bbox=$loLL,$laLL,$loUR,$laUR&bboxSR=4326&size=$szWidth,$szHight&imageSR=4326&format=png24&f=image"
    (servicesWebUrl,errorCode) = getMapServer(mapServer,laLL,loLL,laUR,loUR,szWidth,szHight)
    if errorCode > 0
        return downloadPNGIsComplete,time()-t0,xy,imageMatrix
    end
    # HTTPD options from https://juliaweb.github.io/HTTP.jl/dev/public_interface/
    if debugLevel > 0 @warn "downloadImage - HTTP image start to download url: $servicesWebUrl" end
    tryDownloadFileImagePNG = 1
    while tryDownloadFileImagePNG <= 2 && downloadPNGIsComplete == 0
        io = IOBuffer(UInt8[], read=true, write=true)
        try
            r = HTTP.request("GET",servicesWebUrl,response_stream = io,proxy=mapServer.proxy)
            if r == nothing || (r != nothing && r.status != 200)
                if debugLevel > 1 @warn "Error: downloadImage #1 - HTTP image download code: " * r.status * " residual try: $tryDownloadFileImagePNG" end
                tryDownloadFileImagePNG += 1
            else
                # In Julia there is a copy function between matrices which foresees to define the coordinates of the starting point.
                # This function is extremely efficient and fast, it allows to obtain a matrix of images.
                # Es: imageMatrix[1 + h * (y - 1):h * y,1 + w * (x - 1):w * x] = img
                try
                    ## imageMatrix[1 + sizeHight - (szHight * y):sizeHight - szHight * (y - 1),1 + szWidth * (x - 1):szWidth * x] = load(Stream(format"PNG", io))
                    imageMatrix = Images.load(Stream(format"PNG", io))
                    if debugLevel > 0 println(" ") end
                    # Print actual status
                    print("\rThe image in ",@sprintf("%03.3f,%03.3f,%03.3f,%03.3f",loLL,laLL,loUR,laUR)," load in the matrix: x = $x y = $y Task: $task th: $(Threads.threadid()) try: $tryDownloadFileImagePNG",@sprintf(" time: %3.2f",(time()-t0)))
                    downloadPNGIsComplete = 1
                catch err
                    if debugLevel > 1 @warn "Error: downloadImage #2 - load image $imageWithPathTypePNG is not downloaded, error id: $err" end
                end
            end
        catch err
            # Typical error type 500
            if debugLevel > 1 @warn "Error: downloadImage #3 - load image $imageWithPathTypePNG generic error id: $err" end
            tryDownloadFileImagePNG += 1
        end
        close(io)
    end
    return downloadPNGIsComplete,time()-t0,xy,imageMatrix
end


function downloadImages(tp,imageWithPathTypePNG,mapServer::MapServer,debugLevel)
    lonLL = tp[3]
    latLL = tp[5]
    lonUR = tp[4]
    latUR = tp[6]
    cols = tp[13]
    sizeWidth = tp[12]
    sizeHight = Int(sizeWidth / (8 * PhotoscenaryCommons.tileWidth((latUR + latLL) / 2.0)))
    #imageMatrix = SharedArray(zeros(RGB{N0f8},sizeHight,sizeWidth))
    imageMatrix = SharedArray(zeros(RGB{N0f8},sizeHight,sizeWidth))
    downloadPNGIsCompleteNumber = 0
    szWidth = Int(sizeWidth / cols)
    szHight = Int(sizeHight / cols)
    ΔLat = (latUR - latLL) / cols
    ΔLon = (lonUR - lonLL) / cols
    indexValues = [(x,y) for x in 1:cols for y in 1:cols]
    fs = Dict{Int,Any}()
    @sync for task in 1:(cols*cols)
        @async fs[task] = downloadImage(indexValues[task],lonLL,latLL,ΔLat,ΔLon,szWidth,szHight,sizeHight,imageWithPathTypePNG,task,mapServer,debugLevel)
    end
    res = Dict{Int,Tuple{Int64, Float64, Tuple{Int64, Int64}, Matrix{RGB{N0f8}}}}()
    @sync for task in 1:(cols*cols)
        @async res[task] = fetch(fs[task])
    end

    for task in 1:(cols*cols)
        x = res[task][3][1]
        y = res[task][3][2]
        imageMatrix[1 + sizeHight - (szHight * y):sizeHight - szHight * (y - 1),1 + szWidth * (x - 1):szWidth * x] = res[task][4]
        downloadPNGIsCompleteNumber += res[task][1]
    end

    if downloadPNGIsCompleteNumber > 0
        try
            Images.save(imageWithPathTypePNG,imageMatrix)
            if debugLevel > 0 println("downloadImage - The file $imageWithPathTypePNG is downloaded") end
        catch
            if debugLevel > 1 println("Error: downloadImage - to download the $imageWithPathTypePNG file, error id: ",err) end
            if isfile(imageWithPathTypePNG) rm(imageWithPathTypePNG) end
        end
    else
        if isfile(imageWithPathTypePNG) rm(imageWithPathTypePNG) end
    end

    return downloadPNGIsCompleteNumber
end


function createDDSorPNGFile(rootPath,tp,overWriteTheTiles,imageMagickPath,mapServer::MapServer,tileDatabase::IndexedTable,isPngFileFormatOnly,pathToSave,debugLevel)

    theBatchIsNotCompleted = false
    t0 = time()
    timeElaboration = nothing
    theDDSorPNGFileIsOk = 0
    tileIndex = 0
    fileSizePNG = 0
    fileSizeDDS = 0
    format = isPngFileFormatOnly ? 0 : 1
    isfileImagePNG = false

    path = setPath(rootPath,tp[1],tp[2])
    if path != nothing
        createDDSorPNGFile = false
        tileIndex = tp[7]
        imageWithPathTypePNG = normpath(path * "/" * string(tileIndex) * ".png")
        imageWithPathTypeDDS = normpath(path * "/" * string(tileIndex) * ".dds")
        # Check the image is present
        if isPngFileFormatOnly
            if isfile(imageWithPathTypeDDS) TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,1,pathToSave) end
            dataFileImagePNG = getPNGSize(imageWithPathTypePNG)
            if dataFileImagePNG[1]
                if overWriteTheTiles >= 9
                    TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave)
                    theDDSorPNGFileIsOk = -1
                elseif overWriteTheTiles == 2 || dataFileImagePNG[2] < 512 || dataFileImagePNG[2] > 32768
                    createDDSorPNGFile = true
                    TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave)
                elseif overWriteTheTiles == 1 && tp[12] > dataFileImagePNG[2]
                    createDDSorPNGFile = true
                else
                    theDDSorPNGFileIsOk = -3
                end
            else
                if isfile(imageWithPathTypePNG) TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave) end
                if overWriteTheTiles < 9
                    createDDSorPNGFile = true
                else
                    theDDSorPNGFileIsOk = -2
                end
            end
        else
            dataFileImageDDS = PhotoscenaryCommons.getDDSSize(imageWithPathTypeDDS)
            dataFileImagePNG = PhotoscenaryCommons.getPNGSize(imageWithPathTypePNG)
            if dataFileImageDDS[1]
                if overWriteTheTiles >= 9
                    TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,1,pathToSave)
                    theDDSorPNGFileIsOk = -1
                elseif overWriteTheTiles == 2 || dataFileImageDDS[2] < 512 || dataFileImageDDS[2] > 32768
                    createDDSorPNGFile = true
                elseif overWriteTheTiles == 1 && tp[12] > dataFileImageDDS[2]
                    createDDSorPNGFile = true
                else
                    theDDSorPNGFileIsOk = -3
                end
            else
                if dataFileImagePNG[1]
                    if overWriteTheTiles >= 9
                        TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave)
                        theDDSorPNGFileIsOk = -1
                    elseif overWriteTheTiles == 2 || dataFileImagePNG[2] < 512 || dataFileImagePNG[2] > 32768
                        isfileImagePNG = false
                        TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave)
                        createDDSorPNGFile = true
                    elseif overWriteTheTiles == 1 && tp[12] >= dataFileImagePNG[2]
                        isfileImagePNG = true
                        createDDSorPNGFile = true
                    else
                        isfileImagePNG = false
                        TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave)
                        createDDSorPNGFile = true
                    end
                else
                    if isfile(imageWithPathTypeDDS) TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,1,pathToSave) end
                    if overWriteTheTiles < 9
                        createDDSorPNGFile = true
                    else
                        theDDSorPNGFileIsOk = -2
                    end
                end
            end
        end
        if createDDSorPNGFile
            # Check if there is a file somewhere that could be used as DDS
            if !isfileImagePNG
                TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,1,pathToSave)
                (foundIndex,foundPath,toPath,isSkip) = TilesDatabase.copyTilesByIndex(tileDatabase,tileIndex,tp[12],rootPath,format)
                if debugLevel > 0 println("createDDSorPNGFile - copyTilesByIndex foundIndex: $foundIndex | foundPath: $foundPath | toPath: $toPath | tileDatabase: $tileDatabase | tileIndex: $tileIndex | tp[12]: $(tp[12])") end
            else
                foundIndex = nothing
            end
            if foundIndex != nothing
                theBatchIsNotCompleted = false
                isSkip ? theDDSorPNGFileIsOk = -3 : theDDSorPNGFileIsOk = 3
                if format == 0
                    fileSizePNG = stat(imageWithPathTypePNG).size
                    fileSizeDDS = 0
                else
                    fileSizePNG = 0
                    fileSizeDDS = stat(imageWithPathTypeDDS).size
                end
                timeElaboration = time() - t0
            else
                # The DDS or PNG file was not found, so it must be obtained from an external site
                if !isfileImagePNG
                    TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,0,pathToSave)
                    TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,1,pathToSave)
                    isfileImagePNG = downloadImages(tp,imageWithPathTypePNG,mapServer,debugLevel) > 0
                end
                if isPngFileFormatOnly
                    if isfileImagePNG > 0 && filesize(imageWithPathTypePNG) > 1024
                        try
                            fileSizePNG = stat(imageWithPathTypePNG).size
                            fileSizeDDS = 0
                            if debugLevel > 0 println("createDDSorPNGFile - The file $imageWithPathTypePNG is created") end
                            theBatchIsNotCompleted = false
                            theDDSorPNGFileIsOk = 1
                            timeElaboration = time() - t0
                        catch err
                            if debugLevel > 1 println("createDDSorPNGFile - Error to create $imageWithPathTypePNG file in png format") end
                            try
                                rm(imageWithPathTypePNG)
                            catch
                                if debugLevel > 1 println("createDDSorPNGFile - Error to remove the $imageWithPathTypePNG file") end
                            end
                            theBatchIsNotCompleted = true
                            if theDDSorPNGFileIsOk == 0 theDDSorPNGFileIsOk = -10 end
                        end
                    else
                        theBatchIsNotCompleted = true
                        if theDDSorPNGFileIsOk == 0 theDDSorPNGFileIsOk = -11 end
                    end
                else
                    if isfileImagePNG > 0 && filesize(imageWithPathTypePNG) > 1024
                        # Conversion from .png to .dds
                        try
                            # Original version: -define dds:compression=DXT5 dxt5:$imageWithPathTypeDDS
                            # Compression factor (16K -> 64 MB): -define dds:mipmaps=0 -define dds:compression=dxt1
                            # Compression factor (16K -> 128 MB): -define dds:mipmaps=0 -define dds:compression=dxt5
                            oldFileIsPresent = isfile(imageWithPathTypeDDS)
                            TilesDatabase.moveOrDeleteTiles(tileIndex,rootPath,1,pathToSave)
                            fileSizePNG = stat(imageWithPathTypePNG).size
                            if Base.Sys.iswindows()
                                run(`magick convert $imageWithPathTypePNG -define dds:mipmaps=0 -define dds:compression=dxt1 $imageWithPathTypeDDS`)
                            else
                                imageMagickPath != nothing ? imageMagickWithPathUnix = normpath(imageMagickPath * "/" * "convert") : imageMagickWithPathUnix = "convert"
                                run(`$imageMagickWithPathUnix $imageWithPathTypePNG -define dds:mipmaps=0 -define dds:compression=dxt1 $imageWithPathTypeDDS`)
                            end
                            fileSizeDDS = stat(imageWithPathTypeDDS).size
                            if debugLevel > 0 println("createDDSorPNGFile - The file $imageWithPathTypeDDS is converted in the DDS file: $imageWithPathTypeDDS") end
                            rm(imageWithPathTypePNG)
                            theBatchIsNotCompleted = false
                            oldFileIsPresent ? theDDSorPNGFileIsOk = 2 : theDDSorPNGFileIsOk = 1
                            timeElaboration = time() - t0
                        catch err
                            if debugLevel > 1 println("createDDSorPNGFile - Error to convert the $imageWithPathTypePNG file in dds format") end
                            try
                                rm(imageWithPathTypePNG)
                            catch
                                if debugLevel > 1 println("createDDSorPNGFile - Error to remove the $imageWithPathTypePNG file") end
                            end
                            theBatchIsNotCompleted = true
                            if theDDSorPNGFileIsOk == 0 theDDSorPNGFileIsOk = -10 end
                        end
                    else
                        theBatchIsNotCompleted = true
                        if theDDSorPNGFileIsOk == 0 theDDSorPNGFileIsOk = -11 end
                    end
                end
            end
        else
            if theDDSorPNGFileIsOk == 0 theDDSorPNGFileIsOk = -12 end
        end
    end
    return theBatchIsNotCompleted, tileIndex, theDDSorPNGFileIsOk, timeElaboration, string(tp[7]) * (format == 0 ? ".png" : ".dds"),"../" * tp[1] * "/" * tp[2], fileSizePNG, fileSizeDDS
end


# Main fuctions area

function parseCommandline(args)

    if args != nothing && size(args)[1] == 1
        try
            outfile = args[1]
            f = open(outfile,"r")
            args = String[]
            while ! eof(f)
                line = readline(f)
                if length(line) > 0 push!(args,line) end
            end
            parsed_args = parse_args(args,s)
            println("\nArguments (params) read from the file: $outfile")
        catch
        end
    end

    s = ArgParseSettings()
    @add_arg_table! s begin
        "--args", "-g"
            help = "The arguments files in txt format"
            arg_type = String
            default = nothing
        "--map"
            help = "The map server id"
            arg_type = Int64
            default = 1
        "--latll"
            help = "Lower left area lat"
            arg_type = Float64
            default = 0.0
        "--lonll"
            help = "Lower left area lon"
            arg_type = Float64
            default = 0.0
        "--latur"
            help = "Upper right area lat"
            arg_type = Float64
            default = 0.0
        "--lonur"
            help = "Upper right area lon"
            arg_type = Float64
            default = 0.0
        "--lat", "-a"
            help = "Latitude in deg of central point"
            arg_type = Float64
            default = 45.66
        "--lon", "-o"
            help = "Longitude in deg of central point"
            arg_type = Float64
            default = 9.7
        "--sexagesimal", "-x"
            help = "Set the sexagesimal unit degree.minutes"
            action = :store_true
        "--png"
            help = "Set the only png format files"
            action = :store_true
        "--icao", "-i"
            help = "ICAO airport code for extract LAT and LON"
            arg_type = String
            default = nothing
        "--route"
            help = "Route XML for extract route LAT and LON"
            arg_type = String
            default = nothing
        "--tile", "-t"
            help = "Tile index es coordinate reference"
            arg_type = Int64
            default = nothing
        "--radius", "-r"
            help = "Distance Radius around the center point (nm)"
            arg_type = Float64
            default = 0.0
        "--size", "-s"
            help = "Max size of image 0->512 1->1024 2->2048 3->4096 4->8192 5->16384 6->32768"
            arg_type = Int64
            default = 2
        "--sdwn"
            help = "Down size with distance"
            arg_type = Int64
            default = 0
        "--over"
            help = "Overwrite the tiles: |1|only if bigger resolution |2|for all"
            arg_type = Int64
            default = 0
        "--path", "-p"
            help = "Path to store the dds images"
            arg_type = String
            #default = "fgfs-scenery/photoscenery"
            default = "*"
        "--save"
            help = "Save the remove files in the specific path"
            arg_type = String
            default = nothing
        "--nosave"
            help = "Not save the DDS/PNG files"
            action = :store_true
        "--connect"
            help = "IP and port FGFS program, example format: \"127.0.0.1:5000\""
            arg_type = String
            default = nothing
        "--proxy"
            help = "Proxy string ipv4:port for example: \"192.168.0.1:8080\""
            default = nothing
        "--attemps"
            help = "Number of download attempts"
            arg_type = Int64
            default = 3
        "--debug", "-d"
            help = "Debug level"
            arg_type = Int64
            default = 0
        "--version"
            help = "Program version"
            action = :store_true
    end

    parsed_args = parse_args(args,s)

    outfile = parsed_args["args"]

    if size(args)[1] == 0 || (size(args)[1] == 2 && outfile != nothing)
        try
            if outfile == nothing outfile = "args.txt" end
            f = open(outfile,"r")
            args = String[]
            while ! eof(f)
                line = readline(f)
                if length(line) > 0 push!(args,line) end
            end
            parsed_args = parse_args(args,s)
            println("\nArguments (params) read from the file: $outfile")
        catch
            println("\nArguments (params) default arguments")
        end
    else
        try
            if outfile == nothing outfile = "args.txt" end
            f = open(outfile, "w")
            for i in eachindex(args)
                println(f, args[i])
            end
            println("\nArguments (params) saved in the file: $outfile")
        catch
        end
    end

    for pa in parsed_args
        println("  $(pa[1])  =>  $(pa[2])")
    end

    return parsed_args
end


function cmgsExtract(cmgs)
    a = []
    for cmg in cmgs
        if cmg[2] == 0
            push!(a,cmg[1])
            cmg[2] += 1
        end
        colsStop = Threads.nthreads() - cmg[1][13]
        if colsStop > Sys.CPU_THREADS colsStop = Sys.CPU_THREADS end
        if colsStop <= 0 colsStop = 1 end
        if size(a)[1] >= colsStop
            break
        end
    end
    return a
end


function cmgsExtractTest(cmgs)
    for cmg in cmgs
        if cmg[2] == 0
            return true
        end
    end
    return false
end


inValue(value,extrem) = abs(value) <= extrem


setDegreeUnit(isSexagesimal,degree) = isSexagesimal ? trunc(degree) + (degree - trunc(degree)) * (10.0/6.0) : degree


function photoscenary(args)

    centralPointLon = nothing
    centralPointLat = nothing
    routeList = Any[]
    routeListStep = 1
    routeListSize = 0
    positionRoute = nothing
    rootPath = nothing
    arrow = PhotoscenaryCommons.displayCursorTypeA()
    timeLastConnect = time()

    imageMagickPath = inizialize()
    (imageMagickStatus, imageMagickPath) = checkImageMagick(imageMagickPath)
    if !imageMagickStatus
        println("\nThe program is then terminated as it is absolutely necessary to install ImageMagick (exit code 501)")
        ccall(:jl_exit, Cvoid, (Int32,), 501)
    end

    parsedArgs = parseCommandline(args)

    if parsedArgs["version"] return 0 end

    mapServer = MapServer(parsedArgs["map"], parsedArgs["proxy"])
    (serviceWebUrl,errorCode) = getMapServer(mapServer,1,2,3,4,5,6)
    if errorCode > 0
        println("\nError: The map server with Id $(parsedArgs["map"]) was not found Check the params.xml file\n\tOr check if you entered the right id in the --map command\n\tTerm the program with exit code $errorCode")
        ccall(:jl_exit, Cvoid, (Int32,), errorCode)
    else
        println("\nMap server select id: $(mapServer.id) name: $(mapServer.comment) ($(mapServer.name))")
    end

    isSexagesimalUnit = parsedArgs["sexagesimal"]
    isPngFileFormatOnly = parsedArgs["png"]

    debugLevel = parsedArgs["debug"]
    if debugLevel > 1 @info "parsedArgs:" parsedArgs end

    # Process anothers options
    unCompletedTilesMaxAttemps = parsedArgs["attemps"]
    centralPointRadiusDistance = parsedArgs["radius"]

    if parsedArgs["icao"] != nothing
        # Select lat lon by ICAO airport id or name or municipality
        # Test the DB csv or jdb
        if centralPointRadiusDistance == 0.0 centralPointRadiusDistance = 10.0 end
        (centralPointLat, centralPointLon, errorCode) = selectIcao(parsedArgs["icao"],centralPointRadiusDistance)
        if errorCode > 0
            # Error
            println("Term the program with exit code $errorCode")
            ccall(:jl_exit, Cvoid, (Int32,), errorCode)
        end
        routeList = push!(routeList,(centralPointLat,centralPointLon))
        routeListSize = 1
    elseif parsedArgs["tile"] != nothing
        if centralPointRadiusDistance == 0.0 centralPointRadiusDistance = 10.0 end
        if parsedArgs["tile"] > 20
            centralPointLon = coordFromIndex(parsedArgs["tile"])[1]
            centralPointLat = coordFromIndex(parsedArgs["tile"])[2]
            routeList = push!(routeList,(centralPointLat,centralPointLon))
            routeListSize = 1
        else
            println("\nError: the value of the tile id $(parsedArgs["tile"]) is too small,\n\tit could be a value related to the thread number of the julia compiler\n\tcheck the command line. (exit code 403)")
            ccall(:jl_exit, Cvoid, (Int32,), 403)
        end
    elseif parsedArgs["route"] != nothing
        if centralPointRadiusDistance == 0.0 centralPointRadiusDistance = 10.0 end
        (routeList,routeListSize) = loadRoute(parsedArgs["route"],centralPointRadiusDistance)
    elseif parsedArgs["connect"] != nothing
        connectIp = parsedArgs["connect"]
        if centralPointRadiusDistance == 0.0 centralPointRadiusDistance = 10.0 end
        # The route is built in connection with the aircraft
        # It waits for a small amount of time to connect to the server
        findPosition = false
            @sync begin
                println("\nTry to Flightgear connect with address: $connectIp radius: $centralPointRadiusDistance")
                pathFromParsed = parsedArgs["path"]
                if pathFromParsed == nothing || length(pathFromParsed) == 0 || cmp(pathFromParsed,"*") == 0
                    defaultRootPath = getFGFSPathScenery(connectIp,debugLevel)
                else
                    defaultRootPath = nothing
                end
                @async while !findPosition
                    if positionRoute == nothing positionRoute = getFGFSPositionSetTask(connectIp,centralPointRadiusDistance,0.3,debugLevel) end
                    if positionRoute.size > 0
                        routeListSize += 1
                        routeList = push!(routeList,(positionRoute.marks[routeListSize].latitudeDeg,positionRoute.marks[routeListSize].longitudeDeg))
                        findPosition = true
                        if defaultRootPath != nothing
                            rootPath = normpath(defaultRootPath * "/Orthophotos")
                        end
                        println("\nConnected to Flightgear with address: $connectIp radius: $centralPointRadiusDistance path: '$(rootPath)'")
                    else
                        print("\r$(arrow.get()) Try the frist connection to Flightgear with address: $connectIp waiting time: $(Int(round(time()-timeLastConnect))). Press CTRL+C to stop the program and exit")
                        sleep(positionRoute.stepTime)
                    end
                end
            end
    else
        centralPointLat = setDegreeUnit(isSexagesimalUnit,parsedArgs["lat"])
        centralPointLon = setDegreeUnit(isSexagesimalUnit,parsedArgs["lon"])
        routeList = push!(routeList,(centralPointLat,centralPointLon))
        routeListSize = 1
        if centralPointRadiusDistance == 0.0 centralPointRadiusDistance = 10.0 end
    end

    systemCoordinatesIsPolar = true
    if (parsedArgs["latll"] < parsedArgs["latur"]) && (parsedArgs["lonll"] < parsedArgs["lonur"])
        systemCoordinatesIsPolar = false
    end

    if routeListSize == 0 && systemCoordinatesIsPolar
        println("\nError: processing will stop! The LAT or LON is invalid (exit code 405)")
        ccall(:jl_exit, Cvoid, (Int32,), 405)
    end

    overWriteTheTiles = parsedArgs["over"]

    size = parsedArgs["size"]
    sizeDwn = parsedArgs["sdwn"]
    if sizeDwn == 0 sizeDwn = size end

    # Path prepare
    pathFromParsed = parsedArgs["path"]
    pathToTest = normpath(pathFromParsed)
    if pathFromParsed == nothing || length(pathFromParsed) == 0 || cmp(pathFromParsed,"*") == 0
        # The first asterisk character indicates that the path has not been changed and therefore it is possible to insert the default one
        pathFromParsed = "fgfs-scenery/photoscenery"
    end
    if rootPath == nothing
        if Base.Sys.iswindows()
            if pathToTest[2] == ':' || pathToTest[1] == '\\'
                rootPath = normpath(pathFromParsed * "/Orthophotos")
            else
                cd();
                rootPath = normpath(pwd() * "/" * pathFromParsed * "/Orthophotos")
            end
        else
            if pathToTest[1] == '/'
                rootPath = normpath(pathFromParsed * "/Orthophotos")
            else
                cd();
                rootPath = normpath(pwd() * "/" * pathFromParsed * "/Orthophotos")
            end
        end
    end
    println("\nPath to locate the DDS/PNG orthophotos files: '$(rootPath)'")

    # Path to save the files remove
    isNoSaveFiles = parsedArgs["nosave"]
    pathToSave = parsedArgs["save"]
    if pathToSave != nothing
        isNoSaveFiles = false
        pathToSave = normpath(pathToSave)
    else
        if isNoSaveFiles == false && (parsedArgs["connect"] != nothing || parsedArgs["route"] != nothing)
            # The autosave mode is only active if the program is connected to FGFS or if it is following a route
            pathToSave = rootPath * "-saved"
        end
    end
    println("\nPath to save the DDS/PNG orthophotos files: '$(pathToSave)'")

    # Generate the TileDatabase
    println("\nCreate the Tile Database\nPlease wait for a few seconds to a few minutes")
    tileDatabase = TilesDatabase.createFilesListTypeDDSandPNG(nothing,rootPath,pathToSave)
    println("The tiles database has been generated and verified")

    # Download thread
    timeElaborationForAllTilesInserted = 0.0
    timeElaborationForAllTilesResidual = 0.0
    timeStart = time()
    totalByteDDS = 0
    totalBytePNG = 0

    while routeListStep <= routeListSize

        if routeListSize > 1
            println("\n---------- Route step $routeListStep on $routeListSize ----------")
        end

        if systemCoordinatesIsPolar
            if !(inValue(routeList[routeListStep][1],90) && inValue(routeList[routeListStep][2],180))
                println("\nError: The process will terminate as the entered coordinates are not consistent\n\tlat: $(routeList[routeListStep][1]) lon: $(routeList[routeListStep][2])")
                ccall(:jl_exit, Cvoid, (Int32,), 505)
            end
            mpc = MapCoordinates(routeList[routeListStep][1],routeList[routeListStep][2],centralPointRadiusDistance)
        else
            latLL = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["latll"]),digits=3)
            lonLL = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["lonll"]),digits=3)
            latUR = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["latur"]),digits=3)
            lonUR = round(setDegreeUnit(isSexagesimalUnit,parsedArgs["lonur"]),digits=3)
            # Check the coordinates
            if !(inValue(latLL,90) && inValue(lonLL,180) && inValue(latUR,90) && inValue(lonUR,180))
                println("\nError: The process will terminate as the entered coordinates are not consistent\n\tlatLL: $latLL lonLL: $lonLL latUR: $latUR lonUR: $lonUR")
                ccall(:jl_exit, Cvoid, (Int32,), 505)
            end
            mpc = MapCoordinates(latLL,lonLL,latUR,lonUR)
        end

        ifFristCycle = true
        continueToReatray = true
        unCompletedTilesAttemps = 0
        unCompletedTilesNumber = 0
        numbersOfTilesToElaborate = 0
        numbersOfTilesInserted = 0
        numbersOfTilesElaborate = 0

        while continueToReatray
            # Generate the coordinate matrix
            # Resize management with smaller dimensions
            if ifFristCycle
                (cmgs,cmgsSize) = coordinateMatrixGenerator(mpc,nothing,size,sizeDwn,unCompletedTilesAttemps,positionRoute,debugLevel)
                numbersOfTilesToElaborate = cmgsSize
            else
                (cmgs,cmgsSize) = coordinateMatrixGenerator(mpc,unCompletedTiles,size,sizeDwn,unCompletedTilesAttemps,positionRoute,debugLevel)
                numbersOfTilesToElaborate = cmgsSize
            end

            println("\nStart the elaboration n. $(unCompletedTilesAttemps+1) for $numbersOfTilesToElaborate tiles the Area deg is",
                @sprintf(" latLL: %02.3f",mpc.latLL),
                @sprintf(" lonLL: %03.3f",mpc.lonLL),
                @sprintf(" latUR: %02.3f",mpc.latUR),
                @sprintf(" lonUR: %03.3f",mpc.lonUR),
                " Batch size: $cmgsSize",
                " Width $(getSizePixel(size)[1]) | $(getSizePixel(size)[2])",
                " to $(getSizePixel(sizeDwn)[1]) | $(getSizePixel(sizeDwn)[2]) pix",
                " Cycle: $unCompletedTilesAttemps",
                "\nThe images path is: $rootPath\n")

            while cmgsExtractTest(cmgs)
                threadsActive = 0
                Threads.@threads for cmg in cmgsExtract(cmgs)
                    threadsActive += 1
                    theBatchIsNotCompleted = false
                    (theBatchIsNotCompleted,tileIndex,theDDSorPNGFileIsOk,timeElaboration,tile,pathRel,fileSizePNG,fileSizeDDS) = createDDSorPNGFile(rootPath,cmg,overWriteTheTiles,imageMagickPath,mapServer,tileDatabase,isPngFileFormatOnly,pathToSave,debugLevel)
                    if theDDSorPNGFileIsOk >= 1
                        numbersOfTilesElaborate += 1
                        if timeElaboration != nothing && theBatchIsNotCompleted == false
                            timeElaborationForAllTilesInserted += timeElaboration
                            numbersOfTilesInserted += 1
                        end
                        if haskey(unCompletedTiles,tileIndex)
                            delete!(unCompletedTiles,tileIndex)
                            unCompletedTilesNumber -= 1
                        end
                    elseif theBatchIsNotCompleted
                        if haskey(unCompletedTiles,tileIndex)
                            push!(unCompletedTiles,tileIndex => unCompletedTiles[tileIndex] + 1)
                        else
                            push!(unCompletedTiles,tileIndex => 1)
                        end
                        if ifFristCycle unCompletedTilesNumber += 1 end
                    else
                        numbersOfTilesElaborate += 1
                    end
                    if theDDSorPNGFileIsOk != 0
                        if theDDSorPNGFileIsOk == 1
                            totalBytePNG += fileSizePNG
                            totalByteDDS += fileSizeDDS
                            theDDSorPNGFileIsOkStatus = "(Inserted)"
                        elseif theDDSorPNGFileIsOk == 2
                            totalBytePNG += fileSizePNG
                            totalByteDDS += fileSizeDDS
                            theDDSorPNGFileIsOkStatus = "(Updated)   "
                        elseif theDDSorPNGFileIsOk == 3
                            theDDSorPNGFileIsOkStatus = "(Copied)   "
                        elseif theDDSorPNGFileIsOk == -1
                            theDDSorPNGFileIsOkStatus = "(Removed)   "
                        elseif theDDSorPNGFileIsOk == -2
                            theDDSorPNGFileIsOkStatus = "(Nothing)   "
                        elseif theDDSorPNGFileIsOk == -3
                            theDDSorPNGFileIsOkStatus = "(Skip)      "
                        elseif theDDSorPNGFileIsOk <= -10
                            theDDSorPNGFileIsOkStatus = "(HTTP! $theDDSorPNGFileIsOk) "
                        end
                        timeElaborationForAllTilesResidual = (timeElaborationForAllTilesInserted / numbersOfTilesInserted) * numbersOfTilesToElaborate / Threads.nthreads()
                        println('\r',
                            @sprintf("Time: %6d",time()-timeStart),
                            @sprintf(" elab: %6d",timeElaborationForAllTilesInserted),
                            @sprintf(" (%5d|",(time()-timeStart) / numbersOfTilesInserted),
                            @sprintf("%5d)",timeElaborationForAllTilesResidual),
                            @sprintf(" Tiles: %4d",numbersOfTilesElaborate),
                            @sprintf(" on %4d",numbersOfTilesToElaborate),
                            @sprintf(" res %4d",(numbersOfTilesToElaborate - numbersOfTilesElaborate)),
                            @sprintf(" err %4d",unCompletedTilesNumber),
                            @sprintf(" Th: %2d",threadsActive),
                            " path: $pathRel/$tile ",
                            @sprintf(" Dist: %5.1f",cmg[11]),
                            @sprintf(" pix: %5d",cmg[12]),
                            @sprintf(" MB/s: %3.2f",totalBytePNG / (time()-timeStart) / 1000000),
                            @sprintf(" MB dw: %6.1f ",totalBytePNG / 1000000),
                            theDDSorPNGFileIsOkStatus
                        )
                    else
                        totalBytePNG += fileSizePNG
                    end
                end
            end
            # Check the incomplete Tiles
            continueToReatray = false
            isIncompleteTileList = false
            for idTile in collect(keys(unCompletedTiles))
                if !isIncompleteTileList
                    println("\nIncomplete tiles list:")
                    unCompletedTilesAttemps += 1
                end
                isIncompleteTileList = true
                println("Tile id: ",idTile," attemps: ",unCompletedTilesAttemps)
                if unCompletedTilesAttemps <= unCompletedTilesMaxAttemps
                    continueToReatray = true
                    numbersOfTilesElaborate = 0
                else
                    continueToReatray = false
                end
            end
            if !ifFristCycle && !continueToReatray println("\nThe maximum number of attempts has been reached, some tiles have not been inserted as they cannot be reached") end
            ifFristCycle = false
        end

        println("\n\nThe process is finish, ",@sprintf("Time elab: %5.1f ",time()-timeStart)," number of tiles: ",numbersOfTilesToElaborate," time for tile: ",@sprintf("%5.1f",(time()-timeStart)/numbersOfTilesToElaborate),@sprintf(" MB/s: %3.2f",totalBytePNG / (time()-timeStart) / 1000000),@sprintf(" MB dw: %6.1f ",totalByteDDS / 1000000))

        routeListStep += 1

        if positionRoute != nothing
            println("\n\nA new section of the route begins,\nas soon as the distance is sufficient, and a new reading of tiles occurs\n")
            isSleep = false
            while routeListStep > routeListSize
                if telnetConnectionSockIsOpen(positionRoute)
                    timeLastConnect = time()
                    if isSleep
                        println(" ")
                        isSleep = false
                    end
                    while positionRoute.size < routeListStep && telnetConnectionSockIsOpen(positionRoute)
                        sleep(positionRoute.stepTime * 2.5)
                        println("System pending further advancement speed (mph): ",@sprintf("%5.1f",positionRoute.actualSpeed)," distance (nm): ",@sprintf("%5.1f",positionRoute.actualDistance)," on radius: ",@sprintf("%5.1f",positionRoute.radiusStep)," Direction (deg): ",@sprintf("%4.1f",positionRoute.actualDirectionDeg))
                    end
                    while positionRoute.size > routeListSize && telnetConnectionSockIsOpen(positionRoute)
                        routeListSize += 1
                        routeList = push!(routeList,(positionRoute.marks[routeListSize].latitudeDeg,positionRoute.marks[routeListSize].longitudeDeg))
                    end
                else
                    print("\r$(arrow.get()) Try connect to Flightgear with address: $(parsedArgs["connect"]) waiting time: $(Int(round(time()-timeLastConnect))). Press CTRL+C to stop the program and exit")
                    isSleep = true
                    sleep(0.5)
                end
            end
        end

    end

end


function main(args)
    println("The Photoscenary.jl program has started, it can be stopped with CTRL-C")
    Base.exit_on_sigint(false)
    startPhotoscenary = false
    goProgram = true
    while goProgram
        try
            if !startPhotoscenary
                @async begin
                    photoscenary(args)
                end
                startPhotoscenary = true
            end
            sleep(1.0)
        catch err
            if err isa InterruptException
                goProgram = false
                print("\rThe Photoscenary.jl program was stopped by the user\n\n")
            end
        end
    end
end


main(ARGS)

