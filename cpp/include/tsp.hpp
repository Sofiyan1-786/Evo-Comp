#pragma once

#include <array>
#include <cstddef>
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

using TspFn = TspResult(TspParams);

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
