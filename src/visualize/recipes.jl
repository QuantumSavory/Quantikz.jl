module Recipes

using ..MakiePlot
using Makie: @recipe, plot

@recipe(QuantumCircuitPlot) do scene, circuit
    draw(circuit)
end

end
