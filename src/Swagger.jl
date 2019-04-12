module Swagger

using HTTP
using JSON
using MbedTLS
using Dates

import Base: convert, show, summary, getindex, keys, length, getproperty, setproperty!, propertynames
import JSON: lower
import Base: iterate

abstract type SwaggerModel end
abstract type SwaggerApi end

include("client.jl")
include("json.jl")
include("val.jl")

end # module Swagger
