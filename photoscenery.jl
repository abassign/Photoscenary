#=

Autor: Adriano Bassignana Bargamo 2021
Licence: GPL 2

Exite code:
0 - regular execution
1 - The version check did not pass

=#

using Pkg

if VERSION < v"1.5.4"
    println("The actiual Julia is ",VERSION, " The current version is too old, please upgrade Julia from version 1.5.4 and later")
    exit(code = 1)
end

try
    import ImageMagick
    using LightXML
    using ArgParse
    using Printf
    using HTTP
    using FileIO
catch
    println("\nInstal the packeges necessary for photoscenery.jl execution")
    Pkg.add("LightXML")
    Pkg.add("ImageMagick")
    Pkg.add("ArgParse")
    Pkg.add("Printf")
    Pkg.add("HTTP")
    Pkg.add("FileIO")
    println("\nRemember that for you need to make sure you have the ImageMagick program installed https://imagemagick.org/")
    import ImageMagick
    using LightXML
    using ArgParse
    using Printf
    using HTTP
    using FileIO
end

versionProgram = "0.1.1"

# Test set:
# python3 creator.py --lat 38 --lon 16 --info_only
# Bucket: {'min_lat': 38.0, 'max_lat': 38.125, 'min_lon': 16.0, 'max_lon': 16.25, 'center_lat': 38.0625, 'center_lon': 16.125}. Index: 3219456

# Lat: 38 cmd=python3 creator.py --lat "38.0000" --lon "16.0000" --info_only
# Tile 3219456 needs download
#= Testing (max 4096 x 2048)
/World_Imagery/MapServer/export?bbox=16.0,38.0,16.125,38.0625&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
/World_Imagery/MapServer/export?bbox=16.125,38.0,16.25,38.0625&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
/World_Imagery/MapServer/export?bbox=16.0,38.0625,16.125,38.125&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
/World_Imagery/MapServer/export?bbox=16.125,38.0625,16.25,38.125&bboxSR=4326&size=4096,2048&imageSR=4326&format=png24&f=image
INFO:root:Joining tiles to /home/abassign/photoscenery/Orthophotos/e010n30/e016n38/3219456.png
Bucket: {'min_lat': 38.0, 'max_lat': 38.125, 'min_lon': 16.0, 'max_lon': 16.25, 'center_lat': 38.0625, 'center_lon': 16.125}. Index: 3219456
cmd=python3 creator.py --lat "38.0000" --lon "16.0500" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.1000" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.1500" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.2000" --info_only
cmd=python3 creator.py --lat "38.0000" --lon "16.2500" --info_only
=#

m = [90, 89, 86, 83, 76, 62, 22,-22]
n = [12.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.125]
#servicesWebUrl = "http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export?bbox=$llLon,$llLat,$urLon,$urLat&bboxSR=4326&size=$sizeWidth,$sizeHight&imageSR=4326&format=png24&f=image"

tileWidth(lat) = reduce(+,map((x,y,z)->z * (abs(lat) < x) * (abs(lat) >= y),m,m[begin+1:end],n))

baseX(lat,lon) = floor(floor(lon / tileWidth(lat)) * tileWidth(lat))
x(lat,lon) = floor(Int,(lon - baseX(lat,lon)) / tileWidth(lat))
baseY(lat) = floor(lat)
y(lat) = floor(Int,(lat - baseY(lat)) * 8)

index(lat,lon) = (floor(Int,lon + 180) << 14) + floor(Int,lat + 90) << 6 + (y(lat) << 3) + x(lat,lon)

minLat(lat) = baseY(lat) + 1.0 * (y(lat) // 8)
maxLat(lat) = baseY(lat) + 1.0 * ((1 + y(lat)) // 8)

minLon(lat,lon) = baseX(lat,lon) + x(lat,lon) * tileWidth(lat)
maxLon(lat,lon) = minLon(lat,lon) + tileWidth(lat)

centerLat(lat) = minLat(lat) + (maxLat(lat) - minLat(lat)) / 2.0
centerLon(lat,lon) = minLon(lat,lon) + (maxLon(lat,lon) - minLon(lat,lon)) / 2.0

longDegOnLatitudeNm(lat) = 2 * pi * 6371.0 * 0.53996 * cosd(lat) / 360.0
longDegOnLongitudeNm() = pi * 6378.0 * 0.53996 / 180

latDegByCentralPoint(lat,lon,radius) = (
    round((lat -  mod(lat,0.125)) - (radius/longDegOnLongitudeNm()),digits=1),
    round((lon -  mod(lon,0.125)) - (radius/longDegOnLatitudeNm(lat)),digits=1),
    round((lat - mod(lat,0.125) + 0.125) + (radius/longDegOnLongitudeNm()),digits=1),
    round((lon - mod(lon,0.125) + 0.125)+ (radius/longDegOnLatitudeNm(lat)),digits=1))


# Inizialize section

function inizializeParams()
    # Build the paramsXml
    paramsXml = nothing
    if isfile("params.xml")
        paramsXml = parse_file("params.xml")
        if "params" == lowercase(name(root(paramsXml)))
            xroot = root(paramsXml)
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
    if isfile("params.xml")
        paramsXml = parse_file("params.xml")
        if "params" == lowercase(name(root(paramsXml)))
            xroot = root(paramsXml)
            ces = get_elements_by_tagname(xroot,"versioning")
            if ces != nothing && find_element(ces[1],"version") != nothing
                versionFromParams = content(find_element(ces[1],"version"))
            end
        end
    end
    if versionFromParams == nothing || versionFromParams != versionProgram
        println("\nThe program version is change old version is $versionFromParams the actual version is $versionProgram")
        inizializeParams()
    end
    println('\n',"Photoscenery generator by Julia compilator,\nProgram for uploading Orthophotos files\n")
    paramsXml = parse_file("params.xml")
    if "params" == lowercase(name(root(paramsXml)))
        ces = get_elements_by_tagname(root(paramsXml),"versioning")
        println(ces[1])
    end
end


# Coordinates matrix generator

function coordinateMatrixGenerator(latLL,lonLL,latUR,lonUR,cols,systemCoordinatesIsPolar,isDebug)
    numberOfTiles = 0
    # Normalization to 0.125 deg
    latLL = latLL - mod(latLL,0.125)
    lonLL = lonLL - mod(lonLL,0.250)
    latUR = latUR - mod(latUR,0.125) + 0.125
    lonUR = lonUR - mod(lonUR,0.250) + 0.250
    a = [(
            string(lon >= 0.0 ? "e" : "o",@sprintf("%03d",floor(lon,digits=-1)),lat >= 0.0 ? "n" : "s",@sprintf("%02d",floor(lat,digits=-1))),
            string(lon >= 0.0 ? "e" : "o",@sprintf("%03d",floor(Int,lon)),lat >= 0.0 ? "n" : "s",@sprintf("%02d",floor(Int,lat))),
            lon,
            lat,
            lon + (tileWidth(lat)/cols),
            lat + (0.125 / cols),
            floor(Int,lat*10),
            index(lat,lon),
            x(lat,lon),
            y(lat),
            tileWidth(lat)
        )
        for lat in latLL:(0.125 / cols):latUR for lon in lonLL:(tileWidth(lat)/cols):lonUR]
    # print data sort by tile index
    aSort = sort!(a,by = x -> x[8])
    c = nothing
    d = []
    precIndex = nothing
    counterIndex = 0
    for b in aSort
        if precIndex == nothing || precIndex != b[8]
            if c != nothing push!(d,c) end
            c = []
            precIndex = b[8]
            counterIndex = 1
        else
            counterIndex += 1
        end
        t = (b[1],b[2],
            @sprintf("%02.6f",b[3]),
            @sprintf("%02.6f",b[5]),
            @sprintf("%03.6f",b[4]),
            @sprintf("%03.6f",b[6]),
            b[8],
            counterIndex,
            b[11],
            0)
        push!(c,t)
        numberOfTiles += 1
        if isDebug > 1 println("Tile id: ",t[7]," coordinates: ",t[1]," ",t[2]," | lon: ",t[3]," ",t[4]," lat: ",t[5]," ",t[6]," | Counter: ",t[8]," Width: ",@sprintf("%03.6f",t[9])) end
    end
    if c != nothing
        push!(d,c)
    end

    if isDebug > 0
        println("\n----------")
        println("CoordinateMatrix generator")
        println("latLL: ",latLL," lonLL ",lonLL," latUR: ",latUR," lonUR ",lonUR,"x: ","y:"," Col: ",cols,'\n')
        println("Number of tiles to process: $numberOfTiles")
        println("----------\n")
    end

    return d,numberOfTiles
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


function createDDSFile(rootPath,cmg,sizeWidth,sizeHight,overWriteTheTiles,debugLevel)
    theBatchIsNotCompleted = false
    t0 = time()
    tileIndex = 0
    for tp in cmg
        path = setPath(rootPath,tp[1],tp[2])
        if path != nothing
            tileIndex = tp[7]
            imageWithPathTypePNG = normpath(path * "/" * string(tp[7]) * ".png")
            imageWithPathTypeDDS = normpath(path * "/" * string(tp[7]) * ".dds")
            if overWriteTheTiles > 0 && isfile(imageWithPathTypeDDS) rm(imageWithPathTypeDDS) end
            if isfile(imageWithPathTypeDDS) == false
                if isfile(imageWithPathTypePNG) == false
                    servicesWebUrl = "http://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/export?bbox="
                    servicesWebUrl = servicesWebUrl * tp[3] * "," * tp[5] * "," * tp[4] * "," * tp[6] * "&bboxSR=4326&size=$sizeWidth,$sizeHight&imageSR=4326&format=png24&f=image"
                    if debugLevel > 0 println("Start the HTTP image download url: $servicesWebUrl") end
                    try
                        io = open(imageWithPathTypePNG,"w")
                        r = HTTP.request("GET",servicesWebUrl,response_stream = io)
                        close(io)
                        if debugLevel > 0 println("The file $imageWithPathTypePNG is downloaded") end
                    catch err
                        println("Error to download the $imageWithPathTypePNG file")
                        theBatchIsNotCompleted = true
                    end
                end
                try
                    if Base.Sys.iswindows()
                        run(`magick convert $imageWithPathTypePNG -define dds:compression=DXT5 dxt5:$imageWithPathTypeDDS`)
                    else
                        run(`convert $imageWithPathTypePNG -define dds:compression=DXT5 dxt5:$imageWithPathTypeDDS`)
                    end
                    if debugLevel > 0 println("The file $imageWithPathTypeDDS is converted in the DDS file: $imageWithPathTypeDDS") end
                    rm(imageWithPathTypePNG)
                catch err
                    println("Error to convert the $imageWithPathTypePNG file in dds format")
                    theBatchIsNotCompleted = true
                    try
                        rm(imageWithPathTypePNG)
                    catch
                        println("Error to remove the $imageWithPathTypePNG file")
                    end
                end
            else
                println("","The file ",string(tp[7]) * ".png (",tp[3],":",tp[5]," ",tp[4],":",tp[6],") is existent at ",path)
            end
        end
    end
    return theBatchIsNotCompleted, tileIndex, time()-t0
end


# Main fuctions area

function parseCommandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
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
        "--radius", "-r"
            help = "Distance Radius around the center point (nm)"
            arg_type = Float64
            default = 0.0
        "--size", "-s"
            help = "Max size of image 0->512 1->1024 2->2048 3->4096 4->8192 5->16384"
            arg_type = Int64
            default = 0
        "--over"
            help = "Overwrite the tiles"
            arg_type = Int64
            default = 0
        "--path", "-p"
            help = "Path to store the dds images"
            arg_type = String
            default = "fgfs-scenery/photoscenery"
        "--debug", "-d"
            help = "Debug level"
            arg_type = Int64
            default = 0
        "--version"
            help = "Program version"
            action = :store_true
    end

    return parse_args(s)
end


function main(args)

    inizialize()

    parsedArgs = parseCommandline()

    if parsedArgs["version"]
        return 0
    end

    # Path prepare
    pathToTest = normpath(parsedArgs["path"])
    if Base.Sys.iswindows()
        if pathToTest[2] == ':' || pathToTest[1] == '\\'
            rootPath = normpath(parsedArgs["path"] * "/Orthophotos")
        else
            cd();
            rootPath = normpath(pwd() * "/" * parsedArgs["path"] * "/Orthophotos")
        end
    else
        if pathToTest[1] == '/'
            rootPath = normpath(parsedArgs["path"] * "/Orthophotos")
        else
            cd();
            rootPath = normpath(pwd() * "/" * parsedArgs["path"] * "/Orthophotos")
        end
    end
    # Another options
    debugLevel = parsedArgs["debug"]
    centralPointRadiusDistance = parsedArgs["radius"]
    centralPointLat = parsedArgs["lat"]
    centralPointLon = parsedArgs["lon"]
    overWriteTheTiles = parsedArgs["over"]

    unCompletedTiles = Dict{Int64,Int64}()
    unCompletedTilesMaxRetray = 5

    size = parsedArgs["size"]
    sizeWidth = 512
    sizeHight = 256

    # Only for testing! Remove when cols function is implemented
    if size > 3 size = 3 end
    cols = 1

    if size == 1
        sizeWidth = 1024
        sizeHight = 512
    elseif size == 2
        sizeWidth = 2048
        sizeHight = 1024
    elseif size == 3
        sizeWidth = 4096
        sizeHight = 2048
    elseif size >= 4
        sizeWidth = 8192
        sizeHight = 4096
        cols = 2
    elseif size >= 5
        sizeWidth = 16384
        sizeHight = 8192
        cols = 4
    end

    # Check if the coordinates are consistent
    systemCoordinatesIsPolar = nothing
    if (parsedArgs["latll"] < parsedArgs["latur"]) && (parsedArgs["lonll"] < parsedArgs["lonur"])
        latLL = round(parsedArgs["latll"],digits=3)
        lonLL = round(parsedArgs["lonll"],digits=3)
        latUR = round(parsedArgs["latur"],digits=3)
        lonUR = round(parsedArgs["lonur"],digits=3)
        systemCoordinatesIsPolar = false
    end
    if centralPointLat != nothing && centralPointLon != nothing && centralPointRadiusDistance > 0.0 && systemCoordinatesIsPolar == nothing
        (latLL,lonLL,latUR,lonUR) = latDegByCentralPoint(centralPointLat,centralPointLon,centralPointRadiusDistance)
        systemCoordinatesIsPolar = true
    end
    if systemCoordinatesIsPolar == nothing
        println("\nError: processing will end as the entered coordinates are not consistent")
        return 0.0
    end

    # Generate the coordinate matrix
    cmgs = coordinateMatrixGenerator(latLL,lonLL,latUR,lonUR,cols,systemCoordinatesIsPolar,debugLevel)
    numbersOfTilesToElaborate = cmgs[2]
    numbersOfTilesElaborate = 0
    timeElaborationForAllTiles = 0.0
    timeElaborationForAllTilesResidual = 0.0
    timeStart = time()
    println("\nStart the elaboration for $numbersOfTilesToElaborate tiles the Area deg is",
        @sprintf(" latLL: %02.3f",latLL),
        @sprintf(" lonLL: %03.3f",lonLL),
        @sprintf(" latUR: %02.3f",latUR),
        @sprintf(" lonUR: %03.3f",lonUR),
        "\nThe images path is: $rootPath\n")
    activeThreads = 0

    # Download thread
    continueToReatray = true
    while continueToReatray
        Threads.@threads for cmg in cmgs[1]
            activeThreads += 1
            theBatchIsNotCompleted = false
            (theBatchIsNotCompleted,tileIndex,timeElaboration) = createDDSFile(rootPath,cmg,sizeWidth,sizeHight,overWriteTheTiles,debugLevel)
            if theBatchIsNotCompleted
                if haskey(unCompletedTiles,tileIndex) push!(unCompletedTiles,tileIndex => unCompletedTiles[tileIndex] + 1) else push!(unCompletedTiles,tileIndex => 1) end
                println(unCompletedTiles)
            else
                if haskey(unCompletedTiles,tileIndex) delete!(unCompletedTiles,tileIndex) end
            end
            numbersOfTilesElaborate += 1
            timeElaborationForAllTiles += timeElaboration
            timeElaborationForAllTilesResidual = (timeElaborationForAllTiles / numbersOfTilesElaborate) * (numbersOfTilesToElaborate - numbersOfTilesElaborate)
            println(@sprintf("Time elab: %5.1f ",time()-timeStart),"Residual time to finish: ",@sprintf(" %5.1f",timeElaborationForAllTilesResidual)," Elab. tiles: ",numbersOfTilesToElaborate," residual tiles: ",(numbersOfTilesToElaborate - numbersOfTilesElaborate)," threads used: ",activeThreads)
            activeThreads -= 1
        end
        # Check the incomplete Tiles
        continueToReatray = false
        println("\nIncomplete tiles list:")
        for idTile in collect(keys(unCompletedTiles))
            println("Tile id: ",idTile," retray: ",unCompletedTiles[idTile])
            if unCompletedTiles[idTile] < unCompletedTilesMaxRetray
                continueToReatray = true
                numbersOfTilesElaborate = 0
            end
        end
    end
    println("\n\nThe process is finish, ",@sprintf("Time elab: %5.1f ",time()-timeStart)," number of tiles: ",numbersOfTilesToElaborate)

end

main(ARGS)
