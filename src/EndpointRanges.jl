# copied from https://github.com/JuliaArrays/EndpointRanges.jl
# due to the fact that Quantikz was the only dependent of EndpointRanges
# causing some worry about the support that would be available upstream
module VendoredEndpointRanges

import Base: +, -, *, /, ÷, %
using Base: ViewIndex, tail, axes1

export ibegin, iend

abstract type Endpoint end
struct IBegin <: Endpoint end
struct IEnd   <: Endpoint end
const ibegin = IBegin()
const iend   = IEnd()

(::IBegin)(b::Integer, e::Integer) = b
(::IEnd  )(b::Integer, e::Integer) = e
(::IBegin)(r::AbstractRange) = first(r)
(::IEnd  )(r::AbstractRange) = last(r)

struct IndexFunction{F<:Function} <: Endpoint
    index::F
end
(f::IndexFunction)(r::AbstractRange) = f.index(r)

for op in (:+, :-)
    @eval $op(x::Endpoint) = IndexFunction(r->x(r))
end
for op in (:+, :-, :*, :/, :÷, :%)
    @eval $op(x::Endpoint, y::Endpoint) = IndexFunction(r->$op(x(r), y(r)))
    @eval $op(x::Endpoint, y::Number) = IndexFunction(r->$op(x(r), y))
    @eval $op(x::Number, y::Endpoint) = IndexFunction(r->$op(x, y(r)))
end

# deliberately not <: AbstractUnitRange{Int}
abstract type EndpointRange{T} end
struct EndpointUnitRange{F<:Union{Int,Endpoint},L<:Union{Int,Endpoint}} <: EndpointRange{Int}
    start::F
    stop::L
end
struct EndpointStepRange{F<:Union{Int,Endpoint},L<:Union{Int,Endpoint}} <: EndpointRange{Int}
    start::F
    step::Int
    stop::L
end

(r::EndpointUnitRange)(s::AbstractRange) = r.start(s):r.stop(s)
(r::EndpointUnitRange{Int,E})(s::AbstractRange) where {E<:Endpoint} = r.start:r.stop(s)
(r::EndpointUnitRange{E,Int})(s::AbstractRange) where {E<:Endpoint} = r.start(s):r.stop

(r::EndpointStepRange)(s::AbstractRange) = r.start(s):r.step:r.stop(s)
(r::EndpointStepRange{Int,E})(s::AbstractRange) where {E<:Endpoint} = r.start:r.step:r.stop(s)
(r::EndpointStepRange{E,Int})(s::AbstractRange) where {E<:Endpoint} = r.start(s):r.step:r.stop

(::Colon)(start::Endpoint, stop::Endpoint) = EndpointUnitRange(start, stop)
(::Colon)(start::Endpoint, stop::Int) = EndpointUnitRange(start, stop)
(::Colon)(start::Int, stop::Endpoint) = EndpointUnitRange(start, stop)

(::Colon)(start::Endpoint, step::Int, stop::Endpoint) = EndpointStepRange(start, step, stop)
(::Colon)(start::Endpoint, step::Int, stop::Int) = EndpointStepRange(start, step, stop)
(::Colon)(start::Int, step::Int, stop::Endpoint) = EndpointStepRange(start, step, stop)

function Base.getindex(r::UnitRange, s::EndpointRange)
    getindex(r, newindex(axes1(r), s))
end

function Base.getindex(r::AbstractUnitRange, s::EndpointRange)
    getindex(r, newindex(axes1(r), s))
end

function Base.getindex(r::StepRange, s::EndpointRange)
    getindex(r, newindex(axes1(r), s))
end

function Base.getindex(r::StepRangeLen, s::EndpointRange)
    getindex(r, newindex(axes1(r), s))
end

function Base.getindex(r::LinRange, s::EndpointRange)
    getindex(r, newindex(axes1(r), s))
end


@inline function Base.to_indices(A, inds, I::Tuple{Union{Endpoint, EndpointRange}, Vararg{Any}})
    (newindex(inds[1], I[1]), to_indices(A, (inds)[2:end], Base.tail(I))...)
end

@inline newindices(indsA, inds) = (newindex(indsA[1], inds[1]), newindices(tail(indsA), tail(inds))...)
newindices(::Tuple{}, ::Tuple{}) = ()

newindex(indA, i::Union{Real, AbstractArray, Colon}) = i
newindex(indA, i::EndpointRange) = i(indA)
newindex(indA, i::IBegin) = first(indA)
newindex(indA, i::IEnd)   = last(indA)
newindex(indA, i::Endpoint) = i(indA)

end # module
