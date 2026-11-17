#import "@preview/lovelace:0.3.1": *

= Lab #3
== students:
- Maciej Zygmanowski *160324*
- Sofiyan Mohammed *161933*

Code repository: https://github.com/Sofiyan1-786/Evo-Comp.git

== Problem

The problem is the same as in the previous lab: select 50% of the nodes to form a Hamiltonian cycle, minimizing sum of edge and node costs.


== Local Search
Local Search (LS) improves an initial solution by iteratively exploring a defined neighborhood of candidate solutions reachable via small modifications and replacing the current solution with an improving neighbor until a local optimum is reached.

Let $T = (v_0, v_1, dots, v_(m-1))$ denote the current cycle of $m = n / 2$ selected nodes (with indices taken modulo $m$, so $v_(-1) = v_(m-1)$ and $v_m = v_0$), $U = V without T$ denote the set of $n - m$ unselected nodes, $d(a, b)$ denote the symmetric edge distance between nodes $a$ and $b$, and $c(v)$ denote the cost of node $v$.

=== Randomization Method for Greedy Search
To prevent operational bias toward either move category without pre-evaluating deltas or constructing an $O(n^2)$ vector of move descriptors at every iteration, the neighborhood is traversed using randomized index orders and randomly interleaved move types. In each iteration, the tour position indices and node indices are browsed in a randomized sequence while randomly alternating between intra-route and inter-route move checks. Cost deltas $Delta$ are computed lazily on-the-fly for each sampled pair until the first improving move ($Delta < 0$) is encountered and immediately executed.

*NB: in Greedy algorithm we don't enumerate everything immediately but lazily.
*

== 1. Types of Neighborhood Moves & Cost Deltas ($Delta$)

The complete neighborhood $cal(N)(T)$ consists of two distinct categories of moves evaluated in $O(1)$ time via objective function deltas $Delta = f(T_"new") - f(T)$ (where $Delta < 0$ indicates an improving move):

=== Intra-route Moves
These operations alter the sequence of nodes exclusively within the selected tour $T$ (node costs remain unchanged):

- *Two-edges exchange ($2$-opt):* For two tour positions $0 <= i < j < m$ (excluding $(i, j) = (0, m-1)$, which reverses the entire cycle), removes edges $(v_(i-1), v_i)$ and $(v_j, v_(j+1))$ and reconnects the cycle with edges $(v_(i-1), v_j)$ and $(v_i, v_(j+1))$ by reversing the inclusive sub-segment $T[i dots j]$:
  $ Delta_"2-edges" (i, j) = (d(v_(i-1), v_j) + d(v_i, v_(j+1))) - (d(v_(i-1), v_i) + d(v_j, v_(j+1))) $

- *Two-nodes exchange (swap):* Directly interchanges the tour positions of two selected nodes $v_i$ and $v_j$ ($0 <= i < j < m$), summing the length changes over the unique cycle edges incident to positions $i$ and $j$:
  - _Non-adjacent positions_ ($j - i > 1$ and $(i, j) != (0, m-1)$ — 4 incident edges change):
    $ Delta_"2-nodes" (i, j) = &(d(v_(i-1), v_j) + d(v_j, v_(i+1)) + d(v_(j-1), v_i) + d(v_i, v_(j+1))) \
    &- (d(v_(i-1), v_i) + d(v_i, v_(i+1)) + d(v_(j-1), v_j) + d(v_j, v_(j+1))) $
  - _Adjacent positions_ ($j = i + 1$, or cyclically $i = 0, j = m - 1$ — shared edge $(v_i, v_(i+1))$ is deduplicated):
    $ Delta_"2-nodes" (i, i+1) = (d(v_(i-1), v_(i+1)) + d(v_i, v_(i+2))) - (d(v_(i-1), v_i) + d(v_(i+1), v_(i+2))) $

=== Inter-route Moves
These operations transfer nodes between the selected tour $T$ and unselected set $U$:

- *Node exchange:* Substitutes a selected node $v_p in T$ at tour position $0 <= p < m$ with an unselected node $u in U$, accounting for both modified incident edges and individual node costs:
  $ Delta_"exchange" (p, u) = (d(v_(p-1), u) + d(u, v_(p+1)) + c(u)) - (d(v_(p-1), v_p) + d(v_p, v_(p+1)) + c(v_p)) $

== 2. Local Search Strategies

- *Steepest Local Search:* Systematically evaluates every possible intra-route and inter-route move in $cal(N)(T)$ during each iteration. It executes only the single move that yields the minimum $Delta < 0$ and terminates when no improving move exists ($Delta >= 0$ for all moves).
- *Greedy Local Search:* Browses candidate moves from the combined intra-route and inter-route neighborhood in a uniformly randomized order, evaluating $Delta$ on-the-fly and immediately applying the first move that yields $Delta < 0$.

=== 3. Initialization Schemes

- *Random Start:* Constructs an initial cycle by selecting a random subset of $m = n / 2$ nodes and permuting them uniformly at random.
- *Greedy Start:* Generates the initial cycle from each of the $n = 200$ starting nodes using the best construction heuristic from Lab 2 (2-regret greedy cycle heuristic with weights $"regret" = 1, "delta" = 2$).


== Local Search Master Routines & Algorithm Specifications

=== Master Routine A: Steepest Variants (Algorithms 1, 2, 3, 4)

#block(
  fill: luma(245),
  inset: 10pt,
  radius: 4pt,
  width: 100%,
  [    
    *WHILE (true):*
    #v(4pt)
    `best_delta` $<- 0$ \
    `best_move` $<- "NONE"$
    #v(4pt)
    *1. Evaluate all Intra-route moves* ($0 <= i < j < m$, skipping $(0, m-1)$ for Two-Edges):
    #pad(left: 15pt)[
      - Compute $Delta <- Delta_"2-edges" (i, j)$ or $Delta_"2-nodes" (i, j)$.
      - *IF* $Delta <$ `best_delta`: record `best_move` $<- ("INTRA", i, j)$ and `best_delta` $<- Delta$.
    ]
    *2. Evaluate all Inter-route moves* ($0 <= p < m$ and unselected node $u in U$):
    #pad(left: 15pt)[
      - Compute $Delta <- Delta_"exchange" (p, u)$.
      - *IF* $Delta <$ `best_delta`: record `best_move` $<- ("INTER", p, u)$ and `best_delta` $<- Delta$.
    ]
    *3. Check Termination:*
    #pad(left: 15pt)[
      - *IF* `best_delta` $>= 0$ (no improving move exists) $arrow$ *BREAK* and *RETURN* $T$.
    ]
    *4. Execute Move:*
    #pad(left: 15pt)[
      - *IF* `best_move` $= ("INTRA", i, j)$ with Two-Edges: reverse sub-segment $(v_i, dots, v_j) <- (v_j, dots, v_i)$.
      - *IF* `best_move` $= ("INTRA", i, j)$ with Two-Nodes: swap tour positions $(v_i, v_j) <- (v_j, v_i)$.
      - *IF* `best_move` $= ("INTER", p, u)$: update $U <- (U without {u}) union {v_p}$ and set $v_p <- u$.
    ]
  ]
)

#v(5pt)
- *Algorithm 1 (Steepest, Two-Edges, Random):* Random initial tour $T$ $arrow$ Master Routine A using $Delta_"2-edges"$ and sub-segment reversal.
- *Algorithm 2 (Steepest, Two-Nodes, Random):* Random initial tour $T$ $arrow$ Master Routine A using $Delta_"2-nodes"$ and node position swap.
- *Algorithm 3 (Steepest, Two-Edges, Greedy):* 2-regret initial tour $T$ $arrow$ Master Routine A using $Delta_"2-edges"$ and sub-segment reversal.
- *Algorithm 4 (Steepest, Two-Nodes, Greedy):* 2-regret initial tour $T$ $arrow$ Master Routine A using $Delta_"2-nodes"$ and node position swap.

#line(length: 100%, stroke: 0.5pt + luma(150))




=== Master Routine B: Greedy / First-Improvement Variants (Algorithms 5, 6, 7, 8)

#block(
  fill: luma(245),
  inset: 10pt,
  radius: 4pt,
  width: 100%,
  [
    *WHILE (true):*
    #v(4pt)
    *1. Randomized First-Improvement Neighborhood Scan:*
    #pad(left: 15pt)[
      - `improved` $<- "false"$
      - Browse candidate intra-route index pairs $(i, j)$ ($0 <= i < j < m$, skipping $(0, m-1)$ for Two-Edges) and inter-route pairs $(p, u)$ ($0 <= p < m, u in U$) in a randomized order, interleaving both move categories without pre-computing deltas.
      - *FOR* each sampled candidate move:
        #pad(left: 15pt)[
          - Compute its specific $Delta$ on-the-fly ($Delta_"2-edges"$, $Delta_"2-nodes"$, or $Delta_"exchange"$).
          - *IF* $Delta < 0$:
            #pad(left: 15pt)[
              - *IF* Intra-route (Two-Edges): reverse sub-segment $(v_i, dots, v_j) <- (v_j, dots, v_i)$.
              - *IF* Intra-route (Two-Nodes): swap tour positions $(v_i, v_j) <- (v_j, v_i)$.
              - *IF* Inter-route: update $U <- (U without {u}) union {v_p}$ and set $v_p <- u$.
              - `improved` $<- "true"$
              - *BREAK* out of the scan loop immediately.
            ]
        ]
    ]
    *2. Check Termination:*
    #pad(left: 15pt)[
      - *IF* `improved` $== "false"$ (entire neighborhood scanned without finding $Delta < 0$) $arrow$ *BREAK* and *RETURN* $T$.
    ]
  ]
)

#v(5pt)
- *Algorithm 5 (Greedy, Two-Edges, Random):* Random initial tour $T$ $arrow$ Master Routine B using $Delta_"2-edges"$ and sub-segment reversal.
- *Algorithm 6 (Greedy, Two-Nodes, Random):* Random initial tour $T$ $arrow$ Master Routine B using $Delta_"2-nodes"$ and node position swap.
- *Algorithm 7 (Greedy, Two-Edges, Greedy):* 2-regret initial tour $T$ $arrow$ Master Routine B using $Delta_"2-edges"$ and sub-segment reversal.
- *Algorithm 8 (Greedy, Two-Nodes, Greedy):* 2-regret initial tour $T$ $arrow$ Master Routine B using $Delta_"2-nodes"$ and node position swap.


== Results
=== Objective Function Results

#table(
  columns: (auto, 1fr, 1fr),
  align: (left, right, right),
  table.header(
    [*Method*], [*TSPA — avg (min – max)*], [*TSPB — avg (min – max)*]
  ),
  [random], [261657.92 (232201 – 293747)], [205846.78 (182122 – 229428)],
  [nearest-neighbor-end], [87476.63 (84362 – 90075)], [59397.33 (56007 – 63166)],
  [nearest-neighbor-anywhere], [74347.92 (72328 – 77022)], [59465.47 (52915 – 66164)],
  [greedy-cycle], [73793.40 (72590 – 75281)], [59649.91 (55655 – 63734)],
  [2-regret (regret=1, delta=1) nearest-neighbor-anywhere], [75553.08 (72419 – 78504)], [55716.18 (50374 – 61406)],
  [2-regret (regret=1, delta=1) greedy-cycle], [73353.51 (72011 – 75532)], [57866.33 (52731 – 63370)],
  [2-regret (regret=1, delta=0) nearest-neighbor-anywhere], [122157.10 (110035 – 135771)], [73924.27 (68075 – 79912)],
  [2-regret (regret=1, delta=0) greedy-cycle], [120994.80 (112654 – 130391)], [73459.29 (69609 – 78175)],
  [2-regret (regret=2, delta=1) nearest-neighbor-anywhere], [76415.93 (73614 – 79873)], [54742.25 (51286 – 60794)],
  [2-regret (regret=2, delta=1) greedy-cycle], [74277.18 (72575 – 76095)], [59708.03 (52788 – 63809)],
  [2-regret (regret=1, delta=2) nearest-neighbor-anywhere], [75296.35 (72134 – 78210)], [56156.99 (52302 – 63489)],
  [2-regret (regret=1, delta=2) greedy-cycle], [73190.05 (72049 – 75274)], [55725.29 (52099 – 62556)],
  [LS steepest, two-edges, random start], [76107.70 (73595 – 79915)], [*52715.58* (51045 – *54785*)],
  [LS steepest, two-nodes, random start], [89641.90 (84177 – 96576)], [65491.64 (58400 – 74047)],
  [LS steepest, two-edges, greedy start], [*72809.15* (*71925* – *74680*)], [54921.03 (52096 – 62039)],
  [LS steepest, two-nodes, greedy start], [72854.63 (71955 – 75044)], [55168.69 (52096 – 62323)],
  [LS greedy, two-edges, random start], [76270.35 (74334 – 80188)], [52764.28 (*50431* – 54961)],
  [LS greedy, two-nodes, random start], [87669.85 (80980 – 95622)], [63995.96 (58211 – 70520)],
  [LS greedy, two-edges, greedy start], [72825.35 (71955 – 74873)], [54928.80 (52096 – 62105)],
  [LS greedy, two-nodes, greedy start], [72857.36 (71955 – 75044)], [55170.21 (52096 – 62323)],
)

=== Execution Time Results (seconds) Total time: 92.205 seconds

#table(
  columns: (auto, 1fr, 1fr),
  align: (left, right, right),
  table.header(
    [*Method*], [*TSPA — avg (min – max)*], [*TSPB — avg (min – max)*]
  ),
  [random], [0.0000 (0.0000 – 0.0000)], [0.0000 (0.0000 – 0.0000)],
  [nearest-neighbor-end], [0.0001 (0.0000 – 0.0001)], [0.0000 (0.0000 – 0.0001)],
  [nearest-neighbor-anywhere], [0.0026 (0.0022 – 0.0047)], [0.0025 (0.0022 – 0.0046)],
  [greedy-cycle], [0.0070 (0.0068 – 0.0095)], [0.0068 (0.0065 – 0.0085)],
  [2-regret (regret=1, delta=1) nearest-neighbor-anywhere], [0.0040 (0.0031 – 0.0090)], [0.0039 (0.0032 – 0.0054)],
  [2-regret (regret=1, delta=1) greedy-cycle], [0.0065 (0.0062 – 0.0085)], [0.0065 (0.0058 – 0.0088)],
  [2-regret (regret=1, delta=0) nearest-neighbor-anywhere], [0.0040 (0.0028 – 0.0088)], [0.0039 (0.0029 – 0.0079)],
  [2-regret (regret=1, delta=0) greedy-cycle], [0.0065 (0.0061 – 0.0086)], [0.0065 (0.0060 – 0.0089)],
  [2-regret (regret=2, delta=1) nearest-neighbor-anywhere], [0.0038 (0.0032 – 0.0062)], [0.0038 (0.0029 – 0.0056)],
  [2-regret (regret=2, delta=1) greedy-cycle], [0.0069 (0.0060 – 0.0107)], [0.0069 (0.0059 – 0.0117)],
  [2-regret (regret=1, delta=2) nearest-neighbor-anywhere], [0.0038 (0.0033 – 0.0052)], [0.0039 (0.0032 – 0.0056)],
  [2-regret (regret=1, delta=2) greedy-cycle], [0.0065 (0.0063 – 0.0077)], [0.0066 (0.0059 – 0.0087)],
  [LS steepest, two-edges, random start], [0.0355 (0.0291 – 0.0901)], [0.0380 (0.0313 – 0.0683)],
  [LS steepest, two-nodes, random start], [0.0696 (0.0495 – 0.1252)], [0.0639 (0.0478 – 0.1180)],
  [LS steepest, two-edges, greedy start], [0.0097 (0.0068 – 0.0177)], [0.0097 (0.0072 – 0.0131)],
  [LS steepest, two-nodes, greedy start], [0.0085 (0.0073 – 0.0170)], [0.0102 (0.0071 – 0.0142)],
  [LS greedy, two-edges, random start], [0.0038 (0.0026 – 0.0066)], [0.0037 (0.0026 – 0.0066)],
  [LS greedy, two-nodes, random start], [0.0062 (0.0041 – 0.0102)], [0.0063 (0.0042 – 0.0096)],
  [LS greedy, two-edges, greedy start], [0.0074 (0.0066 – 0.0097)], [0.0076 (0.0065 – 0.0098)],
  [LS greedy, two-nodes, greedy start], [0.0076 (0.0066 – 0.0104)], [0.0081 (0.0067 – 0.0106)],
)





== Visualizations

#let viz-pair(img1, img2, caption1, caption2, main-caption) = [
  #figure(
    box[
      #grid(
        columns: (1fr, 1fr),
        gutter: 10pt,
        box[
          #image("lab3/" + img1, width: 100%)
          #align(center)[#text(size: 8pt, weight: "medium")[#caption1]]
        ],
        box[
          #image("lab3/" + img2, width: 100%)
          #align(center)[#text(size: 8pt, weight: "medium")[#caption2]]
        ]
      )
    ],
    caption: main-caption,
  )
]

=== Steepest Local Search Visualizations

==== Instance TSPA
#viz-pair(
  "ls-steepest-two-edges-greedy_TSPA_min.png",
  "ls-steepest-two-edges-greedy_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Edges Exchange & Greedy Start (TSPA)]
)

#viz-pair(
  "ls-steepest-two-edges-random_TSPA_min.png",
  "ls-steepest-two-edges-random_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Edges Exchange & Random Start (TSPA)]
)

#viz-pair(
  "ls-steepest-two-nodes-greedy_TSPA_min.png",
  "ls-steepest-two-nodes-greedy_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Nodes Exchange & Greedy Start (TSPA)]
)

#viz-pair(
  "ls-steepest-two-nodes-random_TSPA_min.png",
  "ls-steepest-two-nodes-random_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Nodes Exchange & Random Start (TSPA)]
)

==== Instance TSPB
#viz-pair(
  "ls-steepest-two-edges-greedy_TSPB_min.png",
  "ls-steepest-two-edges-greedy_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Edges Exchange & Greedy Start (TSPB)]
)

#viz-pair(
  "ls-steepest-two-edges-random_TSPB_min.png",
  "ls-steepest-two-edges-random_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Edges Exchange & Random Start (TSPB)]
)

#viz-pair(
  "ls-steepest-two-nodes-greedy_TSPB_min.png",
  "ls-steepest-two-nodes-greedy_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Nodes Exchange & Greedy Start (TSPB)]
)

#viz-pair(
  "ls-steepest-two-nodes-random_TSPB_min.png",
  "ls-steepest-two-nodes-random_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Steepest Local Search with 2-Nodes Exchange & Random Start (TSPB)]
)

#line(length: 100%, stroke: 0.5pt + luma(150))
=== Greedy Local Search Visualizations

==== Instance TSPA
#viz-pair(
  "ls-greedy-two-edges-greedy_TSPA_min.png",
  "ls-greedy-two-edges-greedy_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Edges Exchange & Greedy Start (TSPA)]
)

#viz-pair(
  "ls-greedy-two-edges-random_TSPA_min.png",
  "ls-greedy-two-edges-random_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Edges Exchange & Random Start (TSPA)]
)

#viz-pair(
  "ls-greedy-two-nodes-greedy_TSPA_min.png",
  "ls-greedy-two-nodes-greedy_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Nodes Exchange & Greedy Start (TSPA)]
)

#viz-pair(
  "ls-greedy-two-nodes-random_TSPA_min.png",
  "ls-greedy-two-nodes-random_TSPA_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Nodes Exchange & Random Start (TSPA)]
)

==== Instance TSPB
#viz-pair(
  "ls-greedy-two-edges-greedy_TSPB_min.png",
  "ls-greedy-two-edges-greedy_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Edges Exchange & Greedy Start (TSPB)]
)

#viz-pair(
  "ls-greedy-two-edges-random_TSPB_min.png",
  "ls-greedy-two-edges-random_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Edges Exchange & Random Start (TSPB)]
)

#viz-pair(
  "ls-greedy-two-nodes-greedy_TSPB_min.png",
  "ls-greedy-two-nodes-greedy_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Nodes Exchange & Greedy Start (TSPB)]
)

#viz-pair(
  "ls-greedy-two-nodes-random_TSPB_min.png",
  "ls-greedy-two-nodes-random_TSPB_max.png",
  "(a) Best solution (min)",
  "(b) Worst solution (max)",
  [Greedy Local Search with 2-Nodes Exchange & Random Start (TSPB)]
)


== Conclusion and Discussion

The experimental evaluation of the 8 local search configurations across instances TSPA and TSPB provides clear insights into the trade-offs between solution quality, convergence speed, and exploration strategies in combinatorial optimization.

=== 1. Impact of Starting Solutions
- *Greedy vs. Random Starts on TSPA:* Initializing local search with the 2-regret greedy heuristic produces the highest overall tour quality on TSPA (achieving the best average of `72,809.15` and minimum of `71,925` with steepest 2-edges, compared to `76,107.70` from random starts) while converging quickly (`~0.0097s` including heuristic construction).
- *Exploration Advantage of Random Starts on TSPB:* On TSPB, starting from random initial solutions paired with 2-edges exchange outperforms greedy initialization in both average cost (`52,715.58` steepest / `52,764.28` greedy vs. `54,921.03` / `54,928.80`) and best minimum cost (`50,431` greedy random vs. `52,096` greedy start). Because the 2-regret heuristic constructs solutions that already lie near deep local minima, local search performs only marginal adjustments within that same basin of attraction. In contrast, random starts explore widely dispersed trajectories across the search space, enabling 2-opt to reach superior basins of attraction on TSPB.

=== 2. Steepest vs. Greedy Local Search
- *Solution Quality:* Both steepest and greedy local search strategies achieve nearly identical objective function values across all corresponding configurations (e.g., `72,809.15` vs. `72,825.35` average on TSPA with greedy start and 2-edges; `52,715.58` vs. `52,764.28` on TSPB with random start and 2-edges).
- *Computational Efficiency:* Greedy local search demonstrates a substantial speed advantage over steepest local search when starting from random solutions (`~0.0038s` vs. `~0.0355s` for 2-edges, roughly a 9- to 10-fold speedup). Because improving moves are abundant in poor initial tours, greedy search immediately executes the first improving candidate after checking only a few moves on-the-fly, whereas steepest local search is obligated to evaluate all $14,950$ candidate moves in every single iteration. When initialized with a 2-regret tour, both methods execute in similar time frames (`~0.0074s–0.0097s`) because improving moves are sparse, forcing greedy search to inspect a much larger portion of the neighborhood before finding an improving move.

=== 3. Intra-Route Neighborhood Operators ($2$-Edges vs. $2$-Nodes)
- *Superiority of $2$-Edges ($2$-opt):* The $2$-edges exchange operator consistently outperforms the $2$-nodes swap operator across all test configurations. The difference is most pronounced under random initialization, where 2-edges improves average objective values from `89,641.90` to `76,107.70` on TSPA and from `65,491.64` to `52,715.58` on TSPB for steepest search, while cutting runtime approximately in half (`0.0355s` vs. `0.0696s`).
- *Structural Explanation:* Swapping two arbitrary vertices in a tour disrupts up to four edges simultaneously without reversing intermediate path segments, which frequently introduces new long-range crossings. In contrast, a $2$-edges exchange alters only two edges and inverts the intermediate sub-segment, directly untangling intersecting cycle edges while preserving the established local structure of the tour.

== Raw results

#table(
  columns: (auto, 1fr, 1fr, 1fr),
  align: (left, right, right, right),
  table.header(
    [*max/min*], [*method*], [*case*], [*tour*]
  ),
  [min], [random], [TSPA], [[140, 73, 127, 167, 40, 67, 95, 75, 182, 190, 45, 142, 101, 116, 170, 155, 17, 115, 136, 122, 21, 55, 12, 103, 124, 164, 93, 38, 163, 112, 76, 96, 172, 100, 35, 143, 198, 41, 181, 4, 53, 106, 192, 185, 61, 34, 99, 52, 63, 166, 120, 160, 19, 173, 32, 80, 134, 0, 36, 49, 187, 137, 199, 89, 180, 8, 191, 74, 84, 157, 42, 169, 83, 51, 44, 168, 25, 178, 141, 146, 97, 31, 54, 57, 150, 62, 108, 131, 15, 128, 24, 114, 107, 176, 58, 183, 72, 10, 27, 133]],
[max], [random], [TSPA], [[11, 18, 81, 121, 20, 28, 151, 198, 41, 168, 150, 106, 15, 193, 10, 24, 114, 74, 29, 184, 148, 167, 8, 119, 197, 110, 54, 153, 162, 63, 62, 129, 56, 165, 169, 77, 57, 134, 71, 17, 171, 84, 82, 102, 144, 132, 79, 159, 44, 31, 61, 65, 139, 78, 52, 154, 21, 46, 70, 22, 49, 190, 75, 34, 170, 192, 122, 16, 64, 143, 163, 125, 179, 48, 188, 185, 19, 107, 161, 152, 149, 142, 60, 26, 140, 1, 189, 76, 113, 6, 97, 101, 124, 126, 69, 7, 118, 130, 5, 86]],
[min], [random], [TSPB], [[141, 48, 75, 40, 167, 159, 118, 101, 113, 29, 178, 104, 126, 189, 90, 169, 197, 107, 111, 64, 92, 117, 54, 184, 137, 11, 4, 69, 170, 149, 12, 84, 27, 57, 35, 14, 82, 61, 77, 194, 55, 71, 120, 13, 60, 171, 181, 177, 30, 158, 162, 85, 42, 18, 164, 16, 10, 135, 41, 100, 109, 17, 96, 32, 22, 24, 25, 129, 98, 133, 6, 34, 163, 86, 74, 114, 44, 152, 49, 188, 93, 154, 56, 97, 23, 172, 127, 80, 63, 124, 83, 173, 190, 39, 186, 8, 81, 0, 87, 73]],
[max], [random], [TSPB], [[164, 44, 20, 156, 173, 32, 54, 180, 158, 43, 127, 76, 17, 52, 0, 84, 28, 155, 83, 57, 63, 93, 58, 129, 26, 151, 75, 136, 68, 38, 142, 81, 150, 182, 4, 60, 110, 41, 34, 188, 143, 176, 90, 29, 131, 174, 62, 97, 7, 51, 159, 37, 198, 56, 157, 128, 185, 46, 23, 80, 50, 122, 106, 61, 138, 104, 100, 42, 166, 74, 181, 112, 114, 91, 70, 88, 177, 13, 118, 12, 146, 105, 21, 169, 141, 193, 125, 115, 1, 167, 24, 120, 55, 109, 9, 195, 175, 117, 2, 25]],
[min], [nearest-neighbor-end], [TSPA], [[54, 9, 33, 36, 177, 67, 144, 53, 135, 58, 134, 176, 174, 106, 89, 107, 57, 182, 151, 93, 50, 3, 1, 164, 178, 29, 136, 186, 184, 47, 159, 130, 153, 78, 88, 193, 170, 146, 75, 64, 150, 42, 113, 43, 85, 142, 8, 131, 84, 158, 192, 181, 114, 141, 180, 132, 76, 80, 48, 31, 63, 149, 168, 97, 127, 187, 30, 123, 152, 108, 60, 116, 49, 11, 119, 160, 83, 90, 51, 16, 35, 87, 45, 140, 52, 179, 185, 28, 102, 156, 157, 71, 91, 38, 100, 4, 112, 139, 115, 5]],
[max], [nearest-neighbor-end], [TSPA], [[5, 51, 67, 177, 36, 33, 9, 164, 1, 50, 93, 106, 89, 107, 57, 182, 134, 58, 135, 45, 180, 141, 187, 30, 132, 76, 80, 48, 31, 63, 149, 168, 97, 127, 123, 152, 108, 60, 116, 49, 11, 119, 160, 83, 90, 157, 71, 91, 38, 100, 35, 16, 144, 53, 140, 52, 179, 84, 174, 176, 150, 151, 130, 159, 47, 3, 178, 29, 136, 186, 54, 131, 99, 158, 192, 181, 114, 87, 28, 185, 102, 156, 2, 171, 189, 161, 69, 104, 129, 95, 92, 98, 73, 41, 61, 25, 10, 27, 96, 70]],
[min], [nearest-neighbor-end], [TSPB], [[32, 89, 57, 76, 54, 127, 129, 90, 153, 20, 14, 2, 110, 118, 56, 114, 196, 10, 148, 143, 78, 192, 162, 104, 185, 184, 3, 151, 69, 172, 133, 120, 96, 121, 198, 48, 72, 46, 86, 117, 160, 136, 8, 21, 154, 140, 47, 170, 125, 177, 6, 132, 29, 197, 175, 134, 45, 60, 40, 71, 155, 97, 115, 180, 65, 28, 149, 145, 158, 116, 147, 42, 50, 130, 30, 183, 38, 64, 85, 59, 167, 51, 87, 179, 82, 88, 171, 99, 67, 24, 34, 181, 152, 73, 98, 27, 135, 75, 79, 156]],
[max], [nearest-neighbor-end], [TSPB], [[14, 20, 2, 110, 90, 129, 127, 54, 192, 162, 76, 57, 89, 96, 121, 198, 120, 69, 172, 133, 136, 160, 184, 3, 151, 59, 85, 167, 51, 87, 179, 82, 88, 171, 99, 67, 24, 34, 181, 152, 73, 40, 60, 71, 170, 154, 140, 47, 38, 21, 30, 183, 130, 191, 116, 149, 28, 145, 65, 158, 125, 177, 6, 132, 29, 197, 175, 134, 45, 157, 155, 97, 115, 180, 36, 1, 174, 178, 103, 19, 26, 64, 33, 141, 142, 62, 91, 113, 5, 102, 53, 55, 138, 146, 37, 13, 147, 42, 50, 195]],
[min], [nearest-neighbor-anywhere], [TSPA], [[171, 2, 189, 30, 187, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 150, 151, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 113, 89, 42, 106, 93, 47, 147, 50, 3, 169, 1, 178, 101, 29, 163, 136, 186, 164, 8, 174, 131, 54, 9, 33, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 156, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48, 31, 60, 108, 152, 100, 123, 83, 160, 49, 11, 63, 149, 116, 168, 97, 127, 69, 129, 104]],
[max], [nearest-neighbor-anywhere], [TSPA], [[182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 113, 89, 42, 151, 150, 106, 93, 47, 147, 50, 3, 169, 1, 178, 101, 29, 163, 136, 186, 164, 85, 142, 8, 174, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 131, 9, 54, 33, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 156, 35, 185, 45, 87, 96, 189, 2, 171, 187, 30, 141, 28, 180, 132, 76, 90, 83, 160, 123, 100, 152, 49, 97, 127, 95, 168, 63, 149, 116, 60, 108, 80, 91, 71, 157, 48, 31]],
[min], [nearest-neighbor-anywhere], [TSPB], [[82, 87, 179, 181, 24, 34, 152, 167, 73, 51, 85, 59, 64, 168, 189, 183, 30, 176, 21, 38, 47, 140, 154, 97, 141, 40, 60, 157, 45, 134, 175, 71, 155, 115, 180, 6, 29, 132, 36, 197, 170, 26, 125, 177, 158, 65, 145, 28, 149, 13, 146, 37, 116, 147, 42, 50, 191, 130, 121, 198, 96, 48, 43, 156, 120, 133, 136, 172, 69, 160, 8, 117, 122, 151, 173, 184, 3, 72, 46, 86, 89, 57, 185, 76, 104, 162, 192, 54, 80, 127, 129, 90, 52, 182, 153, 74, 20, 14, 2, 110]],
[max], [nearest-neighbor-anywhere], [TSPB], [[58, 121, 198, 96, 48, 164, 43, 156, 166, 92, 120, 133, 136, 172, 168, 189, 183, 30, 21, 69, 160, 8, 117, 95, 122, 151, 98, 111, 22, 27, 173, 184, 3, 137, 109, 72, 46, 86, 32, 89, 83, 57, 79, 185, 75, 135, 76, 144, 104, 162, 159, 54, 192, 106, 80, 127, 129, 90, 52, 182, 153, 150, 84, 119, 66, 11, 24, 34, 152, 25, 73, 59, 107, 85, 101, 51, 167, 82, 87, 179, 88, 126, 181, 67, 31, 163, 99, 39, 171, 17, 74, 20, 14, 188, 2, 9, 93, 118, 68, 110]],
[min], [greedy-cycle], [TSPA], [[31, 116, 149, 168, 63, 11, 49, 60, 108, 152, 100, 90, 123, 83, 160, 97, 127, 69, 171, 2, 189, 30, 187, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 150, 151, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 113, 89, 42, 106, 93, 47, 147, 50, 3, 169, 1, 178, 101, 29, 163, 136, 186, 164, 142, 8, 174, 131, 54, 9, 33, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 156, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48]],
[max], [greedy-cycle], [TSPA], [[18, 16, 52, 33, 9, 54, 174, 8, 142, 164, 186, 136, 163, 29, 101, 178, 1, 169, 3, 50, 147, 47, 93, 106, 42, 89, 113, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 151, 150, 176, 72, 131, 36, 177, 179, 53, 140, 41, 84, 134, 158, 192, 58, 181, 114, 135, 73, 45, 144, 67, 35, 156, 185, 102, 28, 87, 141, 189, 2, 171, 187, 30, 180, 90, 83, 160, 123, 100, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 4, 132, 76, 51]],
[min], [greedy-cycle], [TSPB], [[174, 36, 197, 6, 180, 115, 170, 97, 140, 47, 155, 71, 175, 134, 45, 157, 60, 141, 40, 33, 64, 21, 189, 168, 69, 160, 172, 136, 133, 120, 8, 117, 72, 46, 86, 184, 3, 173, 122, 151, 98, 111, 27, 135, 76, 185, 162, 192, 80, 52, 182, 20, 74, 2, 93, 110, 118, 14, 153, 90, 129, 127, 54, 104, 57, 89, 156, 43, 48, 96, 198, 121, 63, 130, 191, 183, 30, 176, 38, 154, 26, 125, 177, 138, 158, 145, 149, 147, 42, 116, 37, 146, 13, 28, 65, 178, 103, 29, 132, 1]],
[max], [greedy-cycle], [TSPB], [[163, 39, 171, 17, 188, 2, 9, 93, 110, 68, 118, 56, 14, 90, 129, 127, 10, 148, 114, 196, 78, 54, 104, 77, 57, 83, 89, 32, 156, 43, 164, 48, 96, 58, 198, 121, 63, 92, 166, 72, 46, 86, 184, 3, 137, 109, 95, 117, 8, 120, 133, 136, 172, 160, 69, 122, 173, 151, 98, 111, 22, 25, 73, 59, 107, 85, 51, 167, 82, 87, 179, 88, 126, 152, 181, 34, 24, 31, 67, 119, 84, 66, 11, 27, 135, 75, 79, 185, 76, 144, 162, 192, 80, 52, 150, 182, 153, 20, 74, 99]],
[min], [2-regret-r1-d1-nearest-neighbor-anywhere], [TSPA], [[104, 129, 69, 127, 97, 168, 63, 149, 116, 60, 49, 108, 152, 160, 83, 123, 100, 80, 91, 157, 71, 4, 76, 132, 180, 28, 102, 185, 35, 51, 16, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 54, 9, 8, 142, 164, 186, 136, 163, 29, 55, 101, 178, 59, 1, 169, 3, 50, 93, 47, 130, 159, 146, 170, 75, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 42, 89, 113, 106, 150, 174, 176, 72, 134, 84, 58, 158, 192, 181, 114, 135, 73, 45, 87, 141, 30, 187, 189, 2, 171]],
[max], [2-regret-r1-d1-nearest-neighbor-anywhere], [TSPA], [[31, 48, 80, 108, 60, 116, 149, 63, 168, 127, 97, 49, 152, 100, 123, 83, 90, 132, 76, 180, 28, 30, 187, 171, 2, 189, 141, 87, 98, 25, 114, 181, 192, 158, 58, 134, 84, 135, 73, 45, 185, 35, 51, 16, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 54, 9, 143, 62, 109, 164, 186, 136, 184, 178, 29, 55, 101, 59, 1, 169, 3, 50, 93, 85, 142, 8, 174, 176, 150, 106, 113, 89, 42, 151, 138, 182, 57, 64, 88, 78, 193, 153, 107, 130, 146, 170, 159, 47, 37, 147]],
[min], [2-regret-r1-d1-nearest-neighbor-anywhere], [TSPB], [[110, 2, 14, 20, 74, 17, 171, 99, 88, 179, 87, 82, 51, 85, 59, 73, 167, 181, 152, 34, 24, 67, 27, 98, 151, 122, 3, 184, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 124, 21, 183, 30, 38, 47, 154, 140, 64, 33, 40, 155, 71, 60, 157, 45, 134, 175, 62, 36, 197, 6, 180, 115, 170, 125, 177, 19, 29, 132, 103, 178, 65, 145, 28, 149, 13, 146, 37, 116, 147, 42, 50, 130, 63, 121, 198, 96, 48, 156, 89, 57, 185, 76, 162, 192, 54, 80, 127, 129, 90, 153]],
[max], [2-regret-r1-d1-nearest-neighbor-anywhere], [TSPB], [[139, 61, 105, 94, 81, 169, 190, 70, 187, 18, 12, 196, 114, 148, 143, 10, 78, 54, 104, 77, 57, 83, 44, 89, 32, 156, 43, 164, 48, 96, 58, 198, 121, 63, 166, 72, 86, 46, 137, 95, 117, 8, 120, 133, 136, 172, 160, 69, 128, 122, 151, 173, 184, 3, 111, 98, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 181, 152, 34, 24, 31, 67, 66, 11, 27, 135, 185, 76, 162, 192, 80, 127, 129, 90, 52, 182, 153, 74, 20, 14, 188, 2, 9, 93, 110, 68, 118, 56, 131]],
[min], [2-regret-r1-d1-greedy-cycle], [TSPA], [[31, 60, 116, 149, 63, 168, 11, 49, 108, 152, 100, 123, 83, 160, 97, 127, 161, 30, 187, 171, 2, 189, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 174, 150, 106, 113, 89, 42, 151, 138, 182, 57, 64, 107, 88, 78, 193, 153, 75, 170, 146, 159, 130, 47, 93, 50, 3, 169, 1, 178, 101, 55, 29, 163, 136, 186, 164, 142, 8, 9, 54, 33, 131, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48]],
[max], [2-regret-r1-d1-greedy-cycle], [TSPA], [[109, 186, 136, 163, 29, 178, 1, 169, 50, 147, 37, 47, 93, 3, 85, 81, 106, 42, 89, 113, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 150, 174, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 131, 36, 177, 179, 53, 140, 45, 144, 67, 185, 35, 156, 28, 87, 141, 189, 2, 171, 187, 30, 180, 162, 90, 123, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 4, 132, 76, 16, 51, 52, 33, 54, 9, 8, 142, 164]],
[min], [2-regret-r1-d1-greedy-cycle], [TSPB], [[91, 36, 197, 132, 29, 6, 180, 115, 170, 177, 125, 26, 97, 154, 140, 47, 38, 21, 30, 183, 191, 130, 63, 121, 198, 96, 48, 43, 156, 32, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 20, 153, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 126, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 3, 184, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 124, 4, 64, 33, 155, 71, 141, 40, 60, 157, 45, 134, 175, 62]],
[max], [2-regret-r1-d1-greedy-cycle], [TSPB], [[144, 162, 192, 106, 80, 52, 182, 20, 74, 188, 2, 9, 93, 110, 68, 118, 14, 153, 90, 129, 127, 78, 41, 10, 143, 148, 114, 196, 18, 187, 70, 190, 194, 54, 104, 77, 57, 83, 44, 89, 32, 156, 43, 164, 48, 96, 58, 198, 121, 63, 166, 72, 86, 46, 137, 95, 117, 8, 120, 133, 136, 172, 160, 69, 128, 122, 151, 173, 184, 3, 111, 98, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 181, 152, 34, 24, 31, 67, 119, 84, 66, 11, 27, 135, 75, 0, 79, 185, 76]],
[min], [2-regret-r1-d0-nearest-neighbor-anywhere], [TSPA], [[44, 162, 191, 141, 30, 187, 189, 183, 10, 27, 70, 98, 22, 25, 114, 118, 181, 135, 61, 41, 53, 67, 52, 74, 143, 33, 54, 131, 174, 72, 134, 84, 58, 192, 158, 111, 182, 165, 151, 106, 89, 124, 57, 64, 107, 122, 78, 26, 75, 170, 159, 130, 117, 93, 81, 85, 142, 164, 169, 47, 37, 147, 21, 155, 101, 17, 29, 19, 163, 197, 136, 186, 109, 34, 62, 154, 39, 175, 115, 5, 112, 139, 133, 51, 196, 4, 157, 91, 137, 80, 66, 108, 49, 11, 149, 168, 97, 120, 69, 104]],
[max], [2-regret-r1-d0-nearest-neighbor-anywhere], [TSPA], [[78, 122, 107, 103, 42, 43, 117, 47, 37, 147, 21, 46, 86, 55, 17, 29, 19, 163, 197, 136, 195, 56, 164, 142, 85, 3, 81, 174, 194, 9, 33, 143, 62, 15, 34, 154, 39, 175, 115, 5, 112, 139, 18, 4, 196, 51, 190, 74, 177, 53, 140, 61, 121, 84, 134, 65, 0, 151, 165, 182, 111, 158, 192, 181, 118, 114, 25, 22, 70, 10, 183, 166, 198, 32, 92, 125, 120, 110, 104, 188, 95, 168, 119, 63, 167, 49, 160, 148, 23, 162, 68, 44, 14, 66, 80, 91, 137, 126, 48, 77]],
[min], [2-regret-r1-d0-nearest-neighbor-anywhere], [TSPB], [[62, 175, 134, 157, 60, 141, 71, 113, 180, 170, 125, 26, 154, 140, 47, 64, 4, 124, 69, 172, 8, 117, 95, 109, 3, 122, 151, 98, 25, 181, 51, 82, 88, 31, 163, 99, 171, 17, 74, 20, 14, 9, 93, 23, 110, 118, 56, 90, 52, 127, 78, 143, 148, 196, 193, 61, 105, 169, 165, 199, 70, 190, 194, 12, 77, 104, 162, 76, 135, 0, 79, 57, 83, 44, 89, 32, 156, 164, 48, 96, 198, 121, 195, 191, 15, 158, 123, 50, 7, 116, 37, 13, 149, 28, 145, 65, 178, 103, 132, 1]],
[max], [2-regret-r1-d0-nearest-neighbor-anywhere], [TSPB], [[35, 27, 111, 98, 25, 152, 73, 59, 85, 82, 88, 163, 171, 186, 31, 67, 66, 84, 106, 150, 52, 153, 74, 188, 9, 93, 23, 112, 68, 118, 56, 143, 10, 196, 193, 61, 94, 169, 165, 199, 70, 190, 194, 12, 77, 104, 144, 76, 135, 0, 79, 86, 46, 137, 95, 92, 166, 32, 164, 16, 58, 198, 121, 195, 50, 123, 15, 161, 26, 97, 140, 47, 38, 191, 21, 168, 133, 160, 69, 124, 4, 49, 33, 40, 60, 142, 175, 62, 91, 36, 5, 132, 178, 19, 53, 65, 145, 149, 13, 37]],
[min], [2-regret-r1-d0-greedy-cycle], [TSPA], [[133, 139, 112, 5, 175, 39, 154, 62, 34, 109, 186, 136, 24, 163, 19, 29, 17, 101, 155, 21, 147, 37, 47, 169, 164, 142, 85, 81, 93, 117, 130, 159, 170, 75, 193, 107, 64, 57, 124, 89, 106, 151, 0, 72, 134, 84, 58, 158, 192, 181, 118, 114, 25, 98, 70, 27, 10, 183, 166, 171, 92, 110, 129, 188, 97, 161, 12, 160, 123, 100, 152, 108, 49, 63, 82, 77, 199, 48, 126, 137, 91, 71, 4, 76, 132, 68, 162, 23, 145, 180, 102, 35, 67, 45, 61, 140, 177, 52, 190, 51]],
[max], [2-regret-r1-d0-greedy-cycle], [TSPA], [[147, 21, 155, 86, 55, 17, 79, 19, 163, 24, 56, 186, 34, 154, 39, 175, 115, 5, 112, 139, 18, 196, 51, 190, 74, 143, 9, 131, 99, 177, 179, 53, 140, 41, 61, 121, 45, 185, 156, 28, 191, 23, 162, 90, 44, 132, 76, 4, 71, 91, 137, 126, 7, 199, 77, 82, 167, 63, 119, 168, 188, 129, 94, 120, 125, 40, 189, 166, 183, 10, 70, 22, 25, 114, 118, 181, 192, 20, 13, 72, 0, 151, 42, 124, 107, 122, 193, 75, 170, 159, 130, 117, 93, 81, 85, 128, 3, 50, 47, 37]],
[min], [2-regret-r1-d0-greedy-cycle], [TSPB], [[11, 34, 152, 167, 59, 107, 40, 141, 71, 45, 175, 62, 91, 36, 197, 6, 102, 103, 178, 65, 145, 149, 146, 37, 116, 42, 50, 195, 121, 63, 120, 133, 168, 21, 30, 191, 15, 161, 26, 154, 140, 47, 64, 4, 124, 69, 128, 122, 151, 98, 22, 3, 135, 0, 86, 72, 166, 156, 32, 89, 44, 83, 57, 77, 194, 190, 70, 199, 169, 105, 61, 193, 148, 143, 10, 41, 54, 162, 106, 80, 52, 90, 56, 118, 100, 93, 188, 14, 20, 74, 17, 171, 99, 163, 88, 179, 126, 31, 67, 66]],
[max], [2-regret-r1-d0-greedy-cycle], [TSPB], [[21, 168, 172, 117, 109, 122, 4, 33, 47, 140, 97, 141, 71, 113, 5, 36, 108, 62, 175, 142, 45, 107, 59, 73, 25, 152, 126, 82, 88, 163, 99, 171, 17, 74, 14, 9, 93, 110, 118, 131, 143, 10, 196, 193, 139, 105, 165, 199, 70, 190, 194, 12, 77, 104, 144, 162, 106, 127, 90, 182, 150, 84, 66, 35, 27, 135, 0, 46, 83, 44, 89, 32, 43, 164, 16, 58, 198, 121, 195, 50, 42, 116, 37, 13, 149, 28, 65, 178, 103, 102, 19, 53, 55, 138, 158, 123, 15, 161, 130, 30]],
[min], [2-regret-r2-d1-nearest-neighbor-anywhere], [TSPA], [[171, 2, 189, 187, 30, 141, 87, 28, 180, 185, 35, 51, 16, 67, 144, 52, 177, 36, 131, 54, 9, 33, 179, 53, 140, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 174, 150, 106, 89, 42, 151, 138, 182, 57, 64, 107, 88, 78, 193, 153, 75, 170, 159, 130, 47, 93, 50, 3, 1, 85, 142, 164, 184, 178, 101, 55, 29, 163, 136, 186, 154, 39, 175, 115, 112, 139, 71, 157, 91, 80, 38, 76, 132, 90, 123, 152, 108, 49, 60, 149, 116, 63, 168, 97, 127, 69, 129, 104]],
[max], [2-regret-r2-d1-nearest-neighbor-anywhere], [TSPA], [[104, 129, 69, 127, 97, 168, 63, 149, 116, 60, 49, 123, 152, 108, 31, 48, 80, 91, 157, 71, 4, 76, 132, 180, 30, 187, 141, 87, 28, 102, 185, 35, 67, 144, 16, 51, 139, 112, 115, 175, 39, 154, 136, 186, 34, 62, 143, 33, 52, 179, 53, 140, 177, 36, 131, 54, 9, 8, 84, 73, 135, 58, 192, 158, 134, 72, 176, 174, 85, 142, 164, 184, 178, 29, 55, 101, 59, 1, 169, 3, 50, 93, 106, 150, 89, 42, 151, 138, 182, 57, 64, 88, 78, 193, 153, 107, 130, 159, 47, 147]],
[min], [2-regret-r2-d1-nearest-neighbor-anywhere], [TSPB], [[45, 134, 175, 71, 60, 40, 33, 64, 47, 140, 154, 26, 125, 177, 170, 115, 180, 6, 197, 29, 132, 103, 178, 65, 145, 28, 149, 13, 146, 37, 116, 147, 50, 130, 30, 21, 183, 63, 121, 198, 96, 48, 156, 89, 57, 79, 185, 76, 104, 162, 192, 54, 190, 70, 187, 196, 114, 10, 78, 127, 80, 129, 90, 153, 20, 14, 2, 17, 171, 99, 163, 67, 24, 34, 88, 87, 82, 179, 51, 85, 59, 73, 167, 181, 152, 25, 98, 151, 3, 184, 122, 69, 160, 172, 136, 133, 120, 72, 46, 86]],
[max], [2-regret-r2-d1-nearest-neighbor-anywhere], [TSPB], [[1, 174, 62, 175, 45, 60, 71, 36, 197, 132, 29, 103, 6, 180, 115, 170, 177, 125, 26, 97, 154, 140, 47, 38, 21, 30, 183, 189, 168, 133, 63, 121, 198, 96, 48, 43, 156, 166, 120, 117, 8, 136, 172, 160, 69, 128, 122, 151, 98, 111, 27, 3, 184, 137, 46, 72, 86, 75, 135, 76, 185, 79, 89, 57, 77, 104, 162, 192, 54, 12, 194, 190, 70, 187, 169, 81, 94, 105, 61, 139, 196, 114, 148, 143, 10, 78, 127, 80, 129, 90, 153, 74, 20, 14, 2, 9, 93, 110, 118, 56]],
[min], [2-regret-r2-d1-greedy-cycle], [TSPA], [[102, 87, 141, 189, 2, 171, 187, 30, 161, 127, 97, 168, 63, 149, 116, 60, 49, 160, 123, 100, 152, 108, 31, 48, 80, 38, 91, 157, 71, 4, 76, 132, 162, 180, 28, 156, 35, 51, 16, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 9, 54, 8, 142, 164, 186, 136, 163, 29, 178, 59, 1, 169, 3, 50, 93, 47, 130, 159, 146, 170, 75, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 42, 89, 113, 106, 150, 174, 176, 72, 134, 84, 58, 158, 192, 181, 114, 135, 73, 45, 185]],
[max], [2-regret-r2-d1-greedy-cycle], [TSPA], [[124, 89, 42, 106, 150, 151, 176, 174, 72, 134, 84, 58, 158, 192, 181, 114, 135, 73, 45, 87, 141, 189, 2, 171, 187, 30, 28, 180, 162, 90, 123, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 132, 76, 196, 51, 16, 35, 185, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 9, 54, 8, 164, 85, 81, 93, 3, 1, 50, 59, 178, 184, 186, 136, 163, 29, 101, 46, 21, 147, 37, 47, 130, 159, 146, 170, 75, 153, 193, 78, 88, 107, 64, 57, 182]],
[min], [2-regret-r2-d1-greedy-cycle], [TSPB], [[124, 4, 64, 33, 40, 60, 71, 155, 157, 45, 134, 175, 36, 29, 132, 6, 115, 170, 177, 125, 26, 97, 47, 140, 154, 38, 21, 183, 30, 191, 130, 50, 195, 121, 198, 96, 48, 43, 156, 32, 89, 57, 79, 185, 104, 54, 78, 10, 196, 114, 148, 143, 56, 118, 110, 93, 2, 14, 20, 74, 153, 90, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 3, 184, 137, 46, 72, 166, 120, 133, 136, 172, 160, 69]],
[max], [2-regret-r2-d1-greedy-cycle], [TSPB], [[126, 181, 152, 34, 31, 67, 66, 119, 84, 150, 186, 163, 99, 39, 171, 17, 74, 20, 188, 2, 9, 93, 23, 112, 110, 68, 118, 14, 153, 182, 52, 90, 129, 127, 80, 106, 192, 54, 159, 162, 144, 104, 77, 57, 79, 185, 76, 135, 75, 3, 184, 137, 46, 86, 72, 166, 156, 32, 89, 43, 164, 48, 96, 58, 198, 121, 130, 30, 183, 63, 120, 92, 117, 8, 133, 136, 172, 160, 69, 128, 122, 173, 151, 98, 111, 27, 35, 11, 24, 25, 167, 73, 59, 107, 85, 51, 179, 82, 87, 88]],
[min], [2-regret-r1-d2-nearest-neighbor-anywhere], [TSPA], [[171, 2, 189, 30, 187, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 174, 150, 106, 113, 89, 42, 151, 138, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 47, 93, 50, 3, 169, 1, 178, 101, 29, 163, 136, 186, 164, 142, 8, 9, 54, 33, 131, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 48, 31, 80, 38, 100, 123, 83, 160, 152, 108, 49, 60, 116, 149, 63, 168, 97, 127, 69, 129, 104]],
[max], [2-regret-r1-d2-nearest-neighbor-anywhere], [TSPA], [[147, 47, 159, 170, 146, 130, 107, 153, 193, 78, 88, 64, 57, 182, 138, 151, 150, 42, 89, 113, 106, 93, 50, 3, 169, 1, 101, 29, 178, 136, 186, 184, 128, 85, 164, 8, 174, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 99, 131, 9, 54, 33, 36, 177, 52, 179, 53, 140, 45, 185, 144, 67, 16, 51, 35, 156, 180, 28, 87, 141, 189, 2, 171, 187, 30, 76, 132, 90, 83, 160, 123, 100, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 80, 91, 71, 157, 48, 31]],
[min], [2-regret-r1-d2-nearest-neighbor-anywhere], [TSPB], [[121, 198, 96, 48, 43, 156, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 74, 20, 153, 182, 52, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 3, 184, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 168, 189, 21, 183, 130, 191, 30, 176, 38, 47, 140, 154, 97, 26, 125, 177, 170, 115, 180, 6, 197, 36, 29, 132, 103, 178, 65, 145, 28, 149, 13, 146, 37, 116, 147, 42]],
[max], [2-regret-r1-d2-nearest-neighbor-anywhere], [TSPB], [[166, 72, 46, 86, 137, 3, 184, 173, 27, 111, 98, 151, 122, 128, 69, 160, 172, 136, 133, 8, 117, 92, 120, 63, 121, 198, 58, 96, 48, 164, 43, 156, 32, 89, 44, 83, 57, 79, 185, 75, 135, 76, 144, 104, 162, 159, 54, 192, 127, 52, 182, 153, 20, 74, 188, 2, 14, 9, 93, 110, 68, 118, 56, 143, 148, 114, 196, 10, 41, 78, 90, 129, 80, 150, 84, 119, 66, 67, 31, 11, 24, 34, 25, 152, 181, 167, 73, 59, 107, 85, 51, 179, 87, 82, 88, 163, 99, 39, 171, 17]],
[min], [2-regret-r1-d2-greedy-cycle], [TSPA], [[38, 91, 157, 71, 4, 76, 132, 180, 28, 102, 185, 35, 156, 51, 16, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 54, 9, 8, 142, 164, 186, 136, 163, 29, 101, 178, 1, 169, 3, 50, 93, 47, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 42, 89, 113, 106, 150, 174, 176, 72, 134, 84, 58, 158, 192, 181, 114, 135, 73, 45, 87, 141, 189, 2, 171, 187, 30, 161, 127, 97, 168, 63, 149, 116, 60, 49, 160, 83, 123, 90, 100, 152, 108, 31, 48, 80]],
[max], [2-regret-r1-d2-greedy-cycle], [TSPA], [[39, 186, 136, 163, 29, 178, 1, 169, 50, 147, 47, 93, 3, 85, 164, 8, 174, 150, 106, 42, 89, 113, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 9, 54, 131, 36, 177, 179, 53, 140, 144, 67, 35, 185, 45, 87, 141, 189, 2, 171, 187, 30, 28, 180, 90, 83, 123, 100, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 4, 132, 76, 16, 51, 52, 33, 143, 62, 154]],
[min], [2-regret-r1-d2-greedy-cycle], [TSPB], [[91, 36, 197, 132, 29, 6, 180, 115, 170, 177, 125, 26, 154, 140, 38, 176, 30, 183, 191, 130, 63, 121, 198, 96, 48, 43, 156, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 74, 20, 153, 182, 52, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 3, 184, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 168, 189, 21, 47, 97, 155, 71, 141, 40, 60, 157, 45, 134, 175, 62]],
[max], [2-regret-r1-d2-greedy-cycle], [TSPB], [[16, 58, 198, 121, 96, 48, 120, 92, 117, 8, 133, 136, 172, 160, 69, 128, 122, 151, 98, 111, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 152, 181, 34, 24, 31, 67, 119, 84, 66, 11, 27, 173, 3, 184, 137, 46, 72, 86, 75, 135, 76, 162, 192, 80, 52, 182, 20, 74, 99, 39, 171, 17, 188, 2, 9, 93, 110, 68, 118, 14, 153, 90, 129, 127, 10, 143, 148, 114, 196, 61, 187, 70, 190, 194, 18, 41, 78, 54, 104, 144, 185, 79, 57, 83, 89, 32, 156, 43, 164]],
[min], [ls-steepest-two-edges-random], [TSPA], [[57, 42, 89, 106, 113, 107, 153, 193, 78, 170, 159, 130, 93, 47, 37, 147, 59, 1, 169, 50, 3, 85, 142, 8, 164, 184, 178, 101, 55, 29, 163, 136, 186, 62, 33, 9, 54, 131, 36, 177, 52, 179, 53, 140, 144, 67, 185, 16, 51, 35, 156, 28, 180, 90, 123, 100, 132, 76, 4, 71, 157, 91, 80, 48, 31, 60, 108, 152, 49, 11, 63, 149, 116, 168, 97, 127, 69, 129, 104, 171, 2, 187, 30, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 176, 174, 150, 151, 182]],
[max], [ls-steepest-two-edges-random], [TSPA], [[1, 169, 3, 50, 93, 47, 130, 159, 170, 107, 89, 42, 106, 150, 151, 57, 182, 158, 192, 114, 25, 98, 10, 183, 32, 92, 171, 2, 189, 187, 141, 145, 30, 161, 69, 127, 95, 97, 160, 148, 83, 123, 152, 66, 108, 49, 11, 63, 119, 168, 116, 149, 60, 82, 31, 48, 80, 91, 38, 100, 90, 162, 132, 76, 4, 71, 157, 112, 33, 9, 54, 36, 177, 179, 52, 144, 67, 16, 51, 35, 185, 102, 28, 180, 87, 45, 53, 140, 73, 135, 58, 84, 134, 176, 174, 8, 164, 178, 29, 101]],
[min], [ls-steepest-two-edges-random], [TSPB], [[51, 85, 59, 167, 181, 152, 34, 24, 67, 66, 27, 111, 98, 151, 173, 122, 117, 8, 120, 133, 136, 172, 160, 69, 189, 21, 183, 30, 38, 47, 64, 40, 60, 45, 134, 175, 71, 140, 154, 125, 170, 115, 180, 6, 197, 36, 29, 132, 178, 65, 145, 28, 149, 116, 147, 42, 121, 198, 96, 48, 156, 89, 57, 86, 72, 46, 137, 184, 3, 135, 76, 162, 192, 54, 187, 70, 190, 94, 105, 81, 196, 114, 148, 10, 90, 129, 127, 80, 153, 14, 2, 20, 74, 171, 99, 88, 126, 179, 87, 82]],
[max], [ls-steepest-two-edges-random], [TSPB], [[57, 190, 70, 18, 187, 169, 81, 94, 105, 61, 139, 193, 196, 114, 10, 148, 56, 118, 90, 129, 127, 54, 80, 52, 182, 153, 20, 14, 2, 171, 87, 179, 85, 59, 51, 167, 151, 122, 3, 184, 117, 8, 92, 120, 133, 136, 172, 160, 69, 21, 30, 38, 154, 140, 47, 64, 40, 141, 155, 71, 60, 134, 175, 62, 36, 197, 180, 115, 170, 125, 177, 6, 29, 132, 178, 65, 28, 149, 37, 116, 147, 7, 42, 121, 198, 58, 96, 48, 156, 89, 72, 46, 86, 135, 27, 34, 24, 67, 76, 185]],
[min], [ls-steepest-two-nodes-random], [TSPA], [[1, 178, 184, 177, 185, 102, 28, 4, 71, 157, 91, 80, 76, 132, 180, 141, 187, 2, 189, 87, 45, 135, 181, 114, 98, 30, 63, 11, 49, 123, 83, 160, 97, 127, 95, 168, 116, 149, 60, 31, 48, 108, 152, 69, 129, 104, 92, 171, 192, 182, 138, 158, 58, 73, 140, 53, 179, 52, 144, 67, 35, 156, 51, 16, 33, 9, 54, 8, 174, 176, 151, 57, 64, 159, 130, 106, 150, 142, 164, 186, 136, 29, 101, 147, 47, 50, 3, 93, 113, 107, 153, 88, 89, 134, 84, 99, 36, 131, 85, 169]],
[max], [ls-steepest-two-nodes-random], [TSPA], [[116, 60, 71, 115, 39, 136, 178, 186, 62, 90, 123, 83, 160, 30, 141, 180, 28, 102, 185, 67, 144, 52, 54, 194, 8, 36, 177, 179, 53, 140, 41, 61, 73, 45, 135, 181, 192, 182, 57, 107, 88, 78, 153, 159, 152, 108, 49, 97, 187, 189, 87, 98, 58, 84, 99, 131, 9, 164, 1, 169, 85, 33, 51, 4, 91, 80, 31, 48, 157, 5, 112, 139, 143, 174, 93, 3, 50, 147, 47, 130, 89, 106, 2, 92, 171, 114, 158, 151, 150, 35, 156, 132, 76, 16, 176, 72, 134, 168, 63, 149]],
[min], [ls-steepest-two-nodes-random], [TSPB], [[87, 82, 60, 71, 155, 33, 64, 88, 163, 99, 150, 80, 129, 127, 54, 192, 162, 144, 185, 104, 78, 196, 114, 148, 10, 76, 135, 117, 8, 160, 151, 67, 171, 74, 20, 14, 153, 90, 187, 70, 169, 81, 105, 94, 190, 57, 89, 48, 96, 198, 121, 30, 21, 189, 168, 133, 136, 172, 69, 38, 97, 115, 170, 125, 26, 154, 140, 47, 40, 45, 134, 175, 36, 197, 6, 29, 132, 65, 145, 28, 149, 158, 130, 183, 120, 72, 46, 86, 184, 3, 152, 181, 167, 51, 85, 59, 73, 34, 24, 179]],
[max], [ls-steepest-two-nodes-random], [TSPB], [[160, 156, 89, 190, 70, 187, 162, 24, 34, 98, 151, 122, 8, 96, 48, 120, 117, 184, 3, 75, 135, 104, 144, 27, 157, 175, 134, 45, 107, 59, 73, 136, 133, 121, 198, 72, 192, 127, 90, 129, 183, 130, 191, 30, 176, 21, 38, 140, 47, 84, 80, 74, 20, 14, 153, 182, 179, 82, 87, 88, 171, 99, 26, 125, 132, 29, 6, 71, 60, 85, 167, 86, 79, 57, 185, 76, 66, 67, 31, 181, 152, 170, 115, 51, 17, 2, 110, 10, 114, 196, 54, 46, 172, 154, 97, 155, 40, 33, 64, 69]],
[min], [ls-steepest-two-edges-greedy], [TSPA], [[91, 157, 71, 4, 76, 132, 180, 28, 102, 185, 35, 156, 51, 16, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 9, 54, 8, 142, 164, 186, 136, 163, 29, 101, 178, 1, 169, 3, 50, 93, 47, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 42, 89, 113, 106, 150, 174, 176, 72, 134, 84, 58, 158, 192, 181, 114, 135, 73, 45, 87, 141, 189, 2, 171, 187, 30, 161, 127, 97, 168, 116, 149, 63, 49, 160, 83, 123, 90, 100, 152, 108, 60, 31, 48, 80, 38]],
[max], [ls-steepest-two-edges-greedy], [TSPA], [[39, 62, 143, 33, 9, 54, 131, 36, 177, 179, 52, 16, 51, 132, 76, 4, 71, 157, 91, 80, 48, 31, 108, 60, 116, 149, 63, 168, 127, 97, 49, 152, 100, 123, 83, 90, 180, 28, 30, 187, 171, 2, 189, 141, 87, 45, 185, 35, 67, 144, 53, 140, 41, 84, 73, 135, 114, 181, 58, 192, 158, 134, 72, 176, 151, 138, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 113, 89, 42, 106, 150, 174, 8, 164, 85, 3, 93, 47, 147, 50, 169, 1, 178, 29, 163, 136, 186, 154]],
[min], [ls-steepest-two-edges-greedy], [TSPB], [[91, 36, 197, 132, 29, 6, 180, 115, 170, 177, 125, 26, 154, 140, 38, 176, 30, 183, 191, 130, 63, 121, 198, 96, 48, 43, 156, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 74, 20, 153, 182, 52, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 184, 3, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 168, 189, 21, 47, 97, 155, 71, 141, 40, 60, 157, 45, 134, 175, 62]],
[max], [ls-steepest-two-edges-greedy], [TSPB], [[16, 58, 121, 198, 96, 48, 120, 92, 117, 8, 133, 136, 172, 160, 69, 128, 122, 151, 111, 98, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 181, 152, 34, 24, 31, 67, 119, 84, 66, 11, 27, 3, 184, 173, 137, 46, 72, 86, 75, 135, 76, 162, 192, 80, 52, 182, 153, 14, 20, 74, 99, 39, 171, 17, 188, 2, 9, 93, 110, 68, 118, 90, 129, 127, 10, 143, 148, 114, 196, 61, 187, 70, 190, 194, 18, 41, 78, 54, 104, 144, 185, 79, 57, 83, 89, 32, 156, 43, 164]],
[min], [ls-steepest-two-nodes-greedy], [TSPA], [[101, 55, 29, 178, 184, 136, 186, 164, 1, 169, 3, 50, 93, 85, 174, 8, 54, 9, 33, 131, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48, 31, 108, 152, 100, 123, 83, 160, 49, 60, 116, 149, 63, 168, 97, 127, 161, 30, 187, 171, 2, 189, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 150, 106, 113, 89, 42, 151, 138, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 47, 37, 147]],
[max], [ls-steepest-two-nodes-greedy], [TSPA], [[154, 186, 136, 163, 29, 178, 1, 169, 50, 147, 47, 93, 3, 85, 164, 8, 174, 150, 106, 42, 89, 113, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 131, 54, 9, 36, 177, 179, 53, 140, 144, 67, 35, 185, 45, 87, 141, 189, 2, 171, 187, 30, 28, 180, 90, 83, 123, 100, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 4, 76, 132, 51, 16, 52, 33, 143, 62, 39]],
[min], [ls-steepest-two-nodes-greedy], [TSPB], [[91, 36, 197, 132, 29, 6, 180, 115, 170, 177, 125, 26, 154, 140, 38, 176, 30, 183, 191, 130, 63, 121, 198, 96, 48, 43, 156, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 74, 20, 153, 182, 52, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 184, 3, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 168, 189, 21, 47, 97, 155, 71, 141, 40, 60, 157, 45, 134, 175, 62]],
[max], [ls-steepest-two-nodes-greedy], [TSPB], [[16, 58, 121, 198, 96, 48, 120, 92, 117, 8, 133, 136, 172, 160, 69, 128, 122, 151, 111, 98, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 181, 152, 34, 24, 31, 67, 119, 84, 66, 11, 27, 3, 184, 173, 137, 46, 72, 86, 75, 135, 76, 162, 192, 80, 52, 182, 20, 74, 99, 39, 171, 17, 188, 2, 9, 93, 110, 68, 118, 14, 153, 90, 129, 127, 10, 143, 148, 114, 196, 61, 187, 70, 190, 194, 18, 41, 78, 54, 104, 144, 185, 79, 57, 83, 89, 32, 156, 43, 164]],
[min], [ls-greedy-two-edges-random], [TSPA], [[35, 180, 28, 87, 141, 30, 187, 2, 171, 69, 127, 97, 95, 168, 63, 149, 116, 60, 49, 108, 152, 80, 91, 38, 100, 123, 83, 160, 148, 90, 162, 132, 76, 4, 71, 157, 115, 112, 139, 51, 16, 33, 9, 54, 131, 36, 99, 84, 58, 134, 176, 174, 8, 142, 164, 186, 136, 29, 178, 1, 169, 3, 50, 147, 47, 93, 113, 106, 150, 151, 42, 89, 130, 159, 146, 170, 153, 193, 78, 88, 107, 57, 182, 138, 158, 192, 181, 114, 135, 73, 45, 41, 140, 53, 179, 177, 52, 144, 67, 185]],
[max], [ls-greedy-two-edges-random], [TSPA], [[9, 164, 85, 93, 113, 130, 107, 89, 57, 88, 78, 153, 159, 37, 147, 47, 50, 3, 169, 1, 59, 101, 55, 17, 29, 178, 184, 163, 136, 186, 62, 143, 33, 52, 16, 51, 133, 139, 112, 115, 4, 76, 132, 71, 157, 91, 80, 48, 31, 60, 149, 63, 152, 123, 180, 172, 156, 35, 102, 28, 87, 141, 187, 30, 161, 97, 95, 127, 69, 129, 104, 92, 171, 2, 189, 98, 114, 135, 73, 45, 185, 67, 144, 140, 53, 179, 177, 36, 131, 99, 84, 58, 192, 158, 134, 176, 106, 174, 8, 54]],
[min], [ls-greedy-two-edges-random], [TSPB], [[14, 20, 153, 90, 129, 127, 10, 148, 114, 196, 61, 105, 94, 81, 70, 190, 57, 104, 54, 192, 162, 76, 3, 184, 173, 151, 122, 69, 160, 172, 136, 133, 120, 72, 46, 89, 48, 96, 198, 121, 42, 147, 116, 149, 28, 145, 158, 26, 125, 177, 170, 115, 6, 29, 132, 197, 36, 175, 134, 45, 157, 60, 40, 141, 71, 155, 97, 140, 154, 191, 130, 30, 183, 21, 38, 47, 64, 33, 85, 59, 73, 51, 167, 181, 152, 34, 24, 66, 67, 31, 179, 82, 87, 88, 99, 171, 17, 74, 188, 2]],
[max], [ls-greedy-two-edges-random], [TSPB], [[121, 130, 50, 147, 116, 149, 28, 145, 125, 170, 115, 6, 29, 132, 197, 175, 134, 45, 157, 60, 71, 97, 154, 140, 47, 40, 33, 64, 38, 21, 30, 183, 69, 160, 128, 122, 151, 98, 167, 73, 59, 85, 51, 181, 152, 34, 24, 11, 27, 75, 135, 76, 66, 67, 99, 171, 74, 20, 14, 2, 110, 68, 118, 153, 90, 129, 127, 10, 114, 196, 54, 192, 162, 144, 104, 185, 79, 57, 89, 32, 156, 166, 72, 86, 46, 137, 184, 3, 173, 117, 92, 120, 8, 172, 136, 133, 63, 48, 96, 198]],
[min], [ls-greedy-two-nodes-random], [TSPA], [[107, 113, 89, 42, 151, 150, 176, 139, 112, 115, 39, 136, 186, 143, 52, 144, 53, 58, 158, 111, 192, 181, 114, 98, 2, 171, 127, 63, 149, 49, 123, 90, 132, 76, 180, 141, 187, 30, 161, 97, 168, 116, 60, 108, 152, 80, 91, 157, 71, 4, 51, 16, 156, 35, 67, 185, 102, 28, 87, 45, 106, 93, 47, 147, 178, 1, 169, 50, 3, 85, 164, 9, 33, 54, 194, 8, 174, 72, 134, 84, 41, 61, 135, 73, 140, 179, 177, 36, 131, 138, 182, 57, 64, 88, 78, 193, 153, 170, 159, 130]],
[max], [ls-greedy-two-nodes-random], [TSPA], [[45, 135, 158, 151, 106, 150, 98, 2, 171, 104, 129, 69, 174, 85, 3, 50, 47, 130, 159, 146, 170, 107, 48, 31, 80, 73, 58, 134, 89, 113, 93, 176, 84, 41, 140, 53, 54, 164, 184, 186, 9, 143, 16, 51, 139, 71, 91, 157, 115, 39, 154, 136, 178, 29, 101, 1, 8, 185, 102, 28, 156, 35, 67, 144, 4, 76, 132, 90, 123, 83, 160, 25, 114, 192, 57, 182, 181, 189, 161, 127, 97, 168, 49, 63, 149, 116, 60, 108, 152, 179, 177, 36, 131, 33, 52, 180, 30, 187, 141, 87]],
[min], [ls-greedy-two-nodes-random], [TSPB], [[69, 47, 140, 154, 38, 133, 136, 172, 160, 8, 117, 184, 3, 46, 120, 42, 147, 116, 149, 28, 145, 65, 71, 134, 175, 62, 36, 197, 132, 29, 6, 115, 170, 125, 177, 158, 50, 96, 48, 198, 121, 130, 30, 183, 21, 64, 40, 60, 45, 85, 76, 104, 57, 185, 27, 25, 73, 167, 152, 67, 66, 192, 54, 80, 127, 129, 52, 153, 90, 10, 114, 196, 105, 94, 81, 187, 70, 190, 89, 72, 86, 162, 74, 20, 14, 2, 171, 99, 31, 24, 34, 181, 179, 87, 82, 51, 59, 98, 151, 122]],
[max], [ls-greedy-two-nodes-random], [TSPB], [[54, 94, 105, 10, 127, 99, 88, 179, 51, 167, 98, 184, 3, 27, 135, 76, 86, 46, 72, 117, 8, 172, 160, 151, 24, 74, 20, 14, 153, 192, 185, 96, 198, 121, 63, 133, 136, 69, 59, 85, 40, 71, 155, 125, 177, 158, 130, 89, 190, 70, 187, 18, 162, 34, 45, 134, 175, 60, 141, 38, 21, 30, 120, 156, 32, 57, 196, 114, 104, 48, 147, 116, 149, 28, 145, 65, 132, 29, 6, 170, 97, 171, 2, 93, 110, 68, 118, 90, 129, 80, 64, 47, 154, 140, 73, 152, 181, 82, 87, 67]],
[min], [ls-greedy-two-edges-greedy], [TSPA], [[55, 101, 147, 37, 47, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 42, 89, 113, 106, 150, 176, 72, 134, 84, 58, 158, 192, 181, 114, 135, 73, 45, 87, 141, 189, 2, 171, 187, 30, 161, 127, 97, 168, 63, 149, 116, 60, 49, 160, 83, 123, 100, 152, 108, 31, 48, 80, 91, 157, 71, 4, 76, 132, 180, 28, 102, 185, 35, 51, 16, 67, 144, 140, 53, 179, 52, 177, 36, 131, 33, 9, 54, 8, 174, 85, 93, 50, 3, 169, 1, 164, 186, 136, 184, 178, 29]],
[max], [ls-greedy-two-edges-greedy], [TSPA], [[154, 186, 136, 163, 29, 178, 1, 169, 50, 147, 47, 93, 3, 85, 164, 8, 174, 150, 106, 42, 89, 113, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 177, 179, 53, 140, 144, 67, 35, 185, 45, 87, 141, 189, 2, 171, 187, 30, 28, 180, 90, 83, 123, 100, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 4, 76, 132, 51, 16, 52, 36, 131, 54, 9, 33, 143, 62, 39]],
[min], [ls-greedy-two-edges-greedy], [TSPB], [[91, 36, 197, 132, 29, 6, 180, 115, 170, 177, 125, 26, 154, 140, 38, 176, 30, 183, 191, 130, 63, 121, 198, 96, 48, 43, 156, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 74, 20, 153, 182, 52, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 184, 3, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 168, 189, 21, 47, 97, 155, 71, 141, 40, 60, 157, 45, 134, 175, 62]],
[max], [ls-greedy-two-edges-greedy], [TSPB], [[16, 58, 121, 198, 96, 48, 120, 92, 117, 8, 133, 136, 172, 160, 69, 128, 122, 151, 111, 98, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 181, 152, 34, 24, 31, 67, 119, 84, 66, 11, 27, 3, 184, 173, 137, 46, 72, 86, 75, 135, 76, 162, 192, 80, 52, 182, 99, 39, 171, 17, 74, 20, 14, 188, 2, 9, 93, 110, 68, 118, 153, 90, 129, 127, 10, 143, 148, 114, 196, 61, 187, 70, 190, 194, 18, 41, 78, 54, 104, 144, 185, 79, 57, 83, 89, 32, 156, 43, 164]],
[min], [ls-greedy-two-nodes-greedy], [TSPA], [[101, 55, 29, 178, 184, 136, 186, 164, 1, 169, 3, 50, 93, 85, 174, 8, 54, 9, 33, 131, 36, 177, 52, 179, 53, 140, 144, 67, 16, 51, 35, 185, 102, 28, 180, 132, 76, 4, 71, 157, 91, 80, 48, 31, 108, 152, 100, 123, 83, 160, 49, 60, 116, 149, 63, 168, 97, 127, 161, 30, 187, 171, 2, 189, 141, 87, 45, 73, 135, 114, 181, 192, 158, 58, 84, 134, 72, 176, 150, 106, 113, 89, 42, 151, 138, 182, 57, 64, 107, 88, 78, 193, 153, 170, 146, 159, 130, 47, 37, 147]],
[max], [ls-greedy-two-nodes-greedy], [TSPA], [[154, 186, 136, 163, 29, 178, 1, 169, 50, 147, 47, 93, 3, 85, 164, 8, 174, 150, 106, 42, 89, 113, 130, 159, 146, 170, 153, 193, 78, 88, 107, 64, 57, 182, 138, 151, 176, 72, 134, 158, 192, 58, 181, 114, 135, 73, 41, 84, 131, 54, 9, 36, 177, 179, 53, 140, 144, 67, 35, 185, 45, 87, 141, 189, 2, 171, 187, 30, 28, 180, 90, 83, 123, 100, 152, 49, 97, 127, 168, 63, 149, 116, 60, 108, 31, 48, 80, 91, 157, 71, 4, 76, 132, 51, 16, 52, 33, 143, 62, 39]],
[min], [ls-greedy-two-nodes-greedy], [TSPB], [[91, 36, 197, 132, 29, 6, 180, 115, 170, 177, 125, 26, 154, 140, 38, 176, 30, 183, 191, 130, 63, 121, 198, 96, 48, 43, 156, 89, 57, 79, 185, 104, 54, 196, 114, 10, 90, 14, 2, 74, 20, 153, 182, 52, 129, 127, 80, 192, 162, 76, 135, 27, 11, 66, 67, 24, 34, 152, 181, 88, 179, 87, 82, 167, 51, 85, 59, 73, 98, 151, 122, 173, 184, 3, 86, 46, 72, 117, 8, 120, 133, 136, 172, 160, 69, 168, 189, 21, 47, 97, 155, 71, 141, 40, 60, 157, 45, 134, 175, 62]],
[max], [ls-greedy-two-nodes-greedy], [TSPB], [[16, 58, 121, 198, 96, 48, 120, 92, 117, 8, 133, 136, 172, 160, 69, 128, 122, 151, 111, 98, 25, 73, 59, 85, 51, 167, 82, 87, 179, 88, 126, 181, 152, 34, 24, 31, 67, 119, 84, 66, 11, 27, 3, 184, 173, 137, 46, 72, 86, 75, 135, 76, 162, 192, 80, 52, 182, 20, 74, 99, 39, 171, 17, 188, 2, 9, 93, 110, 68, 118, 14, 153, 90, 129, 127, 10, 143, 148, 114, 196, 61, 187, 70, 190, 194, 18, 41, 78, 54, 104, 144, 185, 79, 57, 83, 89, 32, 156, 43, 164]]
)
