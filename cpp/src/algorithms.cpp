#include "tsp.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
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
    auto candidates = std::views::iota(size_t { 0 }, n) | std::views::filter([&](size_t node) { return !visited[node]; })
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
        size_t positions = tour.size() + 1;
        auto candidates =
            // Count n*positions. This will go like this: node0pos0, ..., node0posP-1; ...; nodeN-1pos0, ... nodeN-1posP-1
            std::views::iota(size_t { 0 }, n * positions)
            // Only non-visited nodes
            | std::views::filter([&](size_t index) { return !visited[index / positions]; })
            // Compute costs
            | std::views::transform([&](size_t index) {
                  size_t node = index / positions;
                  size_t position = index % positions;
                  float delta;
                  if (position == 0) {
                      delta = distance_matrix(node, tour.front()) + costs[node];
                  }
                  else if (position == tour.size()) {
                      delta = distance_matrix(tour.back(), node) + costs[node];
                  }
                  else {
                      size_t i = position - 1;
                      delta = distance_matrix(node, tour[i]) + distance_matrix(node, tour[i + 1]) - distance_matrix(tour[i], tour[i + 1])
                          + costs[node];
                  }
                  return std::pair { delta, index };
              });
        size_t best_index = std::ranges::min(candidates).second;
        size_t best_node = best_index / positions;
        size_t best_position = best_index % positions;
        tour.insert(tour.begin() + best_position, best_node);
        visited[best_node] = true;
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
        size_t edges = tour.size();
        auto candidates
            // Count n*edges (node0edge0,...nodeN-1edgeE-1)
            = std::views::iota(size_t { 0 }, n * edges)
            // Only non-visited ones
            | std::views::filter([&](size_t index) { return !visited[index / edges]; })
            // Compute deltas
            | std::views::transform([&](size_t index) {
                  size_t node = index / edges;
                  size_t i = index % edges;
                  size_t next = tour[(i + 1) % edges];
                  float delta = distance_matrix(node, tour[i]) + distance_matrix(node, next) - distance_matrix(tour[i], next) + costs[node];
                  return std::pair { delta, index };
              });
        size_t best_index = std::ranges::min(candidates).second;
        size_t best_node = best_index / edges;
        size_t best_edge = best_index % edges;
        tour.insert(tour.begin() + best_edge + 1, best_node);
        visited[best_node] = true;
    }

    float cost = objective(tour, distance_matrix, costs);
    return { std::move(tour), cost };
}

TspResult random_solution_baseline(TspParams params) {
    static PythonRandom generator({ 123 });
    std::vector<size_t> tour = generator.sample(params.node_costs.size(), params.target_count);
    float cost = objective(tour, params.distance_matrix, params.node_costs);
    return { std::move(tour), cost };
}
