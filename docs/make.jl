push!(LOAD_PATH,"../src/")

using Documenter
using Quantikz

DocMeta.setdocmeta!(Quantikz, :DocTestSetup, :(using Quantikz); recursive=true)

makedocs(
doctest = false,
clean = true,
sitename = "Quantikz.jl",
format = Documenter.HTML(),
modules = [Quantikz],
authors = "Stefan Krastanov",
pages = [
"Quantikz.jl" => "index.md",
#"API" => "API.md"
]
)

deploydocs(
    repo = "github.com/Krastanov/Quantikz.git"
)
