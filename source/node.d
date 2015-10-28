/**
This module contains implementation of nodes for adaptive radix tree

Node types are in prototype based hierarchy.

There are leaf types used to store elements. In general they are
dublicating node types and in some cases can be used in same context.

Hierarchy of Node types:
-Node
|-Nodes
||-Node4
||-...
||-Node256
|-Leafs!(T)
 |-Leaf4!(T)
 |-...
 |-Leaf256!(T)

But in fact there is only one parent(Node) and one level of hierarchy.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Iakh Takh
*/
module art.node;

import std.algorithm;
import std.array;
import std.conv;
import std.range;

import common;

enum NodeType : byte {NullNode, Node4, Node16 , Node48, Node256, Leaf4, Leaf256}

Node* toNode(ChildT)(ref ChildT child)
{
    return toBase!Node(child);
}

/**
$(D Node) is a base type in the hierarchy.
*/
struct Node
{
    this(NodeType type)
    {
        m_type = type;
    }

    immutable NodeType m_type;

    ubyte m_size;

    ubyte m_foldedCount;
    enum FoldedNodesCapacity = 5;
    ubyte[FoldedNodesCapacity] m_foldedNodes;

    Node* m_parent;
}

unittest
{
    static assert(Node.sizeof == 16);
    static assert(Node.sizeof + Node4.Capacity * (ubyte.sizeof + (Node*).sizeof) + 4 == Node4.sizeof);

    Node4 node4;
    node4.m_size = 4;
    Node* node = node4.toNode;
    Node4* pnode4 = node.toChild!Node4;
    pnode4.m_size = 7;

    assert(node4.m_size == 7);
}

private void insertInPlace(T, size_t N)(ref T[N] array, size_t pos, const ref T element, ubyte size)
{
    T buffer;

    foreach (i; pos .. size)
    {
        buffer = array[i + 1];
        array[i + 1] = array[i];
    }

    array[pos] = cast(Node*)element;
}

private void removeElment(T, size_t N)(ref T[N] array, size_t pos, size_t size)
{
    foreach (i; pos .. size)
    {
        array[i] = array[i + 1];
    }
}

private size_t search(T, size_t N)(ref T[N] arr, T element, size_t size)
{
    size_t min = 0;
    size_t max = size;
    size_t mid = (min + size) / 2;

    for (; min < max; mid = (min + max) / 2)
    {
        if (arr[mid] < element)
        {
            min = mid + 1;
        }
        else
        {
            max = mid;
        }
    }

    return max;
}

/**
$(D NullNode) is pseudo type used in special cases and as terminating symbol in
type lists
*/
struct NullNode
{
    enum Capacity = 0;
}

private Node* shrinkTo(MinorNode, NodeT)(ref NodeT node)
{
    if (node.m_size > MinorNode.Capacity)
    {
        return node.toNode;
    }
    else
    {
        static if (is(MinorNode == NullNode))
        {
            return null;
        }
        else
        {
            return (*new MinorNode(node.toNode, node[])).toNode;
        }
    }
}

/**
$(D SmallNode) is used to build node/leaf types with size from 2 to 16 elements

It contains two arrays of size $(D Capacity) to save keys and children.
*/
mixin template SmallNode(ChildT, size_t Capacity, NodeType type)
{
    this(Range)(Node* other, Range r)
    {
        size_t n;

        m_foldedCount = other.m_foldedCount;
        m_foldedNodes = other.m_foldedNodes;

        foreach (i, v; r)
        {
            m_keys[n] = cast(byte)i;
            m_nodes[n] = v;
            static if (is(ChildT == Node*))
            {
                m_nodes[n].m_parent = this.toNode;
            }
            ++n;
        }
    }

    auto opIndex()
    {
        return zip(m_keys[], m_nodes[]).takeExactly(m_size);
    }

    ChildT* addChild(MajorNode)(ubyte key, Node** current)
    {
        ChildT child;
        return addChild!(MajorNode)(key, current, child);
    }

    ChildT* addChild(MajorNode)(ubyte key, Node** current, ref const ChildT child)
    {
        if (m_size < Capacity)
        {
            size_t pos = m_keys.search(key, m_size);

            assert(m_size == 0 || m_keys[pos] != key, "Node[key] has to be free.");

            m_keys.insertInPlace(pos, key, m_size);
            m_nodes.insertInPlace!(ChildT, Capacity)(pos, child, m_size);
            ++m_size;

            return &m_nodes[pos];
        }
        else
        {
            auto newThis = new MajorNode(this.toNode, this[]);
            newThis.m_parent = m_parent;
            *current = (*newThis).toNode;

            return newThis.addChild!MajorNode(key, null, child);
        }
    }

    ChildT* get(ubyte key)
    {
        size_t pos = m_keys.search(key, m_size);

        if (pos < m_size && m_keys[pos] == key)
        {
            return &m_nodes[pos];
        }

        return null;
    }

    Node* remove(MinorNode)(ubyte key)
    {
        auto pos = m_keys.search(key, m_size);

        assert(m_keys[pos] != key); // TODO: Throw OutOfRange or etc.

        m_keys.removeElment(pos, m_size);
        m_nodes.removeElment(pos, m_size);
        --m_size;

        return shrinkTo!MinorNode(this);

    }

    void removeAll()
    {
        foreach (i; 0 .. m_size)
        {
            m_nodes[i] = ChildT.init;
        }

        m_size = 0;
    }

public /+Iteration+/
{
    bool isEnd(int innerIndex)
    {
        return innerIndex >= m_size;
    }

    int next(int innerIndex)
    {
        return innerIndex + 1;
    }

    int getFirstInnerIndex()
    {
        return 0;
    }

    ChildT* getChildByInnerIndex(ubyte innerIndex)
    {
        return &m_nodes[innerIndex];
    }

    ubyte getKeyByInnerIndex(ubyte innerIndex)
    {
        return m_keys[innerIndex];
    }
}

    Node m_prototype = type;
    alias  m_prototype this;

    ubyte[Capacity] m_keys = [ubyte.max];
    ChildT[Capacity] m_nodes;
}

struct Node4
{
    enum Capacity = 4;
    enum TypeId = NodeType.Node4;

    mixin SmallNode!(Node*, Capacity, TypeId);
}

struct Leaf4(T)
{
    enum Capacity = 4;
    enum TypeId = NodeType.Leaf4;

    mixin SmallNode!(T, Capacity, TypeId);
}

/**
$(D Node256) is the largest node type

It contains two arrays of size $(D Capacity) to save keys and children.
*/
struct Node256
{
    this(Range)(Node* other, Range r)
    {
        m_foldedCount = other.m_foldedCount;
        m_foldedNodes = other.m_foldedNodes;

        foreach(i, val; r)
        {
            m_nodes[i] = val;
            m_nodes[i].m_parent = this.toNode;
        }
    }

    auto opIndex()
    {
        return m_nodes[].enumerate.filter!"a[1] != null";
    }

    Node** addChild(MajorNode)(ubyte key, Node** current, ref const Node* child)
    {
        assert(child == null);
        return addChild!(MajorNode)(key, current);
    }

    Node** addChild(MajorNode)(ubyte key, Node** current)
    {
        assert(m_nodes[key] == null, "Node[key] has to be free.");
        ++m_size;

        return &m_nodes[key];
    }

    Node** get(ubyte key)
    {
        if (!m_nodes[key])
        {
            return null;
        }

        return &m_nodes[key];
    }

    Node* remove(MinorNode)(ubyte key)
    {
        assert(m_nodes[key] != null); // TODO: Throw OutOfRange or etc.

        m_nodes[key] = null;
        --m_size;

        return shrinkTo!MinorNode(this);
    }

    void removeAll()
    {
        foreach (i; 0 .. Capacity)
        {
            m_nodes[i] = null;
        }

        m_size = 0;
    }

public /+Iteration+/
{
    bool isEnd(int innerIndex)
    {
        return innerIndex == Capacity;
    }

    int next(int innerIndex)
    {
        do
        {
            ++innerIndex;
        }
        while(innerIndex < Capacity && m_nodes[innerIndex] == null);

        return innerIndex;
    }

    int getFirstInnerIndex()
    {
        return next(-1);
    }

    Node** getChildByInnerIndex(ubyte innerIndex)
    {
        return &m_nodes[innerIndex];
    }

    ubyte getKeyByInnerIndex(ubyte innerIndex)
    {
        return innerIndex;
    }
}

    Node m_prototype = NodeType.Node256;
    alias  m_prototype this;

    enum TypeId = NodeType.Node256;
    enum Capacity = 256;
    Node*[Capacity] m_nodes;

}

/**
$(D Leaf256) is the largest leaf type

It contains one array of size $(D Capacity) to save children and one to mark
used nodes.
*/
struct Leaf256(T)
{
    this(Range)(Node* other, Range r)
    {
        m_foldedCount = other.m_foldedCount;
        m_foldedNodes = other.m_foldedNodes;

        foreach(i, val; r)
        {
            m_mask[i] = true;
            m_nodes[i] = val;
            ++m_size;
        }
    }

    auto opIndex()
    {
        return m_nodes[].enumerate.zip(m_mask[]).filter!"a[1] == true".map!"a[0]";
    }

    T* addChild(MajorNode)(ubyte key, Node** current, ref const T child)
    {
        assert(m_mask[key] == false, "Node[key] has to be free.");

        m_mask[key] = true;
        m_nodes[key] = child;
        ++m_size;

        return &m_nodes[key];
    }

    T* get(ubyte key)
    {
        if (!m_mask[key])
        {
            return null;
        }

        return &m_nodes[key];
    }

    Node* remove(MinorNode)(ubyte key)
    {
        assert(m_mask[key] == true); // TODO: Throw OutOfRange or etc.

        m_mask[key] = false;
        // TODO: destroy m_nodes[key];
        --m_size;

        return shrinkTo!MinorNode(this);
    }

    void removeAll()
    {
        foreach (i; 0 .. Capacity)
        {
            m_nodes[i] = T.init;
        }

        m_size = 0;
    }

public /+Iteration+/
{
    bool isEnd(int innerIndex)
    {
        return innerIndex == Capacity;
    }

    int next(int innerIndex)
    {
        do
        {
            ++innerIndex;
        }
        while(innerIndex < Capacity && m_mask[innerIndex] == false);

        return innerIndex;
    }

    int getFirstInnerIndex()
    {
        return next(-1);
    }

    T* getChildByInnerIndex(ubyte innerIndex)
    {
        return &m_nodes[innerIndex];
    }

    ubyte getKeyByInnerIndex(ubyte innerIndex)
    {
        return innerIndex;
    }
}

    enum TypeId = NodeType.Leaf256;
    Node m_prototype = TypeId;
    alias  m_prototype this;

    enum Capacity = 256;
    StaticBitArray!Capacity m_mask;
    T[Capacity] m_nodes;
}

