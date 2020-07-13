module TestMisc

using ProgressLogging
using Test
using Logging

@testset "implementedby" begin
    @test ProgressLogging.implementedby(NullLogger()) == false
end

end  # module
