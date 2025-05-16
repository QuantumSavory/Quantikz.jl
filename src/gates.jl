module Gates

export Gate

struct Gate
    name::Symbol
    qubits::Vector{Int}
    time::Int
end

end
