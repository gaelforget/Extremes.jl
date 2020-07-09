struct BayesianEVA{T} <: fittedEVA{T}
    "Extreme value model definition"
    model::T
    "MCMC outputs"
    sim::Mamba.Chains
end

"""
    getdistribution(fm::bayesianEVA)::Vector{<:Distribution}

Return the distributions for each MCMC iteration.
"""
function getdistribution(fm::BayesianEVA)::Array{<:ContinuousUnivariateDistribution,2}

    v = fm.sim.value[:,:,1]

    V = Extremes.slicematrix(v, dims=2)

    D = Extremes.getdistribution.(fm.model, V)

    d = Extremes.unslicematrix(D, dims=2)

    return d

end

"""
    quantile(fm::BayesianEVA,p::Real)::Real

Compute the quantile of level `p` from the fitted Bayesian model `fm`. If the
model is stationary, then a quantile is returned for each MCMC steps. If the
model is non-stationary, a matrix of quantiles is returned, where each row
corresponds to a MCMC step and each column to a covariate.

"""
function quantile(fm::BayesianEVA,p::Real)::Array{<:Real}

    @assert zero(p)<p<one(p) "the quantile level should be between 0 and 1."

    θ = slicematrix(fm.sim.value[:,:,1], dims=2)

    q = quantile.(fm.model, θ, p)

    if !(typeof(q) <: Vector{<:Real})
        q = unslicematrix(q, dims=2)
    end

    return q

end

"""
    returnlevel(fm::BayesianEVA{BlockMaxima}, returnPeriod::Real)::ReturnLevel

Compute the return level corresponding to the return period `returnPeriod` from the fitted model `fm`.

"""
function returnlevel(fm::BayesianEVA{BlockMaxima}, returnPeriod::Real)::ReturnLevel

      @assert returnPeriod > zero(returnPeriod) "the return period should be positive."

      # quantile level
      p = 1-1/returnPeriod

      Q = quantile(fm, p)

      return ReturnLevel(BlockMaximaModel(fm), returnPeriod, vec(mean(Q, dims=1)))

end

"""
    cint(rl::ReturnLevel{BayesianEVA{BlockMaxima}};, confidencelevel::Real=.95)::Vector{Vector{Real}}

Compute the confidence interval for the return level corresponding to the return period
`returnPeriod` from the fitted model `fm` with confidence level `confidencelevel`.

"""
function cint(rl::ReturnLevel{BayesianEVA{BlockMaxima}}, confidencelevel::Real=.95)::Vector{Vector{Real}}

      @assert rl.returnperiod > zero(rl.returnperiod) "the return period should be positive."
      @assert zero(confidencelevel)<confidencelevel<one(confidencelevel) "the confidence level should be in (0,1)."

      # quantile level
      p = 1-1/rl.returnperiod

      Q = quantile(rl.model.fm, p)

      # Compute the credible interval

      α = (1 - confidencelevel)

      qsliced = slicematrix(Q)

      a = quantile.(qsliced, α/2)
      b = quantile.(qsliced, 1-α/2)

      return slicematrix(hcat(a,b), dims=2)

end

"""
    returnlevel(fm::BayesianEVA{ThresholdExceedance}, threshold::Real, nobservation::Int,
        nobsperblock::Int, returnPeriod::Real)::ReturnLevel

Compute the return level corresponding to the return period `returnPeriod` from the fitted model `fm`.

The threshold should be a scalar. A varying threshold is not yet implemented.

"""
function returnlevel(fm::BayesianEVA{ThresholdExceedance}, threshold::Real, nobservation::Int,
    nobsperblock::Int, returnPeriod::Real)::ReturnLevel

    @assert returnPeriod > zero(returnPeriod) "the return period should be positive."

    # Exceedance probability
    ζ = length(fm.model.data.value)/nobservation

    # Appropriate quantile level given the probability exceedance and the number of obs per year
    p = 1-1/(returnPeriod * nobsperblock * ζ)

    Q = quantile(fm, p)

    return ReturnLevel(PeakOverThreshold(fm, threshold, nobservation, nobsperblock),
        returnPeriod, threshold .+ vec(mean(Q, dims=1)))

end

"""
    cint(rl::ReturnLevel{BayesianEVA{ThresholdExceedance}}, threshold::Real, nobservation::Int,
        nobsperblock::Int, confidencelevel::Real=.95)::Vector{Vector{Real}}

Compute the confidence interval for the return level corresponding to the return period
`returnPeriod` from the fitted model `fm` with the confidence level `confidencelevel`.

The threshold should be a scalar. A varying threshold is not yet implemented.

"""
function cint(rl::ReturnLevel{BayesianEVA{ThresholdExceedance}}, confidencelevel::Real=.95)::Vector{Vector{Real}}

    @assert rl.returnperiod > zero(rl.returnperiod) "the return period should be positive."
    @assert zero(confidencelevel)<confidencelevel<one(confidencelevel) "the confidence level should be in (0,1)."

    # Exceedance probability
    ζ = length(rl.model.fm.model.data.value)/rl.model.nobservation

    # Appropriate quantile level given the probability exceedance and the number of obs per year
    p = 1-1/(rl.returnperiod * rl.model.nobsperblock * ζ)

    Q = quantile(rl.model.fm, p)

    # Compute the credible interval

    α = (1 - confidencelevel)

    qsliced = slicematrix(Q)

    a = rl.model.threshold .+ quantile.(qsliced, α/2)
    b = rl.model.threshold .+ quantile.(qsliced, 1-α/2)

    return slicematrix(hcat(a,b), dims=2)

end

"""
    showfittedEVA(io::IO, obj::BayesianEVA; prefix::String = "")

Displays a BayesianEVA with the prefix `prefix` before every line.
"""
function showfittedEVA(io::IO, obj::BayesianEVA; prefix::String = "")

    println(io, prefix, "BayesianEVA")
    println(io, prefix, "model :")
    showEVA(io, obj.model, prefix = prefix*"\t")
    println(io)
    println(io, prefix, "sim :")
    showChain(io, obj.sim, prefix = prefix*"\t")

end

"""
    showChain(io::IO, obj::Mamba.Chains; prefix::String = "")

Displays a Mamba.Chains with the prefix `prefix` before every line.
"""
function showChain(io::IO, chain::Mamba.Chains; prefix::String = "")

    println(io, prefix, "Mamba.Chains")
    println(io, prefix, "Iterations :\t\t", chain.range[1], ":", chain.range[end])
    println(io, prefix, "Thinning interval :\t", step(chain.range))
    println(io, prefix, "Chains :\t\t", length(chain.chains))
    println(io, prefix, "Samples per chain :\t", size(chain.value, 1))
    println(io, prefix, "Value :\t\t\t", typeof(chain.value), "[", size(chain.value, 1),
        ",", size(chain.value, 2), ",", size(chain.value, 3),"]")

end

"""
    transform(fm::BayesianEVA{BlockMaxima})::BayesianEVA

Transform the fitted model for the original covariate scales.
"""
function transform(fm::BayesianEVA{BlockMaxima})::BayesianEVA

    locationcovstd = fm.model.location.covariate
    logscalecovstd = fm.model.logscale.covariate
    shapecovstd = fm.model.shape.covariate

    locationcov = Extremes.reconstruct.(locationcovstd)
    logscalecov = Extremes.reconstruct.(logscalecovstd)
    shapecov = Extremes.reconstruct.(shapecovstd)

    # Model on the original covariate scale
    model = BlockMaxima(fm.model.data, locationcov = locationcov, logscalecov = logscalecov, shapecov = shapecov)

    # Transformation of the parameter estimates
    z = fm.sim.value[:,:,1]

    x = deepcopy(z)
    ind = Extremes.paramindex(fm.model)

    for (var, par) in zip([locationcovstd, logscalecovstd, shapecovstd],[:μ, :ϕ, :ξ])
        if !isempty(var)
            a = getfield.(var, :scale)
            b = getfield.(var, :offset)

            for i=1:length(a)
                x[:,ind[par][1]] = x[:,ind[par][1]] - z[:,ind[par][1+i]] * b[i]/a[i]
                x[:,ind[par][1+i]] = z[:,ind[par][1+i]]/a[i]
            end
        end
    end

    sim = fm.sim
    sim.value[:,:,1] = x

    # Contruction of the fittedEVA structure
    return BayesianEVA(model, sim)

end



"""
    transform(fm::BayesianEVA{ThresholdExceedance})

Transform the fitted model for the original covariate scales.
"""
function transform(fm::BayesianEVA{ThresholdExceedance})

    logscalecovstd = fm.model.logscale.covariate
    shapecovstd = fm.model.shape.covariate

    logscalecov = Extremes.reconstruct.(logscalecovstd)
    shapecov = Extremes.reconstruct.(shapecovstd)

    # Model on the original covariate scale
    model = ThresholdExceedance(fm.model.data, logscalecov = logscalecov, shapecov = shapecov)

    # Transformation of the parameter estimates
    z = fm.sim.value[:,:,1]

    x = deepcopy(z)
    ind = Extremes.paramindex(fm.model)

    for (var, par) in zip([logscalecovstd, shapecovstd],[:ϕ, :ξ])
        if !isempty(var)
            a = getfield.(var, :scale)
            b = getfield.(var, :offset)

            for i=1:length(a)
                x[:,ind[par][1]] = x[:,ind[par][1]] - z[:,ind[par][1+i]] * b[i]/a[i]
                x[:,ind[par][1+i]] = z[:,ind[par][1+i]]/a[i]
            end
        end
    end

    sim = fm.sim
    sim.value[:,:,1] = x

    # Contruction of the fittedEVA structure
    return BayesianEVA(model, sim)

end


"""
    parametervar(fm::BayesianEVA)::Array{Float64, 2}

Compute the covariance parameters estimate of the fitted model `fm`.

"""
function parametervar(fm::BayesianEVA)::Array{Float64, 2}

    x = fm.sim.value[:,:,1]

    C = cov(x)

    return C

end



"""
    cint(fm::pwmEVA, clevel::Real=.95, nboot::Int=1000)::Array{Array{Float64,1},1}

Estimate the parameter estimates highest posterior density interval.
"""
function cint(fm::BayesianEVA, clevel::Real=.95)::Array{Array{Float64,1},1}

    @assert 0<clevel<1 "the confidence level should be between 0 and 1."

    α = 1-clevel

    # Chain summary
    s = hpd(fm.sim, alpha=.05)

    # Values
    v = s.value[:,:,1]

    credint = Vector{Vector{Float64}}()

    for r in eachrow(v)
        push!(credint, r)
    end

    return credint

end

"""
    findposteriormode(fm::BayesianEVA)::Vector{<:Real}

Find the maximum a posteriori probability (MAP) estimate.
"""
function findposteriormode(fm::BayesianEVA)::Vector{<:Real}

    θ = Extremes.slicematrix(fm.sim.value[:,:,1], dims=2)

    ll = Extremes.loglike.(fm.model,θ)

    ind = argmax(ll)

    θ̂ = θ[ind]

    return θ̂

end
