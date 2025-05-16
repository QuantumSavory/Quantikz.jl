module Visualize

using CairoMakie
import ..Gates: Gate
import ..CircuitModule: Circuit  # <--- fixed import

export draw

function draw(circuit::Circuit; style=:default, fontsize=16)
    n_qubits = circuit.nqubits
    n_timesteps = isempty(circuit.gates) ? 1 : maximum(g.time for g in circuit.gates)

    fig = Figure(resolution=(100 * n_timesteps, 100 * n_qubits))
    ax = Axis(fig[1, 1], xticks=1:n_timesteps, yticks=1:n_qubits,
              yreversed=true, aspect=1, xlabel="Time", ylabel="Qubits")

    for q in 1:n_qubits
        draw_wire!(ax, q, n_timesteps)
    end

    for g in circuit.gates
        draw_gate!(ax, g)
    end

    return fig
end

function draw_wire!(ax, qubit, steps)
    lines!(ax, 1:steps, fill(qubit, steps), color=:gray)
end

function draw_gate!(ax, g::Gate)
    text!(ax, string(g.gate), position=(g.time, g.qubit), align=(:center, :center), fontsize=20)
end

end
