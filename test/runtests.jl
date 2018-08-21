using Swagger
using Test

# set the current julia executable to be used henceforth
("JULIA" in keys(ENV)) || (ENV["JULIA"] = joinpath(Sys.BINDIR, "julia"))

const gencmd = joinpath(dirname(@__FILE__()), "petstore", "generate.sh")
println("Generating petstore using $gencmd")
run(`$gencmd`)

println("Running petstore tests...")
include("petstore/runtests.jl")
