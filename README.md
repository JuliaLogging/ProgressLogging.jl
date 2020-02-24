# ProgressLogging: a package for defining progress logs

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://junolab.github.io/ProgressLogging.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://junolab.github.io/ProgressLogging.jl/dev)
[![Build Status](https://travis-ci.com/JunoLab/ProgressLogging.jl.svg?branch=master)](https://travis-ci.com/JunoLab/ProgressLogging.jl)
[![Codecov](https://codecov.io/gh/JunoLab/ProgressLogging.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JunoLab/ProgressLogging.jl)
[![Coveralls](https://coveralls.io/repos/github/JunoLab/ProgressLogging.jl/badge.svg?branch=master)](https://coveralls.io/github/JunoLab/ProgressLogging.jl?branch=master)

ProgressLogging.jl is a package for defining _progress logs_.  It can
be used to report progress of a loop/loops with time-consuming body:

```julia
julia> using ProgressLogging

julia> @progress for i in 1:10
           sleep(0.1)
       end
```

This package does not contain any _progress monitors_ for visualizing
the progress of the program.  You need to install a package supporting
progress logs created by ProgressLogging.jl API.  For example:

* [Juno](https://junolab.org/)
* [TerminalLoggers.jl](https://github.com/c42f/TerminalLoggers.jl)
