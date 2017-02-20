# collection formats
const COLL_MULTI = "multi"  # aliased to CSV, as multi is not supported by Requests.jl (https://github.com/JuliaWeb/Requests.jl/issues/140)
const COLL_PIPES = "pipes"
const COLL_SSV = "ssv"
const COLL_TSV = "tsv"
const COLL_CSV = "csv"
const COLL_DLM = Dict{String,String}([COLL_PIPES=>"|", COLL_SSV=>" ", COLL_TSV=>"\t", COLL_CSV=>",", COLL_MULTI=>","])

const DATETIME_FORMATS = (Dates.DateFormat("yyyy-mm-dd HH:MM:SS.sss"), Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.sss"))
const DATE_FORMATS = (Dates.DateFormat("yyyy-mm-dd"),)

function convert(::Type{DateTime}, str::String)
    # strip off timezone, as Julia DateTime does not parse it
    if '+' in str
        str = split(str, "+")[1]
    end
    for fmt in DATETIME_FORMATS
        try
            return DateTime(str, fmt)
        catch
            # try next format
        end
    end
    throw(SwaggerException("Unsupported DateTime format: $str"))
end

function convert(::Type{Date}, str::String)
    for fmt in DATETIME_FORMATS
        try
            return Date(str, fmt)
        catch
            # try next format
        end
    end
    throw(SwaggerException("Unsupported Date format: $str"))
end

immutable SwaggerException <: Exception
    reason::String
end

immutable ApiException <: Exception
    status::Int
    reason::String
    resp::Response

    function ApiException(resp::Response; reason::String="")
        isempty(reason) && (reason = get(STATUS_CODES, resp.status, reason))
        new(resp.status, reason, resp)
    end
end

immutable Client
    root::String
    headers::Dict{String,String}
    get_return_type::Function   # user provided hook to get return type from response data
    tls_conf::Nullable{SSLConfig}

    function Client(root::String; headers::Dict{String,String}=Dict{String,String}(), get_return_type::Function=(default,data)->default, tls_conf=nothing)
        new(root, headers, get_return_type, tls_conf)
    end
end

set_user_agent(client::Client, ua::String) = set_header("User-Agent", ua)
set_cookie(client::Client, ck::String) = set_header("Cookie", ck)
set_header(client::Client, name::String, value::String) = (client.headers[name] = value)

immutable Ctx
    client::Client
    method::String
    return_type::Type
    resource::String
    auth::Vector{String}

    path::Dict{String,String}
    query::Dict{String,String}
    header::Dict{String,String}
    form::Dict{String,String}
    file::Dict{String,String}
    body::Any

    function Ctx(client::Client, method::String, return_type, resource::String, auth, body=nothing)
        resource = client.root * resource
        headers = copy(client.headers)
        new(client, method, return_type, resource, auth, Dict{String,String}(), Dict{String,String}(), headers, Dict{String,String}(), Dict{String,String}(), body)
    end
end

is_json_mime(mime::String) = ("*/*" == mime) || ismatch(r"(?i)application/json(;.*)?", mime)

function select_header_accept(accepts::Vector{String})
    isempty(accepts) && (return "application/json")
    for accept in accepts
        is_json_mime(accept) && (return accept)
    end
    return join(accepts, ", ")
end

function select_header_content_type(ctypes::Vector{String})
    isempty(ctypes) && (return "application/json")
    for ctype in ctypes
        is_json_mime(ctype) && (return (("*/*" == ctype) ? "application/json" : ctype))
    end
    return ctypes[1]
end

set_header_accept{T}(ctx::Ctx, accepts::Vector{T}) = set_header_accept(ctx, convert(Vector{String}, accepts))
function set_header_accept(ctx::Ctx, accepts::Vector{String})
    accept = select_header_accept(accepts)
    !isempty(accept) && (ctx.header["Accept"] = accept)
    return nothing
end

set_header_content_type{T}(ctx::Ctx, ctypes::Vector{T}) = set_header_content_type(ctx, convert(Vector{String}, ctypes))
function set_header_content_type(ctx::Ctx, ctypes::Vector{String})
    ctx.header["Content-Type"] = select_header_content_type(ctypes)
    return nothing
end

set_param(params::Dict{String,String}, name::String, value::Void; collection_format=nothing) = nothing

function set_param{T}(params::Dict{String,String}, name::String, value::Nullable{T}; collection_format=nothing)
    isnull(value) && return
    set_param(params, name, get(value); collection_format=collection_format)
end

function set_param(params::Dict{String,String}, name::String, value; collection_format::String="")
    if !isa(value, Vector) || isempty(collection_format)
        params[name] = string(value)
    else
        dlm = get(COLL_DLM, collection_format, "")
        isempty(dlm) && throw(SwaggerException("Unsupported collection format $collection_format"))
        params[name] = join(map((x)->string(x), value), dlm)
    end
end

function prep_args(ctx::Ctx)
    kwargs = Dict{Symbol,Any}()
    isempty(ctx.query) || (kwargs[:query] = ctx.query)
    isempty(ctx.header) || (kwargs[:headers] = ctx.header)
    isempty(ctx.form) || (kwargs[:data] = ctx.form)
    if !isempty(ctx.file)
        kwargs[:files] = FileParam[]
        for (_k,_v) in ctx.file
            push!(kwargs[:files], FileParam(read(_v), "", _k))
        end
    end
    if ctx.body !== nothing
        isempty(ctx.form) || throw(SwaggerException("Can not send both form-encoded data and body data"))
        kwargs[:data] = is_json_mime(get(ctx.header, "Content-Type", "application/json")) ? to_json(ctx.body) : ctx.body
    end
    # pass TLS conf for ca and client certificates
    isnull(ctx.client.tls_conf) || (kwargs[:tls_conf] = get(ctx.client.tls_conf))
    return kwargs
end

response(::Type{Void}, resp::Response) = nothing::Void
response{T<:Real}(::Type{T}, resp::Response) = response(T, resp.data)::T
response{T<:String}(::Type{T}, resp::Response) = response(T, resp.data)::T
function response{T}(::Type{T}, resp::Response)
    ctype = get(resp.headers, "Content-Type", "application/json")
    v = response(T, is_json_mime(ctype) ? JSON.parse(String(resp.data)) : resp.data)
    v::T
end
response{T<:Real}(::Type{T}, data::Vector{UInt8}) = parse(T, String(data))
response{T<:String}(::Type{T}, data::Vector{UInt8}) = String(data)::T
response{T}(::Type{T}, data::T) = data
response{T}(::Type{T}, data) = convert(T, data)
response{T}(::Type{T}, data::Dict{String,Any}) = from_json(T, data)::T
response{T<:Dict}(::Type{T}, data::Dict{String,Any}) = convert(T, data)
response{T,V}(::Type{Vector{T}}, data::Vector{V}) = [response(T, v) for v in data]

function exec(ctx::Ctx)
    resource_path = replace(ctx.resource, "{format}", "json")
    for (k,v) in ctx.path
        resource_path = replace(resource_path, "{$k}", v)
    end

    # TODO: use auth_settings for authentication
    kwargs = prep_args(ctx)
    httpmethod = getfield(Requests, Symbol(lowercase(ctx.method)))
    resp = httpmethod(resource_path; kwargs...)

    (200 <= resp.status <= 206) || throw(ApiException(resp))

    response(ctx.client.get_return_type(ctx.return_type, resp), resp)
end

name_map{T<:SwaggerModel}(o::T) = name_map(T)
field_map{T<:SwaggerModel}(o::T) = field_map(T)

# TODO: will be good to have a comprehensive selector syntax
function get_field{T<:SwaggerModel}(o::T, path...)
    val = get_field(o, path[1])
    rempath = path[2:end]
    (length(rempath) == 0) && (return val)

    if isa(val, Vector)
        if isa(rempath[1], Integer)
            val = val[rempath[1]]
            rempath = rempath[2:end]
        else
            return [get_field(item, rempath...) for item in val]
        end
    end

    (length(rempath) == 0) && (return val)
    get_field(val, rempath...)
end
get_field{T<:SwaggerModel}(o::T, name::String) = get_field(o, name_map(o)[name])
get_field{T<:SwaggerModel}(o::T, name::Symbol) = get(getfield(o, name))

function isset_field{T<:SwaggerModel}(o::T, path...)
    ret = isset_field(o, path[1])
    rempath = path[2:end]
    (length(rempath) == 0) && (return ret)

    val = get_field(o, path[1])
    if isa(val, Vector)
        if isa(rempath[1], Integer)
            ret = length(val) >= rempath[1]
            if ret
                val = val[rempath[1]]
                rempath = rempath[2:end]
            end
        else
            return [isset_field(item, rempath...) for item in val]
        end
    end

    (length(rempath) == 0) && (return ret)
    isset_field(val, rempath...)
end
isset_field{T<:SwaggerModel}(o::T, name::String) = isset_field(o, name_map(o)[name])
isset_field{T<:SwaggerModel}(o::T, name::Symbol) = !isnull(getfield(o, name))

set_field!{T<:SwaggerModel}(o::T, name::String, val) = set_field!(o, name_map(o)[name], val)
function set_field!{T<:SwaggerModel}(o::T, name::Symbol, val)
    validate_field(o, name, val)
    setfield!(o, name, fieldtype(T,name)(val))
end

convert{T<:SwaggerModel}(::Type{T}, json::Dict{String,Any}) = from_json(T, json)
convert{T<:SwaggerModel}(::Type{T}, v::Void) = T()

show{T<:SwaggerModel}(io::IO, model::T) = print(io, JSON.json(model, 2))
summary{T<:SwaggerModel}(model::T) = print(io, T)
