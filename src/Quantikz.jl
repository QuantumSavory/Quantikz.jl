<<<<<<< HEAD
"""
A module for drawing quantum circuits through the Quantikz latex package.
"""
module Quantikz

using Base.Filesystem
using Base.ScopedValues: @with, ScopedValue
using Pkg.Artifacts

using FileIO
using Ghostscript_jll
using tectonic_jll

include("EndpointRanges.jl")
using .VendoredEndpointRanges
const EndpointRanges = VendoredEndpointRanges

export MultiControl, CNOT, CPHASE, SWAP, H, P, Id, U,
       MultiControlU,
       ClassicalDecision,
       Measurement, ParityMeasurement,
       Noise, NoiseAll,
       Initialize,
       circuit2table, table2string,
       circuit2string,
       string2image,
       circuit2image,
       displaycircuit,
       savecircuit,
       @with, ScopedValue

const quantikzname = "tikzlibraryquantikz.code.tex"
const quantikzfile = joinpath(artifact"quantikz", "quantikz", quantikzname)

const classicalbitslayout = ScopedValue(:compressed)
classicalbitslayout_error() = error("`classicalbitslayout` config variable has to be either `:expanded` or `:complressed`. Instead it is `$(classicalbitslayout[])`")

# This is necessary because typeof(ibegin:iend) <: AbstractRange is false
const ArrayOrRange = Union{A,B,C} where {A<:AbstractVector, B<:EndpointRanges.EndpointUnitRange, C<:EndpointRanges.EndpointStepRange}

function tryrun(cmd)
    try
        run(pipeline(cmd, stderr=devnull, stdout=devnull))
    catch e
        @warn "Command failed... $(e) Retrying..."
        run(cmd)
    end
end

abstract type QuantikzOp end
QuantikzOp(q::QuantikzOp) = q

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
    control::ArrayOrRange
    ocontrol::ArrayOrRange
    target::ArrayOrRange
    targetX::ArrayOrRange
end

CNOT(c::Integer,t::Integer) = MultiControl([c],[],[t],[])
CPHASE(t1::Integer,t2::Integer) = MultiControl([t1,t2],[],[],[])
SWAP(t1::Integer,t2::Integer) = MultiControl([],[],[],[t1,t2])

affectedqubits(g::MultiControl) = [g.control...,g.ocontrol...,g.target...,g.targetX...]
function update_table!(qtable,step,g::MultiControl)
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
    control::ArrayOrRange
    ocontrol::ArrayOrRange
    target::ArrayOrRange
    target_notU::ArrayOrRange
end

function MultiControlU(str::AbstractString,
    control::ArrayOrRange,
    ocontrol::ArrayOrRange,
    target::ArrayOrRange)
    MultiControlU(str,control,ocontrol,target,[])
end
MultiControlU(target::ArrayOrRange) = MultiControlU("\\;\\;",[],[],target)
MultiControlU(str::AbstractString, target::ArrayOrRange) = MultiControlU(str,[],[],target)
MultiControlU(control::ArrayOrRange,ocontrol::ArrayOrRange,target::ArrayOrRange) = MultiControlU("\\;\\;",control,ocontrol,target)
MultiControlU(str::AbstractString,control::Integer,target::ArrayOrRange) = MultiControlU(str,[control],[],target)
MultiControlU(control::Integer,target::ArrayOrRange) = MultiControlU("\\;\\;",[control],[],target)
MultiControlU(str::AbstractString,control::Integer,target::Integer) = MultiControlU(str,[control],[],[target])
MultiControlU(control::Integer,target::Integer) = MultiControlU("\\;\\;",[control],[],[target])

affectedqubits(g::MultiControlU) = [g.control...,g.ocontrol...,g.target...,g.target_notU...]
function update_table!(qtable,step,g::MultiControlU)
    table = qubitsview(qtable)
    control = g.control
    ocontrol = g.ocontrol
    target = g.target
    target_notU = g.target_notU
    controls = sort([
        [("\\ctrl",i) for i in control]...,
        [("\\octrl",i) for i in ocontrol]...,
        [("\\targ{}\\vqw",i) for i in target_notU]...,
        ], by=e->e[2])
    m,M = extrema(target)
    if length(controls)==0
        startpoint = M
    else
        startpoint = min(M,controls[1][2])
    end
    draw_rectangle!(table,step,target,g.str)
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

function draw_rectangle!(table,step,targets,str;checkdelete_evenfortarget=false)
    deleted = Int[]
    m, M = explicit_extrema(table, targets)
    targets = explicit_targets(table, targets)
    for i in m:M
        if i ∉ targets
            if strip(table[i,step-1])==""
                push!(deleted, i)
            else
                table[i,step] = "\\linethrough"
            end
        else
            if checkdelete_evenfortarget && strip(table[i,step-1])==""
                push!(deleted, i)
                i!=m && (table[i,step] = "")
            else
                i!=m && (table[i,step] = "\\qw")
            end
        end
    end
    offset = iseven(M-m) && ((m+M)/2 ∉ vcat(targets,deleted)) && !occursin("\\\\",str) ? ",label style={yshift=0.2cm}" : ""
    nwires = isempty(deleted) ? "" : ",nwires={$(join(deleted,","))}"
    autoheight = M-m+1>1 ? ",disable auto height" : ""
    table[m,step] = "\\gate[$(M-m+1)$(offset)$(nwires)$(autoheight)]{$(str)}"
end

struct U <: QuantikzOp
    str::AbstractString
    target::Integer
end

U(target::Integer) = U("\\;\\;", target)
U(targets::ArrayOrRange) = MultiControlU("\\;\\;", targets)
U(str::AbstractString, targets::ArrayOrRange) = MultiControlU(str, targets)

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
    targets::ArrayOrRange
    bit # might be nothing
end

Measurement(i::Integer) = Measurement("",[i],nothing)
Measurement(str::AbstractString, i::Integer) = Measurement(str,[i],nothing)
Measurement(str::AbstractString, is::ArrayOrRange) = Measurement(str,is,nothing)
Measurement(is::ArrayOrRange) = Measurement("\\;\\;", is, nothing)
Measurement(i::Integer, b::Integer) = Measurement("",[i],b)
Measurement(str::AbstractString, i::Integer, b::Integer) = Measurement(str,[i],b)
Measurement(is::ArrayOrRange, b::Integer) = Measurement("\\;\\;", is, b)

affectedqubits(m::Measurement) = m.targets
function update_table!(qtable,step,meas::Measurement)
    table = qubitsview(qtable)
    layoutbit = if isnothing(meas.bit)
        nothing
    elseif classicalbitslayout[] == :expanded
        meas.bit
    elseif classicalbitslayout[] == :compressed
        1
    else
        classicalbitslayout_error()
    end
    if length(meas.targets) == 1
        table[meas.targets[1],step] = "\\meterD{$(meas.str)}"
        if !isnothing(layoutbit)
            bitsview(qtable)[layoutbit,step] = "\\cwbend{$(-(qtable.qubits-meas.targets[1])-qtable.ancillaries-layoutbit)}"
        end
    else
        step = step+1
        m,M = extrema(meas.targets)
        draw_rectangle!(table,step,meas.targets,meas.str)
        qubitsview(qtable)[meas.targets,step+1] .= "\\qw"
        ancillaryview(qtable)[1,step-1] = "\\lstick{}"
        ancillaryview(qtable)[1,step] = "\\ctrl{$(M-qtable.qubits-1)}"
        ancillaryview(qtable)[1,step+1] = "\\meterD{}"
        if !isnothing(layoutbit)
            bitsview(qtable)[layoutbit,step+1] = "\\cwbend{$(1-qtable.ancillaries-layoutbit)}"
        end
    end
    qtable
end
neededancillaries(m::Measurement) = length(m.targets) > 1 ? 1 : 0
nsteps(m::Measurement) = length(m.targets) > 1 ? 3 : 1
affectedbits(m::Measurement) = isnothing(m.bit) ? [] : [m.bit]
deleteoutputs(m::Measurement) = length(m.targets) == 1 ? m.targets : []

struct Initialize <: QuantikzOp
    str::AbstractString
    targets::AbstractVector
end

affectedqubits(r::Initialize) = r.targets
function update_table!(qtable,step,r::Initialize)
    qvtable = qubitsview(qtable)
    m, M = extrema(r.targets)
    targets = r.targets
    if collect(targets) == collect(m:M)
        qvtable[m,step] = "\\midstick[wires=$(M-m+1),brackets=right]{$(r.str)}"
        for i in targets[2:end]
            qvtable[i,step] = ""
        end
    else
        for i in targets
            qvtable[i,step] = ""
        end
        draw_rectangle!(qvtable, step+1, r.targets, r.str, checkdelete_evenfortarget=true)
    end
    qtable
end
function nsteps(r::Initialize)
    m, M = extrema(r.targets)
    targets = r.targets
    collect(targets) == collect(m:M) ? 1 : 2
end


struct ClassicalDecision <: QuantikzOp
    str::AbstractString
    targets::ArrayOrRange
    bits::ArrayOrRange
end

ClassicalDecision(str::AbstractString, t::Integer, c::Integer) = ClassicalDecision(str, [t], [c])
ClassicalDecision(str::AbstractString, t::ArrayOrRange, c::Integer) = ClassicalDecision(str, t, [c])
ClassicalDecision(str::AbstractString, t::Integer, c::ArrayOrRange) = ClassicalDecision(str, [t], c)
ClassicalDecision(t::Integer, c::Integer) = ClassicalDecision("\\;\\;", [t], [c])
ClassicalDecision(t::ArrayOrRange, c::Integer) = ClassicalDecision("\\;\\;", t, [c])
ClassicalDecision(t::Integer, c::ArrayOrRange) = ClassicalDecision("\\;\\;", [t], c)
ClassicalDecision(t::ArrayOrRange, c::ArrayOrRange) = ClassicalDecision("\\;\\;", t, c)
ClassicalDecision(c::ArrayOrRange) = ClassicalDecision("", [], c)

affectedqubits(g::ClassicalDecision) = g.targets
affectedbits(g::ClassicalDecision) = g.bits
function update_table!(qtable,step,g::ClassicalDecision)
    qvtable = qubitsview(qtable)
    bvtable = bitsview(qtable)
    actualbits = explicit_targets(bvtable, g.bits)
    layoutbits = if classicalbitslayout[] == :expanded
        actualbits
    elseif classicalbitslayout[] == :compressed
        [1]
    else
        classicalbitslayout_error()
    end
    startpoint = minimum(layoutbits)
    if !isa(g.targets,AbstractVector) || length(g.targets)>0
        m, M = explicit_extrema(qvtable, g.targets)
        draw_rectangle!(qvtable,step,g.targets,g.str)
        bvtable[startpoint,step] = "\\cwbend{$(-(qtable.qubits-M)-qtable.ancillaries-startpoint)}"
    else
        bvtable[startpoint,step] = "\\cwbend{0}"
    end
    for b in sort(layoutbits)[2:end]
        bvtable[b,step] = "\\cwbend{$(startpoint-b)}"
        startpoint = b
    end
    qtable
end

struct ParityMeasurement <: QuantikzOp
    paulis::AbstractVector{String}
    qubits::ArrayOrRange
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
    qubits::ArrayOrRange
end

affectedqubits(n::Noise) = n.qubits
function update_table!(qtable,step,n::Noise)
    qvtable = qubitsview(qtable)
    for q in explicit_targets(qvtable,n.qubits)
        qvtable[q,step] = "\\gate[1,style={starburst,starburst points=7,inner xsep=-2pt,inner ysep=-2pt,scale=0.5}]{}"
    end
    qtable
end

NoiseAll() = Noise(ibegin:iend)

const PADDING = 1

conservative_maximum(a::AbstractVector)=  isempty(a) ? 1 : maximum(a)
conservative_maximum(a) = 1 # This captures EndpointRanges and other things... TODO might be a bit too conservative
moreconservative_maximum(a::AbstractVector)=  isempty(a) ? 0 : maximum(a)
moreconservative_maximum(a) = 1
circuitwidth(op) = conservative_maximum(affectedqubits(op))
circuitwidth(circuit::AbstractArray) = maximum(circuitwidth.(circuit))
circuitwidthbits(op) = moreconservative_maximum(affectedbits(op))
circuitwidthbits(circuit::AbstractArray) = maximum(circuitwidthbits.(circuit))

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
    layoutbits = if classicalbitslayout[] == :expanded
        table.bits
    elseif classicalbitslayout[] == :compressed
        1
    else
        classicalbitslayout_error()
    end
    cutoff = table.qubits+table.ancillaries+layoutbits
    return QuantikzTable(table.table[begin:cutoff,:], table.qubits, table.ancillaries, layoutbits)
end

"""Turn implicit endpoints to explicit integer indices and take the extrema"""
function explicit_extrema(table,r)
    t = explicit_targets(table,r)
    isempty(t) ? t : extrema(t)
end
"""Turn implicit endpoints to explicit integer indices"""
function explicit_targets(table,targets)
    targets = (1:size(table,1))[targets]
end
function extrema2range(e)
    isempty(e) ? e : e[1]:e[2]
end

function circuit2table_compressed(circuit, qubits)
    table = QuantikzTable(circuit, qubits)
    qvtable = qubitsview(table)
    bvtable = bitsview(table)
    filled_up_to = fill(1+PADDING,qubits)
    afilled_up_to = fill(1+PADDING,table.ancillaries)
    bfilled_up_to = fill(1+PADDING,table.bits)
    maxbit = 0
    for op in circuit
        qubits = extrema2range(explicit_extrema(qvtable, affectedqubits(op)))
        if circuitwidthbits(op)!=0 || neededancillaries(op)!=0
            qubits = if length(qubits)==0
                ibegin:iend # TODO this branch is too pessimistic
            else
                minimum(qubits):iend
            end
        end
        bits = extrema2range(explicit_extrema(bvtable, affectedbits(op)))
        layoutbits = if isempty(bits) || classicalbitslayout[] == :expanded
            bits
        elseif classicalbitslayout[] == :compressed
            [1]
        else
            classicalbitslayout_error()
        end
        maxbit = max(maxbit, layoutbits...)
        ancillaries = neededancillaries(op)
        steps = nsteps(op)
        current_step = maximum([filled_up_to[qubits]...,afilled_up_to[1:ancillaries]...,bfilled_up_to[bits]...])
        filled_up_to[qubits] .= current_step+steps
        afilled_up_to[1:ancillaries] .= current_step+steps
        if circuitwidthbits(op)!=0
            filled_up_to[qubits.stop:end] .= current_step+steps
            bfilled_up_to[layoutbits] .= current_step+steps
        end
        qvtable[affectedqubits(op),current_step:end] .= "\\qw"
        qvtable[deleteoutputs(op),current_step:end] .= ""
        update_table!(table,current_step,op)
    end
    cutoff = table.qubits+table.ancillaries+maxbit
    return QuantikzTable(table.table[begin:cutoff,1:maximum(filled_up_to)-1+PADDING],table.qubits,table.ancillaries,maxbit)
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
    savefile = get(Dict(kw), :_workaround_savefile, nothing)
    f = open(joinpath(dir,"input.tex"), "w")
    print(f,template)
    close(f)
    tectonic() do bin
        tryrun(`$bin $(joinpath(dir,"input.tex"))`)
    end
    if isnothing(savefile)
        gs() do bin
            tryrun(`$bin -dNOPAUSE -sDEVICE=png16m -dSAFER -dMaxBitmap=500000000 -dAlignToPixels=0 -dGridFitTT=2 -dTextAlphaBits=4 -dGraphicsAlphaBits=1 -dDownScaleFactor=8 -r800 -sOutputFile=$(joinpath(dir,"input.png")) $(joinpath(dir,"input.pdf")) -dBATCH`)
        end
        return load(joinpath(dir,"input.png"))
    else
        cp(joinpath(dir,"input.pdf"), savefile, force=true)
        return
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

function savecircuit(circuit,qubits,filename; scale=5, kw...)
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
=======
module Quantikz

include("gates.jl")
include("circuit.jl")
include("core.jl")
include("visualize/MakiePlot.jl")

using .Gates
using .CircuitModule
using .Visualize

export circuit, Circuit, put!, draw  # <--- make sure these are exported
>>>>>>> 94eb55c (Add Makie-based visualization module)

end
