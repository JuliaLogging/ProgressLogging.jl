module TestMisc

using ProgressLogging
using Test
using Logging

@testset "implemented_by" begin
    @test ProgressLogging.implemented_by(NullLogger()) == false
end

end  # module
