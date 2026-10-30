#include "tsp.hpp"
#include <algorithm>
#include <cstddef>
#include <numeric>
#include <random>
#include <vector>

namespace {

enum class IntraKind { TwoEdges, TwoNodes };
enum class MoveKind { Intra, Inter };

struct Move {
    MoveKind kind;
    size_t a;   // Intra: position i | Inter: position p
    size_t b;   // Intra: position j | Inter: unselected node v
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
float delta_exchange(std::vector<size_t> const& t, size_t p, size_t v,
                     SquareMatrix const& dm, std::vector<float> const& costs) {
    size_t m = t.size();
    size_t prev = (p + m - 1) % m;
    size_t next = (p + 1) % m;
    return dm(t[prev], v) + dm(v, t[next]) - dm(t[prev], t[p]) - dm(t[p], t[next])
        + costs[v] - costs[t[p]];
}

float move_delta(std::vector<size_t> const& t, Move move, IntraKind intra,
                 SquareMatrix const& dm, std::vector<float> const& costs) {
    if (move.kind == MoveKind::Intra) {
        return intra == IntraKind::TwoEdges ? delta_two_edges(t, move.a, move.b, dm)
                                            : delta_two_nodes(t, move.a, move.b, dm);
    }
    return delta_exchange(t, move.a, move.b, dm, costs);
}

void apply_move(std::vector<size_t>& t, Move move, IntraKind intra, std::vector<bool>& selected) {
    if (move.kind == MoveKind::Intra) {
        if (intra == IntraKind::TwoEdges) {
            // 2-opt
            std::reverse(t.begin() + move.a, t.begin() + move.b + 1);   
        } else {
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

TspResult local_search(TspParams params, bool steepest, IntraKind intra, bool random_start) {
    size_t n = params.node_costs.size();
    size_t m = params.target_count;
    SquareMatrix const& dm = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;

    // seed per attempt = 200 reproducible, distinct runs
    std::mt19937 rng(static_cast<unsigned>(params.start_node * 9973u + 7u));

    std::vector<size_t> tour = random_start
        ? random_tour(n, m, rng)
        : two_regret_r1_d2_greedy_cycle(params).tour;
    std::vector<bool> selected(n, false);
    for (size_t node : tour) {
        selected[node] = true;
    }

    if (steepest) {
        while (true) {
            Move best {};
            float best_delta = 0;                       
            // need strictly negative
            for (size_t i = 0; i + 1 < m; ++i) {
                for (size_t j = i + 1; j < m; ++j) {
                    if (intra == IntraKind::TwoEdges && skipped_two_edges(i, j, m)) continue;
                    Move move { MoveKind::Intra, i, j };
                    float delta = move_delta(tour, move, intra, dm, costs);
                    if (delta < best_delta) { best = move; best_delta = delta; }
                }
            }
            for (size_t p = 0; p < m; ++p) {
                for (size_t v = 0; v < n; ++v) {
                    if (selected[v]) continue;
                    Move move { MoveKind::Inter, p, v };
                    float delta = move_delta(tour, move, intra, dm, costs);
                    if (delta < best_delta) { best = move; best_delta = delta; }
                }
            }
            // local optimum
            if (best_delta >= 0) break;                 
            apply_move(tour, best, intra, selected);
        }
    } else {
        std::vector<Move> moves;
        moves.reserve(m * (m - 1) / 2 + m * (n - m));
        while (true) {
            // 1) enumerate move DESCRIPTORS only 
            //  no deltas evaluated here
            moves.clear();
            for (size_t i = 0; i + 1 < m; ++i) {
                for (size_t j = i + 1; j < m; ++j) {
                    if (intra == IntraKind::TwoEdges && skipped_two_edges(i, j, m)) continue;
                    moves.push_back({ MoveKind::Intra, i, j });
                }
            }
            for (size_t p = 0; p < m; ++p) {
                for (size_t v = 0; v < n; ++v) {
                    if (!selected[v]) moves.push_back({ MoveKind::Inter, p, v });
                }
            }
            // 2) Fisher-Yates shuffle of BOTH kinds together
            std::shuffle(moves.begin(), moves.end(), rng);
            // 3) evaluate in random order, stop at first improving move
            bool improved = false;
            for (Move const& move : moves) {
                if (move_delta(tour, move, intra, dm, costs) < 0) {
                    apply_move(tour, move, intra, selected);
                    improved = true;
                    break;
                }
            }
            if (!improved) break;
        }
    }

    float cost = objective(tour, dm, costs);   // compute BEFORE std::move
    return { std::move(tour), cost };
}

}

TspResult local_search_steepest_two_edges_random(TspParams params) {
    return local_search(params, true, IntraKind::TwoEdges, true);
}
TspResult local_search_steepest_two_nodes_random(TspParams params) {
    return local_search(params, true, IntraKind::TwoNodes, true);
}
TspResult local_search_steepest_two_edges_greedy(TspParams params) {
    return local_search(params, true, IntraKind::TwoEdges, false);
}
TspResult local_search_steepest_two_nodes_greedy(TspParams params) {
    return local_search(params, true, IntraKind::TwoNodes, false);
}
TspResult local_search_greedy_two_edges_random(TspParams params) {
    return local_search(params, false, IntraKind::TwoEdges, true);
}
TspResult local_search_greedy_two_nodes_random(TspParams params) {
    return local_search(params, false, IntraKind::TwoNodes, true);
}
TspResult local_search_greedy_two_edges_greedy(TspParams params) {
    return local_search(params, false, IntraKind::TwoEdges, false);
}
TspResult local_search_greedy_two_nodes_greedy(TspParams params) {
    return local_search(params, false, IntraKind::TwoNodes, false);
}