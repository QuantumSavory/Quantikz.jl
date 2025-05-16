module Primitives

using CairoMakie

export draw_wire!, draw_gate!

"""
    draw_wire!(ax, qubit::Int, length::Int)

Draws a horizontal wire on axis `ax` for the given `qubit` from position 1 to `length`.
"""
function draw_wire!(ax, qubit::Int, length::Int)
    lines!(ax, [1, length], [qubit, qubit], color=:black, linewidth=2)
end

"""
    draw_gate!(ax, gate)

Draws a gate on axis `ax` for a gate object with `time`, `qubits`, and `name` fields.
Supports single- and two-qubit gates.
"""
function draw_gate!(ax, gate)
    time = gate.time
    qs = gate.qubits
    label = Symbol(gate.name)

    if length(qs) == 1
        # Single-qubit gate: box with label
        x, y = time, qs[1]
        rect!(ax, x - 0.3, y - 0.3, 0.6, 0.6, color=:white, strokecolor=:black)
        text!(ax, string(label), position=(x, y), align=(:center, :center))

    elseif length(qs) == 2
        # Two-qubit gate (e.g., CNOT): control + target
        x, y1, y2 = time, qs[1], qs[2]
        scatter!(ax, [x], [y1], color=:black, markersize=10) # control dot
        lines!(ax, [x, x], [y1, y2], color=:black)
        rect!(ax, x - 0.3, y2 - 0.3, 0.6, 0.6, color=:white, strokecolor=:black)
        text!(ax, string(label), position=(x, y2), align=(:center, :center))

    else
        @warn "Unsupported multi-qubit gate with $(length(qs)) qubits: $(gate.name)"
    end
end

end
