__precompile__(true)

module Swagger

using Requests
using HttpCommon
using JSON

import Base: convert, show, summary
import JSON: AssociativeWrapper

abstract SwaggerModel
abstract SwaggerApi

include("client.jl")
include("json.jl")
include("val.jl")

end # module Swagger
