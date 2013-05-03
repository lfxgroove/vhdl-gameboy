#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <iomanip>
#include <algorithm>
#include <sstream>
#include <stdlib.h>
#include <string.h>

using namespace std;

typedef unsigned int nat;

string trim(const string &s);

class Instr {
public:
  Instr() {}
  Instr(const string &opcode, const string &comment) {
    this->opcode = strtol(opcode.c_str(), 0, 16);
    if (comment.substr(comment.size() - 2) == "-t") {
      tested = true;
      mnemonic = trim(comment.substr(0, comment.size() - 2));
    } else {
      tested = false;
      mnemonic = comment;
    }
  }
  string mnemonic;
  int opcode;
  bool tested;
};

typedef std::vector<Instr> Instructions;

bool isblank(char c) {
  return c == ' ' || c == '\t';
}

string trim(const string &s) {
  bool empty = true;
  nat startAt = 0;
  for (nat i = 0; i < s.size(); i++) {
    if (!isblank(s[i])) {
      startAt = i;
      empty = false;
      break;
    }
  }

  nat stopAt = s.size();
  for (nat i = s.size(); i > 0; i--) {
    if (!isblank(s[i - 1])) {
      stopAt = i;
      empty = false;
      break;
    }
  }

  if (empty) return "";
  return s.substr(startAt, stopAt - startAt);
}

Instructions parseFile(const string &filename) {
  ifstream read(filename.c_str());
  Instructions r;

  enum {
    start,
    execWhen,
    memRead,
    after,
    execMbWhen,
  } state = start;

  string lastComment;

  string line;
  while (getline(read, line)) {
    line = trim(line);

    switch (state) {
    case start:
      if (line == "when Exec =>") state = execWhen;
      break;
    case execWhen:
      if (line == "case (IR) is") state = memRead;
      break;
    case memRead:
      if (line.size() > 2 && line.substr(0, 2) == "--") {
	lastComment = trim(line.substr(2));
      } else if (line.size() > 7 && line.substr(0, 7) == "when X\"") {
	string opcode = line.substr(7, 2);
	r.push_back(Instr(opcode, lastComment));
      } else if (line.size() >= 8 && line.substr(0, 8) == "end case") {
	state = after;
      }
      break;
    case after:
      if (line == "when Mb_Exec =>") state = execMbWhen;
      break;
    case execMbWhen:
      if (line.size() > 2 && line.substr(0, 2) == "--") {
	lastComment = trim(line.substr(2));
      } else if (line.size() > 7 && line.substr(0, 7) == "when X\"") {
	string opcode = line.substr(7, 4);
	r.push_back(Instr(opcode, lastComment));
      } else if (line.size() >= 8 && line.substr(0, 8) == "end case") {
	state = after;
      }
    }
    
  }

  return r;
}

void fill(ostringstream &s, int width) {
  int toInsert = width - s.str().size();
  while (toInsert > 0) {
    s << " ";
    toInsert--;
  }
}

void outputList(const Instructions &instr, ostream &to) {
  const int cols[] = { 5, 13 };
  int testedOpCodes = 0;
  for (Instructions::const_iterator i = instr.begin(); i != instr.end(); i++) {
    ostringstream line;
    line << setw(2) << setfill('0') << hex << i->opcode;
    if (i->tested) {
      fill(line, cols[0]);
      line << "tested";
      testedOpCodes++;
    }
    fill(line, cols[1]);
    line << i->mnemonic;
    to << line.str() << endl;
  }
  to << "Total: " << testedOpCodes << " of " << instr.size() << " opcodes tested." << endl;
}

bool opcodeComp(const Instr &a, const Instr &b) {
  return a.opcode < b.opcode;
}

bool testComp(const Instr &a, const Instr &b) {
  if (a.tested != b.tested) {
    if (a.tested) return true;
    else return false;
  }
  return a.opcode < b.opcode;
}

int main(int argc, char *argv[]) {
  string file = "cpu.vhd";
  string outputFile = "implemented_op_codes.txt";
  //  string outputFile = "";

  enum Sort {
    sNone,
    sOpcode,
    sTest,
  };
  Sort sort = sNone;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-i") == 0) {
      file = argv[++i];
    } else if (strcmp(argv[i], "-o") == 0) {
      outputFile = argv[++i];
    } else if (strcmp(argv[i], "-so") == 0) {
      sort = sOpcode;
    } else if (strcmp(argv[i], "-st") == 0) {
      sort = sTest;
    } else if (strcmp(argv[i], "-h") == 0) {
      cout << "Usage: -i <inputfile> -o <outputfile> -so" << endl;
      cout << "-i  - specifies input file (otherwise cpu.vhd)" << endl;
      cout << "-o  - specifies output file (default is stdout)" << endl;
      cout << "-so - sort output by op-codes" << endl;
      cout << "-st - sort output by tested status" << endl;
      return 0;
    }
  }
  
  Instructions i = parseFile(file);

  switch (sort) {
  case sNone:
    break;
  case sOpcode:
    cout << "Sorting opcodes" << endl;
    std::sort(i.begin(), i.end(), &opcodeComp);
    break;
  case sTest:
    cout << "Sorting opcodes" << endl;
    std::sort(i.begin(), i.end(), &testComp);
    break;
  }
    //    cout << iNrOfTests << " out of " << iImplementedOps << " are being tested"
   //	 << endl;
  if (outputFile == "") {
    outputList(i, cout);
  } else {
    ofstream f(outputFile.c_str());
    outputList(i, f);
  }

  return 0;
}
