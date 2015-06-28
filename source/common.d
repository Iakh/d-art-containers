import std.format;

struct TypeList(T...)
{
    alias expand = T;
}

auto virtualCall(string method, alias ChildrenTL, T, U...)(T* obj, U args)
{
    alias Children = ChildrenTL.expand;

    string virtualCallSwtichBuilder(size_t t = 0)() pure
    {
        static if (t == Children.length)
        {
            return "";
        }
        else
        {
            return q{
                case Children[%d].TypeId:
                    return obj.toChild!(Children[%d]).%s(args);
                }.format(t, t, method) ~ virtualCallSwtichBuilder!(t + 1)();
        }
    }

    switch (obj.m_type)
    {
        mixin(virtualCallSwtichBuilder());
        default: assert(false, "Object should be one of @param Children types.");

    }
}

template TypeOfMember(T, string member)
{
    mixin("alias TypeOfMember = typeof(T."~member~");");
}

ChildT* toChild(ChildT, PrototypeT)(PrototypeT* parent)
    if (is(PrototypeT == struct))
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

ubyte[bytesUsed] byUBytes(size_t bytesUsed, TInt)(TInt val)
{
    assert(bytesUsed < TInt.sizeof);
    assert(val < 2 ^^ (bytesUsed * 8));

    struct ReinterpretAsUByte
    {
        union
        {
            TInt v;
            ubyte[bytesUsed] arr;
        }
    }

    ReinterpretAsUByte tmp;
    tmp.v = val;

    import std.algorithm : reverse;
    reverse(tmp.arr[]);

    return tmp.arr;
}
