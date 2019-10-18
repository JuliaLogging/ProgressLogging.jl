module TestWithprogressMacro

using Logging
using ProgressLogging
using ProgressLogging: ProgressLevel
using Test
using Test: collect_test_logs

@testset "simple" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress @logprogress "hello" progress = 0.1
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === NaN
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test length(unique([l.id for l in logs])) == 1
end

@testset "with name" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress name = "name" @logprogress "hello" progress = 0.1
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === NaN
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test logs[1].message === "name"
    @test logs[2].message === "hello"
    @test logs[3].message === "name"
    @test length(unique([l.id for l in logs])) == 1
end

@testset "nested" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress begin
            @logprogress "hello" progress = 0.1
            @withprogress begin
                @logprogress "world" progress = 0.2
            end
        end
    end

    @test length(logs) == 6

    ids = unique([l.id for l in logs])
    @test length(ids) == 2

    @test Tuple((l.id, l.message, l.kwargs[:progress]) for l in logs) === (
        (ids[1], "", NaN),
        (ids[1], "hello", 0.1),
        (ids[2], "", NaN),
        (ids[2], "world", 0.2),
        (ids[2], "", "done"),
        (ids[1], "", "done"),
    )
end

@testset "invalid input" begin
    local err
    @test try
        @eval @withprogress invalid_argument = "" nothing
    catch err
        err
    end isa Exception  # unfortunately `LoadError`, not an `ArgumentError`
    msg = sprint(showerror, err)
    @test occursin("First expression to @withprogress must be `name=...`.", msg)
    @test occursin("invalid_argument", msg)
end

end  # module
