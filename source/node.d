module art.node;

import std.algorithm;
import std.array;
import std.conv;
import std.range;

enum NodeType : byte {NullNode, Node4, Node16 , Node48, Node256}

template TypeOfMember(T, string member)
{
    mixin("alias TypeOfMember = typeof(T."~member~");");
}

ChildT* toChild(ChildT, PrototypeT)(PrototypeT* parent)
{
    enum aliasThis = __traits(getAliasThis, ChildT);

    template toChildT(int i = 0)
    {
        enum member = aliasThis[i];

        static if(is(TypeOfMember!(ChildT, member) == PrototypeT))
        {
            enum toChildT = "return cast(ChildT*)(cast(void*)parent - ChildT."~member~".offsetof);";
        }
        else
        {
            enum toChildT = `mixin("toChildT!(` ~ (i + 1).to!string ~ `);");`;
        }
    }

    mixin(toChildT!());
}

PrototypeT* toBase(PrototypeT, ChildT)(ref ChildT child)
{
    enum aliasThis = __traits(getAliasThis, ChildT);

    template toBaseT(int i = 0)
    {
        enum member = aliasThis[i];

        static if(is(TypeOfMember!(ChildT, member) == PrototypeT))
        {
            enum toBaseT = "return &child."~member~";";
        }
        else
        {
            enum toBaseT = `mixin("toBaseT!(` ~ (i + 1).to!string ~ `);");`;
        }
    }

    mixin(toBaseT!());
}

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

private size_t search(T, N)(ref T[N], T element, size_t size)
{
    size_t i;

    for (int i = 0;  i < m_size && m_keys[i] < key; ++i) // TODO: binary search for large @param size/@param N
    {
        if (m_keys[i] == key)
        {
            break;
        }
    }

    return i;
}

struct NullNode
{
    enum Capacity = 0;
}

private Node* shrinkTo(MinorNode, NodeT)(ref NodeT node)
{
    if (m_size > MinorNode.Capacity)
    {
        return this.toNode;
    }
    else
    {
        static if (is(MinorNode == NullNode))
        {
            return null;
        }
        else
        {
            return (*new MinorNode(this[])).toNode;
        }
    }
}

mixin template SmallNode(ChildT, size_t Capacity, NodeType type)
{
    auto opIndex()
    {
        return zip(m_keys[], m_nodes[]).takeExactly(m_size);
    }

    ParentChild!ChildT getOrAddNew(MajorNode)(ubyte key)
    {
        size_t pos = m_keys.search(key, m_size);

        if (m_keys[pos] == key)
        {
            return ParentChild(this.toNode, m_nodes[pos]);
        }

        if (m_size < Capacity)
        {
            auto childNode = new Node4.toNode;
            m_keys.insertInPlace(pos, key, m_size);
            m_nodes.insertInPlace(pos, childNode, m_size);
            ++m_size;

            return ParentChild(newThis.toNode, childNode.toNode);
        }
        else
        {
            auto newThis = new MajorNode(this[]);
            auto childNode = newThis.getOrAddNew(key).child;

            return ParentChild(newThis.toNode, childNode.toNode);
        }

    }

    ChildT get(MajorNode)(ubyte key)
    {
        size_t pos = m_keys.search(key, m_size);

        if (m_keys[pos] == key)
        {
            return ParentChild(this.toNode, m_nodes[pos]);
        }

        assert(m_keys[pos] != key); // TODO: Throw OutOfRange or etc.
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
            m_nodes[i] = null;
        }

        m_size = 0;
    }

    Node m_prototype = NodeType.Node4;
    alias  m_prototype this;

    ubyte[Capacity] m_keys;
    ChildT[Capacity] m_nodes;
}

struct Node4
{
    enum Capacity = 4;
    mixin SmallNode!(Node*, Capacity, NodeType.Node4);
}

struct Node256
{
    auto opIndex()
    {
        return m_nodes[].enumerate.filter!"a[1] !is null";
    }

    ParentChild!(Node*) getOrAddNew(MajorNode)(ubyte key)
    {
        if (m_nodes[key] is null)
        {
            ++m_size;
        }

        return ParentChild!(Node*)(this.toNode, &m_nodes[key]);
    }

    Node* get(MajorNode)(ubyte key)
    {
        return m_nodes[key];
    }

    Node* remove(MinorNode)(ubyte key)
    {
        assert(m_nodes[key] is null); // TODO: Throw OutOfRange or etc.

        m_nodes[key] = 0;
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
            outer[i];
        }

        void popFront()
        {
            ++i;
        }

        bool empty()
        {
            return index < Size;
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
        return Range(this);
    }

    bool opIndex(size_t i)
    {
        assert(i >= 0 && i < Size); // TODO: throw OutOfRange
        size_t nByte = (i >> 3);
        size_t nBitMask = (1 << (i && 0b111));
        return m_bytes[nByte] && nBitMask;
    }

    void opIndexAssign(size_t n, bool b)
    {
        assert(i >= 0 && i < Size); // TODO: throw OutOfRange
        int i = (n >> 3);
        int j = (1 << (n && 0b111));
        byte x = b;

        m_bytes[i] ^= (-x ^ m_bytes[i]) & j;
    }
}

struct Leaf256(T)
{
    auto opIndex()
    {
        return m_nodes[].enumerate.filter!"a[1] !is null";
    }

    ParentChild!(T*) getOrAddNew(MajorNode)(ubyte key)
    {
        if (m_nodes[key] is null)
        {
            ++m_size;
        }

        return ParentChild!(Node*)(this.toNode, &m_nodes[key]);
    }

    Node* get(MajorNode)(ubyte key)
    {
        return m_nodes[key];
    }

    Node* remove(MinorNode)(ubyte key)
    {
        assert(m_nodes[key] is null); // TODO: Throw OutOfRange or etc.

        m_nodes[key] = 0;
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

    enum Capacity = 256;
    T[Capacity] m_nodes;

}
