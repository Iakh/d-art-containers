import std.algorithm;
import std.conv;
import std.format;
import std.range;
import std.typecons;
import std.typetuple;

import art.node;
import common;

struct NodeManager(alias NodeTL, alias LeafTL, T, size_t depth)
{
    alias Nodes = TypeTuple!(NullNode, NodeTL.expand, NullNode);
    alias Leafs = TypeTuple!(NullNode, LeafTL.expand, NullNode);
    alias SmallestNodeType = Nodes[1];
    alias SmallestLeafType = Leafs[1];
    alias Elem = T;

static:
    ref Elem opIndex(ref Node* root, in ubyte[depth] key)
    {
        static string nodeAddSwitchBuilder()
        {
            string result = "";

            foreach (t; 1 .. Nodes.length - 1)
            {
                result ~= q{
                    case Nodes[%d].TypeId:

                        if (auto child = (*current).toChild!(Nodes[%d]).get(key[i]))
                        {
                            current = child;
                        }
                        else
                        {
                            Node* newChild;

                            if (i == depth - 2)
                            {
                                newChild = (*new SmallestLeafType).toNode;
                            }
                            else
                            {
                                newChild = (*new SmallestNodeType).toNode;
                            }

                            *current = (*current).toChild!(Nodes[%d]).addChild!(Nodes[%d + 1])(key[i], newChild);
                            current = (*current).virtualCall!("get", NodeTL)(key[i]);
                        }
                        break;
                    }.format(t, t, t, t);
            }

            return result;
        }

        static string leafAddSwitchBuilder()
        {
            string result = "";

            foreach (t; 1 .. Nodes.length - 1)
            {
                result ~= q{
                    case Leafs[%d].TypeId:
                        if (auto child = (*current).toChild!(Leafs[%d]).get(key[i]))
                        {
                            return *child;
                        }
                        else
                        {
                            T child;

                            *current = (*current).toChild!(Leafs[%d]).addChild!(Leafs[%d + 1])(key[i], child);
                            return *(*current).virtualCall!("get", LeafTL)(key[i]);
                        }
                    }.format(t, t, t, t);
            }

            return result;
        }

        import std.stdio;
        stderr.writeln("SparseArray.opIndex" ~ key.to!string);

        if (!root)
        {
            root = (*new SmallestNodeType).toNode;
        }

        auto current = &root;

        for (int i = 0; i < depth; ++i)
        {
            switch ((*current).m_type)
            {
                mixin(nodeAddSwitchBuilder());
                mixin(leafAddSwitchBuilder());
                default: assert(false, "Node should be one of known node types");
            }
        }

        assert(false);
    }

    void remove(ref Node* root, ref ubyte[depth] key)
    {
        static import std.stdio;
        std.stdio.stderr.writeln("SparseArray.remove key:" ~ key.to!string);

        assert(root != null, "Tree has to cantain at least one element to remove.");

        remove(&root, key, 0);
    }

    private void remove(Node** current, ref ubyte[depth] key, size_t i)
    {
        static string nodeRemoveSwitchBuilder()
        {
            string result = "";

            foreach (t; 1 .. Nodes.length - 1)
            {
                result ~= q{
                    case Nodes[%d].TypeId:
                        auto child = (*current).toChild!(Nodes[%d]).get(key[i]);
                        assert(child != null, "Node has to be in the tree to remove");
                        remove(child, key, i + 1);

                        if (*child == null)
                        {
                            *current = (*current).toChild!(Nodes[%d]).remove!(Nodes[%d - 1])(key[i]);
                        }
                        break;
                }.format(t, t, t, t);

            }

            return result;
        }

        static string leafRemoveSwitchBuilder()
        {
            string result = "";

            foreach (t; 1 .. Nodes.length - 1)
            {
                result ~= q{
                    case Leafs[%d].TypeId:
                        *current = (*current).toChild!(Leafs[%d]).remove!(Leafs[%d - 1])(key[i]);
                        break;
                }.format(t, t, t);
            }

            return result;
        }

        switch ((*current).m_type)
        {
            mixin(nodeRemoveSwitchBuilder());
            mixin(leafRemoveSwitchBuilder());
            default: assert(false, "Node should be one of known node types");
        }
    }

    private Elem* get(Node* current, ref ubyte[depth] key) // TODO: unittests
    {
        static string nodeGetSwitchBuilder()
        {
            string result = "";

            foreach (t; 1 .. Nodes.length - 1)
            {
                result ~= q{
                    case Nodes[%d].TypeId:
                        auto child = current.toChild!(Nodes[%d]).get(key[i]);

                        if (child == null)
                        {
                            return null;
                        }

                        current = *child;
                        break;
                }.format(t, t);

            }

            return result;
        }

        static string leafGetSwitchBuilder()
        {
            string result = "";

            foreach (t; 1 .. Nodes.length - 1)
            {
                result ~= q{
                    case Leafs[%d].TypeId:
                        if (auto result = current.toChild!(Leafs[%d]).get(key[i]))
                        {
                            return result;
                        }
                        else
                        {
                            return null;
                        }
                }.format(t, t);
            }

            return result;
        }

        for (int i = 0; i < depth; ++i)
        {
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

// Fixed langth key
struct SparseArray(T, KeyType = size_t, size_t bytesUsed = KeyType.sizeof)
{
    alias Elem = T;
    alias ArrayNodeManager = NodeManager!(NodeTypes, LeafTypes, Elem, bytesUsed);

    ref Elem opIndex(ref KeyType key)
    {
        return ArrayNodeManager.opIndex(m_root, key.byUBytes!bytesUsed);
    }

    Elem* opBinaryRight(string op)(ref KeyType key) if (op == "in")
    {
        return ArrayNodeManager.get(m_root, key.byUBytes!bytesUsed);
    }
private:
    alias NodeTypes = TypeList!(Node4, Node256);
    alias LeafTypes = TypeList!(Leaf4!Elem, Leaf256!Elem);

    Node* m_root;
}

unittest
{
    import std.stdio;
    stderr.writeln("aparse-arr test");
    alias KeyType = size_t;
    SparseArray!(int, KeyType, 2) arr;
    stderr.writeln("aparse-arr test");
    KeyType i = 0;
    arr[i] = 5;
    assert(arr[i] == 5);

    KeyType j = 0;

    stderr.writeln("aparse-arr test");
    foreach (ubyte k; 0 .. 256)
    {
        j = k;
        arr[j] = k;
        assert(arr[j] == k);
    }

    foreach (ubyte k; 0 .. 256)
    {
        j = k * 256;
        arr[j] = k;
        assert(arr[j] == k);
    }
    stderr.writeln("aparse-arr test");
}
