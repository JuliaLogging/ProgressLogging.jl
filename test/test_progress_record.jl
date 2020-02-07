module TestProgressRecord

using ProgressLogging: Progress, ProgressString
using Random: shuffle!
using Test
using UUIDs: uuid4

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
