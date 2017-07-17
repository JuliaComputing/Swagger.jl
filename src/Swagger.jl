__precompile__(true)

module Swagger

using Requests
using HttpCommon
using JSON
using MbedTLS
using Compat

import Base: convert, show, summary, getindex, keys, length, start, done, next
import JSON: lower

@compat abstract type SwaggerModel end
@compat abstract type SwaggerApi end

include("client.jl")
include("json.jl")
include("val.jl")

end # module Swagger
