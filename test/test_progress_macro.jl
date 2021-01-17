module TestProgressMacro

using ProgressLogging: @progress, ProgressLevel
using Test
using Test: collect_test_logs
using OffsetArrays

@testset "@progress" begin
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

  # Multi-dimensional arrays in comprehension and offset axes
  let off1 = -2, off2 = 21
    v1 = OffsetArray(2:3, off1)
    v2 = OffsetArray(-1:2, off2)
    logs, _ = collect_test_logs(min_level = ProgressLevel) do
      x = @progress y = [i*j for i in v1, j in v2]
      @test x == y == OffsetArray([-2 0 2 4; -3 0 3 6], off1, off2)
    end
    @test isequal(
        [l.kwargs[:progress] for l in logs],
        [nothing; (1:8)./8; "done"],
    )
    m = OffsetArray(reshape(2:7,2,3), off1, off2)
    x = @progress y = [i*j for i in v1, j in m]
    @test x == y == [i*j for i in v1, j in m]
  end

  # non-indexable iterables with axes
  @testset "non-indexable" for off in (0,10)
    let r = OffsetVector(1:5, off)
      x1 = @progress y1 = [i for i in (x^2 for x in r)]
      x2 = @progress y2 = [i for i in zip(r,r)]
      @test x1 == y1 == r.^2
      @test x2 == y2 == collect(zip(r,r))

      y1, y2 = [], []
      x1 = @progress for i in (x^2 for x in r)
        push!(y1, i)
      end
      x2 = @progress for i in zip(r,r)
        push!(y2, i)
      end
      @test x1 == x2 == nothing
      @test OffsetVector(y1,off) == r.^2
      @test OffsetVector(y2,off) == collect(zip(r,r))
    end
  end
end

end  # module
