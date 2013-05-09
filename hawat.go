
package main

import (
  "fmt"
  "flag"
  "bufio"
  "os"
)

type Hawat struct {
  filePath string
  node     Node
}

func newHawat(filePath string) *Hawat {
  h := &Hawat{filePath, nil}
  return h
}

func (h *Hawat) process() {
  file, _ := os.Open(h.filePath)
  fileBuf := bufio.NewReader(file)
  line, _ := fileBuf.ReadString('\n')
  fmt.Printf(line)
}

type Node interface {
  Update()
  Collect() map[string]interface{}
}

type NamedAggregate struct {
  children map[string]Node
}

type MethodAggregate struct {
  children       map[string]Node
  childGenerator func()Node
}

type FrontendAggregate struct {
  children       map[string]Node
  childGenerator func()Node
}

type TimeBucketerAggregate struct {
  children       map[int]Node
  childGenerator func()Node
}

type PathAggregate struct {
  children       map[string]Node
  childGenerator func()Node
}

type StatisticsTerminal struct {
  count           int
  totalDuration   int
  maxDuration     int
  statusCounts    map[int]int
}

type ConcurrencyTerminal struct {
  maxConcurrency int
  liveRequests   []int
}

func usage() {
  fmt.Printf("usage: hawat LOG_FILE\n")
}

func main() {
  flag.Parse()
  if len(flag.Args()) < 1 {
    usage()
  } else {
    path := flag.Args()[0]
    h := newHawat(path)
    h.process()
  }
}




