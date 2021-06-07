```@meta
DocTestSetup = quote
    using Quantikz
end
```

### [Standard Single- and Two-qubit Gates](@id available-operations)

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

### Initial states or resets

#### At the beginning of a circuit

```@example 1
Initialize("\\ket{\\phi}", [1,2,3])
```

```@example 1
Initialize("\\ket{\\phi}", [1,2,4])
```

#### Midway through a circuit

```@example 1
[CNOT(1,2), Measurement(3), Initialize("\\ket{\\phi}", [2,3])]
```

```@example 1
[CNOT(1,2), Measurement(1), Measurement(3), Initialize("\\ket{\\phi}", [1,3])]
```

### Noise Events

```@example 1
[Noise([1,5]), NoiseAll()]
```
