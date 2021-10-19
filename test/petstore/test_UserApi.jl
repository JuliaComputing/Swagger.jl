module TestUserApi

using ..MyPetStore
using Swagger
using Test
using Random

const TEST_USER = "jlswag"
const TEST_USER1 = "jlswag1"
const TEST_USER2 = "jlswag2"

function test_404(uri)
    @info("Error handling")
    client = Swagger.Client(uri*"_invalid")
    api = UserApi(client)

    try
        loginUser(api, TEST_USER, "testpassword")
    catch ex
        @test isa(ex, Swagger.ApiException)
        @test ex.status == 404
        @test ex.error === nothing
        @test ex.resp.status == 404
    end    
end

function test(uri)
    @info("UserApi")
    client = Swagger.Client(uri)
    api = UserApi(client)

    @info("UserApi - loginUser")
    login_result = loginUser(api, TEST_USER, "testpassword")
    @test !isempty(login_result)

    #@info("UserApi - createUser")
    #user1 = User(; id=100, username=TEST_USER1, firstName="test1", lastName="user1", email="jlswag1@example.com", password="testpass1", phone="1000000001", userStatus=0)
    #@test createUser(api, user1) === nothing

    #@info("UserApi - createUsersWithArrayInput")
    #user2 = User(; id=200, username=TEST_USER2, firstName="test2", lastName="user2", email="jlswag2@example.com", password="testpass2", phone="1000000002", userStatus=0)
    #@test createUsersWithArrayInput(api, [user1, user2]) === nothing

    #@info("UserApi - createUsersWithListInput")
    #@test createUsersWithListInput(api, [user1, user2]) === nothing

    @info("UserApi - getUserByName")
    @test_throws Swagger.ApiException getUserByName(api, randstring())
    @test_throws Swagger.ApiException getUserByName(api, TEST_USER)
    #getuser_result = getUserByName(api, TEST_USER)
    #@test isa(getuser_result, User)

    #@info("UserApi - updateUser")
    #@test updateUser(api, TEST_USER2, getuser_result) === nothing
    #@info("UserApi - deleteUser")
    #@test deleteUser(api, TEST_USER2) === nothing

    @info("UserApi - logoutUser")
    logout_result = logoutUser(api)
    @test logout_result === nothing

    nothing
end

end # module TestUserApi
