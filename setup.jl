#=

Autor: Adriano Bassignana - Bergamo 2021
Licence: GPL 2

=#


println("Instal the packeges necessary for photoscenary.jl execution")

import Pkg; Pkg.add("ImageMagick")
import Pkg; Pkg.add("ArgParse")
import Pkg; Pkg.add("Printf")
import Pkg; Pkg.add("HTTP")
import Pkg; Pkg.add("FileIO")

println("Remember that for you need to make sure you have the ImageMagick program installed https://imagemagick.org/")
