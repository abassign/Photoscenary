using JuliaDB
using Printf
using Parsers


include("commons.jl")


struct TailCoordinates
    lonDeg::Float64
    latDeg::Float64
    lon::Int64
    lat::Int64
    x::Int64
    y::Int64
    function TailCoordinates(index::Int64)
        (lonDeg,latDeg,lon,lat,x,y) = coordFromIndex(index)
        return new(lonDeg,latDeg,lon,lat,x,y)
    end
end


struct TailData
    path::Union{String,Nothing}
    name::String
    modDate::Float64
    size::Int64
    pixelSize::Int16
end


mutable struct TailGroupByIndex
    index::Int64
    filesFound::Union{Array{TailData},Nothing}
    coordinates::Union{TailCoordinates,Nothing}
    timeLastScan::Float64
    function TailGroupByIndex() new(0,Any[],nothing,0.0) end
end


function tailGroupByIndexInsert(tgi::TailGroupByIndex,index::Int64,tailData::TailData)
    tgi.index = index
    push!(tgi.filesFound,tailData)
    tgi.coordinates = TailCoordinates(index)
    tgi.timeLastScan = time()
end


function getTailGroupByIndex(db,index::Int64)
    records = filter(val -> val[1] == index,db)
    if length(records) > 0
        return records[1][2]
    else
        return nothing
    end
end


function getTailGroupByIndex(db,index::Int64,path::String)
    records = getTailGroupByIndex(db,index)
    if records != nothing
        for record in records.filesFound
            fl = findlast(path,record.path)
            if fl != nothing
                if fl[1] == 1
                    return record,records.coordinates
                else
                    return nothing
                end
            else
                return nothing
            end
        end
    else
        return nothing
    end
end


function updateFilesListTypeDDS(path::String=homedir())
    filesPath = Dict{Int64,TailGroupByIndex}()
    id = 0
    for (root, dirs, files) in walkdir(path)
        for file in files
            fe = getFileExtension(file)
            if fe != nothing && uppercase(fe) == ".DDS"
                index = Parsers.tryparse(Int,getFileName(file))
                if index != nothing
                    cfi = coordFromIndex(index)
                    fileWithPath = cfi[7] * "/" * cfi[8] * "/" * string(index) * ".dds"
                    jp = joinpath(root, file)
                    if findlast(fileWithPath,jp) != nothing
                        id += 1
                        td = TailData(jp,file,stat(jp).mtime,stat(jp).size,0)
                        if !haskey(filesPath,index) filesPath[index] = TailGroupByIndex() end
                        tailGroupByIndexInsert(filesPath[index],index,td)
                    end
                end
            end
        end
    end
    return JuliaDB.table(collect(filesPath);pkey=1)
end
