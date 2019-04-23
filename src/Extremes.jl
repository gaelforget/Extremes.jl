module Extremes

using Distributions, DataFrames, Dates
using JuMP, Ipopt
using SpecialFunctions, LinearAlgebra

include("functions.jl")

export gevfit, gpdfit, gevfitbayes, gpdfitbayes, getcluster

end # module
