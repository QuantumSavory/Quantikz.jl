module Circuit

export Gate

struct Gate
    name::String
    qubits::Vector{Int}
    time::Int
end

end
