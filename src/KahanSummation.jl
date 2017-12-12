# This file contains code that was formerly a part of Julia.
# License is MIT: https://julialang.org/license

__precompile__(true)

module KahanSummation

if VERSION >= v"0.7.0-DEV.3000" # TODO: More specific bound
    if isdefined(Base, :sum_kbn) # Deprecated
        import Base: sum_kbn, cumsum_kbn
    else
        export sum_kbn, cumsum_kbn
    end
end

if isdefined(Base, Symbol("@default_eltype"))
    using Base: @default_eltype
else
    macro default_eltype(itr)
        quote
            Core.Inference.return_type(first, Tuple{$(esc(itr))})
        end
    end
end

if isdefined(Base, :promote_sys_size_add)
    using Base: promote_sys_size_add
else
    promote_sys_size_add(x::T) where {T} = Base.r_promote(+, zero(T)::T)
end


import Base.TwicePrecision


function plus_kbn(x::T, y::T) where {T}
    hi = x + y
    lo = abs(x) > abs(y) ? (x - hi) + y : (y - hi) + x
    TwicePrecision(hi, lo)
end
function plus_kbn(x::T, y::TwicePrecision{T}) where {T}
    hi = x + y.hi
    if abs(x) > abs(y.hi)
        lo = ((x - hi) + y.hi) + y.lo
    else
        lo = ((y.hi - hi) + x) + y.lo
    end
    TwicePrecision(hi, lo)
end
plus_kbn(x::TwicePrecision{T}, y::T) where {T} = plus_kbn(y, x)

function plus_kbn(x::TwicePrecision{T}, y::TwicePrecision{T}) where {T}
    hi = x.hi + y.hi
    if abs(x.hi) > abs(y.hi)
        lo = (((x.hi - hi) + y.hi) + y.lo) + x.lo
    else
        lo = (((y.hi - hi) + x.hi) + x.lo) + y.lo
    end
    TwicePrecision(hi, lo)
end

Base.r_promote_type(::typeof(plus_kbn), ::Type{T}) where {T<:AbstractFloat} =
    TwicePrecision{T}

Base.mr_empty(f, ::typeof(plus_kbn), T) = TwicePrecision{T}

singleprec(x::TwicePrecision{T}) where {T} = convert(T, x)


"""
    sum_kbn([f,] A)

Return the sum of all elements of `A`, using the Kahan-Babuska-Neumaier compensated
summation algorithm for additional accuracy.
"""
sum_kbn(f, X) = singleprec(mapreduce(f, plus_kbn, X))
sum_kbn(X) = sum_kbn(identity, X)







"""
    cumsum_kbn(A, dim::Integer)

Cumulative sum along a dimension, using the Kahan-Babuska-Neumaier compensated summation
algorithm for additional accuracy.
"""
function cumsum_kbn(A::AbstractArray{T}, axis::Integer) where T<:AbstractFloat
    dimsA = size(A)
    ndimsA = ndims(A)
    axis_size = dimsA[axis]
    axis_stride = 1
    for i = 1:(axis-1)
        axis_stride *= size(A, i)
    end
    axis_size <= 1 && return A
    B = similar(A)
    C = similar(A)
    for i = 1:length(A)
        if div(i-1, axis_stride) % axis_size == 0
            B[i] = A[i]
            C[i] = zero(T)
        else
            s = B[i-axis_stride]
            Ai = A[i]
            B[i] = t = s + Ai
            if abs(s) >= abs(Ai)
                C[i] = C[i-axis_stride] + ((s-t) + Ai)
            else
                C[i] = C[i-axis_stride] + ((Ai-t) + s)
            end
        end
    end
    return B + C
end

function cumsum_kbn(v::AbstractVector{T}) where T<:AbstractFloat
    r = similar(v)
    isempty(v) && return r
    inds = indices(v, 1)
    i1 = first(inds)
    s = r[i1] = v[i1]
    c = zero(T)
    for i = i1+1:last(inds)
        vi = v[i]
        t = s + vi
        if abs(s) >= abs(vi)
            c += ((s-t) + vi)
        else
            c += ((vi-t) + s)
        end
        s = t
        r[i] = s+c
    end
    return r
end

end # module
