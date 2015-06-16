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

struct Node
{
    this(NodeType type)
    {
        m_type = type;
    }

    immutable NodeType m_type;

    union
    {
        ubyte m_size;
        ubyte[3] m_align;
    }

}

unittest
{
    static assert(Node.sizeof == 4);
    static assert(Node.sizeof + Node4.Capacity * (ubyte.sizeof + (Node*).sizeof) == Node4.sizeof);

    Node4 node4;
    node4.m_size = 4;
    Node* node = node4.toNode;
    Node4* pnode4 = node.toChild!Node4;
    pnode4.m_size = 7;

    assert(node4.m_size == 7);
}

struct ParentChild(ChildT)
{
    Node* newParent;
    ChildT* child;
}

private void insertInPlace(T, size_t N)(ref T[N] array, size_t pos, T element, size_t size)
{
    T buffer;

    foreach (i; pos .. size)
    {
        buffer = array[i + 1];
        array[i + 1] = array[i];
    }

    array[pos] = element;
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
        import std.stdio;
        stderr.writeln("search min:" ~ min.to!string ~ " max:"  ~ max.to!string);
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
            return (*new MinorNode(node[])).toNode;
        }
    }
}

mixin template SmallNode(ChildT, size_t Capacity, NodeType type)
{
    this(Range)(Range r)
    {
        size_t n;

        foreach (i, v; r)
        {
            m_keys[n] = cast(byte)i;
            m_nodes[n] = v;
            ++n;
        }
    }

    auto opIndex()
    {
        import std.stdio;
        stderr.writeln(m_type.to!string ~ ".[] keys:" ~ m_keys.to!string);
        return zip(m_keys[], m_nodes[]).takeExactly(m_size);
    }

    Node* addChild(MajorNode)(ubyte key, ChildT child)
    {
        if (m_size < Capacity)
        {
            size_t pos = m_keys.search(key, m_size);

            assert(m_size == 0 || m_keys[pos] != key, "Node[key] has to be free.");

            m_keys.insertInPlace(pos, key, m_size);
            m_nodes.insertInPlace(pos, child, m_size);
            ++m_size;

            import std.stdio;
            stderr.writeln(m_type.to!string ~ ".addChild key:" ~ key.to!string ~ ".addChild size:"  ~ m_size.to!string);

            return this.toNode;
        }
        else
        {
            auto newThis = new MajorNode(this[]);
            return newThis.addChild!MajorNode(key, child);
        }
    }

    ChildT* get(ubyte key)
    {
        import std.stdio;
        stderr.writeln(m_type.to!string ~ ".get key:" ~ key.to!string ~ " size:"  ~ m_size.to!string);
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

struct Node256
{
    this(Range)(Range r)
    {
        foreach(i, val; r)
        {
            m_nodes[i] = val;
        }
    }

    auto opIndex()
    {
        return m_nodes[].enumerate.filter!"a[1] != null";
    }

    Node* addChild(MajorNode)(ubyte key, Node* child)
    {
        assert(m_nodes[key] == null, "Node[key] has to be free.");

        m_nodes[key] = child;
        ++m_size;

        return this.toNode;
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

    Node m_prototype = NodeType.Node256;
    alias  m_prototype this;

    enum TypeId = NodeType.Node256;
    enum Capacity = 256;
    Node*[Capacity] m_nodes;

}

struct StaticBitArray(size_t Size)
{
    enum ByteSize = (Size + 7) / 8;

    struct Range
    {
        bool front()
        {
            return (*m_outer)[m_index];
        }

        void popFront()
        {
            ++m_index;
        }

        bool empty()
        {
            return m_index >= Size;
        }

        this(StaticBitArray* outer)
        {
            m_outer = outer;
        }

    private:
        StaticBitArray* m_outer;
        size_t m_index;
    }

    Range opIndex()
    {
        return Range(&this);
    }

    bool opIndex(size_t i)
    {
        assert(i >= 0 && i < Size); // TODO: throw OutOfRange
        size_t nByte = (i >> 3);
        size_t nBitMask = (1 << (i & 0b111));
        import std.stdio;
        stderr.writeln("BitArray.opIndex" ~ " i: " ~ (i & 0b111).to!string ~ " n: " ~ nByte.to!string ~ " bit " ~ nBitMask.to!string);
        return cast(bool)(m_bytes[nByte] & nBitMask);
    }

    void opIndexAssign(bool value, size_t n)
    {
        assert(n >= 0 && n < Size); // TODO: throw OutOfRange
        ulong i = (n >> 3);
        byte bit = cast(byte)(1 << (n & 0b111));
        byte x = value;

        m_bytes[i] ^= (-x ^ m_bytes[i]) & bit;
        import std.stdio;
        stderr.writeln("BitArray.opIndexAssign" ~ " byte: " ~ m_bytes[i].to!string);
    }

private:
    ubyte[ByteSize] m_bytes;
}

struct Leaf256(T)
{
    this(Range)(Range r)
    {
        foreach(i, val; r)
        {
            import std.stdio;
            stderr.writeln(m_type.to!string ~ ".ctor key:" ~ i.to!string);
            m_mask[i] = true;
            m_nodes[i] = val;
            ++m_size;
        }
    }

    auto opIndex()
    {
        return m_nodes[].enumerate.zip(m_mask[]).filter!"a[1] == true".map!"a[0]";
    }

    Node* addChild(MajorNode)(ubyte key, T child)
    {
        import std.stdio;
        stderr.writeln(m_type.to!string ~ ".addChild key:" ~ key.to!string ~ ".addChild size:"  ~ m_size.to!string);
        scope(exit) stderr.writeln(m_type.to!string ~ ".addChild END");
        if (m_mask[key] == true)
        {
            import std.stdio;
            stderr.writeln("[flase]" ~ m_type.to!string ~ " key: " ~ key.to!string);
        }
        assert(m_mask[key] == false, "Node[key] has to be free.");

        m_mask[key] = true;
        m_nodes[key] = child;
        ++m_size;

        return this.toNode;
    }

    T* get(ubyte key)
    {
        import std.stdio;
        stderr.writeln(m_type.to!string ~ ".get key:" ~ key.to!string ~ ".addChild size:"  ~ m_size.to!string);
        scope(exit) stderr.writeln(m_type.to!string ~ ".get END");
        if (!m_mask[key])
        {
            return null;
        }

        stderr.writeln(m_type.to!string ~ ".get END not null");
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

    enum TypeId = NodeType.Leaf256;
    Node m_prototype = TypeId;
    alias  m_prototype this;

    enum Capacity = 256;
    StaticBitArray!Capacity m_mask;
    T[Capacity] m_nodes;
}

