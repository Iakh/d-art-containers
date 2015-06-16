import std.typetuple;

import art.node;

// Fixed langth key
struct SparseArray(T, KeyType = ubyte[8])
{
    ref T opIndex(ref KeyType key)
    {
        int depth;

        for (int i = 0; i < KeyType.length; ++i)
        {
            
        }
    }

    Node* m_root;
}
