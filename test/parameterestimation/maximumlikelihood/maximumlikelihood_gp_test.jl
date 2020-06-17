@testset "maximumlikelihood_gp.jl" begin
    n = 10000

    x₁ = randn(n) / 3
    x₂ = randn(n) / 10

    ϕ = -.05 .+ x₁
    ξ = x₂

    σ = exp.(ϕ)
    θ = [-0.05; 1.0; 0.0; 1.0]

    pd = GeneralizedPareto.(σ, ξ)
    y = rand.(pd)

    @testset "gpfit(y; logscalecov, shapecov)" begin
        # model building with non-stationary logscale and shape
        fm = Extremes.gpfit(y,
            logscalecov = [ExplanatoryVariable("x₁", x₁)],
            shapecov = [ExplanatoryVariable("x₂", x₂)])

        varM = Extremes.parametervar(fm)
        var = sqrt.([varM[i,i] for i in 1:length(θ)]) .* quantile(Normal(), 0.975)

        @test fm.θ̂ .- var <= θ
        @test θ <= fm.θ̂ .+ var

    end

    @testset "gpfit(df, datacol; logscalecovid, shapecovid)" begin
        # model building with non-stationary location, logscale and shape
        df = DataFrame(y = y, x1 = x₁, x2 = x₂)

        fm = Extremes.gpfit(df, :y, logscalecovid = [:x1], shapecovid = [:x2])

        varM = Extremes.parametervar(fm)
        var = sqrt.([varM[i,i] for i in 1:length(θ)]) .* quantile(Normal(), 0.975)

        @test fm.θ̂ .- var <= θ
        @test θ <= fm.θ̂ .+ var

    end

    @testset "gpfit(model)" begin
        # non-stationary location, logscale and shape
        model = Extremes.ThresholdExceedance(y,
            logscalecov = [ExplanatoryVariable("x₁", x₁)],
            shapecov = [ExplanatoryVariable("x₂", x₂)])

        fm = Extremes.gpfit(model)

        varM = Extremes.parametervar(fm)
        var = sqrt.([varM[i,i] for i in 1:length(θ)]) .* quantile(Normal(), 0.975)

        @test fm.θ̂ .- var <= θ
        @test θ <= fm.θ̂ .+ var

    end

end
