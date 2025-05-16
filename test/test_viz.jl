using Quantikz  # Load the main package/module

# Now you can access `Circuit`, `add_gate!`, `draw`, etc.

circ = Circuit(3)
add_gate!(circ, :H, 1, at=1)
add_gate!(circ, :CNOT, (1, 2), at=2)
add_gate!(circ, :X, 3, at=3)

draw(circ)
