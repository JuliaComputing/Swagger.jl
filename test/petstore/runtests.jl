include(joinpath(dirname(@__FILE__), "MyPetStore", "src", "MyPetStore.jl"))

include("test_UserApi.jl")
include("test_StoreApi.jl")
include("test_PetApi.jl")

const server = "http://127.0.0.1/v2"
TestUserApi.test(server)
TestStoreApi.test(server)
TestPetApi.test(server)
