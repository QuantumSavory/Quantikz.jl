module CircuitModule  # <-- renamed module

import ..Gates: Gate

export Circuit, circuit, put!

struct Circuit
    nqubits::Int
    gates::Vector{Gate}
end

function circuit(nqubits::Int)
    return Circuit(nqubits, Gate[])
end

function put!(c::Circuit, time::Int, op::Pair{Int, Symbol})
    qubit, gate = op
    push!(c.gates, Gate(qubit, gate, time))
end

end
