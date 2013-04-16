#pragma once

#include <list>
#include <string>

class Test;
class AddrData;
class DiffInfo;

typedef std::list<Test> Tests;
typedef unsigned char byte;
typedef std::list<byte> PrepareStatements;
typedef std::list<byte> ByteList;
typedef std::list<AddrData> AddrDatas;
typedef std::list<DiffInfo> DiffList;
