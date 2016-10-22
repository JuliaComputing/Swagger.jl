module Swagger

using Requests
using HttpCommon
using Compat
using JSON

import Base: convert

abstract SwaggerModel
abstract SwaggerApi

include("client.jl")
include("val.jl")

end # module Swagger
