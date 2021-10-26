module TestStoreApi

using ..MyPetStore
using Swagger
using Test
using Dates

function test(uri)
    @info("StoreApi")
    client = Swagger.Client(uri)
    api = StoreApi(client)

    @info("StoreApi - getInventory")
    inventory = getInventory(api)
    @test isa(inventory, Dict{String,Int32})
    @test !isempty(inventory)

    @info("StoreApi - placeOrder")
    @test_throws Swagger.ValidationException Order(; id=10, petId=10, quantity=2, shipDate=DateTime(2017, 03, 12), status="invalid_status", complete=false)
    order = Order(; id=10, petId=10, quantity=2, shipDate=DateTime(2017, 03, 12), status="placed", complete=false)
    neworder = placeOrder(api, order)
    @test neworder.id == 10

    @info("StoreApi - getOrderById")
    @test_throws Swagger.ValidationException getOrderById(api, 0)
    order = getOrderById(api, 10)
    @test isa(order, Order)
    @test order.id == 10

    @info("StoreApi - getOrderById (async)")
    response_channel = Channel{Order}(1)
    @test_throws Swagger.ValidationException getOrderById(api, response_channel, 0)
    @sync begin
        @async begin
            resp = getOrderById(api, response_channel, 10)
            @test (200 <= resp.status <= 206)
        end
        @async begin
            order = take!(response_channel)
            @test isa(order, Order)
            @test order.id == 10
        end
    end

    # a closed channel is equivalent of cancellation of the call, no error should be thrown
    @test !isopen(response_channel)
    resp = getOrderById(api, response_channel, 10)
    @test (200 <= resp.status <= 206)

    @info("StoreApi - deleteOrder")
    @test deleteOrder(api, 10) === nothing

    nothing
end

end # module TestStoreApi
