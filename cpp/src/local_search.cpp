#include "tsp.hpp"
#include <algorithm>
#include <cstddef>
#include <numeric>
#include <random>
#include <vector>
#include <ranges>

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
        // Two small O(n) index vectors (100 and 200 elements) instead of 14,950 moves
        std::vector<size_t> tour_idx(m);
        std::iota(tour_idx.begin(), tour_idx.end(), 0);
        std::vector<size_t> node_idx(n);
        std::iota(node_idx.begin(), node_idx.end(), 0);

        // Lazy generator for unselected nodes in randomized order (sppmacd's exact pattern)
        auto unvisited_nodes = [&]() {
            return node_idx | std::views::filter([&selected](size_t v) { return !selected[v]; });
        };

        while (true) {
            std::shuffle(tour_idx.begin(), tour_idx.end(), rng);
            std::shuffle(node_idx.begin(), node_idx.end(), rng);
            bool improved = false;

            for (size_t idx_a = 0; idx_a < m && !improved; ++idx_a) {
                size_t i = tour_idx[idx_a];
                bool intra_first = (rng() & 1u) != 0;

                // Lazy generator for intra-route moves paired with position i
                auto intra_moves = std::views::iota(idx_a + 1, m)
                    | std::views::transform([&](size_t idx_b) {
                          size_t u = i, w = tour_idx[idx_b];
                          if (u > w) std::swap(u, w);
                          return Move { MoveKind::Intra, u, w };
                      })
                    | std::views::filter([&](Move mv) {
                          return !(intra == IntraKind::TwoEdges && skipped_two_edges(mv.a, mv.b, m));
                      });

                // Lazy generator for inter-route moves at position i
                auto inter_moves = unvisited_nodes()
                    | std::views::transform([i](size_t v) {
                          return Move { MoveKind::Inter, i, v };
                      });

                for (int pass = 0; pass < 2 && !improved; ++pass) {
                    if ((pass == 0) == intra_first) {
                        for (Move move : intra_moves) {
                            if (move_delta(tour, move, intra, dm, costs) < 0) {
                                apply_move(tour, move, intra, selected);
                                improved = true;
                                break;
                            }
                        }
                    } else {
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
