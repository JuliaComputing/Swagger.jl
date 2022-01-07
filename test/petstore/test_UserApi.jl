module TestUserApi

using ..MyPetStore
using Swagger
using Test
using Random
using JSON

const TEST_USER = "jlswag"
const TEST_USER1 = "jlswag1"
const TEST_USER2 = "jlswag2"

function test_404(uri)
    @info("Error handling")
    client = Swagger.Client(uri*"_invalid")
    api = UserApi(client)

    try
        loginUser(api, TEST_USER, "testpassword")
        @error("Swagger.ApiException not thrown")
    catch ex
        @test isa(ex, Swagger.ApiException)
        @test ex.status == 404
    end

    client = Swagger.Client("http://_invalid/")
    api = UserApi(client)

    try
        loginUser(api, TEST_USER, "testpassword")
        @error("Swagger.ApiException not thrown")
    catch ex
        @test isa(ex, Swagger.ApiException)
        @test startswith(ex.reason, "Could not resolve host")
    end    
end

function test_set_methods()
    @info("Error handling")
    client = Swagger.Client("http://_invalid/")

    @test client.timeout[] == Swagger.DEFAULT_TIMEOUT_SECS

    Swagger.with_timeout(client, Swagger.DEFAULT_TIMEOUT_SECS + 10) do client
        @test client.timeout[] == Swagger.DEFAULT_TIMEOUT_SECS + 10
    end
    @test client.timeout[] == Swagger.DEFAULT_TIMEOUT_SECS

    api = UserApi(client)
    Swagger.with_timeout(api, Swagger.DEFAULT_TIMEOUT_SECS + 10) do api
        @test api.client.timeout[] == Swagger.DEFAULT_TIMEOUT_SECS + 10
    end
    @test client.timeout[] == Swagger.DEFAULT_TIMEOUT_SECS

    Swagger.set_timeout(client, Swagger.DEFAULT_TIMEOUT_SECS + 10)
    @test client.timeout[] == Swagger.DEFAULT_TIMEOUT_SECS + 10

    @test isempty(client.headers)
    Swagger.set_user_agent(client, "007")
    Swagger.set_cookie(client, "crumbly")
    @test client.headers["User-Agent"] == "007"
    @test client.headers["Cookie"] == "crumbly"
end

function test_parallel(uri)
    @info("Parallel usage")
    client = Swagger.Client(uri)
    api = UserApi(client)

    for gcidx in 1:100
        @sync begin
            for idx in 1:10^3
                @async begin
                    @debug("[$idx] UserApi Parallel begin")
                    login_result = loginUser(api, TEST_USER, "testpassword")
                    @test !isempty(login_result)
                    result = JSON.parse(login_result)
                    @test startswith(result["message"], "logged in user session")
                    @test result["code"] == 200

                    @test_throws Swagger.ApiException getUserByName(api, randstring())
                    @test_throws Swagger.ApiException getUserByName(api, TEST_USER)

                    logout_result = logoutUser(api)
                    @test logout_result === nothing
                    @debug("[$idx] UserApi Parallel end")
                end
            end
        end
        GC.gc()
        @info("outer loop $gcidx")
    end
    nothing
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
