__precompile__(true)

module Swagger

using Requests
using HttpCommon
using JSON
using MbedTLS

import Base: convert, show, summary, getindex, keys, length, start, done, next
import JSON: lower

abstract SwaggerModel
abstract SwaggerApi

include("client.jl")
include("json.jl")
include("val.jl")

end # module Swagger
