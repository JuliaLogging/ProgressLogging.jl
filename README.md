# ProgressLogging: a Logging-based progress bar frontend

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://junolab.github.io/ProgressLogging.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://junolab.github.io/ProgressLogging.jl/dev)
[![Build Status](https://travis-ci.com/JunoLab/ProgressLogging.jl.svg?branch=master)](https://travis-ci.com/JunoLab/ProgressLogging.jl)
[![Codecov](https://codecov.io/gh/JunoLab/ProgressLogging.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JunoLab/ProgressLogging.jl)
[![Coveralls](https://coveralls.io/repos/github/JunoLab/ProgressLogging.jl/badge.svg?branch=master)](https://coveralls.io/github/JunoLab/ProgressLogging.jl?branch=master)

ProgressLogging.jl is a progress bar _frontend_.  It can be used to
report progress of a loop/loops with time-consuming body:

```julia
julia> using ProgressLogging

julia> @progress for i in 1:10
           sleep(0.1)
       end
```

This package is a _frontend_ in the sense using this package alone
does not show any progress bars.  You need to use one of the backends
to view the progress.

* [Juno](https://junolab.org/)
* [ProgressMeterLogging.jl](https://github.com/tkf/ProgressMeterLogging.jl)
