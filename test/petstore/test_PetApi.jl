module TestPetApi

using ..MyPetStore
using Swagger
using Test

function test(uri)
    println("testing PetApi...")
    client = Swagger.Client(uri)
    api = PetApi(client)

    tag1 = Tag(;id=10, name="juliacat")
    tag2 = Tag(;id=11, name="white")
    cat = Category(;id=10, name="cat")

    @test_throws Swagger.ValidationException Pet(;id=10, category=cat, name="felix", photoUrls=nothing, tags=[tag1, tag2], status="invalid-status")

    pet = Pet(;id=10, category=cat, name="felix", photoUrls=nothing, tags=[tag1,tag2], status="pending")

    println("   - addPet")
    @test addPet(api, pet) == nothing

    println("   - updatePet")
    pet.status = "available"
    @test updatePet(api, pet) == nothing

    println("   - updatePetWithForm")
    @test updatePetWithForm(api, 10; name="meow") == nothing

    println("   - getPetById")
    pet10 = getPetById(api, 10)
    @test pet10.id == 10

    # skip test, has been failing on the test server (some operations on the server are probably dummy)
    #println("   - findPetsByTags")
    #tags = ["juliacat", "white"]
    #pets = findPetsByTags(api, tags)
    #@test isa(pets, Vector{Pet})
    #println("       - got $(length(pets)) pets")
    #for p in pets
    #    ptags = [get_field(t, "name") for t in get_field(p, "tags")]
    #    @test !isempty(intersect(ptags, tags))
    #end

    println("   - findPetsByStatus")
    unsold = ["available", "pending"]
    pets = findPetsByStatus(api, unsold)
    @test isa(pets, Vector{Pet})
    println("       - got $(length(pets)) pets")
    for p in pets
        @test p.status in unsold
    end

    println("   - deletePet")
    @test deletePet(api, 10) == nothing

    # does not work yet. issue: https://github.com/JuliaWeb/Requests.jl/issues/139
    #println("   - uploadFile")
    #img = joinpath(dirname(@__FILE__), "cat.png")
    #resp = uploadFile(api, 10; additionalMetadata="juliacat pic", file=img)
    #@test isa(resp, ApiResponse)
    #@test resp.code == 200
    #println("        - type: ", get_field(resp, "type"))
    #println("        - message: ", get_field(resp, "message"))

    nothing
end

end # module TestPetApi
