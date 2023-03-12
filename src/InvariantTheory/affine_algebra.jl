################################################################################
#
#  Presentation as affine algebra
#
################################################################################

@doc Markdown.doc"""
    affine_algebra(IR::InvRing;
      algo_gens::Symbol = :default, algo_rels::Symbol = :groebner_basis)

Given an invariant ring `IR` with underlying graded polynomial ring, say `R`,
return a graded affine algebra, say `A`, together with a graded algebra
homomorphism `A` $\to$ `R` which maps `A` isomorphically onto `IR`.

!!! note
    If a system of fundamental invariants for `IR` is already cached, the function
    makes use of that system. Otherwise, such a system is computed and cached first.
    The algebra `A` is graded according to the degrees of the fundamental invariants,
    the modulus of `A` is generated by the algebra relations on these invariants, and
    the algebra homomorphism `A` $\to$ `R` is defined by sending the `i`-th
    generator of `A` to the `i`-th fundamental invariant.

# Optional arguments
Using the arguments `:king` or `:primary_and_secondary` for `algo_gens` selects
the algorithm for the computation of the fundamental invariants (see
[`fundamental_invariants`](@ref) for details).
The argument `:groebner_basis` or `:linear_algebra` for `algo_rels` controls
which algorithm for the computation of the relations between the fundamental
invariants is used. With `:groebner_basis`, the relations are computed via the
standard computation of a kernel of a morphism between multivariate polynomial
rings. The option `:linear_algebra` uses an algorithm by Kemper and Steel
[KS99](@cite), Section 17.5.5, to compute the relations without the use of Groebner
bases. Note that this option is only available, if the fundamental invariants
are computed via primary and secondary invariants (i.e.
`algo_gens = :primary_and_secondary`).

!!! note
    If a presentation of `IR` is already computed (and hence cached), this cached
    presentation will be returned and the values of `algo_gens` and `algo_rels`
    will be ignored.
    Further, if fundamental invariants are already computed and cached, the value
    of `algo_gens` might be ignored, as the cached system is used.

# Examples
```jldoctest
julia> K, a = CyclotomicField(3, "a")
(Cyclotomic field of order 3, a)

julia> M1 = matrix(K, [0 0 1; 1 0 0; 0 1 0])
[0   0   1]
[1   0   0]
[0   1   0]

julia> M2 = matrix(K, [1 0 0; 0 a 0; 0 0 -a-1])
[1   0        0]
[0   a        0]
[0   0   -a - 1]

julia> G = MatrixGroup(3, K, [ M1, M2 ])
Matrix group of degree 3 over Cyclotomic field of order 3

julia> IR = invariant_ring(G)
Invariant ring of
Matrix group of degree 3 over Cyclotomic field of order 3
with generators
AbstractAlgebra.Generic.MatSpaceElem{nf_elem}[[0 0 1; 1 0 0; 0 1 0], [1 0 0; 0 a 0; 0 0 -a-1]]

julia> affine_algebra(IR)
(Quotient of Multivariate Polynomial Ring in y1, y2, y3, y4 over Cyclotomic field of order 3 graded by
  y1 -> [3]
  y2 -> [3]
  y3 -> [6]
  y4 -> [9] by ideal(y1^6 - 3*y1^4*y3 - 16*y1^3*y2^3 - 4*y1^3*y4 + 3*y1^2*y3^2 + 24*y1*y2^3*y3 + 4*y1*y3*y4 + 72*y2^6 + 24*y2^3*y4 - y3^3 + 8*y4^2), Map with following data
Domain:
=======
Quotient of Multivariate Polynomial Ring in y1, y2, y3, y4 over Cyclotomic field of order 3 graded by
  y1 -> [3]
  y2 -> [3]
  y3 -> [6]
  y4 -> [9] by ideal(y1^6 - 3*y1^4*y3 - 16*y1^3*y2^3 - 4*y1^3*y4 + 3*y1^2*y3^2 + 24*y1*y2^3*y3 + 4*y1*y3*y4 + 72*y2^6 + 24*y2^3*y4 - y3^3 + 8*y4^2)
Codomain:
=========
Multivariate Polynomial Ring in x[1], x[2], x[3] over Cyclotomic field of order 3 graded by
  x[1] -> [1]
  x[2] -> [1]
  x[3] -> [1])
```
"""
function affine_algebra(IR::InvRing; algo_gens::Symbol = :default, algo_rels::Symbol = :groebner_basis)
  if !isdefined(IR, :presentation)
    if algo_gens == :king && algo_rels == :linear_algebra
      error("Combination of arguments :$(algo_gens) for algo_gens and :$(algo_rels) for algo_rels not possible")
    end

    if algo_rels == :groebner_basis
      _, IR.presentation = relations_via_groebner_basis(IR, algo_gens)
    elseif algo_rels == :linear_algebra
      _, IR.presentation = relations_via_linear_algebra(IR)
    else
      error("Unsupported argument :$(algo_rels) for algo_rels")
    end
  end
  return domain(IR.presentation), IR.presentation
end

################################################################################
#
#  Relations
#
################################################################################

function relations_via_groebner_basis(RG::InvRing, algo_fundamental::Symbol = :default)
  R = polynomial_ring(RG)
  fund_invars = fundamental_invariants(RG, algo_fundamental)

  S = RG.fundamental.S
  StoR = hom(S, R, fund_invars)
  I = kernel(StoR)
  Q, StoQ = quo(S, I)
  QtoR = hom(Q, R, fund_invars)
  return Q, QtoR
end

function relations_via_linear_algebra(RG::InvRing)
  fund_invars = fundamental_invariants(RG, :primary_and_secondary)
  @assert RG.fundamental.via_primary_and_secondary "Cached fundamental invariants do not come from primary and secondary invariants"

  Q, QtoR = relations_primary_and_irreducible_secondary(RG)

  T = base_ring(Q)
  S = RG.fundamental.S

  TtoS = hom(T, S, [ RG.fundamental.toS[QtoR(gen(Q, i))] for i = 1:ngens(T) ])

  I = TtoS(modulus(Q))

  QS, StoQS = quo(S, I)
  QStoR = hom(QS, polynomial_ring(RG), fund_invars)
  return QS, QStoR
end

# Relations between primary and irreducible secondary invariants, see
# [KS99, Section 17.5.5] or [DK15, Section 3.8.3].
function relations_primary_and_irreducible_secondary(RG::InvRing)
  @assert !ismodular(RG)
  # TODO: In the modular case we need module syzygies w.r.t. the secondary invariants

  Rgraded = polynomial_ring(RG)
  R = forget_grading(Rgraded)
  K = coefficient_ring(R)

  p_invars = [ f.f for f in primary_invariants(RG) ]
  s_invars = [ f.f for f in secondary_invariants(RG) ]
  is_invars = [ f.f for f in irreducible_secondary_invariants(RG) ]
  s_invars_cache = RG.secondary

  np = length(p_invars)

  S, t = grade(polynomial_ring(K, "t" => 1:(np + length(is_invars)))[1], append!([ total_degree(f) for f in p_invars ], [ total_degree(f) for f in is_invars ]))

  if isempty(is_invars)
    I = ideal(S, elem_type(S)[])
    Q, StoQ = quo(S, I)
    QtoR = hom(Q, Rgraded, primary_invariants(RG))
    return Q, QtoR
  end

  RtoS = Vector{elem_type(S)}(undef, np + length(s_invars))
  for i = 1:np
    RtoS[i] = t[i]
  end
  for i = 1:length(s_invars)
    exps = append!(zeros(Int, np), s_invars_cache.sec_in_irred[i])
    g = set_exponent_vector!(one(S), 1, exps)
    RtoS[np + i] = g
  end

  # Build all products g*h of secondary invariants g and irreducible secondary
  # invariants h

  # Assumes that s_invars and is_invars are sorted by degree
  maxd = total_degree(s_invars[end]) + total_degree(is_invars[end])
  products_sorted = Vector{Vector{Tuple{elem_type(R), elem_type(S)}}}(undef, maxd)
  for d = 1:maxd
    products_sorted[d] = Vector{Tuple{elem_type(R), elem_type(S)}}()
  end
  for i = 1:length(s_invars)
    for j = 1:length(s_invars)
      if !s_invars_cache.is_irreducible[j]
        continue
      end
      if s_invars_cache.is_irreducible[i] && i > j
        continue
      end
      m = RtoS[np + i]*RtoS[np + j]
      if m in RtoS
        continue
      end
      f = s_invars[i]*s_invars[j]
      push!(products_sorted[total_degree(f)], (f, m))
    end
  end

  # Find relations of the form g*h - f_{g, h} where g*h is one of the products
  # above and f_{g, h} is in the module generated by the secondary invariants
  # over the algebra generated by the primary invariants

  rels = elem_type(S)[]
  C = PowerProductCache(R, p_invars)
  for d = 1:maxd
    if isempty(products_sorted[d])
      continue
    end

    gensd, expsd = generators_for_given_degree!(C, s_invars, d, true)

    monomial_to_column = enumerate_monomials(gensd)

    M = polys_to_smat(gensd, monomial_to_column, copy = false)

    N = polys_to_smat([ t[1] for t in products_sorted[d] ], monomial_to_column, copy = false)
    N.c = M.c

    # Write the products (in N) in the basis of K[V]^G_d given by the secondary
    # invariants (in M)
    fl, x = can_solve_with_solution(M, N, side = :left)
    @assert fl

    # Translate the relations to the free algebra S
    for i = 1:nrows(x)
      s = -products_sorted[d][i][2]
      for j = 1:length(x.rows[i])
        m = S(x.rows[i].values[j])
        e = expsd[gensd[x.rows[i].pos[j]]]
        for k = 1:np + length(s_invars)
          if iszero(e[k])
            continue
          end
          m *= RtoS[k]^e[k]
        end
        s += m
      end
      push!(rels, s)
    end
  end

  I = ideal(S, rels)
  Q, StoQ = quo(S, I)
  QtoR = hom(Q, Rgraded, append!(primary_invariants(RG), irreducible_secondary_invariants(RG)), check = false)

  return Q, QtoR
end
