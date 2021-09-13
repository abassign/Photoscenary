# Functions load route to all programs
# Aut: Adriano Bassignana
# Licence: GPL 2
# Date start production: September 2021

module Route

    import Unicode: graphemes # To solve the problem of an error in extracting unicode characters from a string.
    using Unicode
    using LightXML
    using Geodesy
    using JuliaDB
    using Printf

    include("./Commons.jl")
    include("./ScanDir.jl")

    export loadRoute


    function findFileOfRoute(fileName::String,idTypeOfFile::Int=0)
        typeOfFile = [("FGFS","route"),("GPX","rte")]
        date = 0.0
        fileId = 0
        route = nothing
        files = Commons.findFile(fileName)
        typeOfFileSelected = Nothing
        for file in files
            if file[3] > date
                # Test the file
                try
                    if idTypeOfFile > 0
                        route = get_elements_by_tagname(LightXML.root(parse_file(file[2])),typeOfFile[idTypeOfFile][2])
                        typeOfFileSelected = typeOfFile[idTypeOfFile][1]
                    else
                        for (nameFormat,selector) in typeOfFile
                            route = get_elements_by_tagname(LightXML.root(parse_file(file[2])),selector)
                            typeOfFileSelected = nameFormat
                            if size(route)[1] > 0 break end
                        end
                    end
                    fileId = file[1]
                    date = file[3]
                catch
                end
            end
        end
        if fileId > 0
            return route,files[fileId][2],typeOfFileSelected
        else
            return nothing
        end
    end


    # Select lat lon by ICAO airport id or name or municipality
    function selectIcao(icaoToSelect, centralPointRadiusDistance)
        centralPointLat = nothing
        centralPointLon = nothing
        errorCode = 0
        retrayNumber = 0
        # Test the DB csv or jdb
        while retrayNumber <= 1
            if stat("airports.csv").mtime > stat("airports.jdb").mtime
                println("\nThe airports database 'airports.csv' is loading for conversion to airports.jdb file")
                JuliaDB.save(JuliaDB.loadtable("airports.csv"),"airports.jdb")
                println("The airports database 'airports.jdb' is converted")
            elseif stat("airports.jdb").mtime == 0.0
                println("\nError: The airports.jdb file and airports.csv file is unreachable!\nPlease, make sure it is present in the photoscenary.jl program directory")
                errorCode = 403
                retrayNumber = 9
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
                        if !(Commons.inValue(centralPointLat,90) && Commons.inValue(centralPointLon,180))
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
                    retrayNumber = 9
                catch err
                    if retrayNumber == 0
                        retrayNumber = 1
                        rm("airports.jdb", force=true)
                        println("\nError: The airports.jdb file is corrupt\n\tI make an attempt to regenerate the file using the data from the file: airports.csv")
                    else
                        println("\nError: The airports.jdb file is corrupt\n\tPlease, make sure if airports.csv file is present in the program directory\n\tRemove the corrupt airports.jdb file and restart the program\nError code is $err")
                        errorCode = 404
                        retrayNumber = 9
                    end
                end
            end
            if retrayNumber == 0 retrayNumber = 9 end
        end
        return centralPointLat, centralPointLon, errorCode
    end


    function getRouteListFormatFGFS!(routeList,route,minDistance)
        wps = LightXML.get_elements_by_tagname(route[1][1], "wp")
        centralPointLatPrec = nothing
        centralPointLonPrec = nothing
        for wp in wps
            foundData = false
            if wp != nothing
                if find_element(wp,"icao") != nothing
                    icao = strip(content(find_element(wp,"icao")))
                    (centralPointLat, centralPointLon, errorCode) = selectIcao(icao,minDistance)
                    if errorCode == 0 foundData = true end
                elseif find_element(wp,"lon") != nothing
                    centralPointLat = Base.parse(Float64, strip(content(find_element(wp,"lat"))))
                    centralPointLon = Base.parse(Float64, strip(content(find_element(wp,"lon"))))
                    foundData = true
                end
                if foundData
                    # Get the distance
                    if centralPointLatPrec != nothing && centralPointLonPrec != nothing
                        posPrec = Geodesy.LLA(centralPointLatPrec,centralPointLonPrec, 0.0)
                        pos = Geodesy.LLA(centralPointLat,centralPointLon, 0.0)
                        distanceNm = euclidean_distance(pos,posPrec) / 1852.0
                    else
                        distanceNm = 0.0
                    end
                    if minDistance < distanceNm
                        numberTrunk = Int32(round(distanceNm / minDistance))
                        for i in 1:(numberTrunk - 1)
                            degLat = centralPointLatPrec + i * (centralPointLat - centralPointLatPrec) / numberTrunk
                            deglon = centralPointLonPrec + i * (centralPointLon - centralPointLonPrec) / numberTrunk
                            dist = euclidean_distance(Geodesy.LLA(degLat,deglon, 0.0),posPrec) / 1852.0
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
        return routeList
    end


    function getRouteListFormatGPX!(routeList,route,minDistance)
        wps = LightXML.get_elements_by_tagname(route[1][1], "rtept")
        centralPointLatPrec = nothing
        centralPointLonPrec = nothing
        for wp in wps
            if wp != nothing
                if attribute(wp,"lon") != nothing && attribute(wp,"lat") != nothing
                    centralPointLat = Base.parse(Float64, strip(attribute(wp,"lat")))
                    centralPointLon = Base.parse(Float64, strip(attribute(wp,"lon")))
                    # Get the distance
                    if centralPointLatPrec != nothing && centralPointLonPrec != nothing
                        posPrec = Geodesy.LLA(centralPointLatPrec,centralPointLonPrec, 0.0)
                        pos = Geodesy.LLA(centralPointLat,centralPointLon, 0.0)
                        distanceNm = euclidean_distance(pos,posPrec) / 1852.0
                    else
                        distanceNm = 0.0
                    end
                    if minDistance < distanceNm
                        numberTrunk = Int32(round(distanceNm / minDistance))
                        for i in 1:(numberTrunk - 1)
                            degLat = centralPointLatPrec + i * (centralPointLat - centralPointLatPrec) / numberTrunk
                            deglon = centralPointLonPrec + i * (centralPointLon - centralPointLonPrec) / numberTrunk
                            dist = euclidean_distance(Geodesy.LLA(degLat,deglon, 0.0),posPrec) / 1852.0
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
        return routeList
    end


    function loadRoute(fileOfRoute,centralPointRadiusDistance)
        centralPointRadiusDistanceFactor = 0.5
        minDistance = centralPointRadiusDistance * centralPointRadiusDistanceFactor
        route = findFileOfRoute(fileOfRoute)
        routeList = Any[]
        if route != nothing
            if route[3] == "FGFS"
                getRouteListFormatFGFS!(routeList,route,minDistance)
            elseif route[3] == "GPX"
                getRouteListFormatGPX!(routeList,route,minDistance)
            else
            end
        else
            println("\nError: loadRoute in the route file: $fileOfRoute")
        end
        #ccall(:jl_exit, Cvoid, (Int32,), 405)
        return routeList, size(routeList)[1]
    end


end
