/**
This module contains features that should be moved to other (currently not
existing) modules.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Iakh Takh
*/
module art.common;

import std.format;

template TypePack(T...)
{
    alias expand = T;
}

/**
TODO: Try to rewrite it with template mixin, UDA for method that could be called
as virtual (@switch_call) and opDispatch
mixin SwitchCall(signature, prefix, user_defined_type_info_field)
*/
/**
Safe call method of the $(D obj). Where $(obj) is pointer to prototype "base"
struct. Field T.m_type should represent correct type of the child struct.
*/
auto virtualCall(string method, alias ChildrenTL, T, U...)(T* obj, U args)
{
    alias Children = ChildrenTL.expand;

    string virtualCallSwtichBuilder() pure
    {
        string str = "";
        foreach (t;  0 .. Children.length)
        {
            str ~= q{
                case Children[%d].TypeId:
                    return obj.toChild!(Children[%d]).%s(args);
                }.format(t, t, method);
        }

        return str;
    }

    switch (obj.m_type)
    {
    mixin(virtualCallSwtichBuilder());
    default:
    {
        assert(false, "Object should be one of @param Children types. Actual value is %s. Func: %s".format(obj.m_type, __FUNCTION__));
    }
    }
}

auto visit(Params...)()
{
    string visitSwtichBuilder() pure
    {
        string str;

        string visitTypePackSwitchBuilder(string handler, P : TypePack!(TL))()
        {
            str += bulidCase(Params[t * 2], Params[t * 2 + 1]);

            foreach (t; 0 .. TL.length)
            {
                str ~= q{
                    case TL[%d].TypeId:
                    {
                        %s
                    }
                    break;
                }.format(t, handler);
            }

            return str;
        }

        foreach (t; 0 .. Params.length / 2)
        {
            str += visitTypePackSwitchBuilder(Params[t * 2 + 1], Params[t * 2]);
        }

        return str;
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

/**
Convinient cast to child type from prototype type.
*/
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

/**
Convinient cast from prototype type to child type.
*/
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
    static assert(bytesUsed <= TInt.sizeof);
    assert(bytesUsed == TInt.sizeof || val < cast(TInt)2 ^^ (bytesUsed * 8));

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

    return tmp.arr;
}

TInt ubytesTo(TInt, size_t size)(ubyte[size] val)
{
    static assert(size <= TInt.sizeof);

    struct ReinterpretAsUByte
    {
        union
        {
            TInt v;
            ubyte[size] arr;
        }
    }

    ReinterpretAsUByte tmp;

    import std.algorithm : copy;
    copy(val[], tmp.arr[]);

    return tmp.v;
}

struct StaticBitArray(size_t Size)
{
    enum ByteSize = (Size + 7) / 8;

    struct Range
    {
        bool front()
        {
            return (*m_outer)[m_first];
        }

        void popFront()
        {
            ++m_first;
        }

        bool empty()
        {
            return m_first >= m_end;
        }

        this(StaticBitArray* outer)
        {
            m_outer = outer;
            m_end = Size;
        }

        this(StaticBitArray* outer, size_t first, size_t end)
        {
            m_outer = outer;
            m_first = first;
            m_end = end;
        }

    private:
        StaticBitArray* m_outer;
        size_t m_first;
        size_t m_end;
    }

    Range opIndex()
    {
        return Range(&this);
    }

    Range opSlice(size_t first, size_t end)
    {
        return Range(&this, first, end);
    }

    bool opIndex(size_t i)
    {
        assert(i >= 0 && i < Size); // TODO: throw OutOfRange
        size_t nByte = (i >> 3);
        size_t nBitMask = (1 << (i & 0b111));

        return cast(bool)(m_bytes[nByte] & nBitMask);
    }

    void opIndexAssign(bool value, size_t n)
    {
        assert(n >= 0 && n < Size); // TODO: throw OutOfRange
        ulong i = (n >> 3);
        byte bit = cast(byte)(1 << (n & 0b111));
        byte x = value;

        m_bytes[i] ^= (-x ^ m_bytes[i]) & bit;
    }

    size_t opDollar()
    {
        return Size;
    }

private:
    ubyte[ByteSize] m_bytes;
}

unittest
{
    import std.algorithm;
    StaticBitArray!33 arr;
    arr[27] = true;
    assert(arr[].canFind(true));
    assert(arr[].any);
    assert(arr[15 .. 33].any);
    assert(arr[27] == true);
    arr[$ - 1] = true;
    assert(arr[$ - 1 .. $].any);

}

