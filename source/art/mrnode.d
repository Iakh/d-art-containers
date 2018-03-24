/**
This module contains implementation of multi radix nodes for adaptive radix tree

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Iakh Takh
*/
module art.mrnode;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.typecons : Tuple, tuple;

import art.common;
import art.node;

template MRNodeDataTemplate()
{
    alias Radix = uint;
    enum Capacity = 4;
    enum TypeId = M4Node4;
    alias ElementType = T;
    alias DecayTopType = M2Node8;
    alias DecayBottomType = M2Leaf8;
}


/**
$(D MRSmallNode) is used to build node/leaf types with size from 2 to 16 elements
and radix 16 or 32 bits.

It contains two arrays of size $(D Capacity) to save keys and children.
*/
mixin template MRSmallNode(alias MRNodeData)
{
    this(Range)(Node* other, Range r)
    {
        other.copyTo(this);
        size_t n;

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

    ChildT* addChild(MajorNode)(Radix key, Node** current)
    {
        ChildT child;
        return addChild!(MajorNode)(key, current, child);
    }

    ChildT* addChild(MajorNode)(Radix key, Node** current, auto ref ChildT child)
    {
        if (m_size < Capacity)
        {
            size_t pos = search(m_keys, key, m_size);

            assert(m_size == 0 || m_keys[pos] != key, "Node[key] has to be free.");

            insertInPlace(m_keys, pos, key, m_size);
            insertInPlace!(ChildT, Capacity)(m_nodes, pos, child, m_size);
            ++m_size;

            return &m_nodes[pos];
        }
        else
        {
            auto newThis = new MajorNode(this.toNode, this[]);
            *current = (*newThis).toNode;

            return newThis.addChild!MajorNode(key, null, child);
        }
    }

    ChildT* get(Radix key)
    {
        size_t pos = search(m_keys, key, m_size);

        if (pos < m_size && m_keys[pos] == key)
        {
            return &m_nodes[pos];
        }

        return null;
    }

    Node* remove(MinorNode)(Radix key)
    {
        auto pos = search(m_keys, key, m_size);

        assert(m_keys[pos] == key); // TODO: Throw OutOfRange or etc.

        removeElment(m_keys, pos, m_size);
        removeElment(m_nodes, pos, m_size);
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

    Radix getKeyByInnerIndex(ubyte innerIndex)
    {
        return m_keys[innerIndex];
    }
}

    alias Radix = MRNodeData.Radix;
    alias ChildT = MRNodeData.ElementType;
    alias Capacity = MRNodeData.Capacity;
    Node m_prototype = MRNodeData.TypeId;
    alias  m_prototype this;

    Radix[Capacity] m_keys = [Radix.max];
    ChildT[Capacity] m_nodes;

private static:
    void insertInPlace(T, size_t N)(ref T[N] array, size_t pos, auto ref T element, ubyte size)
    {
        T buffer = cast(T)element;

        foreach (i; pos .. size)
        {
            swap(array[i], buffer);
        }

        move(buffer, array[size]);
    }

    void removeElment(T, size_t N)(ref T[N] array, size_t pos, size_t size)
    {
        /* TODO: remove
           array[i] = T.init;

        foreach (i; pos .. size)
        {
            moveEmplace(array[i + 1], array[i]);
        }*/
        array[pos..size - 1] = std.algorithm.remove(array[pos..size], 0);
    }

    size_t search(size_t N)(ref Radix[N] arr, Radix element, size_t size)
    {
        for (int i = 0; i < size - 1; ++i)
        {
            if (arr[i] == element)
            {
                return i;
            }
        }

        return size - 1;
    }

}

struct MRNode8
{
    struct UshortRadixNodeData
    {
        alias Radix = ushort;
        enum Capacity = 8;
        enum TypeId = NodeType.MRNode8;
        alias ElementType = Node*;
        alias DecayTopType = Node16;
        alias DecayBottomType = Node16;
    }

    mixin MRSmallNode!UshortRadixNodeData;
}

struct MRLeaf8(T)
{
    struct UshortRadixLeafData
    {
        alias Radix = ushort;
        enum Capacity = 8;
        enum TypeId = NodeType.MRLeaf8;
        alias ElementType = T;
        alias DecayTopType = Node16;
        alias DecayBottomType = Leaf16;
    }

    mixin MRSmallNode!UshortRadixLeafData;
}
