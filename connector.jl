#=

Autor: Adriano Bassignana Bargamo 2021
Licence: GPL 2

Program for reading the aircraft position via Telnet protocol over TCP-IP.

=#

using Sockets
using EzXML
using Dates
#using Geodesy


mutable struct TelnetConnection
    ipAddress::IPv4
    ipPort::Int
    sock::Union{TCPSocket,Nothing}
    telnetData::Vector{Any}

    function TelnetConnection(address::String)
        (ipAddress,ipPort) = getFGFSPositionIpAndPort(address)
        new(IPv4(ipAddress),ipPort,nothing,Any[])
    end
end


struct FGFSPosition
    latitudeDeg::Float64
    longitudeDeg::Float64
    altitudeFt::Float64
    directionDeg::Float64
    distanceNm::Float64
    speedMph::Float64
    time::Float64

    function FGFSPosition(lat::Float64,lon::Float64,alt::Float64)
        new(lat,lon,alt,0.0,0.0,0.0,time())
    end

    function FGFSPosition(lat::Float64,lon::Float64,alt::Float64,precPosition::FGFSPosition)
        t = time()
        try
            dir = Main.Geodesics.azimuth(precPosition.longitudeDeg,precPosition.latitudeDeg,lon,lat)
            dist = Main.Geodesics.surface_distance(precPosition.longitudeDeg,precPosition.latitudeDeg,lon,lat,Main.Geodesics.localEarthRadius(lat)) / 1852.0
            deltaTime = t - precPosition.time
            speedMph = (dist-precPosition.distanceNm) * 3600 / deltaTime
            new(lat,lon,alt,dir,dist,speedMph,t)
        catch err
            println("FGFSPosition - Error: $err")
            new(lat,lon,alt,precPosition.dir,precPosition.dist,precPosition.speedMph,t)
        end
    end
end


mutable struct FGFSPositionRoute
    marks::Vector{FGFSPosition}
    size::Int64
    actual::Union{FGFSPosition,Nothing}
    precPosition::Union{FGFSPosition,Nothing}
    actualDistance::Float64
    actualSpeed::Float64
    actualDirectionDeg::Float64
    radiusStep::Float64
    stepTime::Float64
    telnetLastTime::Float64
    telnet::Union{TelnetConnection,Nothing}

    function FGFSPositionRoute(centralPointRadiusDistance)
        new(Any[],0,nothing,nothing,0.0,0.0,0.0,centralPointRadiusDistance,2.0,0.0,nothing)
    end
end


telnetConnectionSockIsOpen(telnet::Union{TelnetConnection,Nothing}) = telnet == nothing || telnet.sock == nothing ? false : Sockets.isopen(telnet.sock)

telnetConnectionSockIsOpen(positionRoute::Union{FGFSPositionRoute,Nothing}) = positionRoute == nothing || positionRoute.telnet == nothing || positionRoute.telnet.sock == nothing ? false : Sockets.isopen(positionRoute.telnet.sock)


function getFGFSPositionIpAndPort(ipAddressAndPort::String)
    s = split(ipAddressAndPort,":")
    ip = "127.0.0.1"
    p = 5000
    if Base.size(s)[1] > 1
        try
            p = parse(Int,s[2])
        catch
        end
    end
    if length(s[1]) > 0 ip = string(s[1]) end
    return ip,p
end


function setFGFSConnect(telnet::TelnetConnection,debugLevel::Int)
    @async begin
        try
            if !telnetConnectionSockIsOpen(telnet)
                telnet.sock = connect(telnet.ipAddress,telnet.ipPort)
                sleep(0.5)
                debugLevel > 1 && println("setFGFSConnect - Frist connection $(telnet.ipAddress):$(telnet.ipPort)")
            end
            try
                while telnetConnectionSockIsOpen(telnet)
                    line = Sockets.readline(telnet.sock)
                    if length(line) > 0
                        push!(telnet.telnetData,line)
                    end
                end
            catch err
                telnet.sock = nothing
                debugLevel > 1 && println("setFGFSConnect - connection ended with error $err")
            end
        catch err
            telnet.sock = nothing
            debugLevel > 1 && println("setFGFSConnect - socket not create with error $err")
        end
    end
    return telnet
end


function getFGFSPosition(telnet::TelnetConnection, precPosition::Union{FGFSPosition,Nothing},debugLevel::Int)
    telnetDataXML = ""
    telnet.telnetData = Any[]
    try
        retray = 1
        while telnetConnectionSockIsOpen(telnet) && retray <= 3
            write(telnet.sock,string("dump /position","\r\n"))
            sleep(0.5)
            if size(telnet.telnetData)[1] >= 8
                for td in telnet.telnetData[2:end] telnetDataXML *= td end
                try
                    primates = EzXML.root(EzXML.parsexml(telnetDataXML))
                    lat = Base.parse(Float64,EzXML.nodecontent.(findall("//latitude-deg",primates))[1])
                    lon = Base.parse(Float64,EzXML.nodecontent.(findall("//longitude-deg",primates))[1])
                    alt = Base.parse(Float64,EzXML.nodecontent.(findall("//altitude-ft",primates))[1])
                    if precPosition == nothing
                        position = FGFSPosition(lat,lon,alt)
                    else
                        position = FGFSPosition(lat,lon,alt,precPosition)
                    end
                    return position
                catch err
                    debugLevel > 1 && println("\ngetFGFSPosition - Error in XML: $err")
                    return nothing
                end
            end
            retray += 1
        end
        debugLevel > 1 && println("\ngetFGFSPosition - Sockets is close")
        return nothing
    catch err
        debugLevel > 1 && println("\ngetFGFSPosition - Error connection: $err")
        return nothing
    end
end


function getFGFSPositionSetTask(ipAddressAndPort::String,centralPointRadiusDistance::Float64,debugLevel::Int)
    positionRoute = FGFSPositionRoute(centralPointRadiusDistance)
    maxRetray = 10
    @async while true
        positionRoute.telnet = setFGFSConnect(TelnetConnection(ipAddressAndPort),debugLevel)
        sleep(1.0)
        if telnetConnectionSockIsOpen(positionRoute)
            while telnetConnectionSockIsOpen(positionRoute)
                retray = 1
                while telnetConnectionSockIsOpen(positionRoute) && retray <= maxRetray
                    position = getFGFSPosition(positionRoute.telnet,positionRoute.precPosition,debugLevel)
                    if position == nothing
                        if !telnetConnectionSockIsOpen(positionRoute)
                            break
                        else
                            debugLevel > 0 && println("\ngetFGFSPositionSetTask - Error: contact lost to FGFS program | n. retray: $retray")
                            retray += 1
                            sleep(1.0)
                        end
                    else
                        sleep(positionRoute.stepTime)
                        retray = 1
                        if positionRoute.size == 0
                            push!(positionRoute.marks,position)
                            positionRoute.size += 1
                        end
                        oldDistance = positionRoute.actualDistance
                        oldTime = 0.0
                        if positionRoute.actual != nothing oldTime = positionRoute.actual.time end
                        positionRoute.actual = position
                        positionRoute.actualDistance = Main.Geodesics.surface_distance(positionRoute.marks[end].longitudeDeg,positionRoute.marks[end].latitudeDeg,position.longitudeDeg,position.latitudeDeg,Main.Geodesics.localEarthRadius(position.latitudeDeg)) / 1852.0
                        if oldTime > 0.0 && (positionRoute.actual.time - positionRoute.marks[end].time) > 0.0
                            positionRoute.actualSpeed = positionRoute.actualDistance * 3600 / (positionRoute.actual.time - positionRoute.marks[end].time)
                        else
                            positionRoute.actualSpeed = 0.0
                        end
                        positionRoute.actualDirectionDeg = Main.Geodesics.azimuth(positionRoute.marks[end].longitudeDeg,positionRoute.marks[end].latitudeDeg,position.longitudeDeg,position.latitudeDeg)
                        if positionRoute.actualDistance >= (positionRoute.radiusStep * 0.7)
                            # Speed, radius and direction correction
                            push!(positionRoute.marks,position)
                            positionRoute.size += 1
                        end
                        positionRoute.precPosition = position
                        positionRoute.telnetLastTime = time()
                        break
                    end
                end
            end
            if telnetConnectionSockIsOpen(positionRoute) && retray > maxRetray
                Sockets.close(positionRoute.telnet.sock)
            end
        end
    end
    return positionRoute
end





