@testset "Port Pirie example from Coles (2001)" begin

    data = load("portpirie")

    y = data[:, :SeaLevel]

    # Fit of the GEV distribution by maximum likelihood
    fm = gevfit(y)

    # Parameter estimates
    θ̂ = fm.θ̂

    # Approximate variance-covariance matrix of the parameter estimates
    V̂ = Extremes.parametervar(fm)

    # correction factor for using ϕ instead of σ (computation using the delta method)
    c = [
        1.0 exp(θ̂[2]) 1.0
        exp(θ̂[2]) exp(2 * θ̂[2]) exp(θ̂[2])
        1.0 exp(θ̂[2]) 1.0
    ]

    # 10-year return level
    R₁₀ = returnlevel(fm, 10, 0.95)
    # 100-year return level
    R₁₀₀ = returnlevel(fm, 100, 0.95)

    # Parameter estimates in Coles
    θ = [3.87; log(0.198); -0.050]

    # Approximate variance-covariance matrix of the parameter estimates in Coles
    V = [
        0.000780 0.000197 -.00107
        0.000197 0.000410 -.000778
        -.00107 -.000778 0.00965
    ]

    @test θ̂ ≈ θ rtol = 0.1
    @test c .* V̂ ≈ V rtol = 0.1
    @test Extremes.loglike(fm.model, θ̂) ≈ 4.34 rtol = 0.1
    @test R₁₀.value[] ≈ 4.30 rtol = 0.1
    @test R₁₀.cint[] ≈ [4.19; 4.45] rtol = 0.1
    @test R₁₀₀.value[] ≈ 4.69 rtol = 0.1
    @test R₁₀₀.cint[] ≈ [4.5; 5.27] rtol = 0.1

end



@testset "Fremantle example from Coles (2001)" begin

    df = load("fremantle")

    n = length(df[:, :SeaLevel])

    t = collect(1:n)

    data = Dict(
        :SeaLevel => df[:, :SeaLevel],
        :t => t,
        :t2 => t .^ 2,
        :soi => df[:, :SOI],
        :n => n,
    )

    dataid = :SeaLevel

    Covariate = Dict(:μ => [:t])
    fm = gevfit(data, dataid, Covariate = Covariate)

    # Parameter estimates
    θ̂ = fm.θ̂

    # Variance of the parameter estimates
    V̂ = diag(Extremes.parametervar(fm))

    # Computing the variance of σ instead of ϕ with the delta method
    V̂[3] = exp(2 * θ̂[3]) * V̂[3]

    # Computing the standard errors of the parameters estimates
    Ŝ = sqrt.(V̂)

    # Values given in Coles (2001, Chap 6) for the temporal linear trend in μ
    θ = [1.38; 0.00203; log(0.124); -.125]
    S = [0.03; 0.00052; 0.010; 0.070]


    @test θ̂ ≈ θ rtol = 0.1
    @test Ŝ ≈ S rtol = 0.1
    @test Extremes.loglike(fm.model, θ̂) ≈ 49.9 rtol = 0.1

    # Quadratic trend in μ
    Covariate = Dict(:μ => [:t, :t2])
    fm = gevfit(data, dataid, Covariate = Covariate)
    @test Extremes.loglike(fm.model, fm.θ̂) ≈ 50.6 rtol = 0.1

    # Linear trend in both μ and ϕ
    Covariate = Dict(:μ => [:t], :ϕ => [:t])
    fm = gevfit(data, dataid, Covariate = Covariate)
    @test Extremes.loglike(fm.model, fm.θ̂) ≈ 50.7 rtol = 0.1

    # Linear trend in μ as function of the time and the SOI
    Covariate = Dict(:μ => [:t, :soi])
    fm = gevfit(data, dataid, Covariate = Covariate)
    @test Extremes.loglike(fm.model, fm.θ̂) ≈ 53.9 rtol = 0.1
    @test fm.θ̂[3] ≈ 0.055 rtol = 0.1

end
