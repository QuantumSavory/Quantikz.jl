module Quantikz

using Makie
using LinearAlgebra

export Circuit, 
       add_gate!, wire,
       push_gate!, pop_gate!, 
       X, Y, Z, H, S, T, P, Rx, Ry, Rz, U,
       CNOT, CZ, CH, SWAP, Toffoli,
       Measure,
       plot

"""
    Wire

A representation of a quantum wire in a circuit.
"""
struct Wire
    label::String
    classical::Bool
end

Wire(label::String) = Wire(label, false)
Wire(; label::String="", classical::Bool=false) = Wire(label, classical)

"""
    AbstractGate

Abstract type for quantum gates.
"""
abstract type AbstractGate end

"""
    SingleQubitGate <: AbstractGate

Abstract type for single-qubit gates.
"""
abstract type SingleQubitGate <: AbstractGate end

"""
    TwoQubitGate <: AbstractGate

Abstract type for two-qubit gates.
"""
abstract type TwoQubitGate <: AbstractGate end

"""
    MultiQubitGate <: AbstractGate

Abstract type for multi-qubit gates.
"""
abstract type MultiQubitGate <: AbstractGate end

"""
    ParamGate <: SingleQubitGate

A parameterized single-qubit gate.
"""
struct ParamGate <: SingleQubitGate
    name::String
    wire_idx::Int
    params::Vector{Float64}
end

"""
    StandardGate <: SingleQubitGate

A standard (non-parameterized) single-qubit gate.
"""
struct StandardGate <: SingleQubitGate
    name::String
    wire_idx::Int
end

"""
    ControlledGate <: TwoQubitGate

A controlled gate with one control qubit and one target qubit.
"""
struct ControlledGate <: TwoQubitGate
    name::String
    control_idx::Int
    target_idx::Int
end

"""
    SwapGate <: TwoQubitGate

A SWAP gate between two qubits.
"""
struct SwapGate <: TwoQubitGate
    wire1_idx::Int
    wire2_idx::Int
end

"""
    MultiControlGate <: MultiQubitGate

A multi-controlled gate with multiple control qubits and one target qubit.
"""
struct MultiControlGate <: MultiQubitGate
    name::String
    control_idxs::Vector{Int}
    target_idx::Int
end

"""
    MeasureGate <: SingleQubitGate

A measurement gate.
"""
struct MeasureGate <: SingleQubitGate
    wire_idx::Int
    target_idx::Union{Int, Nothing}
end

# Constructor for measurement without specified classical bit
MeasureGate(wire_idx::Int) = MeasureGate(wire_idx, nothing)

"""
    Circuit

A structure representing a quantum circuit.
"""
struct Circuit
    wires::Vector{Wire}
    gates::Vector{AbstractGate}
    # Positional information for gates (if specified)
    positions::Dict{AbstractGate, Float64}
end

# Default constructor
Circuit() = Circuit(Wire[], AbstractGate[], Dict{AbstractGate, Float64}())

# Constructor with specified wires
Circuit(n::Int) = Circuit([Wire("q$i") for i in 0:n-1], AbstractGate[], Dict{AbstractGate, Float64}())
Circuit(wires::Vector{Wire}) = Circuit(wires, AbstractGate[], Dict{AbstractGate, Float64}())

# Add a wire to the circuit
function wire(circuit::Circuit, label::String="", classical::Bool=false)
    wire_obj = Wire(label, classical)
    return Circuit(vcat(circuit.wires, [wire_obj]), circuit.gates, circuit.positions)
end

# Shorthand for classical wire
function classical_wire(circuit::Circuit, label::String="")
    wire(circuit, label, true)
end

"""
    add_gate!(circuit::Circuit, gate::AbstractGate, position::Union{Float64, Nothing}=nothing)

Add a gate to a quantum circuit with optional position.
"""
function add_gate!(circuit::Circuit, gate::AbstractGate, position::Union{Float64, Nothing}=nothing)
    new_gates = push!(copy(circuit.gates), gate)
    new_positions = copy(circuit.positions)
    if position !== nothing
        new_positions[gate] = position
    end
    Circuit(circuit.wires, new_gates, new_positions)
end

# Standard gates
X(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("X", wire_idx), position)
Y(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("Y", wire_idx), position)
Z(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("Z", wire_idx), position)
H(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("H", wire_idx), position)
S(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("S", wire_idx), position)
T(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("T", wire_idx), position)
P(circuit::Circuit, wire_idx::Int, position=nothing) = add_gate!(circuit, StandardGate("P", wire_idx), position)

# Parameterized gates
Rx(circuit::Circuit, wire_idx::Int, theta::Real, position=nothing) = 
    add_gate!(circuit, ParamGate("Rx", wire_idx, [Float64(theta)]), position)
Ry(circuit::Circuit, wire_idx::Int, theta::Real, position=nothing) = 
    add_gate!(circuit, ParamGate("Ry", wire_idx, [Float64(theta)]), position)
Rz(circuit::Circuit, wire_idx::Int, theta::Real, position=nothing) = 
    add_gate!(circuit, ParamGate("Rz", wire_idx, [Float64(theta)]), position)
U(circuit::Circuit, wire_idx::Int, params::Vector{<:Real}, position=nothing) = 
    add_gate!(circuit, ParamGate("U", wire_idx, Float64.(params)), position)

# Two-qubit gates
CNOT(circuit::Circuit, control_idx::Int, target_idx::Int, position=nothing) = 
    add_gate!(circuit, ControlledGate("X", control_idx, target_idx), position)
CZ(circuit::Circuit, control_idx::Int, target_idx::Int, position=nothing) = 
    add_gate!(circuit, ControlledGate("Z", control_idx, target_idx), position)
CH(circuit::Circuit, control_idx::Int, target_idx::Int, position=nothing) = 
    add_gate!(circuit, ControlledGate("H", control_idx, target_idx), position)
SWAP(circuit::Circuit, wire1_idx::Int, wire2_idx::Int, position=nothing) = 
    add_gate!(circuit, SwapGate(wire1_idx, wire2_idx), position)

# Multi-qubit gates
Toffoli(circuit::Circuit, control1_idx::Int, control2_idx::Int, target_idx::Int, position=nothing) = 
    add_gate!(circuit, MultiControlGate("X", [control1_idx, control2_idx], target_idx), position)

# Measurement gate
Measure(circuit::Circuit, wire_idx::Int, target_idx::Union{Int, Nothing}=nothing, position=nothing) = 
    add_gate!(circuit, MeasureGate(wire_idx, target_idx), position)

# Support push_gate! and pop_gate! for compatibility with existing API
function push_gate!(circuit::Circuit, gate::AbstractGate)
    new_gates = push!(copy(circuit.gates), gate)
    Circuit(circuit.wires, new_gates, circuit.positions)
end

function pop_gate!(circuit::Circuit)
    if isempty(circuit.gates)
        return circuit
    end
    
    new_gates = copy(circuit.gates)
    gate = pop!(new_gates)
    new_positions = copy(circuit.positions)
    
    if haskey(new_positions, gate)
        delete!(new_positions, gate)
    end
    
    Circuit(circuit.wires, new_gates, new_positions)
end

# Layers for visualization - organize gates by time slices
function circuit_layers(circuit::Circuit)
    # Check if all gates have positions
    all_positioned = all(g -> haskey(circuit.positions, g), circuit.gates)
    
    if all_positioned
        # Sort gates by position
        positions = sort(collect(values(circuit.positions)))
        unique_positions = unique(positions)
        
        # Group gates by position
        layers = [AbstractGate[] for _ in 1:length(unique_positions)]
        for gate in circuit.gates
            pos = circuit.positions[gate]
            pos_idx = findfirst(x -> x == pos, unique_positions)
            push!(layers[pos_idx], gate)
        end
        
        return layers
    end
    
    # Otherwise, compute layout automatically
    layers = Vector{Vector{AbstractGate}}()
    remaining_gates = copy(circuit.gates)
    
    while !isempty(remaining_gates)
        layer = Vector{AbstractGate}()
        occupied_wires = Set{Int}()
        
        i = 1
        while i <= length(remaining_gates)
            gate = remaining_gates[i]
            
            # Get all wires this gate affects
            gate_wires = Int[]
            
            if gate isa StandardGate || gate isa ParamGate
                gate_wires = [gate.wire_idx]
            elseif gate isa ControlledGate
                gate_wires = [gate.control_idx, gate.target_idx]
            elseif gate isa SwapGate
                gate_wires = [gate.wire1_idx, gate.wire2_idx]
            elseif gate isa MultiControlGate
                gate_wires = vcat(gate.control_idxs, [gate.target_idx])
            elseif gate isa MeasureGate
                gate_wires = [gate.wire_idx]
                # Add target wire if it exists
                if gate.target_idx !== nothing
                    push!(gate_wires, gate.target_idx)
                end
            end
            
            # Check if any wires are already occupied in this layer
            if isempty(intersect(occupied_wires, gate_wires))
                push!(layer, gate)
                union!(occupied_wires, gate_wires)
                deleteat!(remaining_gates, i)
            else
                i += 1
            end
        end
        
        push!(layers, layer)
    end
    
    return layers
end

# Rendering functions
function Makie.plot(circuit::Circuit; 
                    wire_spacing=1.0,
                    gate_spacing=1.5,
                    gate_size=0.6,
                    fontsize=14,
                    linewidth=1.5,
                    show_labels=true)
    
    fig = Figure()
    ax = Axis(fig[1, 1], aspect=DataAspect())
    
    hidespines!(ax)
    hidedecorations!(ax)
    
    # Get layers
    layers = circuit_layers(circuit)
    num_layers = length(layers)
    num_wires = length(circuit.wires)
    
    # Circuit width
    width = (num_layers + 1) * gate_spacing
    
    # Draw wires
    for (i, wire) in enumerate(circuit.wires)
        y = (num_wires - i + 1) * wire_spacing
        
        # Draw wire label if requested
        if show_labels && !isempty(wire.label)
            text!(ax, -0.5, y, text=wire.label, fontsize=fontsize, 
                 align=(:right, :center))
        end
        
        # Draw wire
        if wire.classical
            # Double line for classical wire
            lines!(ax, [0, width], [y-0.05, y-0.05], 
                  color=:black, linewidth=linewidth/2)
            lines!(ax, [0, width], [y+0.05, y+0.05], 
                  color=:black, linewidth=linewidth/2)
        else
            # Single line for quantum wire
            lines!(ax, [0, width], [y, y], 
                  color=:black, linewidth=linewidth)
        end
    end
    
    # Draw gates
    for (layer_idx, layer) in enumerate(layers)
        x = layer_idx * gate_spacing
        
        for gate in layer
            draw_gate!(ax, gate, circuit, x, wire_spacing, gate_size, fontsize, linewidth)
        end
    end
    
    return fig
end

# Draw specific gate types
function draw_gate!(ax, gate::StandardGate, circuit::Circuit, x, wire_spacing, gate_size, fontsize, linewidth)
    y = wire_position(circuit, gate.wire_idx, wire_spacing)
    
    # Draw gate box
    rect = Rect(Point2f(x - gate_size/2, y - gate_size/2), Vec2f(gate_size, gate_size))
    poly!(ax, rect, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
    
    # Draw gate label
    text!(ax, x, y, text=gate.name, fontsize=fontsize, align=(:center, :center))
end

function draw_gate!(ax, gate::ParamGate, circuit::Circuit, x, wire_spacing, gate_size, fontsize, linewidth)
    y = wire_position(circuit, gate.wire_idx, wire_spacing)
    
    # Draw gate box
    rect = Rect(Point2f(x - gate_size/2, y - gate_size/2), Vec2f(gate_size, gate_size))
    poly!(ax, rect, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
    
    # Draw gate label with parameters
    label = gate.name
    if gate.name in ["Rx", "Ry", "Rz"] && !isempty(gate.params)
        label = "$(gate.name)($(round(gate.params[1]; digits=2)))"
    end
    
    text!(ax, x, y, text=label, fontsize=fontsize, align=(:center, :center))
end

function draw_gate!(ax, gate::ControlledGate, circuit::Circuit, x, wire_spacing, gate_size, fontsize, linewidth)
    control_y = wire_position(circuit, gate.control_idx, wire_spacing)
    target_y = wire_position(circuit, gate.target_idx, wire_spacing)
    
    # Draw vertical line connecting control to target
    lines!(ax, [x, x], [control_y, target_y], color=:black, linewidth=linewidth)
    
    # Draw control point
    scatter!(ax, [x], [control_y], color=:black, markersize=8)
    
    # Draw target gate
    if gate.name == "X"  # CNOT
        circle = Circle(Point2f(x, target_y), gate_size/2)
        poly!(ax, circle, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
        lines!(ax, [x-gate_size/2, x+gate_size/2], [target_y, target_y], 
               color=:black, linewidth=linewidth)
        lines!(ax, [x, x], [target_y-gate_size/2, target_y+gate_size/2], 
               color=:black, linewidth=linewidth)
    elseif gate.name == "Z"  # CZ
        circle = Circle(Point2f(x, target_y), gate_size/2)
        poly!(ax, circle, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
        text!(ax, x, target_y, text="Z", fontsize=fontsize, align=(:center, :center))
    elseif gate.name == "H"  # CH
        circle = Circle(Point2f(x, target_y), gate_size/2)
        poly!(ax, circle, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
        text!(ax, x, target_y, text="H", fontsize=fontsize, align=(:center, :center))
    end
end

function draw_gate!(ax, gate::SwapGate, circuit::Circuit, x, wire_spacing, gate_size, fontsize, linewidth)
    y1 = wire_position(circuit, gate.wire1_idx, wire_spacing)
    y2 = wire_position(circuit, gate.wire2_idx, wire_spacing)
    
    # Draw vertical line connecting qubits
    lines!(ax, [x, x], [y1, y2], color=:black, linewidth=linewidth)
    
    # Draw X symbols for each qubit
    for y in [y1, y2]
        lines!(ax, [x-gate_size/3, x+gate_size/3], [y-gate_size/3, y+gate_size/3], 
               color=:black, linewidth=linewidth)
        lines!(ax, [x-gate_size/3, x+gate_size/3], [y+gate_size/3, y-gate_size/3], 
               color=:black, linewidth=linewidth)
    end
end

function draw_gate!(ax, gate::MultiControlGate, circuit::Circuit, x, wire_spacing, gate_size, fontsize, linewidth)
    control_ys = [wire_position(circuit, idx, wire_spacing) for idx in gate.control_idxs]
    target_y = wire_position(circuit, gate.target_idx, wire_spacing)
    
    # Find top and bottom y positions
    top_y = min(minimum(control_ys), target_y)
    bottom_y = max(maximum(control_ys), target_y)
    
    # Draw vertical line connecting all points
    lines!(ax, [x, x], [top_y, bottom_y], color=:black, linewidth=linewidth)
    
    # Draw control points
    for control_y in control_ys
        scatter!(ax, [x], [control_y], color=:black, markersize=8)
    end
    
    # Draw target gate
    if gate.name == "X"  # Toffoli
        circle = Circle(Point2f(x, target_y), gate_size/2)
        poly!(ax, circle, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
        lines!(ax, [x-gate_size/2, x+gate_size/2], [target_y, target_y], 
               color=:black, linewidth=linewidth)
        lines!(ax, [x, x], [target_y-gate_size/2, target_y+gate_size/2], 
               color=:black, linewidth=linewidth)
    end
end

function draw_gate!(ax, gate::MeasureGate, circuit::Circuit, x, wire_spacing, gate_size, fontsize, linewidth)
    y = wire_position(circuit, gate.wire_idx, wire_spacing)
    
    # Draw measurement circle
    circle = Circle(Point2f(x, y), gate_size/2)
    poly!(ax, circle, color=(:white, 1.0), strokecolor=:black, strokewidth=linewidth)
    text!(ax, x, y, text="M", fontsize=fontsize, align=(:center, :center))
    
    # If there's a target classical wire
    if gate.target_idx !== nothing
        target_y = wire_position(circuit, gate.target_idx, wire_spacing)
        lines!(ax, [x, x], [y, target_y], color=:black, linewidth=linewidth)
    end
end

# Helper to compute wire y-position
function wire_position(circuit::Circuit, wire_idx::Int, wire_spacing::Real)
    num_wires = length(circuit.wires)
    return (num_wires - wire_idx + 1) * wire_spacing
end

# Example circuit functions
function bell_pair()
    # Create circuit with 2 qubits
    qc = Circuit(2)
    
    # Create Bell state
    qc = H(qc, 1)
    qc = CNOT(qc, 1, 2)
    
    return qc
end

function quantum_teleportation()
    # Create circuit with 3 qubits and 2 classical bits
    qc = Circuit([Wire("q₀"), Wire("q₁"), Wire("q₂"), Wire("c₀", true), Wire("c₁", true)])
    
    # Create bell pair between qubits 2 and 3
    qc = H(qc, 2)
    qc = CNOT(qc, 2, 3)
    
    # Apply gates to teleport qubit 1's state to qubit 3
    qc = CNOT(qc, 1, 2)
    qc = H(qc, 1)
    
    # Measure qubits 1 and 2
    qc = Measure(qc, 1, 4)  # Measure q₀ to c₀
    qc = Measure(qc, 2, 5)  # Measure q₁ to c₁
    
    # Conditional operations based on measurement results
    qc = X(qc, 3, 5.0)  # Apply X based on c₁
    qc = Z(qc, 3, 5.5)  # Apply Z based on c₀
    
    return qc
end

# Example usage with matching the API in the image
function example_from_image()
    # Create circuit with 8 qubits
    qc = Circuit([Wire("q$i") for i in 1:8])
    
    # Follow the circuit pattern from the image
    qc = CNOT(qc, 1, 2, 1.0)
    qc = CNOT(qc, 1, 3, 1.0)
    qc = SWAP(qc, 3, 4, 1.0)
    
    qc = H(qc, 1, 2.0)
    qc = X(qc, 2, 2.0)
    qc = H(qc, 5, 2.0)
    qc = P(qc, 6, 2.0)
    
    qc = U(qc, 4, [0.0, 0.0, 0.0], 3.0)  # Generic U gate
    
    qc = Measure(qc, 4, nothing, 4.0)
    
    qc = G(qc, 5, 5.0)  # G gate (defined below)
    
    # Add measurements with connections to classical lines
    qc = Measure(qc, 7, nothing, 5.0)
    qc = Measure(qc, 8, nothing, 5.0)
    
    return qc
end

# Extra gate for the example
function G(circuit::Circuit, wire_idx::Int, position=nothing)
    add_gate!(circuit, StandardGate("G", wire_idx), position)
end

end  # module