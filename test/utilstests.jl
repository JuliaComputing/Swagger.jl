using Swagger, Test

function as_taskfailedexception(ex)
    try
        task = @async throw(ex)
        wait(task)
    catch ex
        return ex
    end
end

function test_longpoll_exception_check()
    resp = Swagger.Downloads.Response("http", "http://localhost", 200, "no error", [])
    reqerr1 = Swagger.Downloads.RequestError("http://localhost", 500, "not timeout error", resp)
    reqerr2 = Swagger.Downloads.RequestError("http://localhost", 200, "Operation timed out after 300 milliseconds with 0 bytes received", resp) # timeout error

    @test Swagger.is_longpoll_timeout("not an exception") == false

    swaggerex1 = Swagger.ApiException(reqerr1)
    @test Swagger.is_longpoll_timeout(swaggerex1) == false
    @test Swagger.is_longpoll_timeout(as_taskfailedexception(swaggerex1)) == false

    swaggerex2 = Swagger.ApiException(reqerr2)
    @test Swagger.is_longpoll_timeout(swaggerex2)
    @test Swagger.is_longpoll_timeout(as_taskfailedexception(swaggerex2))

    @test Swagger.is_longpoll_timeout(CompositeException([swaggerex1, swaggerex2]))
    @test Swagger.is_longpoll_timeout(CompositeException([swaggerex1, as_taskfailedexception(swaggerex2)]))
    @test Swagger.is_longpoll_timeout(CompositeException([swaggerex1, as_taskfailedexception(swaggerex1)])) == false
end
