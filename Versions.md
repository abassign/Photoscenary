# Versioning

## 0.3.4

Correction of Unicode characters (Aa for example Chinese characters) in file names as https://docs.julialang.org/en/v1/manual/strings/#Unicode-and-UTF-8
Commons.jl in the getFileName function
The old code is: filename[1:fl-1]
the new code is: filename[1:prevind(filename,fl)]
