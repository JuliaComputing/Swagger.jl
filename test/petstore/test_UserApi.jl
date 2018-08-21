module TestUserApi

using ..MyPetStore
using Swagger
using Test
using Random

const TEST_USER = "jlswag"
const TEST_USER1 = "jlswag1"
const TEST_USER2 = "jlswag2"

function test(uri)
    println("testing UserApi...")
    client = Swagger.Client(uri)
    api = UserApi(client)

    println("   - loginUser")
    login_result = loginUser(api, TEST_USER, "testpassword")
    @test !isempty(login_result)

    #println("   - createUser")
    #user1 = User(; id=100, username=TEST_USER1, firstName="test1", lastName="user1", email="jlswag1@example.com", password="testpass1", phone="1000000001", userStatus=0)
    #@test createUser(api, user1) === nothing

    #println("   - createUsersWithArrayInput")
    #user2 = User(; id=200, username=TEST_USER2, firstName="test2", lastName="user2", email="jlswag2@example.com", password="testpass2", phone="1000000002", userStatus=0)
    #@test createUsersWithArrayInput(api, [user1, user2]) === nothing

    #println("   - createUsersWithListInput")
    #@test createUsersWithListInput(api, [user1, user2]) === nothing

    println("   - getUserByName")
    @test_throws Swagger.ApiException getUserByName(api, randstring())
    @test_throws Swagger.ApiException getUserByName(api, TEST_USER)
    #getuser_result = getUserByName(api, TEST_USER)
    #@test isa(getuser_result, User)

    #println("   - updateUser")
    #@test updateUser(api, TEST_USER2, getuser_result) === nothing
    #println("   - deleteUser")
    #@test deleteUser(api, TEST_USER2) === nothing

    println("   - logoutUser")
    logout_result = logoutUser(api)
    @test logout_result === nothing

    nothing
end

end # module TestUserApi
