using Swagger
using Test

# set the current julia executable to be used henceforth
("JULIA" in keys(ENV)) || (ENV["JULIA"] = joinpath(Sys.BINDIR, "julia"))

const gencmd = joinpath(dirname(@__FILE__()), "petstore", "generate.sh")
@info("Generating petstore", gencmd)
run(`$gencmd`)

if ENV["RUNNER_OS"] == "Linux"
    @info("Running petstore tests")
    include("petstore/runtests.jl")
else
    @info("Skipping petstore tests in OSX (can not run petstore docker on travis OSX)")
end
