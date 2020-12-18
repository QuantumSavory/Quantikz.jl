"""
A module for drawing quantum circuits through the Quantikz latex package.
"""
module Quantikz

using Base.Filesystem
using Pkg.Artifacts

export CNOT, CPHASE, H, P, Id, U, ControlU,
       Measurement, ParityMeasurement,
       circuit2table, table2string,
       circuit2string,
       string2png,
       displaycircuit,
       savepng, savepdf, savetex

quantikzname = "tikzlibraryquantikz.code.tex"
quantikzfile = joinpath(artifact"quantikz", quantikzname)

abstract type QuantikzOp end

function update_table!(table,step,op)
    update_table!(table,step,QuantikzOp(op))
end

struct CNOT <: QuantikzOp
    control::Integer
    target::Integer
end

maxqubit(cnot::CNOT) = max(cnot.control,cnot.target)
function update_table!(table,step,cnot::CNOT)
    table[cnot.control,step] = "\\ctrl{$(cnot.target-cnot.control)}"
    table[cnot.target ,step] = "\\targ{}"
    table
end

struct CPHASE <: QuantikzOp
    target1::Integer
    target2::Integer
end

maxqubit(cphase::CPHASE) = max(cphase.target1,cphase.target2)
function update_table!(table,step,cphase::CPHASE)
    table[cphase.target1,step] = "\\ctrl{$(cphase.target2-cphase.target1)}"
    table[cphase.target2,step] = "\\control{}"
    table
end

struct U <: QuantikzOp
    str::AbstractString
    target::Integer
end

maxqubit(u::U) = u.target
function update_table!(table,step,u::U)
    table[u.target,step] = "\\gate{$(u.str)}"
    table
end

H(target) = U("H",target)
P(target) = U("P",target)

struct Id <: QuantikzOp
    target::Integer
end

maxqubit(i::Id) = i.target
function update_table!(table,step,i::Id)
    table[i.target,step] = "\\qw"
    table
end

struct Measurement <: QuantikzOp
    str::AbstractString
    target::Integer
end

Measurement(i::Integer) = Measurement("",i)

maxqubit(m::Measurement) = m.target
function update_table!(table,step,meas::Measurement)
    table[meas.target,step] = "\\meterD{$(meas.str)}"
    table[meas.target,step+1:end] .= ""
    table
end

struct ParityMeasurement <: QuantikzOp
    paulis::String
    qubits::AbstractVector{Integer}
end

maxqubit(pm::ParityMeasurement) = maximum(pm.qubits)
function update_table!(table,step,meas::ParityMeasurement)
    qubits = meas.qubits
    paulis = meas.paulis
    first = qubits[1]
    table[first,step] = "\\meterD{$(paulis[1])}"
    table[first,step+1:end] .= ""
    for (i,p) in zip(qubits[2:end], paulis[2:end])
        if i!=first
            table[i,step] = "\\meterD{$(p)}\\vcw{$(first-i)}"
        table[i,step+1:end] .= ""
        first = i
        end
    end
    table
end

function circuit2table(circuit, qubits)
    steps = length(circuit)+2
    table = fill(raw"\qw",qubits,steps)
    current_step = 2
    for op in circuit
        update_table!(table,current_step,op)
        current_step+=1
    end
    return table
end

circuit2table(circuit) = circuit2table(circuit, maximum([maxqubit(o) for o in circuit]))

function table2string(table)
    lstr = join([join(row," & ") for row in eachrow(table)], "\\\\\n")
    return "\\begin{quantikz}\n$(lstr)\n\\end{quantikz}"
end

circuit2string(circuit, qubits) = table2string(circuit2table(circuit, qubits))
circuit2string(circuit) = table2string(circuit2table(circuit))

function string2png(string)
    dir = mktempdir()
    cp(quantikzfile, joinpath(dir,quantikzname))
    template = """
    \\documentclass[convert={density=100}]{standalone}
    \\usepackage{tikz}
    \\usetikzlibrary{quantikz}
    \\begin{document}
    $(string)
    \\end{document}
    """
    cd(dir) do
        f = open("input.tex", "w")
        print(f,template)
        close(f)
        read(`pdflatex -shell-escape input.tex`)
        return read("input.png")
    end
end

circuit2png(circuit, qubits) = string2png(table2string(circuit2table(circuit, qubits)))
circuit2png(circuit) = string2png(table2string(circuit2table(circuit)))

displaycircuit(circuit, qubits) = display(MIME"image/png"(),circuit2png(circuit,qubits))
displaycircuit(circuit) = display(MIME"image/png"(),circuit2png(circuit))

function savepng(circuit,qubits,filename) # TODO remove duplicated code
    string = circuit2string(circuit,qubits)
    dir = mktempdir()
    cp(quantikzfile, joinpath(dir,quantikzname))
    template = """
    \\documentclass[convert={density=100}]{standalone}
    \\usepackage{tikz}
    \\usetikzlibrary{quantikz}
    \\begin{document}
    $(string)
    \\end{document}
    """
    cd(dir) do
        f = open("input.tex", "w")
        print(f,template)
        close(f)
        read(`pdflatex -shell-escape input.tex`)
    end
    cp(joinpath(dir,"input.png"), filename)
end

savepng(circuit, filename) = savepng(circuit, maximum([maxqubit(o) for o in circuit]), filename)

function savepdf(circuit,qubits,filename) # TODO remove duplicated code
    string = circuit2string(circuit,qubits)
    dir = mktempdir()
    cp(quantikzfile, joinpath(dir,quantikzname))
    template = """
    \\documentclass[]{standalone}
    \\usepackage{tikz}
    \\usetikzlibrary{quantikz}
    \\begin{document}
    $(string)
    \\end{document}
    """
    cd(dir) do
        f = open("input.tex", "w")
        print(f,template)
        close(f)
        read(`pdflatex input.tex`)
    end
    cp(joinpath(dir,"input.png"), filename)
end

savepdf(circuit, filename) = savepdf(circuit, maximum([maxqubit(o) for o in circuit]), filename)

function savetex(circuit,qubits,filename)
    string = circuit2string(circuit,qubits)
    f = open(filename, "w")
    print(f,string)
    close(f)
end

savetex(circuit, filename) = savetex(circuit, maximum([maxqubit(o) for o in circuit]), filename)

end