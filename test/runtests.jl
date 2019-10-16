using Base.Filesystem: contractuser, path_separator

using LibGit2: LibGit2, GitCommit, GitRemote, GitRepo
using Pkg: Pkg
using Random: Random
using Test: @test, @testset, @test_logs, @test_throws

using ReferenceTests: @test_reference
using SimpleMock: mock
using Suppressor: @suppress

using PkgTemplates
const PT = PkgTemplates

const USER = "tester"

Random.seed!(1)

# Creata a template that won't error because of a missing username.
tpl(; kwargs...) = Template(; user=USER, kwargs...)

const PKG = Ref("A")

# Generate an unused package name.
pkgname() = PKG[] *= "a"

# Create a randomly named package with a template, and delete it afterwards.
function with_pkg(f::Function, t::Template, pkg::AbstractString=pkgname())
    @suppress t(pkg)
    try
        f(pkg)
    finally
        # On 1.4, this sometimes won't work, but the error is that the package isn't installed.
        # We're going to delete the package directory anyways, so just ignore any errors.
        PT.version_of(pkg) === nothing || try @suppress Pkg.rm(pkg) catch; end
        rm(joinpath(t.dir, pkg); recursive=true, force=true)
    end
end

mktempdir() do dir
    Pkg.activate(dir)
    pushfirst!(DEPOT_PATH, dir)
    try
        @testset "PkgTemplates.jl" begin
            include("template.jl")
            include("plugin.jl")
            include("show.jl")

            if PT.git_is_installed()
                include("git.jl")

                # Quite a bit of output depends on the Julia version,
                # and the test fixtures are made with Julia 1.2.
                # TODO: Keep this on the latest stable Julia version.
                if VERSION.major == 1 && VERSION.minor == 2
                    include("reference.jl")
                else
                    @info "Skipping reference tests" julia=VERSION
                end
            else
                @info "Git is not installed, skipping Git and reference tests"
            end
        end
    finally
        popfirst!(DEPOT_PATH)
    end
end
