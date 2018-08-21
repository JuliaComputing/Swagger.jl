module Swagger

using HTTP
using JSON
using MbedTLS
using Dates

import Base: convert, show, summary, getindex, keys, length
import JSON: lower

@static if VERSION < v"0.7.0-"
    import Base: start, done, next
else
    import Base: iterate
end

abstract type SwaggerModel end
abstract type SwaggerApi end

include("client.jl")
include("json.jl")
include("val.jl")

end # module Swagger
