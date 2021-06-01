# Functions common to all programs
# Aut: Adriano Bassignana
# Licence: GPL 2
# Date start production: April 2021

m = [90, 89, 86, 83, 76, 62, 22,-22]
n = [12.0, 4.0, 2.0, 1.0, 0.5, 0.25, 0.125]

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
    round((lon -  mod(lon,tileWidth(lat))) - (radius/longDegOnLatitudeNm(lat)),digits=1),
    round((lat - mod(lat,0.125) + 0.125) + (radius/longDegOnLongitudeNm()),digits=1),
    round((lon - mod(lon,tileWidth(lat)) + tileWidth(lat))+ (radius/longDegOnLatitudeNm(lat)),digits=1))

sizeHight(sizeWidth,lat) = Int(sizeWidth / (8 * tileWidth(lat)))


function coordFromIndex(index)
    lon = (index >> 14) - 180
    lat = ((index - ((lon + 180) << 14)) >> 6) - 90
    y = (index - (((lon + 180) << 14) + ((lat + 90) << 6))) >> 3
    x = index - ((((lon + 180) << 14) + ((lat + 90) << 6)) + (y << 3))
    a = string(lon >= 0.0 ? "e" : "w", lon >= 0.0 ? @sprintf("%03d",floor(abs(lon),digits=-1)) : @sprintf("%03d",ceil(abs(lon),digits=-1)),
        lat >= 0.0 ? "n" : "s", lat >= 0.0 ? @sprintf("%02d",floor(abs(lat),digits=-1)) : @sprintf("%02d",ceil(abs(lat),digits=-1)))
    b = string(lon >= 0.0 ? "e" : "w", lon >= 0.0 ? @sprintf("%03d",floor(Int,abs(lon))) : @sprintf("%03d",ceil(Int,abs(lon))),
        lat >= 0.0 ? "n" : "s", lat >= 0.0 ? @sprintf("%02d",floor(Int,abs(lat))) : @sprintf("%02d",ceil(Int,abs(lat))))
    return lon + (tileWidth(lat) / 2.0 + x * tileWidth(lat)) / 2.0, lat + (0.125 / 2 + y * 0.125) / 2.0, lon, lat, x, y, a, b
end


function findFile(fileName,path=homedir())
    filesPath = Any[]
    id = 0
    for (root, dirs, files) in walkdir(path)
        for file in files
            if file == fileName
                id += 1
                push!(filesPath,(id,joinpath(root, file),stat(joinpath(root, file)).mtime,stat(joinpath(root, file)).size))
            end
        end
    end
    return filesPath
end


function getFileExtension(filename::String)
    fl = findlast(isequal('.'),filename)
    return fl != nothing ? filename[fl:end] : nothing
end


function getFileName(filename::String)
    fl = findlast(isequal('.'),filename)
    return fl != nothing ? filename[1:fl-1] : nothing
end

