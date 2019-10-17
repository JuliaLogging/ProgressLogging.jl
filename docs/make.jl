using Documenter, ProgressLogging

makedocs(;
    modules=[ProgressLogging],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tkf/ProgressLogging.jl/blob/{commit}{path}#L{line}",
    sitename="ProgressLogging.jl",
    authors="Takafumi Arakaki <aka.tkf@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/tkf/ProgressLogging.jl",
)
