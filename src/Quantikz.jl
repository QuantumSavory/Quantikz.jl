"""
A module for drawing quantum circuits through the Quantikz latex package.
"""
module Quantikz

using Base.Filesystem
using Pkg.Artifacts

export CNOT, CPHASE, H, P, Id, U, ControlU, SWAP,
       Measurement, ParityMeasurement,
       circuit2table, table2string,
       circuit2string,
       string2png,
       displaycircuit,
       savepng, savepdf, savetex

quantikzname = "tikzlibraryquantikz.code.tex"
quantikzfile = joinpath(artifact"quantikz", "quantikz-0.9.6", quantikzname)

abstract type QuantikzOp end

function update_table!(table,step,op)
    update_table!(table,step,QuantikzOp(op))
end

struct CNOT <: QuantikzOp
    control::Integer
    target::Integer
end

affectedqubits(cnot::CNOT) = [cnot.control,cnot.target]
function update_table!(table,step,cnot::CNOT)
    table[cnot.control,step] = "\\ctrl{$(cnot.target-cnot.control)}"
    table[cnot.target ,step] = "\\targ{}"
    table
end

struct CPHASE <: QuantikzOp
    target1::Integer
    target2::Integer
end

affectedqubits(cphase::CPHASE) = [cphase.target1,cphase.target2]
function update_table!(table,step,cphase::CPHASE)
    table[cphase.target1,step] = "\\ctrl{$(cphase.target2-cphase.target1)}"
    table[cphase.target2,step] = "\\control{}"
    table
end

struct SWAP <: QuantikzOp
    target1::Integer
    target2::Integer
end

affectedqubits(s::SWAP) = [s.target1,s.target2]
function update_table!(table,step,s::SWAP)
    table[s.target1,step] = "\\swap{$(s.target2-s.target1)}"
    table[s.target2,step] = "\\targX{}"
    table
end

struct U <: QuantikzOp
    str::AbstractString
    target::Integer
end

affectedqubits(u::U) = [u.target]
function update_table!(table,step,u::U)
    table[u.target,step] = "\\gate{$(u.str)}"
    table
end

H(target) = U("H",target)
P(target) = U("P",target)

struct Id <: QuantikzOp
    target::Integer
end

affectedqubits(i::Id) = [i.target]
function update_table!(table,step,i::Id)
    table[i.target,step] = "\\qw"
    table
end

struct Measurement <: QuantikzOp
    str::AbstractString
    target::Integer
end

Measurement(i::Integer) = Measurement("",i)

affectedqubits(m::Measurement) = [m.target]
function update_table!(table,step,meas::Measurement)
    table[meas.target,step] = "\\meterD{$(meas.str)}"
    table[meas.target,step+1:end] .= ""
    table
end

struct ParityMeasurement <: QuantikzOp
    paulis::String
    qubits::AbstractVector{Integer}
end

affectedqubits(pm::ParityMeasurement) = pm.qubits
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

const PADDING = 1

function circuit2table_expanded(circuit, qubits)
    steps = length(circuit)
    table = fill(raw"\qw",qubits,steps+2*PADDING)
    current_step = 1+PADDING
    for op in circuit
        update_table!(table,current_step,op)
        current_step+=1
    end
    return table
end

function circuit2table_compressed(circuit, qubits)
    steps = length(circuit)
    table = fill(raw"\qw",qubits,steps+2*PADDING)
    filled_up_to = fill(1+PADDING,qubits)
    for op in circuit
        qubits = affectedqubits(op)
        current_step = maximum(filled_up_to[qubits])
        update_table!(table,current_step,op)
        l,h = extrema(qubits)
        filled_up_to[l:h] .= current_step+1
    end
    return table[:,1:maximum(filled_up_to)-1+PADDING]
end

function circuit2table(circuit, qubits; mode=:compressed)
    if mode==:compressed
        return circuit2table_compressed(circuit, qubits)
    elseif mode==:expanded
        return circuit2table_expanded(circuit, qubits)
    else
        throw("Unknown mode: must be `:compressed` or `:expanded`!")
    end
end

circuit2table(circuit; kw...) = circuit2table(circuit, maximum([maximum(affectedqubits(o)) for o in circuit]); kw...)

function table2string(table)
    lstr = join([join(row," & ") for row in eachrow(table)], "\\\\\n")
    return "\\begin{quantikz}\n$(lstr)\n\\end{quantikz}"
end

circuit2string(circuit, qubits; kw...) = table2string(circuit2table(circuit, qubits; kw...))
circuit2string(circuit; kw...) = table2string(circuit2table(circuit; kw...))

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

circuit2png(circuit, qubits; kw...) = string2png(table2string(circuit2table(circuit, qubits; kw...)))
circuit2png(circuit; kw...) = string2png(table2string(circuit2table(circuit; kw...)))

displaycircuit(circuit, qubits; kw...) = display(MIME"image/png"(),circuit2png(circuit,qubits; kw...))
displaycircuit(circuit; kw...) = display(MIME"image/png"(),circuit2png(circuit; kw...))

function savepng(circuit,qubits,filename; kw...) # TODO remove duplicated code
    string = circuit2string(circuit,qubits; kw...)
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

savepng(circuit, filename; kw...) = savepng(circuit, maximum([maximum(affectedqubits(o)) for o in circuit]), filename; kw...)

function savepdf(circuit,qubits,filename; kw...) # TODO remove duplicated code
    string = circuit2string(circuit,qubits; kw...)
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

savepdf(circuit, filename; kw...) = savepdf(circuit, maximum([maximum(affectedqubits(o)) for o in circuit]), filename; kw...)

function savetex(circuit,qubits,filename; kw...)
    string = circuit2string(circuit,qubits; kw...)
    f = open(filename, "w")
    print(f,string)
    close(f)
end

savetex(circuit, filename; kw...) = savetex(circuit, maximum([maximum(affectedqubits(o)) for o in circuit]), filename; kw...)

end