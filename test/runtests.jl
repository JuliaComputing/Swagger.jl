using Swagger
using Test

# set the current julia executable to be used henceforth
("JULIA" in keys(ENV)) || (ENV["JULIA"] = joinpath(Sys.BINDIR, "julia"))

const gencmd = joinpath(dirname(@__FILE__()), "petstore", "generate.sh")
println("Generating petstore using $gencmd")
run(`$gencmd`)

if ENV["TRAVIS_OS_NAME"] == "linux"
    println("Running petstore tests...")
    include("petstore/runtests.jl")
else
    println("Skipping petstore tests in OSX (can not run petstore docker on travis OSX)")
end
