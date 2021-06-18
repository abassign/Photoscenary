using JuliaDB
using Printf
using Parsers


include("commons.jl")
include("ScanDir.jl")


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
    pixelSizeW::Int16
    pixelSizeH::Int16
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


function copyTilesByIndex(db,index::Int64,pixelSizeW::Int64,aBasePath::String)
    # The PathTo not include the file name and the super 2 levels name
    # For example:
    # Base path: /home/abassign
    # index: 1105762
    # Result is: /home/abassign/w120n30/w113n35/1105762.dds
    records = getTailGroupByIndex(db,index)
    if records != nothing
        for record in records.filesFound
            if records.filesFound[1].pixelSizeW >= pixelSizeW
                # Create the effective path
                cfi = coordFromIndex(index)
                basePath = normpath(aBasePath * "/" * cfi[7] * "/" * cfi[8] * "/" * string(index) * ".dds")
                if !ispath(basePath) mkpath(basePath) end
                cp(records.filesFound[1].path,basePath,force=true)
                return (index,records.filesFound[1].path,basePath)
            end
        end
        return nothing,nothing,nothing
    else
        return nothing,nothing,nothing
    end
end


function countDirError()
    dirsWithErrors::Int = 0
    add(err) = dirsWithErrors += 1
    get() = dirsWithErrors
    () -> (add;get)
end


function updateFilesListTypeDDS(path::String=homedir())
    filesPath = Dict{Int64,TailGroupByIndex}()
    rowsNumber = 0
    filesSize = 0
    cde = countDirError()
    if ispath(path)
	for (root, dirs, files) in ScanDir.walkdir(path; onerror = e->(cde.add(e)))
            for file in files
                fe = getFileExtension(file)
                if fe != nothing && uppercase(fe) == ".DDS"
                    index = Parsers.tryparse(Int,getFileName(file))
                    if index != nothing
                        cfi = coordFromIndex(index)
                        slash = "/"
                        if Base.Sys.iswindows() slash = "\\" end
                        fileWithPath = cfi[7] * slash * cfi[8] * slash * string(index) * ".dds"
                        jp = joinpath(root, file)
                        if findlast(fileWithPath,jp) != nothing
                            (isDDS,pixelSizeW,pixelSizeH) = getDDSSize(jp)
                            if isDDS
                                td = TailData(jp,file,stat(jp).mtime,stat(jp).size,pixelSizeW,pixelSizeH)
                                if !haskey(filesPath,index) filesPath[index] = TailGroupByIndex() end
                                tailGroupByIndexInsert(filesPath[index],index,td)
                                rowsNumber += 1
                                filesSize += stat(jp).size
                            end
                        end
                    end
                end
            end
        end
	println("updateFilesListTypeDDS: find n. $(cde.get()) dir with errors")
        return JuliaDB.table(collect(filesPath);pkey=1),rowsNumber,filesSize
    else
        print("\nError: not found the root path: $path")
    end
end
