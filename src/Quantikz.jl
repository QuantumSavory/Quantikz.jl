"""
A module for drawing quantum circuits through the Quantikz latex package.
"""
module Quantikz

using Base.Filesystem
using Pkg.Artifacts

using EndpointRanges
using FileIO
using Ghostscript_jll
using Tectonic

export MultiControl, CNOT, CPHASE, SWAP, H, P, Id, U,
       MultiControlU,
       ClassicalDecision,
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

function tryrun(cmd)
    try
        run(pipeline(cmd, stderr=devnull, stdout=devnull))
    catch e
        @warn "Command failed... $(e) Retrying..."
        run(cmd)
    end
end

abstract type QuantikzOp end

struct QuantikzTable
    table::Matrix{String}
    qubits::Int
    ancillaries::Int
    bits::Int
end

function QuantikzTable(qubits::Integer,ancillaries::Integer,bits::Integer,length::Integer)
    tableq = fill(raw"\qw",qubits,length)
    tablea = fill(raw"",ancillaries,length)
    tablec = fill(raw"\cw",bits,length)
    QuantikzTable(vcat(tableq,tablea,tablec), qubits, ancillaries, bits)
end

qubitsview(qt::QuantikzTable) = @view qt.table[1:qt.qubits,:]
ancillaryview(qt::QuantikzTable) = @view qt.table[qt.qubits+1:qt.qubits+qt.ancillaries,:]
bitsview(qt::QuantikzTable) = @view qt.table[qt.qubits+qt.ancillaries+1:end,:]

update_table!(table,step,op) = update_table!(table,step,QuantikzOp(op))
affectedqubits(op) = affectedqubits(QuantikzOp(op))
affectedbits(op) = affectedbits(QuantikzOp(op))
neededancillaries(op) = neededancillaries(QuantikzOp(op))
nsteps(op) = nsteps(QuantikzOp(op))
deleteoutputs(op) = deleteoutputs(QuantikzOp(op))

affectedbits(op::QuantikzOp) = []
neededancillaries(op::QuantikzOp) = 0
nsteps(op::QuantikzOp) = 1
deleteoutputs(op::QuantikzOp) = []

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
function update_table!(qtable,step,g::MultiControl) # TODO displaycircuit([CNOT([1,4],[3],[2,5])]) has bad ocircle covered by line and a disconnected target
    table = qtable.table
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
    qtable
end

struct MultiControlU <: QuantikzOp
    str::AbstractString
    control::AbstractVector{Integer}
    ocontrol::AbstractVector{Integer}
    target::AbstractVector{Integer}
end

MultiControlU(target::AbstractVector{<:Integer}) = MultiControlU("\\;\\;",[],[],target)
MultiControlU(str::AbstractString, target::AbstractVector{<:Integer}) = MultiControlU(str,[],[],target)
MultiControlU(control::AbstractVector{<:Integer},ocontrol::AbstractVector{<:Integer},target::AbstractVector{<:Integer}) = MultiControlU("\\;\\;",control,ocontrol,target)
MultiControlU(str::AbstractString,control::Integer,target::AbstractVector{<:Integer}) = MultiControlU(str,[control],[],target)
MultiControlU(control::Integer,target::AbstractVector{<:Integer}) = MultiControlU("\\;\\;",[control],[],target)
MultiControlU(str::AbstractString,control::Integer,target::Integer) = MultiControlU(str,[control],[],[target])
MultiControlU(control::Integer,target::Integer) = MultiControlU("\\;\\;",[control],[],[target])

affectedqubits(g::MultiControlU) = [g.control...,g.ocontrol...,g.target...]
function update_table!(qtable,step,g::MultiControlU) # TODO displaycircuit([CNOT([1,4],[3],[2,5])]) has bad ocircle covered by line and a disconnected target
    table = qtable.table
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
        if i > M && startpoint < M
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
    qtable
end

struct U <: QuantikzOp
    str::AbstractString
    target::Integer
end

U(target::Integer) = U("\\;\\;", target)

affectedqubits(u::U) = [u.target]
function update_table!(qtable,step,u::U)
    table = qtable.table
    table[u.target,step] = "\\gate{$(u.str)}"
    qtable
end

H(target) = U("H",target)
P(target) = U("P",target)

struct Id <: QuantikzOp
    target::Integer
end

affectedqubits(i::Id) = [i.target]
function update_table!(qtable,step,i::Id)
    table = qtable.table
    table[i.target,step] = "\\qw"
    qtable
end

struct Measurement <: QuantikzOp
    str::AbstractString
    targets::Vector{Integer}
    bit # might be nothing
end

Measurement(i::Integer) = Measurement("",[i],nothing)
Measurement(str::AbstractString, i::Integer) = Measurement(str,[i],nothing)
Measurement(str::AbstractString, is::AbstractVector{<:Integer}) = Measurement(str,is,nothing)
Measurement(is::AbstractVector{<:Integer}) = Measurement("\\;\\;", is, nothing)
Measurement(i::Integer, b::Integer) = Measurement("",[i],b)
Measurement(str::AbstractString, i::Integer, b::Integer) = Measurement(str,[i],b)
Measurement(is::AbstractVector{<:Integer}, b::Integer) = Measurement("\\;\\;", is, b)

affectedqubits(m::Measurement) = m.targets
function update_table!(qtable,step,meas::Measurement)
    table = qtable.table
    if length(meas.targets) == 1
        table[meas.targets[1],step] = "\\meterD{$(meas.str)}"
        if !isnothing(meas.bit)
            bitsview(qtable)[meas.bit,step] = "\\cwbend{$(-(qtable.qubits-meas.targets[1])-qtable.ancillaries-meas.bit)}"
        end
    else
        step = step+1
        m,M = extrema(meas.targets)
        offset = iseven(M-m) && (m+M)/2 ∉ meas.targets ? ",label style={yshift=0.2cm}" : ""
        table[m,step] = "\\gate[$(M-m+1)$(offset)]{$(meas.str)}"
        for i in m+1:M
            if i ∉ meas.targets
                table[i,step] = "\\linethrough"
            else
                table[i,step] = ""
            end
        end
        qubitsview(qtable)[meas.targets,step+1] .= "\\qw"
        ancillaryview(qtable)[1,step-1] = "\\lstick{}"
        ancillaryview(qtable)[1,step] = "\\ctrl{$(M-qtable.qubits-1)}"
        ancillaryview(qtable)[1,step+1] = "\\meterD{}"
        if !isnothing(meas.bit)
            bitsview(qtable)[meas.bit,step+1] = "\\cwbend{$(1-qtable.ancillaries-meas.bit)}"
        end
    end
    qtable
end
neededancillaries(m::Measurement) = length(m.targets) > 1 ? 1 : 0
nsteps(m::Measurement) = length(m.targets) > 1 ? 3 : 1
affectedbits(m::Measurement) = isnothing(m.bit) ? [] : [m.bit]
deleteoutputs(m::Measurement) = length(m.targets) == 1 ? m.targets : []

struct ClassicalDecision <: QuantikzOp
    str::AbstractString
    targets::Vector{Integer}
    bits::Vector{Integer}
end

ClassicalDecision(str::AbstractString, t::Integer, c::Integer) = ClassicalDecision(str, [t], [c])
ClassicalDecision(str::AbstractString, t::AbstractVector{<:Integer}, c::Integer) = ClassicalDecision(str, t, [c])
ClassicalDecision(t::Integer, c::Integer) = ClassicalDecision("\\;\\;", [t], [c])
ClassicalDecision(t::AbstractVector{<:Integer}, c::Integer) = ClassicalDecision("\\;\\;", t, [c])

affectedqubits(g::ClassicalDecision) = g.targets
affectedbits(g::ClassicalDecision) = g.bits
function update_table!(qtable,step,g::ClassicalDecision)
    table = qtable.table
    m,M = extrema(g.targets) # TODO this piece of code is repeated frequently, abstract it away
    offset = iseven(M-m) && (m+M)/2 ∉ g.targets ? ",label style={yshift=0.2cm}" : ""
    table[m,step] = "\\gate[$(M-m+1)$(offset)]{$(g.str)}"
    for i in m+1:M
        if i ∉ g.targets
            table[i,step] = "\\linethrough"
        else
            table[i,step] = ""
        end
    end
    startpoint = minimum(g.bits)
    bitsview(qtable)[startpoint,step] = "\\cwbend{$(-(qtable.qubits-M)-qtable.ancillaries-startpoint)}"
    for b in sort(g.bits)[2:end]
        bitsview(qtable)[b,step] = "\\cwbend{$(startpoint-b)}"
        startpoint = b
    end
    qtable
end

struct ParityMeasurement <: QuantikzOp
    paulis::AbstractVector{String}
    qubits::AbstractVector{Integer}
end

affectedqubits(pm::ParityMeasurement) = pm.qubits
function update_table!(qtable,step,meas::ParityMeasurement)
    table = qtable.table
    qubits = meas.qubits
    paulis = meas.paulis
    first = qubits[1]
    table[first,step] = "\\meterD{$(paulis[1])}"
    for (i,p) in zip(qubits[2:end], paulis[2:end])
        if i!=first
            table[i,step] = "\\meterD{$(p)}\\vcw{$(first-i)}"
        first = i
        end
    end
    qtable
end
deleteoutputs(m::ParityMeasurement) = affectedqubits(m)

struct Noise <: QuantikzOp
    qubits::AbstractVector{Integer}
end

affectedqubits(n::Noise) = n.qubits
function update_table!(qtable,step,n::Noise)
    table = qtable.table
    for q in n.qubits
        table[q,step] = "\\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{}"
    end
    qtable
end

struct NoiseAll <: QuantikzOp
end

affectedqubits(n::NoiseAll) = ibegin:iend
function update_table!(qtable,step,n::NoiseAll)
    table = qubitsview(qtable)
    table[:,step] .= ["\\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{}"]
    qtable
end

const PADDING = 1

circuitwidth(circuit) = maximum([affectedqubits(o)==ibegin:iend ? 1 : maximum(affectedqubits(o)) for o in circuit])
function circuitwidthbits(circuit) 
    bits = vcat(map(affectedbits,circuit)...)
    if isempty(bits)
        return 0
    else
        return maximum(bits)
    end
end

function QuantikzTable(circuit::AbstractVector, qubits::Integer)
    steps = sum(map(nsteps, circuit))
    ans = maximum(map(neededancillaries, circuit))
    bits = circuitwidthbits(circuit)
    table = QuantikzTable(qubits,ans,bits,steps+2*PADDING)
end

function circuit2table_expanded(circuit, qubits)
    table = QuantikzTable(circuit, qubits)
    current_step = 1+PADDING
    for op in circuit
        update_table!(table,current_step,op)
        current_step+=nsteps(op)
        qubitsview(table)[affectedqubits(op),current_step:end] .= "\\qw"
        qubitsview(table)[deleteoutputs(op),current_step:end] .= ""
    end
    return table
end

Base.extrema(r::EndpointRanges.EndpointUnitRange) = (r.start, r.stop) # TODO submit these to EndpointRanges (and make them <:AbstractRange)
Base.extrema(r::EndpointRanges.EndpointStepRange) = r.step>0 ? (r.start, r.stop) : (r.stop, r.start)
function extremarange(r::AbstractVector)
    if isempty(r)
        return r
    else
        start, stop = extrema(r)
        return start:stop
    end
end
function extremarange(r) # TODO should really be AbstractRange
    start, stop = extrema(r)
    return start:stop
end


function circuit2table_compressed(circuit, qubits)
    table = QuantikzTable(circuit, qubits)
    filled_up_to = fill(1+PADDING,qubits)
    afilled_up_to = fill(1+PADDING,table.ancillaries)
    bfilled_up_to = fill(1+PADDING,table.bits)
    for op in circuit
        qubits = extremarange(affectedqubits(op))
        bits = extremarange(affectedbits(op))
        ancillaries = neededancillaries(op)
        steps = nsteps(op)
        current_step = maximum([filled_up_to[qubits]...,afilled_up_to[1:ancillaries]...,bfilled_up_to[bits]...])
        filled_up_to[qubits] .= current_step+steps
        afilled_up_to[1:ancillaries] .= current_step+steps
        if !isempty(affectedbits(op))
            filled_up_to[qubits.stop:end] .= current_step+steps
            bfilled_up_to[bits] .= current_step+steps
        end
        qubitsview(table)[affectedqubits(op),current_step:end] .= "\\qw"
        qubitsview(table)[deleteoutputs(op),current_step:end] .= ""
        update_table!(table,current_step,op)
    end
    return QuantikzTable(table.table[:,1:maximum(filled_up_to)-1+PADDING],table.qubits,table.ancillaries,table.bits)
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

circuit2table(circuit; kw...) = circuit2table(circuit, circuitwidth(circuit); kw...)

function table2string(qtable; sep=0.8, quantikzoptions=nothing, kw...)
    lstr = join([join(row," & ") for row in eachrow(qtable.table)], "\\\\\n")
    if isnothing(quantikzoptions)
        opts = "transparent, row sep={$(sep)cm,between origins}"
    else
        opts = quantikzoptions
    end
    return "\\begin{quantikz}[$(opts)]\n$(lstr)\n\\end{quantikz}"
end

circuit2string(circuit, qubits; kw...) = table2string(circuit2table(circuit, qubits; kw...); kw...)
circuit2string(circuit; kw...) = table2string(circuit2table(circuit; kw...); kw...)

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
        tectonic() do bin
            tryrun(`$bin input.tex`)
        end
        # Workaround for imagemagick failing to find gs on Windows (see https://github.com/JuliaIO/ImageMagick.jl/issues/198)
        #gs() do bin
        #    return load("input.pdf")
        #end
        if isnothing(savefile)
            gs() do bin
                tryrun(`$bin -dNOPAUSE -sDEVICE=png16m -dSAFER -dMaxBitmap=500000000 -dAlignToPixels=0 -dGridFitTT=2 -dTextAlphaBits=4 -dGraphicsAlphaBits=1 -dDownScaleFactor=8 -r800 -sOutputFile=input.png input.pdf -dBATCH`)
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
function Base.show(io::IO, mime::MIME"image/png", circuit::AbstractVector{<:QuantikzOp}; scale=1, kw...)
    save(Stream(format"PNG", io), circuit2image(circuit; scale=scale, kw...))
end
Base.show(io::IO, mime::MIME"image/png", gate::T; scale=1, kw...) where T<:QuantikzOp = show(io, mime, [gate]; scale=scale, kw...)

function displaystring(string)
    io = IOBuffer()
    save(Stream(format"PNG", io), string2image(string))
    display(MIME"image/png"(),read(seekstart(io)))
end

function savecircuit(circuit,qubits,filename; scale=5, kw...) # TODO remove duplicated code
    # Workaround for imagemagick failing to find gs on Windows (see https://github.com/JuliaIO/ImageMagick.jl/issues/198)
    if endswith(filename, "pdf") || endswith(filename, "PDF")
        circuit2image(circuit, qubits; scale=scale, _workaround_savefile=filename)
        return
    elseif endswith(filename, "tex") || endswith(filename, "TEX")
        savetex(circuit,qubits,filename; kw...)
        return
    end
    image = circuit2image(circuit, qubits; scale=scale, kw...)
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
