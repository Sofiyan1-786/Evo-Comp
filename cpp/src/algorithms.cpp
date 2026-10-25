#include "tsp.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <compare>
#include <cstdint>
#include <numeric>
#include <ranges>
#include <stdexcept>
#include <utility>

namespace {

class PythonRandom {
public:
    explicit PythonRandom(std::vector<uint32_t> const& key) {
        init_by_array(key);
    }

    std::vector<size_t> sample(size_t n, size_t k) {
        if (k > n) {
            throw std::runtime_error("sample larger than population");
        }
        std::vector<size_t> result(k);
        size_t setsize = 21;
        if (k > 5) {
            double exponent = std::ceil(std::log(static_cast<double>(k) * 3) / std::log(4.0));
            setsize += static_cast<size_t>(std::pow(4.0, exponent));
        }
        if (n <= setsize) {
            std::vector<size_t> pool(n);
            std::iota(pool.begin(), pool.end(), 0);
            for (size_t i = 0; i < k; ++i) {
                size_t j = randbelow(n - i);
                result[i] = pool[j];
                pool[j] = pool[n - i - 1];
            }
        }
        else {
            std::vector<bool> selected(n);
            for (size_t i = 0; i < k; ++i) {
                size_t value = randbelow(n);
                while (selected[value]) {
                    value = randbelow(n);
                }
                selected[value] = true;
                result[i] = value;
            }
        }
        return result;
    }

private:
    static constexpr size_t N = 624;
    static constexpr size_t M = 397;
    static constexpr uint32_t UPPER_MASK = 0x80000000u;
    static constexpr uint32_t LOWER_MASK = 0x7fffffffu;

    std::array<uint32_t, N> state_ {};
    size_t index_ = N + 1;

    void init_genrand(uint32_t seed) {
        state_[0] = seed;
        for (size_t i = 1; i < N; ++i) {
            state_[i] = 1812433253u * (state_[i - 1] ^ (state_[i - 1] >> 30)) + i;
        }
        index_ = N;
    }

    void init_by_array(std::vector<uint32_t> const& key) {
        init_genrand(19650218u);
        size_t i = 1;
        size_t j = 0;
        for (size_t k = std::max(N, key.size()); k != 0; --k) {
            state_[i] = (state_[i] ^ ((state_[i - 1] ^ (state_[i - 1] >> 30)) * 1664525u)) + key[j] + j;
            ++i;
            ++j;
            if (i >= N) {
                state_[0] = state_[N - 1];
                i = 1;
            }
            if (j >= key.size()) {
                j = 0;
            }
        }
        for (size_t k = N - 1; k != 0; --k) {
            state_[i] = (state_[i] ^ ((state_[i - 1] ^ (state_[i - 1] >> 30)) * 1566083941u)) - i;
            ++i;
            if (i >= N) {
                state_[0] = state_[N - 1];
                i = 1;
            }
        }
        state_[0] = 0x80000000u;
        index_ = N;
    }

    void twist() {
        constexpr std::array<uint32_t, 2> mag01 { 0u, 0x9908b0dfu };
        size_t k = 0;
        for (; k < N - M; ++k) {
            uint32_t y = (state_[k] & UPPER_MASK) | (state_[k + 1] & LOWER_MASK);
            state_[k] = state_[k + M] ^ (y >> 1) ^ mag01[y & 1u];
        }
        for (; k < N - 1; ++k) {
            uint32_t y = (state_[k] & UPPER_MASK) | (state_[k + 1] & LOWER_MASK);
            state_[k] = state_[k + (M - N)] ^ (y >> 1) ^ mag01[y & 1u];
        }
        uint32_t y = (state_[N - 1] & UPPER_MASK) | (state_[0] & LOWER_MASK);
        state_[N - 1] = state_[M - 1] ^ (y >> 1) ^ mag01[y & 1u];
        index_ = 0;
    }

    uint32_t genrand_uint32() {
        if (index_ >= N) {
            twist();
        }
        uint32_t y = state_[index_++];
        y ^= y >> 11;
        y ^= (y << 7) & 0x9d2c5680u;
        y ^= (y << 15) & 0xefc60000u;
        y ^= y >> 18;
        return y;
    }

    uint32_t getrandbits(unsigned int bits) {
        return genrand_uint32() >> (32 - bits);
    }

    size_t randbelow(size_t n) {
        unsigned int bits = std::bit_width(n);
        uint32_t value = getrandbits(bits);
        while (value >= n) {
            value = getrandbits(bits);
        }
        return value;
    }
};

// Find the node with the lowest cost delta (node+edge cost) to `start_node`.
size_t find_best_second_node(size_t start_node, TspParams const& params, std::vector<bool> const& visited, float distance_weight) {
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t n = costs.size();
    auto candidates =
        // enumerate nodes 0..n-1
        std::views::iota(size_t { 0 }, n)
        // get only unvisited ones
        | std::views::filter([&](size_t node) { return !visited[node]; })
        // compute cost delta as D[start,node]*w + C[node]
        // w=1 - the nearest-neighbor version
        // w=2 - the greedy-cycle version (edge counted twice)
        | std::views::transform([&](size_t node) {
              return std::pair {
                  distance_matrix(start_node, node) * distance_weight + costs[node],
                  node,
              };
          });
    if (candidates.empty()) {
        return n;
    }
    return std::ranges::min(candidates).second;
}

struct Candidate {
    float delta;
    size_t node;
    size_t place;

    /// Sort by cost delta by default.
    auto operator<=>(Candidate const&) const = default;
};

/// Get indexes of unvisited nodes.
auto unvisited_nodes(size_t n, std::vector<bool> const& visited) {
    return
        // Enumerate nodes: 0,1,...,n-1
        std::views::iota(size_t { 0 }, n)
        // Return only unvisited nodes
        | std::views::filter([&visited](size_t node) { return !visited[node]; });
}

/// Get a list of all possible placements (using placement_fn), for every unvisited node.
/// Or in other words, enumerate all possible ways we can extend/modify
/// the tour (next node + its insertion point + delta cost)
template<typename PlacementFn>
auto get_all_placements(
    PlacementFn placement_fn, std::vector<size_t> const& tour, std::vector<bool> const& visited, TspParams const& params
) {
    return
        // Enumerate all nodes
        std::views::iota(size_t { 0 }, params.node_costs.size())
        // Only non-visited nodes
        | std::views::filter([&](size_t node) { return !visited[node]; })
        // Get possible placements for every node
        | std::views::transform([&, placement_fn](size_t node) { return placement_fn(node, tour, params); })
        // Turn these into a single range
        | std::views::join;
}

}

//////////
// LAB 1
//////////

namespace {

/// Get a list of indexes we can insert `note` in and their deltas.
auto nearest_neighbor_anywhere_placements(size_t node, std::vector<size_t> const& tour, TspParams const& params) {
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t positions = tour.size() + 1;
    return
        // Enumerate positions: 0,1,...,n-1
        std::views::iota(size_t { 0 }, positions)
        // Compute cost
        | std::views::transform([&, node, positions](size_t position) {
              float delta;
              // Push at start: D[t[0], n] + C[n]
              if (position == 0) {
                  delta = distance_matrix(node, tour.front()) + costs[node];
              }
              // Push at end: D[t[len(t)-1], n] + C[n]
              else if (position == positions - 1) {
                  delta = distance_matrix(tour.back(), node) + costs[node];
              }
              // Insert in the middle: D[n,t[i]] + D[n,t[i-1]] - D[t[i], t[i-1]] + C[n]
              else {
                  size_t i = position - 1;
                  delta = distance_matrix(node, tour[i]) + distance_matrix(node, tour[i + 1]) - distance_matrix(tour[i], tour[i + 1])
                      + costs[node];
              }
              return Candidate { delta, node, position };
          });
}

/// Get a list of indexes we can insert `note` in and their deltas.
auto greedy_cycle_placements(size_t node, std::vector<size_t> const& tour, TspParams const& params) {
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t edges = tour.size();
    return
        // Enumerate edges
        std::views::iota(size_t { 0 }, edges)
        // Compute delta as D[t'[e],n] + D[n,t'[e+1]] - D[t[e], t'[e+1]]
        // assuming t'[e] = t[e mod len(t)] (wrapping)
        | std::views::transform([&, node, edges](size_t edge) {
              size_t next = tour[(edge + 1) % edges];
              float delta
                  = distance_matrix(node, tour[edge]) + distance_matrix(node, next) - distance_matrix(tour[edge], next) + costs[node];
              return Candidate { delta, node, edge + 1 };
          });
}

}

TspResult nearest_neighbor_end(TspParams params) {
    size_t start_node = params.start_node;
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t n = costs.size();

    std::vector<size_t> tour;
    tour.reserve(params.target_count);
    std::vector<bool> visited(n);

    // Init with start-node
    tour.push_back(start_node);
    visited[start_node] = true;

    while (tour.size() < params.target_count) {
        size_t last_node = tour.back();
        // Find best node
        size_t best_node = find_best_second_node(last_node, params, visited, 1);
        tour.push_back(best_node);
        visited[best_node] = true;
    }

    float cost = objective(tour, distance_matrix, costs);
    return { std::move(tour), cost };
}

TspResult nearest_neighbor_solution_all_positions(TspParams params) {
    size_t start_node = params.start_node;
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t n = costs.size();

    std::vector<size_t> tour;
    tour.reserve(params.target_count);
    std::vector<bool> visited(n);
    tour.push_back(start_node);
    visited[start_node] = true;

    if (tour.size() < params.target_count) {
        size_t best_second_node = find_best_second_node(start_node, params, visited, 1);
        tour.push_back(best_second_node);
        visited[best_second_node] = true;
    }

    while (tour.size() < params.target_count) {
        Candidate best = std::ranges::min(get_all_placements(nearest_neighbor_anywhere_placements, tour, visited, params));
        tour.insert(tour.begin() + best.place, best.node);
        visited[best.node] = true;
    }

    float cost = objective(tour, distance_matrix, costs);
    return { std::move(tour), cost };
}

TspResult greedy_cycle(TspParams params) {
    size_t start_node = params.start_node;
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t n = costs.size();

    std::vector<size_t> tour;
    tour.reserve(params.target_count);
    std::vector<bool> visited(n);
    tour.push_back(start_node);
    visited[start_node] = true;

    if (tour.size() < params.target_count) {
        size_t best_second_node = find_best_second_node(start_node, params, visited, 2);
        tour.push_back(best_second_node);
        visited[best_second_node] = true;
    }

    while (tour.size() < params.target_count) {
        Candidate best = std::ranges::min(get_all_placements(greedy_cycle_placements, tour, visited, params));
        tour.insert(tour.begin() + best.place, best.node);
        visited[best.node] = true;
    }

    float cost = objective(tour, distance_matrix, costs);
    return { std::move(tour), cost };
}

//////////
// LAB 2
//////////

namespace {

/// Find best and next-to-best place to insert a node.
template<typename Range>
std::array<Candidate, 2> find_2_best_places_to_insert(Range placements) {
    std::array<Candidate, 2> best {};
    std::ranges::partial_sort_copy(placements, best);
    return best;
}

/// Parameters for the weighted 2-regret selection criterion.
struct TwoRegretParams {
    float second_node_weight = 1.0f;
    float regret_weight = 1.0f;
    float delta_weight = 1.0f;
};

/// Run a 2-regret greedy heuristic using placements.
/// Note that the "pure" 2-regret is a special-case of the "weighted
/// sum criterion" version but with cost delta weight == 0.
template<typename PlacementFn>
TspResult two_regret(TspParams params, TwoRegretParams heuristic, PlacementFn placements) {
    size_t start_node = params.start_node;
    SquareMatrix const& distance_matrix = params.distance_matrix;
    std::vector<float> const& costs = params.node_costs;
    size_t n = costs.size();

    std::vector<size_t> tour;
    tour.reserve(params.target_count);
    std::vector<bool> visited(n);
    tour.push_back(start_node);
    visited[start_node] = true;

    if (tour.size() < params.target_count) {
        size_t best_second_node = find_best_second_node(start_node, params, visited, heuristic.second_node_weight);
        tour.push_back(best_second_node);
        visited[best_second_node] = true;
    }

    struct TRCandidate {
        float score;
        size_t node;
        size_t place;
    };

    while (tour.size() < params.target_count) {
        auto scores = unvisited_nodes(n, visited)
            // Compute regrets, as differences between the 2nd best
            // and the best placement for every node.
            // Maximize regret, but minimize cost delta.
            | std::views::transform([&](size_t node) {
                          auto best = find_2_best_places_to_insert(placements(node, tour, params));
                          float regret = best[1].delta - best[0].delta;
                          float score = heuristic.regret_weight * regret - heuristic.delta_weight * best[0].delta;
                          return TRCandidate {
                              score,
                              node,
                              best[0].place,
                          };
                      });

        // Use the max weighted score.
        TRCandidate chosen = std::ranges::max(scores, {}, &TRCandidate::score);
        tour.insert(tour.begin() + chosen.place, chosen.node);
        visited[chosen.node] = true;
    }

    float cost = objective(tour, distance_matrix, costs);
    return { std::move(tour), cost };
}

}

TspResult two_regret_nearest_neighbor_anywhere(TspParams params) {
    return two_regret(
        params,
        TwoRegretParams {
            1.0f,
            1.0f,
            0.0f,
        },
        nearest_neighbor_anywhere_placements
    );
}

TspResult two_regret_greedy_cycle(TspParams params) {
    return two_regret(
        params,
        TwoRegretParams {
            2.0f,
            1.0f,
            0.0f,
        },
        greedy_cycle_placements
    );
}

TspResult two_regret_weighted_nearest_neighbor_anywhere(TspParams params) {
    return two_regret(
        params,
        TwoRegretParams {
            1.0f,
            1.0f,
            1.0f,
        },
        nearest_neighbor_anywhere_placements
    );
}

TspResult two_regret_weighted_greedy_cycle(TspParams params) {
    return two_regret(
        params,
        TwoRegretParams {
            2.0f,
            1.0f,
            1.0f,
        },
        greedy_cycle_placements
    );
}

TspResult random_solution_baseline(TspParams params) {
    static PythonRandom generator({ 123 });
    std::vector<size_t> tour = generator.sample(params.node_costs.size(), params.target_count);
    float cost = objective(tour, params.distance_matrix, params.node_costs);
    return { std::move(tour), cost };
}
