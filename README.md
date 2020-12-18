# Quatikz.jl

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/Krastanov/Quantikz/CI)](https://github.com/Krastanov/Quantikz/actions?query=workflow%3ACI+branch%3Amain)
[![Test coverage from codecov](https://img.shields.io/codecov/c/gh/Krastanov/Quantikz?label=codecov)](https://codecov.io/gh/Krastanov/Quantikz)

A minimal package for drawing quantum circuits using the `quantikz` and `tikz` TeX libraries. Only a small subset of the `quantikz` operations are currently implemented.

To install it use:

```julia
] add Quantikz
```

If you have the `quantikz` and `standalone` TeX libraries installed, with working `pdflatex` and `convert` binaries accessible, the use of this package is as symple as:

```julia
circuit = [CNOT(1,2),Measurement(2)]
displaycircuit(circuit)
```

If you do not have a working version of `convert` (which has been problematic on a number of recent operating systems), you can still generate a PDF containing the circuit with:

```
savepdf(circuit, filename)
```

If you do not have a functional TeX environment you can still view the corresponding TeX string or save it to file with:

```
circuit2string(circuit)
savetex(circuit, filename)
```

## Built-in quantum circuit operations

`CNOT`, `CPHASE`, `H`, `P`, `Id`, a generic single qubit gate `U`, a generic measurement `Measurement`, and a parity check measurement `ParityMeasurement`.

## Custom objects

For your `CustomQuantumOperation` simply define a `QuantikzOp(op::CustomQuantumOperation)` that converts your object to one of the built-in objects.

If you need more freedom for your custom quantum operation, simply define `update_table!(table,step,op::CustomQuantumOperation)` that directly modifies the `quantikz` table and define `maxqubit(op::CustomQuantumOperation)` that gives the maximum index of the qubits involved in the operation.

Internally, this library converts the array of circuit operations to a 2D array of `quantikz` macros which is then converted to a single TeX string, which is then compiled with a call to `pdflatex`.
