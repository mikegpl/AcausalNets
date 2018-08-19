#=
clusterization:
- Julia version: 
- Author: marcin
- Date: 2018-08-19
=#

using LightGraphs
import AcausalNets.Structures:
    DiscreteBayesNet,
    parent_systems,
    systems,
    system_to_node

import AcausalNets.Systems:
    DiscreteSystem,
    ncategories

import AcausalNets.Common:
    is_subset

const MoralGraph = Graph

function moral_graph(dbn::DiscreteBayesNet)::MoralGraph
    result = MoralGraph(deepcopy(dbn.dag))
    for sys in systems(dbn)
        for p1 in parent_systems(sys, dbn)
            for p2 in parent_systems(sys, dbn)
                p1_ind = system_to_node(p1, dbn)
                p2_ind = system_to_node(p2, dbn)
                if(p1_ind!=p2_ind)
                    add_edge!(result, p1_ind, p2_ind)
                end
            end
        end
    end
    return result
end

const TriangulatedGraph = Graph
const SystemCluster = Vector{DiscreteSystem}

function triangulate(mg::MoralGraph, dbn::DiscreteBayesNet)::Tuple{TriangulatedGraph, Vector{SystemCluster}}
    mg_copy = [false for _ in vertices(mg)]
    mg = deepcopy(mg)
    nl = systems(dbn)
    clusters = Set[]
    while(!all(mg_copy))
        least_edges_to_be_added = Inf
        chosen_vertex = 0
        chosen_cluster = Set()
        for v=1:length(mg_copy)
            if mg_copy[v]
                continue
            else
                cluster = Set()
                for e in edges(mg)
                    if (v==src(e) || v==dst(e)) && !mg_copy[src(e)] && !mg_copy[dst(e)]
                        push!(cluster, src(e))
                        push!(cluster, dst(e))
                    end
                end
                edges_todo = 0
                for v1 in cluster
                    for v2 in cluster
                        if v1 != v2 && !in((v1, v2), edges(mg))
                            edges_todo +=1
                        end
                    end
                end
                edges_todo /= 2

                if edges_todo < least_edges_to_be_added ||
                    ((edges_todo == least_edges_to_be_added) &&
                        (prod([ncategories(systems(dbn)[n]) for n in cluster]) <= prod([ncategories(systems(dbn)[n]) for n in chosen_cluster])))
                    least_edges_to_be_added = edges_todo
                    chosen_vertex = v
                    chosen_cluster = cluster
                end
            end
        end
        chosen_nodes = Set([nl[n] for n in chosen_cluster])
        if !any([is_subset(chosen_nodes, cluster) for cluster in clusters])
            push!(clusters, chosen_nodes)
        end
        mg_copy[chosen_vertex] = true
        for v1 in chosen_cluster
            for v2 in chosen_cluster
                if v1 != v2 && !in((v1, v2), edges(mg))
                    add_edge!(mg, v1, v2)
                end
            end
        end
    end
    clusters = [sort([c for c in cluster], by=c -> system_to_node(c, dbn)) for cluster in clusters]
    return mg, clusters
end