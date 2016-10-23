using Swagger
using Base.Test

const gencmd = joinpath(dirname(@__FILE__()), "petstore", "generate.sh")
println("Generating petstore using $gencmd")
run(`$gencmd`)

println("Running petstore tests...")
include("petstore/runtests.jl")
