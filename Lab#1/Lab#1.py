import random
import math
import numpy as np
import matplotlib.pyplot as plt

num_of_nodes = 100
target_count = int(0.5 * num_of_nodes)  # Exactly 50% coverage required
nodes = {} 
random_edges = []
distance_matrix = [[0.0 for _ in range(num_of_nodes)] for _ in range(num_of_nodes)]

# Generate nodes with spatial coordinates and individual selection costs
for i in range(1, num_of_nodes + 1):
    nodes[i] = {
        "x": random.uniform(0, 1000),
        "y": random.uniform(0, 2000),
        "cost": random.uniform(-100, 100)
    }

# Generate a complete graph (clique): every node connects to every other node
for i in range(1, num_of_nodes + 1):
    for j in range(i + 1, num_of_nodes + 1):
        random_edges.append((i, j))

# Precompute full distance matrix for the complete graph
adjacency = {node_id: set() for node_id in nodes.keys()}
for i in range(1, num_of_nodes + 1):
    for j in range(1, num_of_nodes + 1):
        if i == j:
            distance_matrix[i - 1][j - 1] = 0
        elif (i, j) in random_edges or (j, i) in random_edges:
            x1, y1 = nodes[i]["x"], nodes[i]["y"]
            x2, y2 = nodes[j]["x"], nodes[j]["y"]
            distance = round(math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2))
            distance_matrix[i - 1][j - 1] = distance
            # Populate neighbor lists
            adjacency[i].add(j)
            adjacency[j].add(i)
        else:
            distance_matrix[i - 1][j - 1] = float('inf')


def random_walk_cycle(nodes, adjacency, distance_matrix, target_count, max_attempts=5000):
    """Return a random cycle and its objective score."""
    for attempt in range(max_attempts):
        start_node = random.choice(list(nodes.keys()))
        current_path = [start_node]
        visited = {start_node}

        while len(current_path) < target_count:
            curr = current_path[-1]
            candidates = list(adjacency[curr] - visited)
            if not candidates:
                break

            nxt = random.choice(candidates)
            current_path.append(nxt)
            visited.add(nxt)

        if len(current_path) == target_count and current_path[0] in adjacency[current_path[-1]]:
            baseline_distance = 0
            baseline_node_cost = sum(nodes[node_id]["cost"] for node_id in current_path)

            for idx in range(len(current_path)):
                u = current_path[idx]
                v = current_path[(idx + 1) % len(current_path)]
                baseline_distance += distance_matrix[u - 1][v - 1]

            baseline_objective = baseline_distance + baseline_node_cost
            return current_path, baseline_objective

    raise ValueError("maybe the edge probability too low")


# Random walk baseline: generate multiple valid cycles and keep the one with the highest objective
solutions = [random_walk_cycle(nodes, adjacency, distance_matrix, target_count) for _ in range(1000)]
cycle, baseline_objective = max(solutions, key=lambda item: item[1])
objectives = [objective for _, objective in solutions]
best_solution = [node_id - 1 for node_id in cycle]
print(f"Best Solution (0-based indices): {best_solution}")
print(f"Min Objective: {min(objectives):.2f}")
print(f"Max Objective: {max(objectives):.2f}")
print(f"Average Objective: {sum(objectives) / len(objectives):.2f}")



# 2D visualization of the best solution for each instance and method. Cost of nodes should be presented e.g. by a color, greyscale, or size
plt.figure(figsize=(12, 6))

# Extract costs for normalization
costs = [node["cost"] for node in nodes.values()]
min_cost, max_cost = min(costs), max(costs)

# Plot all nodes with color representing cost
scatter = plt.scatter([node["x"] for node in nodes.values()],
                      [node["y"] for node in nodes.values()],
                      c=costs, s=50, cmap='viridis', alpha=0.7, edgecolors='black', linewidth=0.5)
cbar = plt.colorbar(scatter, label='Node Cost')

# Plot the random walk baseline cycle
if cycle:
    cycle_coords = [(nodes[node_id]["x"], nodes[node_id]["y"]) for node_id in cycle]
    cycle_coords.append(cycle_coords[0])  # Close the cycle
    cycle_x, cycle_y = zip(*cycle_coords)
    plt.plot(cycle_x, cycle_y, color='red', linewidth=2, label='Random Walk Baseline Cycle')
    #add # of node coverage
    plt.text(0.02, 0.98, f'Node Coverage: {len(cycle)}', transform=plt.gca().transAxes, verticalalignment='top')
    #include arrows to indicate direction
    for i in range(len(cycle)):
        start_node = cycle[i]
        end_node = cycle[(i + 1) % len(cycle)]
        plt.annotate('', xy=(nodes[end_node]["x"], nodes[end_node]["y"]),
                     xytext=(nodes[start_node]["x"], nodes[start_node]["y"]),
                     arrowprops=dict(arrowstyle='->', color='blue', lw=1.5))
        
    # Highlight selected nodes
    selected_x = [nodes[node_id]["x"] for node_id in cycle]
    selected_y = [nodes[node_id]["y"] for node_id in cycle]
    plt.scatter(selected_x, selected_y, s=100, marker='s', facecolors='none', edgecolors='red', linewidth=2)

plt.title("Random Walk Baseline Cycle (Node Cost Visualization)")
plt.xlabel("X Coordinate")
plt.ylabel("Y Coordinate")
plt.legend()
plt.grid()
plt.show()
