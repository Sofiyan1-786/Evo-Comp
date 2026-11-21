#pragma once

#include <array>
#include <cstddef>
#include <functional>
#include <istream>
#include <vector>

struct SquareMatrix {
    SquareMatrix() = default;
    explicit SquareMatrix(size_t size) : size_(size), cells_(size * size) {}

    size_t size() const { return size_; }
    float const& operator()(size_t row, size_t col) const { return cells_[row * size_ + col]; }
    float& operator()(size_t row, size_t col) { return cells_[row * size_ + col]; }

private:
    size_t size_ = 0;
    std::vector<float> cells_;
};

struct TspParams {
    SquareMatrix const& distance_matrix;
    std::vector<float> node_costs;
    size_t target_count = 0;
    size_t start_node = 0;
};

struct TspResult {
    std::vector<size_t> tour;
    float cost;
};

using TspFn = std::function<TspResult(TspParams)>;

// lab#4: the intra-route move type, and the keys a candidate ranking can use
// (node = node cost, edge = edge length, delta = edge length + node cost)
enum class IntraKind { TwoEdges, TwoNodes };
enum class CandidateKey { NodeCost, EdgeCost, NodeEdgeCost };

struct Instance {
    std::vector<std::array<float, 2>> coordinates;
    std::vector<float> node_costs;
    SquareMatrix distance_matrix;
};

Instance load_instance(std::istream& input);
SquareMatrix compute_distance_matrix(std::vector<std::array<float, 2>> const& coordinates);
float objective(std::vector<size_t> const& cycle, SquareMatrix const& distance_matrix,
                std::vector<float> const& costs);
float check_solution(std::vector<size_t> const& cycle, size_t n, size_t target_count,
                     SquareMatrix const& distance_matrix, std::vector<float> const& costs);

TspResult random_solution_baseline(TspParams params);
TspResult nearest_neighbor_end(TspParams params);
TspResult nearest_neighbor_solution_all_positions(TspParams params);
TspResult greedy_cycle(TspParams params);
TspResult two_regret_r1_d1_nearest_neighbor_anywhere(TspParams params);
TspResult two_regret_r1_d1_greedy_cycle(TspParams params);
TspResult two_regret_r1_d0_nearest_neighbor_anywhere(TspParams params);
TspResult two_regret_r1_d0_greedy_cycle(TspParams params);
TspResult two_regret_r2_d1_nearest_neighbor_anywhere(TspParams params);
TspResult two_regret_r2_d1_greedy_cycle(TspParams params);
TspResult two_regret_r1_d2_nearest_neighbor_anywhere(TspParams params);
TspResult two_regret_r1_d2_greedy_cycle(TspParams params);
TspResult local_search_steepest_two_edges_random(TspParams params);
TspResult local_search_steepest_two_nodes_random(TspParams params);
TspResult local_search_steepest_two_edges_greedy(TspParams params);
TspResult local_search_steepest_two_nodes_greedy(TspParams params);
TspResult local_search_greedy_two_edges_random(TspParams params);
TspResult local_search_greedy_two_nodes_random(TspParams params);
TspResult local_search_greedy_two_edges_greedy(TspParams params);
TspResult local_search_greedy_two_nodes_greedy(TspParams params);
TspResult local_search_steepest_candidates(TspParams params, IntraKind intra, CandidateKey intra_key,
                                           CandidateKey inter_key);
// lab#5 LM sEarch
TspResult local_search_steepest_two_edges_random_lm(TspParams params);
