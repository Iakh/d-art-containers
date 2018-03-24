/**
This module provides an $(D SparseArray) container based on adaptive radix tree.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Iakh Takh
*/
module art.sparse_array;

import std.algorithm;
import std.conv;
import std.format;
import std.range;
import std.typecons;
import std.typetuple;

import art.node;
import art.mrnode;
import art.common;

struct NodeTypeGraph(T)
{
    alias Elem = T;
    alias NodeTypes = TypeTuple!(Node4, Node16, Node48, Node256);
    alias LeafTypes = TypeTuple!(Leaf4!Elem, Leaf16!Elem, Leaf48!Elem, Leaf256!Elem);

    //template NextNode(T);
    alias NextNode(T : Node4) = Node16;
    alias NextNode(T : Node16) = Node48;
    alias NextNode(T : Node48) = Node256;
    alias NextNode(T : Node256) = NullNode;

    //template PrevNode(T);
    alias PrevNode(T : Node256) = Node48;
    alias PrevNode(T : Node48) = Node16;
    alias PrevNode(T : Node16) = Node4;
    alias PrevNode(T : Node4) = NullNode;

    //template NextLeaf(T);
    alias NextLeaf(T : Leaf4!Elem) = Leaf16!Elem;
    alias NextLeaf(T : Leaf16!Elem) = Leaf48!Elem;
    alias NextLeaf(T : Leaf48!Elem) = Leaf256!Elem;
    alias NextLeaf(T : Leaf256!Elem) = NullNode;

    //template PrevLeaf(T);
    alias PrevLeaf(T : Leaf256!Elem) = Leaf48!Elem;
    alias PrevLeaf(T : Leaf48!Elem) = Leaf16!Elem;
    alias PrevLeaf(T : Leaf16!Elem) = Leaf4!Elem;
    alias PrevLeaf(T : Leaf4!Elem) = NullNode;

    alias SmallestNodeType = Node4;
    alias SmallestLeafType = Leaf4!Elem;
}

struct MRNodeTypeGraph(T)
{
    alias Elem = T;
    alias NodeTypes = TypeTuple!(MRNode8, Node4, Node16, Node48, Node256);
    alias LeafTypes = TypeTuple!(MRLeaf8!Elem, Leaf4!Elem, Leaf16!Elem, Leaf48!Elem, Leaf256!Elem);

    //template NextNode(T);
    alias NextNode(T : MRNode8) = Node4;
    alias NextNode(T : Node4) = Node16;
    alias NextNode(T : Node16) = Node48;
    alias NextNode(T : Node48) = Node256;
    alias NextNode(T : Node256) = NullNode;

    //template PrevNode(T);
    alias PrevNode(T : Node256) = Node48;
    alias PrevNode(T : Node48) = Node16;
    alias PrevNode(T : Node16) = Node4;
    alias PrevNode(T : Node4) = NullNode;
    alias PrevNode(T : MRNode8) = NullNode;

    //template NextLeaf(T);
    alias NextLeaf(T : MRLeaf8!Elem) = Leaf4!Elem;
    alias NextLeaf(T : Leaf4!Elem) = Leaf16!Elem;
    alias NextLeaf(T : Leaf16!Elem) = Leaf48!Elem;
    alias NextLeaf(T : Leaf48!Elem) = Leaf256!Elem;
    alias NextLeaf(T : Leaf256!Elem) = NullNode;

    //template PrevLeaf(T);
    alias PrevLeaf(T : Leaf256!Elem) = Leaf48!Elem;
    alias PrevLeaf(T : Leaf48!Elem) = Leaf16!Elem;
    alias PrevLeaf(T : Leaf16!Elem) = Leaf4!Elem;
    alias PrevLeaf(T : Leaf4!Elem) = NullNode;
    alias PrevLeaf(T : MRLeaf8!Elem) = NullNode;

    alias SmallestNodeType = Node4;
    alias SmallestLeafType = Leaf4!Elem;
}

private struct NodeManager(alias NodeTypeGraph, size_t depth)
{
    alias Elem = NodeTypeGraph.Elem;
    alias NodeTL = NodeTypeGraph.NodeTypes;
    alias LeafTL = NodeTypeGraph.LeafTypes;
    alias NodePack = TypePack!NodeTL;
    alias LeafPack = TypePack!LeafTL;
    alias AllNodes = TypePack!(NodeTL, LeafTL);
    alias SmallestNodeType = NodeTypeGraph.SmallestNodeType;
    alias SmallestLeafType = NodeTypeGraph.SmallestLeafType;

    struct RangeKeyValue
    {
        this(Node* root)
        {
            m_node = root;
            int i = depth - 1;
            copyFoldedNodes(m_node, m_keys, i);
            m_innerIndexes[i] = cast(ubyte)m_node.virtualCall!("getFirstInnerIndex", AllNodes)();
            m_keys[i] =  m_node.virtualCall!("getKeyByInnerIndex", AllNodes)(m_innerIndexes[$ - 1]);
            --i;

            for (; i >= 0; --i)
            {
                m_node = *m_node.virtualCall!("getChildByInnerIndex", NodePack)(m_innerIndexes[i + 1]);
                copyFoldedNodes(m_node, m_keys, i);
                m_innerIndexes[i] = cast(ubyte)m_node.virtualCall!("getFirstInnerIndex", AllNodes)();
                m_keys[i] =  m_node.virtualCall!("getKeyByInnerIndex", AllNodes)(m_innerIndexes[i]);
            }

        }

        @property
        Tuple!(ubyte[depth], Elem) front()
        {
            return tuple(m_keys, *m_node.virtualCall!("getChildByInnerIndex", LeafPack)(m_innerIndexes[0]));
        }

        void popFront()
        {
            assert(!empty, "Range should be not empty");
            int i = 0;
            for (; i < depth; ++i)
            {
                int innerIndex = m_innerIndexes[i];
                innerIndex = m_node.virtualCall!("next", AllNodes)(innerIndex);
                if (m_node.virtualCall!("isEnd", AllNodes)(innerIndex))
                {
                    i += m_node.m_foldedCount;

                    if (i == depth - 1)
                    {
                        m_node = null;
                        return;
                    }

                    m_node = m_node.m_parent;
                    continue;
                }
                m_innerIndexes[i] = cast(ubyte)innerIndex;
                m_keys[i] =  m_node.virtualCall!("getKeyByInnerIndex", AllNodes)(m_innerIndexes[i]);
                break;
            }
            --i;
            for (; i >= 0; --i)
            {
                m_node = *m_node.virtualCall!("getChildByInnerIndex", NodePack)(m_innerIndexes[i + 1]);
                copyFoldedNodes(m_node, m_keys, i);
                m_innerIndexes[i] = cast(ubyte)m_node.virtualCall!("getFirstInnerIndex", AllNodes)();
                m_keys[i] =  m_node.virtualCall!("getKeyByInnerIndex", AllNodes)(m_innerIndexes[i]);
            }
        }

        @property
        bool empty()
        {
            return m_node == null;
        }

        private static void copyFoldedNodes(Node* node, ref ubyte[depth] keys, ref int i)
        {
            for (int j = 0; j < node.m_foldedCount; ++j)
            {
                assert(i < depth, "i = %s, m_foldedCount = %s, type = %s".format(i, node.m_foldedCount, node.m_type));
                keys[i] = node.m_foldedNodes[j];
                --i;
            }
        }

    private:
        Node* m_node;
        ubyte[depth] m_keys;
        ubyte[depth] m_innerIndexes;
    }

static:
    auto opIndex(Node* root)
    {
        return RangeKeyValue();
    }

    // TODO: reverse m_keys, m_innerIndexes order, remove functions that do it(just do reinterpret cast)
    ref Elem opIndexAssign()(ref Node* root, auto ref Elem value, in ubyte[depth] key)
    {
        static string nodeAddSwitchBuilder()
        {
            string result = "";

            foreach (t; 0 .. NodeTL.length)
            {
                result ~= q{{
                    enum t = %d;
                    alias NodeT = NodeTL[t];
                    alias NextNodeT = NodeTypeGraph.NextNode!NodeT;
                    case NodeT.TypeId:
                        if (auto child = (*current).toChild!NodeT.get(key[i]))
                        {
                            current = child;
                        }
                        else
                        {
                            auto child = (*current).toChild!NodeT.addChild!NextNodeT(key[i], current);
                            parent = *current;
                            auto type = (*current).m_type;
                            current = child;
                            assert(current, "key[%%s]: %%s, type: %%s".format(i, key[i], type));
                        }
                        break;
                }}.format(t);
            }

            return result;
        }

        static string leafAddSwitchBuilder()
        {
            string result = "";

            foreach (t; 0 .. LeafTL.length)
            {
                result ~= q{{
                    enum t = %d;
                    alias NodeT = LeafTL[t];
                    alias NextNodeT = NodeTypeGraph.NextLeaf!NodeT;
                    case NodeT.TypeId:
                        if (auto child = (*current).toChild!NodeT.get(key[i]))
                        {
                            *child = value;
                            return *child;
                        }
                        else
                        {
                            auto child = (*current).toChild!NodeT.addChild!NextNodeT(key[i], current, value);
                            return *child;
                        }
                }}.format(t);
            }

            return result;
        }

        auto current = &root;
        Node* parent = null;

    mainLoop:
        for (int i = depth - 1; i >= 0; --i)
        {
            if (!*current)
            {
                // TODO: mixin MakeAMAPFoldedNodes
                if (Node.FoldedNodesCapacity < i)
                {
                    *current = (*new SmallestNodeType).toNode;
                }
                else
                {
                    *current = (*new SmallestLeafType).toNode;
                }
                (*current).m_parent = parent;
                (*current).m_foldedCount = cast(ubyte)min(Node.FoldedNodesCapacity, i);
                foreach (j; 0 .. (*current).m_foldedCount)
                {
                    (*current).m_foldedNodes[j] = key[i];
                    --i;
                }
            }
            else
            {
                for (int j = 0; j < (*current).m_foldedCount; ++j)
                {
                    if ((*current).m_foldedNodes[j] == key[i])
                    {
                        --i;
                    }
                    else
                    {
                        auto branchyNode = new SmallestNodeType;
                        branchyNode.m_foldedCount = cast(ubyte)j;
                        branchyNode.m_foldedNodes[0 .. j] = (*current).m_foldedNodes[0 .. j];
                        auto foldedLeft = (*current).m_foldedCount - j - 1; /+
                            j folded nodes used in the branchyNode and one for the currKey
                            +/
                        auto currKey = (*current).m_foldedNodes[j];
                        static void copyByByte(ubyte[] from, ubyte[] to)
                        {
                            for (int i = 0; i < from.length; ++i)
                            {
                                to[i] = from[i];
                            }
                        }
                        copyByByte((*current).m_foldedNodes[j + 1 .. (*current).m_foldedCount],
                                (*current).m_foldedNodes[0 .. foldedLeft]);
                        (*current).m_foldedCount = cast(ubyte)foldedLeft;

                        // Inserting branchyNode into the tree
                        branchyNode.m_parent = (*current).m_parent;
                        (*current).m_parent = (*branchyNode).toNode;
                        alias SecondSmallestNode = NodeTypeGraph.NextNode!SmallestNodeType;
                        *branchyNode.addChild!SecondSmallestNode(currKey, null) = *current; // TODO: check SmallestNodeType capacity >= 2
                        *current = (*branchyNode).toNode;
                        current = branchyNode.addChild!SecondSmallestNode(key[i], null); // TODO: check SmallestNodeType capacity >= 2

                        // TODO: shrink(reshape) path if "old current" is one way node
                        parent = (*branchyNode).toNode;
                        continue mainLoop;
                    }
                }
            }

            switch ((*current).m_type)
            {
                mixin(nodeAddSwitchBuilder());
                mixin(leafAddSwitchBuilder());
                default: assert(false, "Node should be one of known node types");
            }
        }

        assert(false, "Return should be reached in for/switch statements.");
    }

    void remove(ref Node* root, in ubyte[depth] key)
    {
        remove(&root, key, depth - 1);
    }

    private void remove(Node** current, in ubyte[depth] key, size_t i)
    {
        static string nodeRemoveSwitchBuilder()
        {
            string result = "";

            foreach (t; 0 .. NodeTL.length)
            {
                result ~= q{{
                    enum t = %d;
                    alias NodeT = NodeTL[t];
                    alias PrevNodeT = NodeTypeGraph.PrevNode!NodeT;
                    case NodeT.TypeId:
                        auto child = (*current).toChild!NodeT.get(key[i]);
                        assert(child != null, "Node has to be in the tree to remove");
                        remove(child, key, i - 1);

                        if (*child == null)
                        {
                            *current = (*current).toChild!NodeT.remove!PrevNodeT(key[i]);
                        }
                        break;
                }}.format(t);

            }

            return result;
        }

        static string leafRemoveSwitchBuilder()
        {
            string result = "";

            foreach (t; 0 .. LeafTL.length)
            {
                result ~= q{{
                    enum t = %d;
                    alias NodeT = LeafTL[t];
                    alias PrevNodeT = NodeTypeGraph.PrevLeaf!NodeT;
                    case NodeT.TypeId:
                        assert(i == 0, "i should be at the last (leaf) key");
                        *current = (*current).toChild!NodeT.remove!PrevNodeT(key[i]);
                        break;
                }}.format(t);
            }

            return result;
        }

        assert(current != null, "(Sub-)Tree has to cantain element to remove."); // TODO: enforce OutOfRange or etc

        for (int j = 0; j < (*current).m_foldedCount; ++j)
        {
            assert((*current).m_foldedNodes[j] == key[i]); // TODO: enforce OutOfRange or etc
            --i;
        }

        switch ((*current).m_type)
        {
            mixin(nodeRemoveSwitchBuilder());
            mixin(leafRemoveSwitchBuilder());
            default: assert(false, "Node should be one of known node types");
        }
    }

    private Elem* get(Node* current, in ubyte[depth] key) // TODO: unittests
    {
        static string nodeGetSwitchBuilder()
        {
            string result = "";

            foreach (t; 0 .. NodeTL.length)
            {
                result ~= q{{
                    enum t = %d;
                    alias NodeT = NodeTL[t];
                    case NodeT.TypeId:
                        auto child = current.toChild!NodeT.get(key[i]);

                        if (child == null)
                        {
                            return null;
                        }

                        current = *child;
                        break;
                }}.format(t);

            }

            return result;
        }

        static string leafGetSwitchBuilder()
        {
            string result = "";

            foreach (t; 0 .. LeafTL.length)
            {
                result ~= q{{
                    enum t = %d;
                    alias NodeT = LeafTL[t];
                    case NodeT.TypeId:
                        auto e = current.toChild!NodeT.get(key[i]);
                        return e;
                }}.format(t);
            }

            return result;
        }

        for (int i = depth - 1; i >= 0; --i)
        {
            for (int j = 0; j < current.m_foldedCount; ++j)
            {
                if (current.m_foldedNodes[j] == key[i])
                {
                    --i;
                }
                else
                {
                    return null;
                }
            }
            switch (current.m_type)
            {
                mixin(nodeGetSwitchBuilder());
                mixin(leafGetSwitchBuilder());
                default: assert(false, "Node should be one of known node types");
            }
        }

        assert(false, "Return should be reached in for/shwitch statements.");
    }
}

/**
SparseArray is a container based on adaptive radix tree. For each byte of the
key there is one level of the tree nodes. So each node contains no more then
256 children and whole tree has $(D sizeof(KeyType)) levels. There are several
types of nodes (each defined by it's size) to save space. Each node type has
its own strategy to manage children. Nodes with one child can be folded into
branchy nodes. Folded(collapsed) nodes not actualy created but their keys
saved in child nodes.

Key of the element not directly stored in the tree. Key can be restored from
the path to the node.

Params:
T = Type of payload.
KeyType = Integral type used as key
bytesUsed = Number used bytes for a key. Setting this parameter to value
    less than KeyType.sizeof(default value) may speed up access to elements.
*/
struct SparseArray(T, KeyType = size_t, size_t bytesUsed = KeyType.sizeof)
{
    alias NodeTypes = TypePack!(Node4, Node16, Node48, Node256);
    alias LeafTypes = TypePack!(Leaf4!Elem, Leaf16!Elem, Leaf48!Elem, Leaf256!Elem);

    alias Elem = T;
    alias ArrayNodeManager = NodeManager!(NodeTypeGraph!Elem, bytesUsed);

    struct RangeKeyValue
    {
        this(Node* root)
        {
            m_range = ArrayNodeManager.RangeKeyValue(root);
        }

        void popFront()
        {
            m_range.popFront;
        }

        @property
        Tuple!(KeyType, T) front()
        {
            auto elem = m_range.front();
            return tuple(elem[0].ubytesTo!KeyType, elem[1]);
        }

        @property
        bool empty()
        {
            return m_range.empty;
        }

    private:
        ArrayNodeManager.RangeKeyValue m_range;
    }

    /**
    Returns a range that iterates over elements of the container, in
    forward order.
    Complexity: $(BIGOH bytesUsed)
     */
    auto opIndex()
    {
        return RangeKeyValue(m_root);
    }

    /**
    Indexing operators yield the value at a specified index.
    It is an error if value not exist.
    Complexity: $(BIGOH bytesUsed)
     */
    ref Elem opIndex(KeyType key)
    {
        auto val = ArrayNodeManager.get(m_root, key.byUBytes!bytesUsed);
        assert(val, "Value at specified idex should exists");
        return *val;
    }

    /**
    Index assign operator modify the value at a specified index.
    If value not exist it will be created.
    Complexity: $(BIGOH bytesUsed)
     */
    ref Elem opIndexAssign()(auto ref T value, KeyType key)
    {
        return ArrayNodeManager.opIndexAssign(m_root, value, key.byUBytes!bytesUsed);
    }

    /**
    Removes the value at a specified index.
    Complexity: $(BIGOH bytesUsed)
     */
    void remove(ref KeyType key)
    {
        return ArrayNodeManager.remove(m_root, key.byUBytes!bytesUsed);
    }

    /**
    Returns pointer to value at a specified index. If there is no value
    at a specified index returns $D(null)
    Complexity: $(BIGOH bytesUsed)
     */
    Elem* opBinaryRight(string op)(KeyType key) if (op == "in")
    {
        return ArrayNodeManager.get(m_root, key.byUBytes!bytesUsed);
    }
private:
    Node* m_root;

    unittest
    {
        alias KeyType = size_t;
        SparseArray!(int, KeyType, bytesUsed) arr;
        KeyType i = 0;
        arr[i] = 5;
        assert(arr[i] == 5);

        KeyType j = 0;

        foreach (k; 0 .. 256)
        {
            j = k;
            arr[j] = k;
            assert(*(k in arr) == k, "Actual: %s, Expected: %s".format(*(k in arr), k));
        }

        foreach (k; 0 .. 256)
        {
            j = k * 256;
            arr[j] = k;
            j in arr;
            assert(arr[j] == k, "Actual: %s, Expected: %s".format(*(j in arr), k));
        }

        foreach (size_t k; iota(0, 256, 2))
        {
            arr.remove(k);
            assert((k in arr) == null);
            assert(*(k + 1 in arr) == k + 1);
        }

        auto expected = [
            tuple(64000, 250),
            tuple(64256, 251),
            tuple(64512, 252),
            tuple(64768, 253),
            tuple(65024, 254),
            tuple(65280, 255)
        ];

        assert(equal(arr[].filter!"a[0] >= 64000", expected));
    }
}

unittest
{
    SparseArray!(int, size_t, 2) arr2;
    SparseArray!(int, size_t, 8) arr8;
}

