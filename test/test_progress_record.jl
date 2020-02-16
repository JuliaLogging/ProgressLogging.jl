module TestProgressRecord

using ProgressLogging: Progress, ProgressString
using Random: shuffle!
using Test
using UUIDs: uuid4

@testset "fraction :: Int" begin
    @test Progress(id = uuid4(), fraction = 0).fraction === 0.0
    @test Progress(id = uuid4(), fraction = 1).fraction === 1.0
    @test Progress(uuid4(), 0).fraction === 0.0
    @test Progress(uuid4(), 1).fraction === 1.0
end

@testset "cmp: ProgressString" begin
    strings = Any[
        let s = string(i)
            rand(Bool) ? s : ProgressString(Progress(uuid4(), 0.0; name = s))
        end
        for i in 10:99
    ]
    shuffle!(strings)
    @test string.(sort!(strings)) == string.(10:99)
end

end  # module
