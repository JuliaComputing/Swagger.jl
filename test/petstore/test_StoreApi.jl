module TestStoreApi

using ..MyPetStore
using Swagger
using Test
using Dates

function test(uri)
    println("testing StoreApi...")
    client = Swagger.Client(uri)
    api = StoreApi(client)

    println("   - getInventory")
    inventory = getInventory(api)
    @test isa(inventory, Dict{String,Int32})
    @test !isempty(inventory)

    println("   - placeOrder")
    @test_throws Swagger.ValidationException Order(; id=10, petId=10, quantity=2, shipDate=DateTime(2017, 03, 12), status="invalid_status", complete=false)
    order = Order(; id=10, petId=10, quantity=2, shipDate=DateTime(2017, 03, 12), status="placed", complete=false)
    neworder = placeOrder(api, order)
    @test neworder.id == 10

    println("   - getOrderById")
    @test_throws Swagger.ValidationException getOrderById(api, 0)
    order = getOrderById(api, 10)
    @test isa(order, Order)
    @test order.id == 10

    println("   - deleteOrder")
    @test deleteOrder(api, 10) == nothing

    nothing
end

end # module TestStoreApi
