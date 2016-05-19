import std.algorithm;
import std.datetime;
import std.json;
import std.random;
import std.range;
import std.stdio;

import art.sparse_array;

struct BMFunc
{
    this(size_t dataCount) @safe pure
    {
        m_dataCount = cast(int)dataCount;
    }

    void runInsertSeq(AA)()
    {
        AA a;

        foreach (i; iota(m_dataCount))
        {
            a[i] = i;
        }
    }

    void runInsertDense(AA)()
    {
        AA a;
        enum maxChunkSize = 500;

        for (int i = m_dataCount, step = maxChunkSize;
                i > 0;
                i -= step, step = uniform(0, maxChunkSize))
        {
            auto start = uniform!int;

            foreach (j; iota(step))
            {
                a[j + start] = j + start;
            }
        }
    }

    void runInsertSparse(AA)()
    {
        AA a;

        for (int i = m_dataCount; i > 0; --i)
        {
            auto j = uniform!int;

            a[j] = j;
        }
    }

    private immutable int m_dataCount;
}

auto normalize(T)(T t)
{
    auto a = minPos(t[])[0];
    double[t.length] res;
    enum double scaleFactor = 1_000_000;
    foreach (i, v; t)
    {
        res[i] = cast(double)v.hnsecs/scaleFactor;

    }

    return res;
}

enum BMTimes = 5;

void saveBMResults(T)(T res, JSONValue stats)
{
    auto n = normalize(res);

    stats.object["ART"].array ~= JSONValue(n[0]);
    stats.object["AA"].array ~= JSONValue(n[1]);
}

void runInsertSeqBM(size_t dataSize, JSONValue stats)
{
    enum size_t keySize = int.sizeof;
    immutable size_t dataLength = dataSize / keySize;

    auto art = () => BMFunc(dataLength).runInsertSeq!(SparseArray!(int, int));
    auto aa = () => BMFunc(dataLength).runInsertSeq!(int[int]);

    // Cold pass
    auto t = benchmark!(art, aa)(BMTimes);

    t = benchmark!(art, aa)(BMTimes);
    saveBMResults(t, stats);
}

void runInsertDenseBM(size_t dataSize, JSONValue stats)
{
    enum size_t keySize = int.sizeof;
    immutable size_t dataLength = dataSize / keySize;

    auto art = () => BMFunc(dataLength).runInsertDense!(SparseArray!(int, int));
    auto aa = () => BMFunc(dataLength).runInsertDense!(int[int]);

    // Cold pass
    auto t = benchmark!(art, aa)(BMTimes);

    t = benchmark!(art, aa)(BMTimes);
    saveBMResults(t, stats);
}

void runInsertSparseBM(size_t dataSize, JSONValue stats)
{
    enum size_t keySize = int.sizeof;
    immutable size_t dataLength = dataSize / keySize;

    auto art = () => BMFunc(dataLength).runInsertSparse!(SparseArray!(int, int));
    auto aa = () => BMFunc(dataLength).runInsertSparse!(int[int]);

    // Cold pass
    auto t = benchmark!(art, aa)(BMTimes);

    t = benchmark!(art, aa)(BMTimes);
    saveBMResults(t, stats);
}

void main()
{
    enum size_t K = 1024;
    enum size_t M = K * K;
    size_t[] dataSizes = [32 * K, 256 * K, 3 * M, 16 * M];
    JSONValue stats = parseJSON(`{"sequential":{"AA":[],"ART":[]},"dense":{"AA":[],"ART":[]},"sparse":{"AA":[],"ART":[]}}`);
    stats.object["dataSizes"] = JSONValue(dataSizes);

    foreach (size; dataSizes)
    {
        runInsertSeqBM(size, stats["sequential"]);
        runInsertDenseBM(size, stats["dense"]);
        runInsertSparseBM(size, stats["sparse"]);
    }

    writeln(stats.toString());
}
