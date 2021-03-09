# Quantikz.jl

```@meta
DocTestSetup = quote
    using Quantikz
end
```

A minimal package for drawing quantum circuits using the `quantikz`[^1] and `tikz` TeX libraries.

[^1]: [Tutorial on the Quantikz Package, Alastair Kay](https://arxiv.org/abs/1809.03842)

## Available Operations

### Standard Single- and Two-qubit Gates

```@example 1
using Quantikz # hide
[P(1), H(2), Id(3), U(4), U(raw"\mathrm{Gate}",5)]
```

```@example 1
latexmatrix = raw"\begin{pmatrix}
\alpha & \beta \\
\gamma & \delta
\end{pmatrix}"
U(latexmatrix,1)
```

```@example 1
[CNOT(1,2), CPHASE(2,3), SWAP(3,4)]
```

### Multi Qubit Gates

#### Arbitrary combination of filled circle, open circle, NOT, and cross

```@example 1
MultiControl([1],[2],[3],[4])
```

#### Arbitrary controlled gate

```@example 1
[
    MultiControlU([1], [2], [3,4]),
    MultiControlU("XYZ",  [1], [2], [3,4,5]),
    MultiControlU("U_a",  [1], [2], [3,5]),
]
```

#### Gate dependent on classical bits

```@example 1
[
    ClassicalDecision(1, 1),
    ClassicalDecision("U",  [1,2], 2),
    ClassicalDecision("U_a",  [1,3], [1,3]),
]
```

### Measurements

#### Single qubit, with optional result stored to bits

```@example 1
[
    Measurement(1),
    Measurement("X", 2),
    Measurement("Z", 3, 1)
]
```

#### Multiple qubits stabilizer measurement, with optional result stored to bits.

```@example 1
[
    Measurement([1,2]),
    Measurement("ZZ", [2,3]),
    Measurement("XX", [3,4], 1)
]
```

#### Multiqubit Bell measurements

```@example 1
ParityMeasurement(["X","Y","Z"], [1,2,4])
```

### Noise Events

```@example 1
[Noise([1,5]), NoiseAll()]
```

## Custom `quantikz` TeX code

For each circuit you can get the `quantikz` table if you want to modify it.

```@example 1
qtable = circuit2table([CNOT(1,2), CPHASE(2,3)])
qtable.qubits, qtable.ancillaries, qtable.bits
```

```@example 1
qtable.table
```

And after modifications, the table can be turned into a tex string

```@exampl 1
table2string(qtable)
```

## Saving files

Use `savecircuit(circuit, filename)` for `tex`, `pdf`, and `png` files.

## Custom Objects

For your `CustomQuantumOperation` simply define a `QuantikzOp(op::CustomQuantumOperation)` that converts your object to one of the built-in objects from the examples above.

If you need more freedom for your custom quantum operation, simply define:
- `update_table!(table,step,op::CustomQuantumOperation)` that directly modifies the `quantikz` table
- `affectedqubits(op::CustomQuantumOperation)` that gives the indices of qubits involved in the operation.
- (optional) `affectedbits(op)` that gives the indices of classical bits in use (empty by default)
- (optional) `neededancillaries(op)` that gives the number of temporary ancillary qubits to reserve (0 by default)
- (optional) `nsteps(op)` that gives the number of steps involved in the gate (1 by default)
- (optional) `deleteoutputs(op)` that gives which qubits to be deleted, e.g., their lines removed (empty by default)

Instead of returning an array of indices `affectedqubits` can also return the lazy slice `ibegin:iend` (from `EndpointRanges.jl`) which tells the layout engine that all qubits are used in this stage of the circuit.