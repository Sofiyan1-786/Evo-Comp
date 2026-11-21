#include "tsp.hpp"
#include <algorithm>
#include <cstddef>
#include <numeric>
#include <random>
#include <ranges>
#include <span>
#include <vector>

namespace {

enum class MoveKind { Intra, Inter };
enum class CandidatesKind { All, Lab4 };

// max_n from the lab#4 candidate list: number of nearest nodes per node
size_t constexpr kMaxCandidates = 10;

struct Move {
    MoveKind kind;
    size_t a; // Intra: position i | Inter: position p
    size_t b; // Intra: position j | Inter: unselected node v
};

std::vector<size_t> random_tour(size_t n, size_t k, std::mt19937& rng) {
    std::vector<size_t> pool(n);
    std::iota(pool.begin(), pool.end(), 0);
    std::shuffle(pool.begin(), pool.end(), rng);
    pool.resize(k);
    return pool;
}

// delta = sum (new - old) over the cycle edges incident to positions i and j
float delta_two_edges(std::vector<size_t> const& t, size_t i, size_t j, SquareMatrix const& dm) {
    size_t m = t.size();
    size_t prev = (i + m - 1) % m;
    size_t next = (j + 1) % m;
    return dm(t[prev], t[j]) + dm(t[i], t[next]) - dm(t[prev], t[i]) - dm(t[j], t[next]);
}

// sum (new - old) over the cycle edges incident to position i or j
float delta_two_nodes(std::vector<size_t> const& t, size_t i, size_t j, SquareMatrix const& dm) {
    size_t m = t.size();
    size_t edges[4] = { (i + m - 1) % m, i, (j + m - 1) % m, j };
    float delta = 0;
    for (size_t e = 0; e < 4; ++e) {
        bool duplicate = false;
        for (size_t f = 0; f < e; ++f) {
            duplicate = duplicate || edges[f] == edges[e];
        }
        if (duplicate) {
            continue;
        }
        size_t k = edges[e];
        size_t next = (k + 1) % m;
        size_t u_old = t[k], v_old = t[next];
        size_t u_new = (k == i) ? t[j] : (k == j) ? t[i] : u_old;
        size_t v_new = (next == i) ? t[j] : (next == j) ? t[i] : v_old;
        delta += dm(u_new, v_new) - dm(u_old, v_old);
    }
    return delta;
}

// delta = edge change at position p + node cost change C[v] - C[t[p]]
float delta_exchange(std::vector<size_t> const& t, size_t p, size_t v, SquareMatrix const& dm, std::vector<float> const& costs) {
    size_t m = t.size();
    size_t prev = (p + m - 1) % m;
    size_t next = (p + 1) % m;
    return dm(t[prev], v) + dm(v, t[next]) - dm(t[prev], t[p]) - dm(t[p], t[next]) + costs[v] - costs[t[p]];
}

float move_delta(std::vector<size_t> const& t, Move move, IntraKind intra, SquareMatrix const& dm, std::vector<float> const& costs) {
    if (move.kind == MoveKind::Intra) {
        return intra == IntraKind::TwoEdges ? delta_two_edges(t, move.a, move.b, dm) : delta_two_nodes(t, move.a, move.b, dm);
    }
    return delta_exchange(t, move.a, move.b, dm, costs);
}

template<class T>
std::vector<T> to_vector(std::ranges::input_range auto r) {
    std::vector<T> v;
    for (auto n : r) {
        v.push_back(std::move(n));
    }
    return v;
}

void apply_move(std::vector<size_t>& t, Move move, IntraKind intra, std::vector<bool>& selected) {
    if (move.kind == MoveKind::Intra) {
        if (intra == IntraKind::TwoEdges) {
            // 2-opt
            std::reverse(t.begin() + move.a, t.begin() + move.b + 1);
        }
        else {
            // swap
            std::swap(t[move.a], t[move.b]);
        }
        return;
    }
    selected[t[move.a]] = false;
    // inter: node exchange
    t[move.a] = move.b;
    selected[move.b] = true;
}

bool skipped_two_edges(size_t i, size_t j, size_t m) {
    // reversing the whole cycle is the same cycle (delta formula would double-count)
    return i == 0 && j + 1 == m;
}

// ============================== lab#4: candidate rankings ==============================
// A ranking lists the other nodes for one move class, best first, under that
// class's key ("nearest" = node | edge | delta). It depends on the instance
// only, so build_ranking runs once per attempt -- never on the tour.
//
//   key          shape
//   node cost    one row of all n nodes, shared by every u (the key has no u in it)
//   edge keys    n rows of k: the k nearest nodes of each u
//
// Eligibility (in / out of the tour) changes while the search runs, so it is
// applied when candidates are read: top_k_eligible keeps the first
// kMaxCandidates eligible nodes of a ranking.

// how far is v from u under a key: the three readings of "nearest"
float key_distance(CandidateKey key, size_t u, size_t v, SquareMatrix const& dm, std::vector<float> const& costs) {
    if (key == CandidateKey::NodeCost) {
        return costs[v]; // no edge involved
    }
    if (key == CandidateKey::EdgeCost) {
        return dm(u, v);
    }
    return dm(u, v) + costs[v]; // the cost terms of the standard move delta
}

struct CandidateRanking {
    std::vector<size_t> rows;
    size_t row_len = 0;
    bool per_node = false;

    // nodes nearest to u, best first; a shared row answers every u alike
    std::span<size_t const> operator[](size_t u) const {
        return { rows.data() + (per_node ? u : 0) * row_len, row_len };
    }
};

// lookup table for one move class: instance only, built once per attempt
CandidateRanking build_ranking(size_t n, size_t k, CandidateKey key, SquareMatrix const& dm,
                               std::vector<float> const& costs) {
    if (key == CandidateKey::NodeCost) {
        // the key ignores u -> a single ranking shared by every node
        std::vector<size_t> order(n);
        std::iota(order.begin(), order.end(), 0);
        std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return costs[a] < costs[b]; });
        return { std::move(order), n, false };
    }
    // the key depends on u -> k nearest nodes per node
    size_t row_len = std::min(k, n - 1);
    CandidateRanking ranking { std::vector<size_t>(n * row_len), row_len, true };
    std::vector<std::pair<float, size_t>> row;
    row.reserve(n);
    for (size_t u = 0; u < n; ++u) {
        row.clear();
        for (size_t v = 0; v < n; ++v) {
            if (v != u) {
                row.emplace_back(key_distance(key, u, v, dm, costs), v);
            }
        }
        std::partial_sort(row.begin(), row.begin() + row_len, row.end());
        for (size_t r = 0; r < row_len; ++r) {
            ranking.rows[u * row_len + r] = row[r].second;
        }
    }
    return ranking;
}

// the first kMaxCandidates eligible nodes of a ranking, best first
template <class Eligible>
auto top_k_eligible(std::span<size_t const> ranking, Eligible const& eligible) {
    return ranking | std::views::filter(eligible) | std::views::take(kMaxCandidates);
}

struct LocalSearchSteepestParams {
    IntraKind intra;
    bool random_start;
    CandidatesKind candidates;
    // lab#4: the key each move class ranks candidates by (ignored for All)
    CandidateKey intra_key = CandidateKey::EdgeCost;
    CandidateKey inter_key = CandidateKey::NodeCost;
};

TspResult local_search_steepest(TspParams params, LocalSearchSteepestParams const& ls_params) {
    size_t n = params.node_costs.size();
    size_t m = params.target_count;
    SquareMatrix const& dm = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;

    // seed per attempt = 200 reproducible, distinct runs
    std::mt19937 rng(static_cast<unsigned>(params.start_node * 9973u + 7u));

    std::vector<size_t> tour = ls_params.random_start ? random_tour(n, m, rng) : two_regret_r1_d2_greedy_cycle(params).tour;
    std::vector<bool> selected(n, false);
    for (size_t node : tour) {
        selected[node] = true;
    }

    // lab#4: one candidate ranking per move class, built once per attempt
    CandidateRanking intra_candidates;
    CandidateRanking inter_candidates;
    std::vector<size_t> pos;
    if (ls_params.candidates == CandidatesKind::Lab4) {
        intra_candidates = build_ranking(n, kMaxCandidates, ls_params.intra_key, dm, costs);
        inter_candidates = build_ranking(n, kMaxCandidates, ls_params.inter_key, dm, costs);
        pos.assign(n, n);
    }

    while (true) {
        Move best {};
        float best_delta = 0;

        switch (ls_params.candidates) {
        case CandidatesKind::All: {
            // need strictly negative
            for (size_t i = 0; i + 1 < m; ++i) {
                for (size_t j = i + 1; j < m; ++j) {
                    if (ls_params.intra == IntraKind::TwoEdges && skipped_two_edges(i, j, m))
                        continue;
                    Move move { MoveKind::Intra, i, j };
                    float delta = move_delta(tour, move, ls_params.intra, dm, costs);
                    if (delta < best_delta) {
                        best = move;
                        best_delta = delta;
                    }
                }
            }
            for (size_t p = 0; p < m; ++p) {
                for (size_t v = 0; v < n; ++v) {
                    if (selected[v])
                        continue;
                    Move move { MoveKind::Inter, p, v };
                    float delta = move_delta(tour, move, ls_params.intra, dm, costs);
                    if (delta < best_delta) {
                        best = move;
                        best_delta = delta;
                    }
                }
            }
        } break;
        case CandidatesKind::Lab4: {
            auto consider = [&](Move move) {
                float delta = move_delta(tour, move, ls_params.intra, dm, costs);
                if (delta < best_delta) {
                    best = move;
                    best_delta = delta;
                }
            };
            auto in_tour = [&](size_t v) { return selected[v]; };
            auto outside = [&](size_t v) { return !selected[v]; };

            // Iterate over candidate edges to find best delta:

            // pos(u) := position of node u within the tour, or n if not selected
            std::fill(pos.begin(), pos.end(), n);
            for (size_t i = 0; i < m; ++i) {
                pos[tour[i]] = i;
            }

            // Intra-moves
            // for every node u in the tour:
            for (size_t i = 0; i < m; ++i) {
                size_t u = tour[i];
                //   for every node j in top K nodes nearest to u (intra-cost),
                //   that is in the tour:
                for (size_t j : top_k_eligible(intra_candidates[u], in_tour)) {
                    //     p := pos(j)
                    size_t p = pos[j];

                    //     let's say we have 0,1,2,3,4 and the candidate edge (i, p) is (2,4)
                    if (ls_params.intra == IntraKind::TwoEdges) {
                        //       lo, hi := min(i, p), max(i, p)
                        size_t lo = std::min(i, p);
                        size_t hi = std::max(i, p);
                        //       reverse a segment that always skips the node on one side,
                        //       so that the candidate edge appears in the tour; needs at
                        //       least one node strictly between i and p, otherwise both
                        //       moves are no-ops
                        if (lo + 1 < hi) {
                            //         0,1,2,(3,4) --> 0,1,[2,4],3
                            consider({ MoveKind::Intra, lo + 1, hi });
                            //         0,1,(2,3),4 --> 0,1,3,[2,4]
                            consider({ MoveKind::Intra, lo, hi - 1 });
                        }
                    }
                    else {
                        //       try exchanging p with a node ADJACENT TO i, which creates
                        //       an edge between p and i
                        size_t prev = (i + m - 1) % m;
                        size_t next = (i + 1) % m;
                        if (prev != p) {
                            //         0,(1),2,3,(4) --> 0,[4,2],3,1
                            //         note that this inverts the edge which preserves
                            //         the costs only for symmetric distance matrices
                            //         (this is a problem for all this move stuff though, probably)
                            consider({ MoveKind::Intra, std::min(prev, p), std::max(prev, p) });
                        }
                        if (next != p) {
                            //         0,1,2,(3),(4) --> 0,1,[2,4],3
                            consider({ MoveKind::Intra, std::min(next, p), std::max(next, p) });
                        }
                    }
                }
            }

            // Inter-moves
            // for every node u in the tour:
            for (size_t i = 0; i < m; ++i) {
                size_t u = tour[i];
                //   for every node v in top K unselected nodes with lowest inter-cost
                //   (the ranking is built once per attempt, the unselected filter is not:
                //   selected changes with every accepted move)
                for (size_t v : top_k_eligible(inter_candidates[u], outside)) {
                    //     try replacing the node at position i - 1 or i + 1 with v so that
                    //     (u, v) becomes an edge in the tour
                    consider({ MoveKind::Inter, (i + m - 1) % m, v });
                    consider({ MoveKind::Inter, (i + 1) % m, v });
                }
            }
        } break;
        }

        // local optimum
        if (best_delta >= 0)
            break;
        apply_move(tour, best, ls_params.intra, selected);
    }

    float cost = objective(tour, dm, costs); // compute BEFORE std::move
    return { std::move(tour), cost };
}

TspResult local_search_greedy(TspParams params, IntraKind intra, bool random_start) {
    size_t n = params.node_costs.size();
    size_t m = params.target_count;
    SquareMatrix const& dm = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;

    // seed per attempt = 200 reproducible, distinct runs
    std::mt19937 rng(static_cast<unsigned>(params.start_node * 9973u + 7u));

    std::vector<size_t> tour = random_start ? random_tour(n, m, rng) : two_regret_r1_d2_greedy_cycle(params).tour;
    std::vector<bool> selected(n, false);
    for (size_t node : tour) {
        selected[node] = true;
    }

    // Two small O(n) index vectors (100 and 200 elements) instead of 14,950 moves
    std::vector<size_t> tour_idx(m);
    std::iota(tour_idx.begin(), tour_idx.end(), 0);
    std::vector<size_t> node_idx(n);
    std::iota(node_idx.begin(), node_idx.end(), 0);

    // Lazy generator for unselected nodes in randomized order (sppmacd's exact pattern)
    auto unvisited_nodes = [&]() { return node_idx | std::views::filter([&selected](size_t v) { return !selected[v]; }); };

    while (true) {
        std::shuffle(tour_idx.begin(), tour_idx.end(), rng);
        std::shuffle(node_idx.begin(), node_idx.end(), rng);
        bool improved = false;

        for (size_t idx_a = 0; idx_a < m && !improved; ++idx_a) {
            size_t i = tour_idx[idx_a];
            bool intra_first = (rng() & 1u) != 0;

            // Lazy generator for intra-route moves paired with position i
            auto intra_moves = std::views::iota(idx_a + 1, m) | std::views::transform([&](size_t idx_b) {
                                   size_t u = i, w = tour_idx[idx_b];
                                   if (u > w)
                                       std::swap(u, w);
                                   return Move { MoveKind::Intra, u, w };
                               })
                | std::views::filter([&](Move mv) { return !(intra == IntraKind::TwoEdges && skipped_two_edges(mv.a, mv.b, m)); });

            // Lazy generator for inter-route moves at position i
            auto inter_moves = unvisited_nodes() | std::views::transform([i](size_t v) { return Move { MoveKind::Inter, i, v }; });

            for (int pass = 0; pass < 2 && !improved; ++pass) {
                if ((pass == 0) == intra_first) {
                    for (Move move : intra_moves) {
                        if (move_delta(tour, move, intra, dm, costs) < 0) {
                            apply_move(tour, move, intra, selected);
                            improved = true;
                            break;
                        }
                    }
                }
                else {
                    for (Move move : inter_moves) {
                        if (move_delta(tour, move, intra, dm, costs) < 0) {
                            apply_move(tour, move, intra, selected);
                            improved = true;
                            break;
                        }
                    }
                }
            }
        }
        if (!improved)
            break;
    }

    float cost = objective(tour, dm, costs); // compute BEFORE std::move
    return { std::move(tour), cost };
}

struct LmMove {
    MoveKind kind;
    float delta;
    // Intra (2-opt): removed directed edges e1 = (a, b) and e2 = (c, d)
    // Inter (swap):  selected node u = a, unselected node v = b, saved neighbors c = u_prev, d = u_next
    size_t a, b, c, d;
    bool active = true;
};

TspResult local_search_steepest_lm(TspParams params) {
    size_t n = params.node_costs.size();
    size_t m = params.target_count;
    SquareMatrix const& dm = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;

    // Exact same RNG seed as ls-steepest-two-edges-random for identical 200 starting tours
    std::mt19937 rng(static_cast<unsigned>(params.start_node * 9973u + 7u));
    std::vector<size_t> tour = random_tour(n, m, rng);

    // O(1) lookup tables
    std::vector<uint8_t> selected(n, 0);
    std::vector<size_t> pos(n, n);
    std::vector<size_t> next_node(n, n);
    std::vector<size_t> prev_node(n, n);

    for (size_t u : tour) {
        selected[u] = 1;
    }

    auto sync_tour = [&]() {
        for (size_t i = 0; i < m; ++i) {
            size_t u = tour[i];
            pos[u] = i;
            next_node[u] = tour[(i + 1) % m];
            prev_node[u] = tour[(i + m - 1) % m];
        }
    };
    sync_tour();

    std::vector<LmMove> lm;
    lm.reserve(m * (m - 1) + m * (n - m));

    // Full neighborhood evaluation (batch refill), including inverted-edge 2-opt moves
    auto refill_lm = [&]() {
        lm.clear();
        bool has_valid_move = false;

        // 1. Intra-route 2-opt moves (both standard and inverted relative directions)
        for (size_t i = 0; i + 1 < m; ++i) {
            size_t a = tour[i];
            size_t b = tour[(i + 1) % m];
            for (size_t j = i + 2; j < m; ++j) {
                if (i == 0 && j + 1 == m) {
                    continue; // adjacent edges sharing tour[0]
                }
                size_t c = tour[j];
                size_t d = tour[(j + 1) % m];
                float removed = dm(a, b) + dm(c, d);

                // Standard valid 2-opt: reconnect (a, c) and (b, d)
                float delta1 = dm(a, c) + dm(b, d) - removed;
                if (delta1 < 0) {
                    lm.push_back({ MoveKind::Intra, delta1, a, b, c, d, true });
                    has_valid_move = true;
                }

                // Inverted-edge 2-opt: reconnect (a, d) and (b, c), stored with e2 = (d, c)
                float delta2 = dm(a, d) + dm(b, c) - removed;
                if (delta2 < 0) {
                    lm.push_back({ MoveKind::Intra, delta2, a, b, d, c, true });
                }
            }
        }

        // 2. Inter-route node exchange moves (selected u <-> unselected v)
        for (size_t p = 0; p < m; ++p) {
            size_t u = tour[p];
            size_t u_prev = prev_node[u];
            size_t u_next = next_node[u];
            float removed = dm(u_prev, u) + dm(u, u_next) + costs[u];
            for (size_t v = 0; v < n; ++v) {
                if (selected[v]) {
                    continue;
                }
                float delta = dm(u_prev, v) + dm(v, u_next) + costs[v] - removed;
                if (delta < 0) {
                    lm.push_back({ MoveKind::Inter, delta, u, v, u_prev, u_next, true });
                    has_valid_move = true;
                }
            }
        }

        if (!has_valid_move) {
            lm.clear();
            return;
        }

        std::sort(lm.begin(), lm.end(), [](LmMove const& x, LmMove const& y) {
            return x.delta < y.delta;
        });
    };

    // Initial full evaluation
    refill_lm();

    while (!lm.empty()) {
        bool applied = false;

        for (LmMove& mv : lm) {
            if (!mv.active) {
                continue;
            }

            if (mv.kind == MoveKind::Intra) {
                size_t a = mv.a, b = mv.b, c = mv.c, d = mv.d;
                bool e1_fwd = selected[a] && (next_node[a] == b);
                bool e1_rev = selected[a] && (prev_node[a] == b);
                bool e2_fwd = selected[c] && (next_node[c] == d);
                bool e2_rev = selected[c] && (prev_node[c] == d);

                // Case 1 (Broken): at least one edge no longer exists -> remove from LM
                if ((!e1_fwd && !e1_rev) || (!e2_fwd && !e2_rev)) {
                    mv.active = false;
                    continue;
                }

                // Case 2 (Inverted relative direction): keep in LM, skip for now
                if ((e1_fwd && e2_rev) || (e1_rev && e2_fwd)) {
                    continue;
                }

                // Case 3 (Same relative direction: both forward or both reversed): apply 2-opt
                size_t idx1 = e1_fwd ? pos[a] : pos[b];
                size_t idx2 = e2_fwd ? pos[c] : pos[d];
                size_t lo = std::min(idx1, idx2);
                size_t hi = std::max(idx1, idx2);
                std::reverse(tour.begin() + lo + 1, tour.begin() + hi + 1);
                sync_tour();

                mv.active = false;
                applied = true;
                break; // restart scan from the very top of LM
            } else {
                size_t u = mv.a, v = mv.b, u_prev = mv.c, u_next = mv.d;
                bool valid = selected[u] && !selected[v]
                    && ((prev_node[u] == u_prev && next_node[u] == u_next)
                        || (prev_node[u] == u_next && next_node[u] == u_prev));

                if (!valid) {
                    mv.active = false;
                    continue;
                }

                // Apply inter-route node swap
                size_t p = pos[u];
                selected[u] = 0;
                pos[u] = n;
                next_node[u] = n;
                prev_node[u] = n;

                tour[p] = v;
                selected[v] = 1;
                sync_tour();

                mv.active = false;
                applied = true;
                break; // restart scan from the very top of LM
            }
        }

        // Batch refill condition: full pass through LM found 0 applicable moves
        if (!applied) {
            refill_lm();
            // If refill_lm() added 0 improving moves, lm.empty() is true and the while loop terminates
        }
    }

    float cost = objective(tour, dm, costs);
    return { std::move(tour), cost };
}


}

TspResult local_search_steepest_two_edges_random(TspParams params) {
    return local_search_steepest(params, { .intra = IntraKind::TwoEdges, .random_start = true, .candidates = CandidatesKind::All });
}
TspResult local_search_steepest_two_nodes_random(TspParams params) {
    return local_search_steepest(params, { .intra = IntraKind::TwoNodes, .random_start = true, .candidates = CandidatesKind::All });
}
TspResult local_search_steepest_two_edges_greedy(TspParams params) {
    return local_search_steepest(params, { .intra = IntraKind::TwoEdges, .random_start = false, .candidates = CandidatesKind::All });
}
TspResult local_search_steepest_two_nodes_greedy(TspParams params) {
    return local_search_steepest(params, { .intra = IntraKind::TwoNodes, .random_start = false, .candidates = CandidatesKind::All });
}
TspResult local_search_greedy_two_edges_random(TspParams params) {
    return local_search_greedy(params, IntraKind::TwoEdges, true);
}
TspResult local_search_greedy_two_nodes_random(TspParams params) {
    return local_search_greedy(params, IntraKind::TwoNodes, true);
}
TspResult local_search_greedy_two_edges_greedy(TspParams params) {
    return local_search_greedy(params, IntraKind::TwoEdges, false);
}
TspResult local_search_greedy_two_nodes_greedy(TspParams params) {
    return local_search_greedy(params, IntraKind::TwoNodes, false);
}

// Lab 4: ls-steepest-<two-edges|two-nodes>-random-candidates-intra-<node|edge|delta>-inter-<node|edge|delta>
TspResult local_search_steepest_candidates(TspParams params, IntraKind intra, CandidateKey intra_key,
                                           CandidateKey inter_key) {
    return local_search_steepest(params, {
        .intra = intra,
        .random_start = true,
        .candidates = CandidatesKind::Lab4,
        .intra_key = intra_key,
        .inter_key = inter_key,
    });
}

// Lab 5: ls-steepest-two-edges-random-lm
TspResult local_search_steepest_two_edges_random_lm(TspParams params)   {
    return local_search_steepest_lm(params);
}
