#import "@preview/lovelace:0.3.1": *

= Lab #1
== students:
- Maciej Zygmanowski *160324*
- Sofiyan Mohammed *161933*

Code repository: https://github.com/Sofiyan1-786/Evo-Comp.git

== Problem
The goal is to select exactly 50% of the nodes (if the number of nodes is odd we round the number of nodes to be selected up) and form a Hamiltonian cycle (closed path) through this set of nodes such that the sum of the total length of the path plus the total cost of the selected nodes is minimized. The distances between nodes are calculated as Euclidean distances rounded mathematically to integer values. The distance matrix should be calculated just after reading an instance and then only the distance matrix (no nodes coordinates) should be accessed by optimization methods to allow instances defined only by distance matrices.

== Pseudocode

#import "@preview/lovelace:0.3.0": *

#import "@preview/lovelace:0.3.0": *

#set text(font: "New Computer Modern", size: 11pt)

#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  caption: [Random solution],
  pseudocode-list(booktabs: true, numbered-title: [Random solution])[
    + *Input:* a list of all nodes, the number of nodes to pick $k$
    + *Output:* a closed tour through $k$ nodes
    + Pick $k$ different nodes completely at random
    + Put the picked nodes in a random order
    + Connect them one after another, and connect the last node back to the first
    + *return* the tour
  ]
)

#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  caption: [Nearest neighbor, adding nodes only at the end],
  pseudocode-list(booktabs: true, numbered-title: [Nearest neighbor (end)])[
    + *Input:* a start node, all other nodes, distances between nodes, node costs, the number of nodes to pick $k$
    + *Output:* a closed tour through $k$ nodes
    + Start a path that contains only the start node
    + *while* the path has fewer than $k$ nodes *do*
      // + Look at the last node of the path
      + *for* every _node_ that is not yet in the path *do*
        + Compute its price: distance from _last node in path_ to _node_ + cost of _node_
      + Choose the node with the lowest price
      + Add it to the end of the path
    + Connect the last node back to the first node to close the tour
    + *return* the tour
  ]
)

#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  caption: [Nearest neighbor, adding nodes at any position],
  pseudocode-list(booktabs: true, numbered-title: [Nearest neighbor (any position)])[
    + *Input:* a start node, all other nodes, distances between nodes, node costs, the number of nodes to pick $k$
    + *Output:* a closed tour through $k$ nodes
    + Start a path that contains only the start node
    + Find the node with the lowest price: _distance from the start node to it_ + _its own cost_
    + Add that node to the path, so the path now has two nodes
    + *while* the path has fewer than $k$ nodes *do*
      + *for* every node that is not yet in the path *do*
        + *for* every place where it could be put: before the first node, after the last node, or between two neighbors in the path *do*
          + *if* it goes before the first node *then*
            + price = _distance from it to the first node_ + _its own cost_
          + *else if* it goes after the last node *then*
            + price = _distance from the last node to it_ + _its own cost_
          + *else*
            + price = _distance from the left neighbor to it_ + _distance from it to the right neighbor_ - _the old distance between the two neighbors_ + _its own cost_
      + Choose the node and place with the lowest price
      + Put that node in that place
    + Connect the last node back to the first node to close the tour
    + *return* the tour
  ]
)

#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  caption: [Greedy cycle],
  pseudocode-list(booktabs: true, numbered-title: [Greedy cycle])[
    + *Input:* a start node, all other nodes, distances between nodes, node costs, the number of nodes to pick $k$
    + *Output:* a closed tour through $k$ nodes
    + Start with a tour that contains only the start node
    + Find the node with the lowest price: _twice the distance from the start node to it_ + _its own cost_
    + Add it, so the tour is a small loop of two nodes that go back and forth
    + *while* the tour has fewer than $k$ nodes *do*
      + *for* every node that is not yet in the tour *do*
        + *for* every connection between two neighbors in the tour *do*
          + price = _distance from the left neighbor to the node_ + _distance from the node to the right neighbor_ - _the old distance between the two neighbors_ + _its own cost_
      + Choose the node and connection with the lowest price
      + Break that connection and place the node between the two neighbors
    + *return* the tour
  ]
)



== Methods
- Random solution
Objective value: *Min* = 224650, *Max* = 285708, *Average* = 262760.91

- Nearest neighbour (Insertion at the End)
Objective value: *Min* = 84362, *Max* = 90075, *Average* = 87476.63

- Nearest neighbour (Insertion anywhere)
Objective value: *Min* = 72328, *Max* = 77022, *Average* = 74347.92

- Greedy cycle
Objective value: *Min *= 72590, *Max* = 75281, *Average* = 73793.40

#figure(
  image("lab#1/TSPA_best.png", width: 100%),
  caption: [
    TSPA best solution visualisation. Left to right, top to bottom: random, nearest neighbor only end, nearest neighbor anywhere, greedy cycle
  ],
)


#figure(
  image("lab#1/TSPB_best.png", width: 100%),
  caption: [
    TSPB best solution visualisation. Left to right, top to bottom: random, nearest neighbor only end, nearest neighbor anywhere, greedy cycle
  ],
)


#set text(font: "New Computer Modern", size: 11pt)
#set page(margin: 1.5cm)

#figure(
  caption: [Best solution found by each method on each instance, as a list of node indices (starting from 0), in visiting order.],
  table(
    columns: (auto, auto, 1fr),
    align: (center + horizon, left + horizon, left),
    stroke: 0.5pt,
    inset: 6pt,
    table.header([*Instance*], [*Method*], [*Best solution (node indices)*]),

    table.cell(rowspan: 4)[TSPA],
    [Random],
    text(size: 7pt)[91, 173, 123, 23, 118, 1, 179, 67, 2, 120, 97, 107, 105, 58, 24, 89, 26, 35, 56, 99, 78, 140, 9, 151, 22, 177, 156, 57, 52, 142, 166, 15, 195, 68, 62, 79, 160, 47, 88, 42, 51, 48, 13, 84, 85, 103, 6, 73, 76, 190, 50, 134, 25, 28, 144, 189, 102, 69, 7, 37, 159, 65, 147, 163, 155, 4, 11, 192, 168, 82, 172, 3, 135, 39, 41, 145, 104, 161, 181, 19, 17, 36, 162, 164, 174, 54, 175, 117, 131, 31, 95, 92, 187, 184, 139, 186, 108, 167, 106, 49],
    [Nearest Neighbor (end)],
    text(size: 7pt)[54, 9, 33, 36, 177, 67, 144, 53, 135, 58, 134, 176, 174, 106, 89, 107, 57, 182, 151, 93, 50, 3, 1, 164, 178, 29, 136, 186, 184, 47, 159, 130, 153, 78, 88, 193, 170, 146, 75, 64, 150, 42, 113, 43, 85, 142, 8, 131, 84, 158, 192, 181, 114, 141, 180, 132, 76, 80, 48, 31, 63, 149, 168, 97, 127, 187, 30, 123, 152, 108, 60, 116, 49, 11, 119, 160, 83, 90, 51, 16, 35, 87, 45, 140, 52, 179, 185, 28, 102, 156, 157, 71, 91, 38, 100, 4, 112, 139, 115, 5],
    [Nearest Neighbor (any position)],
    text(size: 7pt)[171, 2, 189, 30, 187, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 150, 151, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 113, 89, 42, 106, 93, 47, 147, 50, 3, 169, 1, 178, 101, 29, 163, 136, 186, 164, 8, 174, 131, 54, 9, 33, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 156, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48, 31, 60, 108, 152, 100, 123, 83, 160, 49, 11, 63, 149, 116, 168, 97, 127, 69, 129, 104],
    [Greedy Cycle],
    text(size: 7pt)[31, 116, 149, 168, 63, 11, 49, 60, 108, 152, 100, 90, 123, 83, 160, 97, 127, 69, 171, 2, 189, 30, 187, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 150, 151, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 113, 89, 42, 106, 93, 47, 147, 50, 3, 169, 1, 178, 101, 29, 163, 136, 186, 164, 142, 8, 174, 131, 54, 9, 33, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 156, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48],

    table.cell(rowspan: 4)[TSPB],
    [Random],
    text(size: 7pt)[199, 159, 151, 49, 155, 134, 186, 182, 138, 180, 161, 37, 172, 142, 50, 195, 133, 136, 27, 189, 141, 121, 21, 72, 131, 190, 94, 83, 77, 105, 84, 148, 4, 67, 25, 124, 39, 183, 23, 89, 177, 187, 135, 171, 86, 147, 55, 194, 52, 57, 113, 82, 112, 2, 90, 193, 191, 107, 145, 116, 149, 152, 137, 45, 175, 192, 126, 110, 76, 162, 174, 101, 106, 12, 178, 60, 48, 150, 51, 181, 58, 87, 3, 31, 99, 129, 28, 93, 128, 143, 122, 80, 43, 109, 164, 160, 0, 42, 8, 16],
    [Nearest Neighbor (end)],
    text(size: 7pt)[32, 89, 57, 76, 54, 127, 129, 90, 153, 20, 14, 2, 110, 118, 56, 114, 196, 10, 148, 143, 78, 192, 162, 104, 185, 184, 3, 151, 69, 172, 133, 120, 96, 121, 198, 48, 72, 46, 86, 117, 160, 136, 8, 21, 154, 140, 47, 170, 125, 177, 6, 132, 29, 197, 175, 134, 45, 60, 40, 71, 155, 97, 115, 180, 65, 28, 149, 145, 158, 116, 147, 42, 50, 130, 30, 183, 38, 64, 85, 59, 167, 51, 87, 179, 82, 88, 171, 99, 67, 24, 34, 181, 152, 73, 98, 27, 135, 75, 79, 156],
    [Nearest Neighbor (any position)],
    text(size: 7pt)[82, 87, 179, 181, 24, 34, 152, 167, 73, 51, 85, 59, 64, 168, 189, 183, 30, 176, 21, 38, 47, 140, 154, 97, 141, 40, 60, 157, 45, 134, 175, 71, 155, 115, 180, 6, 29, 132, 36, 197, 170, 26, 125, 177, 158, 65, 145, 28, 149, 13, 146, 37, 116, 147, 42, 50, 191, 130, 121, 198, 96, 48, 43, 156, 120, 133, 136, 172, 69, 160, 8, 117, 122, 151, 173, 184, 3, 72, 46, 86, 89, 57, 185, 76, 104, 162, 192, 54, 80, 127, 129, 90, 52, 182, 153, 74, 20, 14, 2, 110],
    [Greedy Cycle],
    text(size: 7pt)[174, 36, 197, 6, 180, 115, 170, 97, 140, 47, 155, 71, 175, 134, 45, 157, 60, 141, 40, 33, 64, 21, 189, 168, 69, 160, 172, 136, 133, 120, 8, 117, 72, 46, 86, 184, 3, 173, 122, 151, 98, 111, 27, 135, 76, 185, 162, 192, 80, 52, 182, 20, 74, 2, 93, 110, 118, 14, 153, 90, 129, 127, 54, 104, 57, 89, 156, 43, 48, 96, 198, 121, 63, 130, 191, 183, 30, 176, 38, 154, 26, 125, 177, 138, 158, 145, 149, 147, 42, 116, 37, 146, 13, 28, 65, 178, 103, 29, 132, 1],
  )
)

#v(1em)

#figure(
  caption: [Verification of the best solutions with the solution checker (Solution_checker.xlsx). The objective computed by the code was compared with the objective computed by the checker.],
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (center, left, right, right, center),
    stroke: 0.5pt,
    inset: 6pt,
    table.header([*Instance*], [*Method*], [*Objective (code)*], [*Objective (checker)*], [*Checked*]),

    table.cell(rowspan: 4)[TSPA],
    [Random], [224650], [224650], [OK],
    [Nearest Neighbor (end)], [84362], [84362], [OK],
    [Nearest Neighbor (any position)], [72328], [72328], [OK],
    [Greedy Cycle], [72590], [72590], [OK],

    table.cell(rowspan: 4)[TSPB],
    [Random], [185419], [185419], [OK],
    [Nearest Neighbor (end)], [56007], [56007], [OK],
    [Nearest Neighbor (any position)], [52915], [52915], [OK],
    [Greedy Cycle], [55655], [55655], [OK],
  )
)

= Conclusions

All three greedy heuristics are much better than random solutions. On both instances they reduced the objective by about 65-75%, for example from 224650 (random, best of 200) to 72328 on TSPA.

The results depend on the instance, so no single method is best everywhere.

Methods that can insert nodes inside the tour are generally better than the one that only appends. 

Since all of these methods are greedy, they cannot undo a bad choice, so their solutions can probably be improved further with local search. 

All best solutions were verified with the solution checker, and the objective values matched.