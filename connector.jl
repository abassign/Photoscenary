#=

Autor: Adriano Bassignana Bargamo 2021
Licence: GPL 2

Program for reading the aircraft position via Telnet protocol over TCP-IP.

=#

using Sockets
using EzXML
using Dates
#using Geodesy

mutable struct TelnetConnect
    ipAddress::IPv4
    ipPort::Int
    sock::Union{TCPSocket,Nothing}
    telnetData::Vector{Any}
    isConnect::Bool

    function TelnetConnect(ipAddress::IPv4, ipPort::Int)
        try
            sock = connect(ipAddress,ipPort)
            new(ipAddress,ipPort,sock,Any[],true)
        catch err
            println("TelnetConnect - Error: $err")
            new(ipAddress,ipPort,nothing,Any[],false)
        end
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
            speedMph = dist * 3600 / deltaTime
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
    actualDistance::Float64
    actualSpeed::Float64
    actualDirectionDeg::Float64
    radiusStep::Float64
    stepTime::Float64

    function FGFSPositionRoute()
        new(Any[],0,nothing,0.0,0.0,0.0,10.0,5.0)
    end

    function FGFSPositionRoute(radiusStep)
        new(Any[],0,nothing,0.0,0.0,0.0,radiusStep,5.0)
    end
end


function setFGFSConnect(ipAddress::String, ipPort::Int)
    telnet = TelnetConnect(IPv4(ipAddress),ipPort)
    nullLine = 0
    @async begin
        try
            while telnet.isConnect
                line = Sockets.readline(telnet.sock)
                if length(line) > 0
                    push!(telnet.telnetData,line)
                    nullLine = 0
                else
                    nullLine += 1
                    if nullLine > 2 telnet.isConnect = false end
                end
            end
        catch err
            print("connection ended with error $err")
            telnet.isConnect = false
        end
    end
    return telnet
end


function getFGFSPosition(telnet::TelnetConnect, precPosition::Union{FGFSPosition,Nothing})
    telnetDataXML = ""
    telnet.telnetData = Any[]
    try
        write(telnet.sock,string("dump /position","\r\n"))
        while telnet.isConnect
            sleep(0.1)
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
                    println("getFGFSPosition - Error in XML: $err")
                    return nothing
                end
            end
        end
    catch err
        println("getFGFSPosition - Error connection: $err")
        telnet.isConnect = false
    end
end


function ifFGFSActive(positionRoute::FGFSPositionRoute)
    return (time() - positionRoute.actual.time) <  1.2 * positionRoute.stepTime
end


function getFGFSPositionSetTask(positionRoute::FGFSPositionRoute, ipAddressAndPort::String)
    s = split(ipAddressAndPort,":")
    ip = "127.0.0.1"
    p = 5000
    if size(s)[1] > 1
        try
            p = parse(Int,s[2])
        catch
        end
    end
    if length(s[1]) > 0 ip = string(s[1]) end
    getFGFSPositionSetTask(positionRoute,ip,p)
end


function getFGFSPositionSetTask(positionRoute::FGFSPositionRoute, ipAddress::String, ipPort::Int)
    telnet = setFGFSConnect(ipAddress,ipPort)
    precPosition = nothing
    @async begin
        while telnet.isConnect
            position = getFGFSPosition(telnet,precPosition)
            if position == nothing
                println("getFGFSPositionSetTask - Error: contact lost to FGFS program")
            else
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
                if positionRoute.actualDistance >= positionRoute.radiusStep
                    # Speed, radius and direction correction
                    ## a = (lon,lat,baz) = Main.Geodesics.angular_step(position.longitudeDeg,position.latitudeDeg,positionRoute.actualDirectionDeg,positionRoute.radiusStep * 0.5)
                    push!(positionRoute.marks,position)
                    positionRoute.size += 1
                end
                precPosition = position
            end
            sleep(positionRoute.stepTime)
        end
    end
end





