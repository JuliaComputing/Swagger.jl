using Swagger
using Test

const gencmd = joinpath(dirname(@__FILE__()), "petstore", "generate.sh")

include("utilstests.jl")

@testset "Swagger" begin
    @testset "Utils" begin
        test_longpoll_exception_check()
    end
    @testset "Code generation" begin
        # set the current julia executable to be used henceforth
        ("JULIA" in keys(ENV)) || (ENV["JULIA"] = joinpath(Sys.BINDIR, "julia"))

        @info("Generating petstore", gencmd)
        run(`$gencmd`)
    end
    @testset "Petstore" begin
        if get(ENV, "RUNNER_OS", "") == "Linux"
            @info("Running petstore tests")
            include("petstore/runtests.jl")
        else
            @info("Skipping petstore tests in non Linux environment (can not run petstore docker on OSX or Windows)")
        end
    end
end
