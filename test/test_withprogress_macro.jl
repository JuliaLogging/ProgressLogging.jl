module TestWithprogressMacro

using Logging
using ProgressLogging
using ProgressLogging: ProgressLevel, ROOTID
using Test
using Test: collect_test_logs

@testset "specify name in `@logprogress`" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress @logprogress "hello" 0.1
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === nothing
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test logs[1].message == ""
    @test logs[2].message == "hello"
    @test logs[3].message == ""
    @test [l.message.progress.fraction for l in logs] == [nothing, 0.1, nothing]
    @test [l.message.progress.done for l in logs] == [false, false, true]
    @test length(unique([l.message.progress.id for l in logs])) == 1
    @test length(unique([l.id for l in logs])) == 1
    @test unique([l.message.progress.parentid for l in logs]) == [ROOTID]
end

@testset "specify name in `@withprogress`" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress name = "hello" @logprogress 0.1
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === nothing
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test logs[1].message == "hello"
    @test logs[2].message == "hello"
    @test logs[3].message == "hello"
    @test [l.message.progress.fraction for l in logs] == [nothing, 0.1, nothing]
    @test [l.message.progress.done for l in logs] == [false, false, true]
    @test length(unique([l.message.progress.id for l in logs])) == 1
    @test length(unique([l.id for l in logs])) == 1
    @test unique([l.message.progress.parentid for l in logs]) == [ROOTID]
end

@testset "keyword argument when no name" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress @logprogress 0.1 message = "hello"
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === nothing
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test logs[2].kwargs[:message] === "hello"
    @test [l.message.progress.fraction for l in logs] == [nothing, 0.1, nothing]
    @test [l.message.progress.done for l in logs] == [false, false, true]
    @test length(unique([l.message.progress.id for l in logs])) == 1
    @test length(unique([l.id for l in logs])) == 1
    @test unique([l.message.progress.parentid for l in logs]) == [ROOTID]
end

@testset "change name" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress name = "name" @logprogress "hello" 0.1
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === nothing
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test logs[1].message == "name"
    @test logs[2].message == "hello"
    @test logs[3].message == "name"
    @test [l.message.progress.fraction for l in logs] == [nothing, 0.1, nothing]
    @test [l.message.progress.done for l in logs] == [false, false, true]
    @test length(unique([l.message.progress.id for l in logs])) == 1
    @test length(unique([l.id for l in logs])) == 1
    @test unique([l.message.progress.parentid for l in logs]) == [ROOTID]
end

@testset "nested @withprogress" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress begin
            @logprogress "hello" 0.1
            @withprogress begin
                @logprogress "world" 0.2
            end
        end
    end

    @test length(logs) == 6

    ids = unique([l.id for l in logs])
    @test length(ids) == 2

    @test Tuple(
        (l.id, l.message.progress.parentid, string(l.message), l.kwargs[:progress])
        for l in logs
    ) === (
        (ids[1], ROOTID, "", nothing),
        (ids[1], ROOTID, "hello", 0.1),
        (ids[2], ids[1], "", nothing),
        (ids[2], ids[1], "world", 0.2),
        (ids[2], ids[1], "", "done"),
        (ids[1], ROOTID, "", "done"),
    )
end

@testset "nested @progress" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @progress "o" -1 for i in 1:2
            @progress "i" -1 for j in 1:2
            end
        end
    end

    idxs = [1, 2, 2, 2, 2, 1, 3, 3, 3, 3, 1, 1]
    ids = unique([l.id for l in logs])
    pids = [ROOTID, ids[1], ids[1]]
    messages = ["o", "i", "i"]

    @test [l.id for l in logs] == ids[idxs]
    @test [l.message.progress.parentid for l in logs] == pids[idxs]
    @test [string(l.message) for l in logs] == messages[idxs]
    @test isequal(
        [l.kwargs[:progress] for l in logs],
        [nothing, nothing, 0.5, 1.0, "done", 0.5, nothing, 0.5, 1.0, "done", 1.0, "done"],
    )
end

@testset "`@logprogress 1.0` is not `done`" begin
    logs, = collect_test_logs(min_level = ProgressLevel) do
        @withprogress @logprogress 1.0
    end
    @test [l.message.progress.done for l in logs] == [false, false, true]
end

@testset "invalid input" begin
    local err
    @test try
        @eval @withprogress invalid_argument = "" nothing
    catch err
        err
    end isa Exception  # unfortunately `LoadError`, not an `ArgumentError`
    msg = sprint(showerror, err)
    @test occursin("Unsupported optional arguments:", msg)
    @test occursin("invalid_argument", msg)
end

module IsolatedNamespace
import ProgressLogging
using Test: @test, @testset, collect_test_logs
@testset "IsolatedNamespace" begin
    logs, = collect_test_logs(min_level = ProgressLogging.ProgressLevel) do
        ProgressLogging.@withprogress ProgressLogging.@logprogress "hello" 0.1
    end
    @test length(logs) == 3
    @test logs[1].kwargs[:progress] === nothing
    @test logs[2].kwargs[:progress] === 0.1
    @test logs[3].kwargs[:progress] === "done"
    @test logs[1].message == ""
    @test logs[2].message == "hello"
    @test logs[3].message == ""
    @test [l.message.progress.fraction for l in logs] == [nothing, 0.1, nothing]
    @test [l.message.progress.done for l in logs] == [false, false, true]
    @test length(unique([l.message.progress.id for l in logs])) == 1
    @test length(unique([l.id for l in logs])) == 1
    @test unique([l.message.progress.parentid for l in logs]) == [ProgressLogging.ROOTID]
end
end  # module IsolatedNamespace

end  # module
