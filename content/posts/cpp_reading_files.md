---
Title: "mmap vs. ifstream to read a file"
Date: "2017-05-14"
categories: hacking
draft: true
tags: [cpp, linux]
Author: Petr Tikilyaynen
description: "Trade-offs of reading files in C++"
---

Working on an app that iterates over a huge corpus file line by line made me curious about efficient disk I/O in C++. On each line I need to use the current vector for a calculation that represent words' semantic associations. In this case, the large file is a corpus built from GoogleNews. Each line starts with a word followed by space-separated floats making a 300-dimensional vector finishing with a newline char. The principles should apply for other large files too.

I am examining different ways of efficiently reading a file from disk line-by-line. Each method described below will run on the same file, surrounded by a timer built from ```std::chrono``` objects as below.

TODO:

  * Profile improved mmap - solving the 2 caveats: iterate over chars in each mapping, and dealing with leftover data in the last mapping.
  * Strace analysis
  * Assembly analysis

```cpp
int main(int argc, char *argv[]) {
  auto start = std::chrono::steady_clock::now();
  read_file_by_lines(argv[1]);
  auto stop = std::chrono::steady_clock::now();
  std::chrono::duration<double> diff = stop - start;
  std::cout << "\n" << diff.count() << " seconds\n";
  return 0;
}
```

## C++ standard

The standard C++ way of reading a textfile from disk is by using an input file stream ```ifstream```. Given a path to file and optional arguments, it creates an input filestream associated with the file at the filename. Then using a for-loop, a line of type std::string is created, as we move the input filestream line-by-line.

```cpp
void read_file_by_lines(std::string filename) {
  /* Uses the ifstream from std to open a file given the filename in cur_dir and
   * read it out line-by-line */
  std::ifstream input(filename); 
  for (std::string line; getline(input, line);) { // uses the \n char in txt file
    // calculation logic
  }
}
```

## mmap txt file

The method opens a file descriptor to the filename and starting from the offset of 0, iterates over page_size blocks of memory. 

```cpp
void read_mmaped_file_by_lines(std::string filename) {
  /*
     mmaps the file into memory by pages (not always aligned with line size).
  */
  // find filesize using the stat syscall
  struct stat st;
  stat(filename.c_str(), &st);
  const size_t file_size = st.st_size;

  const long page_size = 0x1000; // linux page size - 4 KB
  long off = 0;
  void *data;
  int fd = open(filename.c_str(), O_RDONLY);

  while (off < file_size) {
    data = mmap(NULL, page_size, PROT_READ, MAP_PRIVATE, fd, off);
    std::string line = std::string{(char *)data, (char *)data + page_size};
    // do stuff with data
    munmap(data, page_size);
    off += page_size;
  }
}
```

2 caveats:

  * the inconvinience of operating on raw bytes of data. There is no getline facility for raw bytes, so you need to iterate over each char in the stream and carry over into next mmaping to join split vectors. eg. if pagebreak comes in the middle of a vector like below

-0.097343 0.029601 0.058967 0.062243 -0.087515**\n**with -0.015970 0.014091 

the newline will be read as well as the next word and its vector values. To avoid losing data we need to carry a std::vector<300> and push_back values into it. Once all values in it aren't equal to the initialisation value, we can write it out with the word into an unordered\_map. getline abstracts this away and looks for "/n" char and strips it out. 

  * If the filesize isn't a multiple of pagesize (most of the time it's not), we need a special case to manually mmap the last bits


## mmap bin file

Since mmap doesn't care about newline characters (it's all just bytes), we can implement a mmap that takes a binary file and fix the 2 caveats above. 


## Comparison

### Time

The memory mapped read takes a second longer than the std method.

```bash
$$$$ clang++-3.7 -Wall -O3 -std=c++11 std_read_lines.cpp -o std_read_lines
$$$$ ./std_read_lines gnews_corpus.txt 

14.8439 seconds
$$$$ clang++-3.7 -Wall -O3 -std=c++11 mmap_read_lines.cpp -o map_read_lines
$$$$ ./map_read_lines gnews_corpus.txt 

16.5109 seconds
```

### Syscalls

Straced both programmes to compare the kind of syscalls they make to investigate potential bottlenecks.

### Assembly

Generated assembly using Godbolt's Compiler Explorer. [Link](https://godbolt.org/g/SRsjN1). Need to recompile it first. WIP.
