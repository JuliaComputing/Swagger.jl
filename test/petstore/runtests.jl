include(joinpath(dirname(@__FILE__), "MyPetStore", "src", "MyPetStore.jl"))

include("test_UserApi.jl")
include("test_StoreApi.jl")
include("test_PetApi.jl")

const server = "http://petstore.swagger.io/v2"
TestUserApi.test(server)
TestStoreApi.test(server)
TestPetApi.test(server)
