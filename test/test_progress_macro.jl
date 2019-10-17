module TestProgressMacro

using ProgressLogging
using Test

let i = 0, x
    x = @progress for _ = 1:100
        i += 1
    end
    @test i == 100
    @test x == nothing
end

let i = 0, r = -50:10:50, x
    x = @progress for _ in r
        i += 1
    end
    @test i == 11
    @test x == nothing
end

let i = 0, x
    x = @progress "named" for _ = 1:100
        i += 1
    end
    @test i == 100
    @test x == nothing
end

let i = 0, j = 0, x
    x = @progress for _ = 1:10, __ = 1:20
        i += 1
    end
    @test i == 200
    @test x == nothing
end

let i = 0, j = 0, x
    bar = "bar"
    x = @progress "foo $bar" for _ = 1:10
        i += 1
    end
    @test i == 10
    @test x == nothing
end

let x, y
    x = @progress y = [i + 3j for i = 1:3, j = 1:4]
    @test y == reshape(4:15, 3, 4)
    @test x == y
end

let a = [], x
    x = @progress for i = 1:3, j in [-5, -2, -1, 8]
        j > 0 && continue
        push!(a, (i, j))
        i > 1 && break
    end
    @test a == [(1, -5), (1, -2), (1, -1), (2, -5)]
    @test x == nothing
end

end  # module
