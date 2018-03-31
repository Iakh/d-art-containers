# d-art-containers
My implementation of sparse array based on adaptive radix tree(ART) using Dlang. Also planed sparse bit set.

It is based on this article
http://www-db.in.tum.de/~leis/papers/ART.pdf

And here is general information about radix tree:
https://en.wikipedia.org/wiki/Radix_tree

Radix tree uses node with N = "Radix" children. For this iplementation Radix == 256(byte capacity).
Each byte of a key for the container corresponds one level of the tree (tree haight is equal to
size of the key). Also radix tree doesn't store keys of the data explicitly. A key can be restored
on the path to the leaf.

ART uses several optimizations few of wich currently implemented:
 - Adaptive node size: there are Node4, Node16,Node48, Node256 with different strategies to store
elements (implemented). Note: In a NodeX, X is a capacity of the node. 
 - Collapsing nodes. Nodes with one child does not explixitly created. Only their
 keys stored. (implemented)
 - SIMD optimisations for fast access in nodes other then Node256. (not implemented).

Also implemented range over container.
TODO list for ranges:
 - Slices from key to key.
 - Removing element at the begin(end).

Interface implementation:
 - byUbytes/byOrderedUbytes (decomposes typed key by ubytes)
   - for uints
   - ints
   - floats/doubles
   - structures
   - objects
   - strings
   - arrays (static and dynamic)

MultiRadix nodes (possible optimisation not used in base ART):
    Radix treas are slow for random insertions.
    To improve it try to use node like SmallNode but with bigger keys (ushort, uint).
