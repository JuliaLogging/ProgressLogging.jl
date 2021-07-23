using Documenter, ProgressLogging

makedocs(;
    modules=[ProgressLogging],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/JuliaLogging/ProgressLogging.jl/blob/{commit}{path}#L{line}",
    sitename="ProgressLogging.jl",
    assets=String[],
)

deploydocs(;
    repo="github.com/JuliaLogging/ProgressLogging.jl",
)
