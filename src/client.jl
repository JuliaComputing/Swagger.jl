# collection formats
const COLL_MULTI = "multi"  # aliased to CSV, as multi is not supported by Requests.jl (https://github.com/JuliaWeb/Requests.jl/issues/140)
const COLL_PIPES = "pipes"
const COLL_SSV = "ssv"
const COLL_TSV = "tsv"
const COLL_CSV = "csv"
const COLL_DLM = Dict{String,String}([COLL_PIPES=>"|", COLL_SSV=>" ", COLL_TSV=>"\t", COLL_CSV=>",", COLL_MULTI=>","])

const DATETIME_FORMATS = (Dates.DateFormat("yyyy-mm-dd HH:MM:SS.sss"), Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.sss"), Dates.DateFormat("yyyy-mm-ddTHH:MM:SSZ"))
const DATE_FORMATS = (Dates.DateFormat("yyyy-mm-dd"),)

const DEFAULT_TIMEOUT_SECS = 5*60
const DEFAULT_LONGPOLL_TIMEOUT_SECS = 15*60

function convert(::Type{DateTime}, str::String)
    # strip off timezone, as Julia DateTime does not parse it
    if '+' in str
        str = split(str, '+')[1]
    end
    # truncate micro/nano seconds to milliseconds, as Julia DateTime does not parse it
    if '.' in str
        uptosec,subsec = split(str, '.')
        if length(subsec) > 3
            str = uptosec * "." * subsec[1:3]
        end
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

struct SwaggerException <: Exception
    reason::String
end

struct ApiException <: Exception
    status::Int
    reason::String
    resp::Downloads.Response
    error::Union{Nothing,Downloads.RequestError}

    function ApiException(error::Downloads.RequestError; reason::String="")
        isempty(reason) && (reason = error.message)
        isempty(reason) && (reason = error.response.message)
        new(error.response.status, reason, error.response, error)
    end
    function ApiException(resp::Downloads.Response; reason::String="")
        isempty(reason) && (reason = resp.message)
        new(resp.status, reason, resp, nothing)
    end
end

struct Client
    root::String
    headers::Dict{String,String}
    get_return_type::Function   # user provided hook to get return type from response data
    clntoptions::Dict{Symbol,Any}
    downloader::Downloader
    timeout::Ref{Int}
    pre_request_hook::Function  # user provided hook to modify the request before it is sent

    function Client(root::String;
            headers::Dict{String,String}=Dict{String,String}(),
            get_return_type::Function=(default,data)->default,
            long_polling_timeout::Int=DEFAULT_LONGPOLL_TIMEOUT_SECS,
            timeout::Int=DEFAULT_TIMEOUT_SECS,
            pre_request_hook::Function=noop_pre_request_hook)
        clntoptions = Dict{Symbol,Any}(:throw=>false, :verbose=>false)
        downloader = Downloads.Downloader()
        downloader.easy_hook = (easy, opts) -> begin
            Downloads.Curl.setopt(easy, LibCURL.CURLOPT_LOW_SPEED_TIME, long_polling_timeout)
        end
        new(root, headers, get_return_type, clntoptions, downloader, Ref{Int}(timeout), pre_request_hook)
    end
end

set_user_agent(client::Client, ua::String) = set_header(client, "User-Agent", ua)
set_cookie(client::Client, ck::String) = set_header(client, "Cookie", ck)
set_header(client::Client, name::String, value::String) = (client.headers[name] = value)
set_timeout(client::Client, timeout::Int) = (client.timeout[] = timeout)

function with_timeout(fn, client::Client, timeout::Integer)
    oldtimeout = client.timeout[]
    client.timeout[] = timeout
    try
        fn(client)
    finally
        client.timeout[] = oldtimeout
    end
end

function with_timeout(fn, api::SwaggerApi, timeout::Integer)
    client = api.client
    oldtimeout = client.timeout[]
    client.timeout[] = timeout
    try
        fn(api)
    finally
        client.timeout[] = oldtimeout
    end
end

struct Ctx
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
    timeout::Int
    curl_mime_upload::Any
    pre_request_hook::Function

    function Ctx(client::Client, method::String, return_type, resource::String, auth, body=nothing;
            timeout::Int=client.timeout[],
            pre_request_hook::Function=client.pre_request_hook)
        resource = client.root * resource
        headers = copy(client.headers)
        new(client, method, return_type, resource, auth, Dict{String,String}(), Dict{String,String}(), headers, Dict{String,String}(), Dict{String,String}(), body, timeout, nothing, pre_request_hook)
    end
end

is_json_mime(mime::T) where {T <: AbstractString} = ("*/*" == mime) || occursin(r"(?i)application/json(;.*)?", mime) || occursin(r"(?i)application/(.*)-patch\+json(;.*)?", mime)

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

set_header_accept(ctx::Ctx, accepts::Vector{T}) where {T} = set_header_accept(ctx, convert(Vector{String}, accepts))
function set_header_accept(ctx::Ctx, accepts::Vector{String})
    accept = select_header_accept(accepts)
    !isempty(accept) && (ctx.header["Accept"] = accept)
    return nothing
end

set_header_content_type(ctx::Ctx, ctypes::Vector{T}) where {T} = set_header_content_type(ctx, convert(Vector{String}, ctypes))
function set_header_content_type(ctx::Ctx, ctypes::Vector{String})
    ctx.header["Content-Type"] = select_header_content_type(ctypes)
    return nothing
end

set_param(params::Dict{String,String}, name::String, value::Nothing; collection_format=nothing) = nothing

function set_param(params::Dict{String,String}, name::String, value::Union{Nothing,T}; collection_format=nothing) where {T}
    (value === nothing) && return

    if !isa(value, Vector) || isempty(collection_format)
        params[name] = string(value)
    else
        dlm = get(COLL_DLM, collection_format, "")
        isempty(dlm) && throw(SwaggerException("Unsupported collection format $collection_format"))
        params[name] = join(string.(value), dlm)
    end
end

function prep_args(ctx::Ctx)
    kwargs = copy(ctx.client.clntoptions)
    kwargs[:downloader] = ctx.client.downloader     # use the default downloader for most cases

    isempty(ctx.file) && (ctx.body === nothing) && isempty(ctx.form) && !("Content-Length" in keys(ctx.header)) && (ctx.header["Content-Length"] = "0")
    headers = ctx.header
    body = nothing
    if !isempty(ctx.form)
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        body = URIs.escapeuri(ctx.form)
    end

    if !isempty(ctx.file)
        # use a separate downloader for file uploads
        # until we have something like https://github.com/JuliaLang/Downloads.jl/pull/148
        downloader = Downloads.Downloader()
        downloader.easy_hook = (easy, opts) -> begin
            Downloads.Curl.setopt(easy, LibCURL.CURLOPT_LOW_SPEED_TIME, long_polling_timeout)
            mime = LibCURL.curl_mime_init(easy)
            for (_k,_v) in ctx.file
                part = LibCURL.curl_mime_addpart(mime)
                LibCURL.curl_mime_name(part, _k)
                LibCURL.curl_mime_filedata(part, _v)
                # TODO: make provision to call curl_mime_type in future?
            end
            Downloads.Curl.setopt(easy, LibCURL.CURLOPT_MIMEPOST, mime)
        end
        kwargs[:downloader] = downloader
        ctx.curl_mime_upload = mime
    end

    if ctx.body !== nothing
        (isempty(ctx.form) && isempty(ctx.file)) || throw(SwaggerException("Can not send both form-encoded data and a request body"))
        if is_json_mime(get(ctx.header, "Content-Type", "application/json"))
            body = to_json(ctx.body)
        elseif ("application/x-www-form-urlencoded" == ctx.header["Content-Type"]) && isa(ctx.body, Dict)
            body = URIs.escapeuri(ctx.body)
        elseif isa(ctx.body, SwaggerModel) && isempty(get(ctx.header, "Content-Type", ""))
            headers["Content-Type"] = "application/json"
            body = to_json(ctx.body)
        else
            body = ctx.body
        end
    end

    kwargs[:timeout] = ctx.timeout
    kwargs[:method] = uppercase(ctx.method)
    kwargs[:headers] = headers

    return body, kwargs
end

function header(resp::Downloads.Response, name::AbstractString, defaultval::AbstractString)
    for (n,v) in resp.headers
        (n == name) && (return v)
    end
    return defaultval
end

response(::Type{Nothing}, resp::Downloads.Response, body) = nothing::Nothing
response(::Type{T}, resp::Downloads.Response, body) where {T <: Real} = response(T, body)::T
response(::Type{T}, resp::Downloads.Response, body) where {T <: String} = response(T, body)::T
function response(::Type{T}, resp::Downloads.Response, body) where {T}
    ctype = header(resp, "Content-Type", "application/json")
    response(T, is_json_mime(ctype), body)::T
end
response(::Type{T}, ::Nothing, body) where {T} = response(T, true, body)
function response(::Type{T}, is_json::Bool, body) where {T}
    (length(body) == 0) && return T()
    response(T, is_json ? JSON.parse(String(body)) : body)::T
end
response(::Type{String}, data::Vector{UInt8}) = String(data)
response(::Type{T}, data::Vector{UInt8}) where {T<:Real} = parse(T, String(data))
response(::Type{T}, data::T) where {T} = data
response(::Type{T}, data) where {T} = convert(T, data)
response(::Type{T}, data::Dict{String,Any}) where {T} = from_json(T, data)::T
response(::Type{T}, data::Dict{String,Any}) where {T<:Dict} = convert(T, data)
response(::Type{Vector{T}}, data::Vector{V}) where {T,V} = [response(T, v) for v in data]

struct ChunkReader
    buffered_input::Base.BufferStream
end

function Base.iterate(iter::ChunkReader, _state=nothing)
    if eof(iter.buffered_input)
        return nothing
    else
        out = IOBuffer()
        while !eof(iter.buffered_input)
            byte = read(iter.buffered_input, UInt8)
            (byte == codepoint('\n')) && break
            write(out, byte)
        end
        return (take!(out), iter)
    end
end

noop_pre_request_hook(ctx::Ctx) = ctx
noop_pre_request_hook(resource_path::AbstractString, body::Any, headers::Dict{String,String}) = (resource_path, body, headers)

function do_request(ctx::Ctx, stream::Bool=false; stream_to::Union{Channel,Nothing}=nothing)
    # call the user hook to allow them to modify the request context
    ctx = ctx.pre_request_hook(ctx)

    # prepare the url
    resource_path = replace(ctx.resource, "{format}"=>"json")
    for (k,v) in ctx.path
        resource_path = replace(resource_path, "{$k}"=>v)
    end
    # append query params if needed
    if !isempty(ctx.query)
        resource_path = string(URIs.URI(URIs.URI(resource_path); query=escapeuri(ctx.query)))
    end

    body, kwargs = prep_args(ctx)

    # call the user hook again, to allow them to modify the processed request
    resource_path, body, headers = ctx.pre_request_hook(resource_path, body, kwargs[:headers])
    kwargs[:headers] = headers

    if body !== nothing
        input = PipeBuffer()
        write(input, body)
    else
        input = nothing
    end

    if stream
        @assert stream_to !== nothing
    end

    resp = nothing
    output = Base.BufferStream()

    try
        if stream
            @sync begin
                download_task = @async begin
                    try
                        resp = Downloads.request(resource_path;
                            input=input,
                            output=output,
                            kwargs...
                        )
                    catch ex
                        if !isa(ex, InterruptException)
                            @error("exception invoking request", exception=(ex,catch_backtrace()))
                            rethrow()
                        end
                    finally
                        close(output)
                    end
                end
                @async begin
                    try
                        for chunk in ChunkReader(output)
                            return_type = ctx.client.get_return_type(ctx.return_type, String(copy(chunk)))
                            data = response(return_type, resp, chunk)
                            put!(stream_to, data)
                        end
                    catch ex
                        if !isa(ex, InvalidStateException) && isopen(stream_to)
                            @error("exception reading chunk", exception=(ex,catch_backtrace()))
                            rethrow()
                        end
                    finally
                        close(stream_to)
                    end
                end
                @async begin
                    interrupted = false
                    while isopen(stream_to)
                        try
                            wait(stream_to)
                            yield()
                        catch ex
                            isa(ex, InvalidStateException) || rethrow(ex)
                            interrupted = true
                            istaskdone(download_task) || schedule(download_task, InterruptException(), error=true)
                        end
                    end
                    interrupted || istaskdone(download_task) || schedule(download_task, InterruptException(), error=true)
                end
            end
        else
            resp = Downloads.request(resource_path;
                        input=input,
                        output=output,
                        kwargs...
                    )
            close(output)
        end
    finally
        if ctx.curl_mime_upload !== nothing
            LibCURL.curl_mime_free(ctx.curl_mime_upload)
            ctx.curl_mime_upload = nothing
        end
    end

    return resp, output
end

function exec(ctx::Ctx, stream_to::Union{Channel,Nothing}=nothing)
    stream = stream_to !== nothing
    resp, output = do_request(ctx, stream; stream_to=stream_to)

    if resp === nothing
        # request was interrupted
        return nothing
    end

    if isa(resp, Downloads.RequestError) || !(200 <= resp.status <= 206)
        throw(ApiException(resp))
    end

    if stream
        return resp
    else
        data = read(output)
        return_type = ctx.client.get_return_type(ctx.return_type, String(copy(data)))
        return response(return_type, resp, data)
    end
end

property_type(::Type{T}, name::Symbol) where {T<:SwaggerModel} = error("invalid type $T")
field_name(::Type{T}, name::Symbol) where {T<:SwaggerModel} = error("invalid type $T")

getproperty(o::T, name::Symbol) where {T<:SwaggerModel} = getfield(o, field_name(T,name))
hasproperty(o::T, name::Symbol) where {T<:SwaggerModel} = ((name in propertynames(T)) && (getproperty(o, name) !== nothing))
function setproperty!(o::T, name::Symbol, val) where {T<:SwaggerModel}
    validate_property(T, name, val)
    fieldtype = property_type(T, name)
    fieldname = field_name(T, name)

    if isa(val, fieldtype)
        return setfield!(o, fieldname, val)
    else
        ftval = try
            convert(fieldtype, val)
        catch
            fieldtype(val)
        end
        return setfield!(o, fieldname, ftval)
    end
end

function getpropertyat(o::T, path...) where {T<:SwaggerModel}
    val = getproperty(o, Symbol(path[1]))
    rempath = path[2:end]
    (length(rempath) == 0) && (return val)

    if isa(val, Vector)
        if isa(rempath[1], Integer)
            val = val[rempath[1]]
            rempath = rempath[2:end]
        else
            return [getpropertyat(item, rempath...) for item in val]
        end
    end

    (length(rempath) == 0) && (return val)
    getpropertyat(val, rempath...)
end

function haspropertyat(o::T, path...) where {T<:SwaggerModel}
    p1 = Symbol(path[1])
    ret = hasproperty(o, p1)
    rempath = path[2:end]
    (length(rempath) == 0) && (return ret)

    val = getproperty(o, p1)
    if isa(val, Vector)
        if isa(rempath[1], Integer)
            ret = length(val) >= rempath[1]
            if ret
                val = val[rempath[1]]
                rempath = rempath[2:end]
            end
        else
            return [haspropertyat(item, rempath...) for item in val]
        end
    end

    (length(rempath) == 0) && (return ret)
    haspropertyat(val, rempath...)
end

convert(::Type{T}, json::Dict{String,Any}) where {T<:SwaggerModel} = from_json(T, json)
convert(::Type{T}, v::Nothing) where {T<:SwaggerModel} = T()

show(io::IO, model::T) where {T<:SwaggerModel} = print(io, JSON.json(model, 2))
summary(model::T) where {T<:SwaggerModel} = print(io, T)

"""
    is_longpoll_timeout(ex::Exception)

Examine the supplied exception and returns true if the reason is timeout
of a long polling request. If the exception is a nested exception of type
CompositeException or TaskFailedException, then navigates through the nested
exception values to examine the leaves.
"""
is_longpoll_timeout(ex) = false
is_longpoll_timeout(ex::TaskFailedException) = is_longpoll_timeout(ex.task.exception)
is_longpoll_timeout(ex::CompositeException) = any(is_longpoll_timeout, ex.exceptions)
function is_longpoll_timeout(ex::Swagger.ApiException)
    ex.status == 200 && match(r"Operation timed out after \d+ milliseconds with \d+ bytes received", ex.reason) !== nothing
end
