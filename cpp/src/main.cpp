#include "tsp.hpp"

#include <algorithm>
#include <chrono>
#include <exception>
#include <iomanip>
#include <iostream>
#include <ranges>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

int main(int argc, char** argv) {
    try {
        if (argc != 2) {
            std::cerr << "usage: tsp [algorithm]\n";
            return 2;
        }

        std::unordered_map<std::string, TspFn*> algorithms {
            { "random", &random_solution_baseline },
            { "nearest-neighbor-end", &nearest_neighbor_end },
            { "nearest-neighbor-anywhere", &nearest_neighbor_solution_all_positions },
            { "greedy-cycle", &greedy_cycle },
        };

        auto algorithm = algorithms.find(argv[1]);
        if (algorithm == algorithms.end()) {
            std::cerr << "unknown algorithm: " << argv[1] << '\n';
            return 2;
        }

        Instance instance = load_instance(std::cin);
        size_t n = instance.node_costs.size();
        if (n == 0) {
            throw std::runtime_error("empty instance");
        }

        // Run TSP
        size_t target_count = (n + 1) / 2;
        size_t attempts = std::string(argv[1]) == "random" ? 200 : n;
        TspParams params { instance.distance_matrix, instance.node_costs, target_count, 0 };
        std::vector<TspResult> results;
        results.reserve(attempts);
        auto started = std::chrono::steady_clock::now();
        for (size_t start_node = 0; start_node < attempts; ++start_node) {
            params.start_node = start_node;
            results.push_back(algorithm->second(params));
        }
        auto finished = std::chrono::steady_clock::now();
        double seconds = std::chrono::duration<double>(finished - started).count();

        // Sanity checks
        for (TspResult const& result : results) {
            float checked = check_solution(result.tour, n, target_count, instance.distance_matrix, instance.node_costs);
            if (checked != result.cost) {
                throw std::runtime_error("objective mismatch");
            }
        }
        float min_cost = std::ranges::min(
            results | std::views::transform([](TspResult const& result) { return result.cost; }));

        // Write out
        for (TspResult const& result : results) {
            for (size_t i = 0; i < result.tour.size(); ++i) {
                if (i != 0) {
                    std::cout << ',';
                }
                std::cout << result.tour[i];
            }
            std::cout << '\n';
        }
        std::cerr << "cost: " << static_cast<long long>(min_cost) << ", time: " << std::fixed << std::setprecision(3) << seconds
                  << " s\n";
        return 0;
    } catch (std::exception const& error) {
        std::cerr << "error: " << error.what() << '\n';
        return 1;
    }
}
