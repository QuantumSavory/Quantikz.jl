"""
A module for drawing quantum circuits through the Quantikz latex package.
"""
module Quantikz

using Base.Filesystem
using Pkg.Artifacts

using FileIO
using Ghostscript_jll
using Suppressor
using Tectonic

export MultiControl, CNOT, CPHASE, SWAP, H, P, Id, U,
       MultiControlU,
       Measurement, ParityMeasurement,
       Noise, NoiseAll,
       circuit2table, table2string,
       circuit2string,
       string2image,
       circuit2image,
       displaycircuit,
       savecircuit, savetex

quantikzname = "tikzlibraryquantikz.code.tex"
quantikzfile = joinpath(artifact"quantikz", "quantikz-0.9.6", quantikzname)

macro trysuppress(expr)
    :(try; @suppress($(esc(expr))); catch; @warn "Command failed... Retrying..."; $(esc(expr)); end;)
end

abstract type QuantikzOp end

update_table!(table,step,op) = update_table!(table,step,QuantikzOp(op))
affectedqubits(op) = affectedqubits(QuantikzOp(op))

struct MultiControl <: QuantikzOp
    control::AbstractVector{Integer}
    ocontrol::AbstractVector{Integer}
    target::AbstractVector{Integer}
    targetX::AbstractVector{Integer}
end

CNOT(c::Integer,t::Integer) = MultiControl([c],[],[t],[])
CPHASE(t1::Integer,t2::Integer) = MultiControl([t1,t2],[],[],[])
SWAP(t1::Integer,t2::Integer) = MultiControl([],[],[],[t1,t2])

affectedqubits(g::MultiControl) = [g.control...,g.ocontrol...,g.target...,g.targetX...]
function update_table!(table,step,g::MultiControl) # TODO displaycircuit([CNOT([1,4],[3],[2,5])]) has bad ocircle covered by line and a disconnected target
    control = g.control
    ocontrol = g.ocontrol
    target = g.target
    targetX = g.targetX
    controls = sort([
        [("\\ctrl",i) for i in control]...,
        [("\\octrl",i) for i in ocontrol]...,
        [("\\targ{}\\vqw",i) for i in target]...,
        [("\\swap",i) for i in targetX]...
        ], by=e->e[2])
    startpoint = controls[1][2]
    for (str, i) in controls
        table[i,step] = str*"{$(startpoint-i)}"
        startpoint = i
    end
    table
end

struct MultiControlU <: QuantikzOp
    str::AbstractString
    control::AbstractVector{Integer}
    ocontrol::AbstractVector{Integer}
    target::AbstractVector{Integer}
end

MultiU(str::AbstractString, target::AbstractVector{Integer}) = MultiControlU(str,[],[],target)

affectedqubits(g::MultiControlU) = [g.control...,g.ocontrol...,g.target...]
function update_table!(table,step,g::MultiControlU) # TODO displaycircuit([CNOT([1,4],[3],[2,5])]) has bad ocircle covered by line and a disconnected target
    control = g.control
    ocontrol = g.ocontrol
    target = g.target
    controls = sort([
        [("\\ctrl",i) for i in control]...,
        [("\\octrl",i) for i in ocontrol]...,
        ], by=e->e[2])
    m,M = extrema(target)
    if length(controls)==0
        startpoint = M
    else
        startpoint = min(M,controls[1][2])
    end
    offset = iseven(M-m) && (m+M)/2 ∉ target ? ",label style={yshift=0.2cm}" : ""
    table[m,step] = "\\gate[$(M-m+1)$(offset)]{$(g.str)}"
    for i in m+1:M
        if i ∉ target
            table[i,step] = "\\linethrough"
        else
            table[i,step] = ""
        end
    end
    for (str, i) in controls
        if i > M
            if startpoint < m
                table[m,step] *= "\\vqw{$(startpoint-m)}"
            end
            startpoint = M
        end
        table[i,step] = str*"{$(startpoint-i)}"
        startpoint = i
    end
    if startpoint < m
        table[m,step] *= "\\vqw{$(startpoint-m)}"
    end
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
    paulis::AbstractVector{String}
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

struct Noise <: QuantikzOp
    qubits::AbstractVector{Integer}
end

affectedqubits(n::Noise) = n.qubits
function update_table!(table,step,n::Noise)
    for q in n.qubits
        table[q,step] = "\\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{}"
    end
    table
end

struct NoiseAll <: QuantikzOp
end

affectedqubits(n::NoiseAll) = :all # TODO consider using EndpointRanges.jl
function update_table!(table,step,n::NoiseAll)
    table[:,step] .= ["\\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{}"]
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
    for op in circuit # TODO consider using EndpointRanges.jl
        qubits = affectedqubits(op)
        if qubits==:all
            current_step = maximum(filled_up_to)
            filled_up_to .= current_step+1
        else
            current_step = maximum(filled_up_to[qubits])
            l,h = extrema(qubits)
            filled_up_to[l:h] .= current_step+1
        end
        update_table!(table,current_step,op)
    end
    return table[:,1:maximum(filled_up_to)-1+PADDING]
end

function circuit2table(circuit, qubits; mode=:compressed, kw...)
    if mode==:compressed
        return circuit2table_compressed(circuit, qubits)
    elseif mode==:expanded
        return circuit2table_expanded(circuit, qubits)
    else
        throw("Unknown mode: must be `:compressed` or `:expanded`!")
    end
end

circuitwidth(circuit) = maximum([affectedqubits(o)==:all ? 1 : maximum(affectedqubits(o)) for o in circuit])
circuit2table(circuit; kw...) = circuit2table(circuit, circuitwidth(circuit); kw...)

function table2string(table)
    lstr = join([join(row," & ") for row in eachrow(table)], "\\\\\n")
    return "\\begin{quantikz}[transparent]\n$(lstr)\n\\end{quantikz}"
end

circuit2string(circuit, qubits; kw...) = table2string(circuit2table(circuit, qubits; kw...))
circuit2string(circuit; kw...) = table2string(circuit2table(circuit; kw...))

function string2image(string; scale=5, kw...)
    dir = mktempdir()
    cp(quantikzfile, joinpath(dir,quantikzname))
    template = """
    \\documentclass[]{standalone}
    \\usepackage{tikz}
    \\usetikzlibrary{quantikz}
    \\usepackage{adjustbox}
    \\begin{document}
    \\begin{adjustbox}{scale=$(scale)}
    $(string)
    \\end{adjustbox}
    \\end{document}
    """
    # Workaround for imagemagick failing to find gs on Windows (see https://github.com/JuliaIO/ImageMagick.jl/issues/198)
    savefile = get(Dict(kw), :_workaround_savefile, nothing)
    olddir = pwd()
    cd(dir) do
        f = open("input.tex", "w")
        print(f,template)
        close(f)
        @trysuppress tectonic() do bin
            run(`$bin input.tex`)
        end
        # Workaround for imagemagick failing to find gs on Windows (see https://github.com/JuliaIO/ImageMagick.jl/issues/198)
        #gs() do bin
        #    return load("input.pdf")
        #end
        if isnothing(savefile)
            @trysuppress gs() do bin
                run(`$bin -dNOPAUSE -sDEVICE=pngalpha -dSAFER -dMaxBitmap=500000000 -dAlignToPixels=0 -dGridFitTT=2 -dTextAlphaBits=4 -dGraphicsAlphaBits=1 -sOutputFile=input.png input.pdf -dBATCH`)
            end
            return load("input.png")
        else
            cp("input.pdf", joinpath(olddir,savefile), force=true)
            return
        end
    end
end

circuit2image(circuit, qubits; scale=5, kw...) = string2image(table2string(circuit2table(circuit, qubits; kw...)); scale=scale, kw...)
circuit2image(circuit; scale=5, kw...) = circuit2image(circuit, circuitwidth(circuit); scale=scale, kw...)

function displaycircuit(circuit, qubits; scale=1, kw...)
    io = IOBuffer()
    save(Stream(format"PNG", io), circuit2image(circuit,qubits; scale=scale, kw...))
    display(MIME"image/png"(),read(seekstart(io)))
end
displaycircuit(circuit; scale=1, kw...) = displaycircuit(circuit, circuitwidth(circuit); scale=scale, kw...)

function savecircuit(circuit,qubits,filename; scale=5, kw...) # TODO remove duplicated code
    # Workaround for imagemagick failing to find gs on Windows (see https://github.com/JuliaIO/ImageMagick.jl/issues/198)
    if endswith(filename, "pdf") || endswith(filename, "PDF")
        circuit2image(circuit, qubits; scale=scale, _workaround_savefile=filename)
        return
    end
    image = circuit2image(circuit, qubits; scale=scale)
    save(filename,image)
end
savecircuit(circuit, filename; kw...) = savecircuit(circuit, circuitwidth(circuit), filename; kw...)

function savetex(circuit,qubits,filename; kw...)
    string = circuit2string(circuit,qubits; kw...)
    f = open(filename, "w")
    print(f,string)
    close(f)
end

savetex(circuit, filename; kw...) = savetex(circuit, circuitwidth(circuit), filename; kw...)

end