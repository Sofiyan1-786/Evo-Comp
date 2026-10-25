#include "tsp.hpp"

#include <cmath>
#include <sstream>
#include <stdexcept>
#include <string>

Instance load_instance(std::istream& input) {
    Instance instance;
    std::string line;
    while (std::getline(input, line)) {
        if (line.empty()) {
            continue;
        }
        std::istringstream row(line);
        std::string x, y, cost;
        if (!std::getline(row, x, ';') || !std::getline(row, y, ';') || !std::getline(row, cost, ';')) {
            throw std::runtime_error("malformed csv row: " + line);
        }
        instance.coordinates.push_back({ std::stof(x), std::stof(y) });
        instance.node_costs.push_back(std::stof(cost));
    }
    instance.distance_matrix = compute_distance_matrix(instance.coordinates);
    return instance;
}

SquareMatrix compute_distance_matrix(std::vector<std::array<float, 2>> const& coordinates) {
    size_t n = coordinates.size();
    SquareMatrix distance_matrix(n);
    for (size_t i = 0; i < n; ++i) {
        for (size_t j = i; j < n; ++j) {
            double dx = static_cast<double>(coordinates[i][0]) - coordinates[j][0];
            double dy = static_cast<double>(coordinates[i][1]) - coordinates[j][1];
            float distance = static_cast<float>(std::floor(std::sqrt(dx * dx + dy * dy) + 0.5));
            distance_matrix(i, j) = distance;
            distance_matrix(j, i) = distance;
        }
    }
    return distance_matrix;
}

float objective(std::vector<size_t> const& cycle, SquareMatrix const& distance_matrix, std::vector<float> const& costs) {
    if (cycle.empty()) {
        return 0;
    }
    float total = 0;
    for (size_t i = 0; i < cycle.size(); ++i) {
        total += distance_matrix(cycle[i], cycle[(i + 1) % cycle.size()]) + costs[cycle[i]];
    }
    return total;
}

float check_solution(
    std::vector<size_t> const& cycle, size_t n, size_t target_count, SquareMatrix const& distance_matrix, std::vector<float> const& costs
) {
    if (cycle.size() != target_count) {
        throw std::runtime_error("wrong number of nodes");
    }
    std::vector<bool> visited(n);
    for (size_t node : cycle) {
        if (node >= n) {
            throw std::runtime_error("index out of range");
        }
        if (visited[node]) {
            throw std::runtime_error("duplicate nodes");
        }
        visited[node] = true;
    }
    return objective(cycle, distance_matrix, costs);
}
