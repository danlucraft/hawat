
package main

import (
  "fmt"
  "io"
  "flag"
  "bufio"
  "os"
  "regexp"
  "strconv"
  "encoding/json"
  "strings"
)

// example 
// Apr 28 00:00:15 dc1-live-lb1.srv.songkick.net haproxy[32647]: 10.32.75.139:53757 [28/Apr/2013:00:00:15.885] skweb skweb/dc1-live-frontend6_3000 0/0/9/9/20 200 5732 - - ---- 104/39/39/5/0 0/0 \"GET /favicon.ico HTTP/1.1\"\n"
//LINE_RE = /^(\w+ \d+ \d+:\d+:\d+) (\S+) haproxy\[(\d+)\]: ([\d\.]+):(\d+) \[(\d+)\/(\w+)\/(\d+):(\d+:\d+:\d+\.\d+)\] ([^ ]+) ([^ ]+)\/([^ ]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+) (\d+) - - ([\w-]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+)\/(\d+) "(\w+) ([^ ]+)/

var LineRegex = regexp.MustCompile("^(\\w+ \\d+ \\d+:\\d+:\\d+) (\\S+) haproxy\\[(\\d+)\\]: ([\\d\\.]+):(\\d+) \\[(\\d+)\\/(\\w+)\\/(\\d+):(\\d+:\\d+:\\d+\\.\\d+)\\] ([^ ]+) ([^ ]+)\\/([^ ]+) (-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+) (\\d+) (\\d+) - - ([\\w-]+) (-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+) (\\d+)\\/(\\d+) \"(\\w+) ([^ ]+)")

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
  reader := bufio.NewReader(file)

  node := newNamedAggregate(map[string]Node {
            "methods": newMethodAggregate(func()Node { return newStatisticsTerminal() }),
            "paths":   newPathAggregate(func()Node { return newStatisticsTerminal() }),
            "global": newStatisticsTerminal()})

  for {
    line, err := reader.ReadString('\n')
    if err == io.EOF {
      break
    } else {
      match := LineRegex.FindStringSubmatch(line)
      ld := LineData(match)
      node.Update(ld)
    }
  }
  b, _ := json.MarshalIndent(node.Collect(), "", "  ")
  fmt.Printf(string(b) + "\n")
}

type LineData []string
func (md LineData) haproxyHost() string { return md[2] }
func (md LineData) haproxyPid() string { return  md[3] }
func (md LineData) haproxyIp() string { return  md[4] }
func (md LineData) haproxyPort() string { return  md[5] }
func (md LineData) day() string { return md[6] }
func (md LineData) month() string { return md[7] }
func (md LineData) year() string { return md[8] }
func (md LineData) timestamp() string { return md[9] }
func (md LineData) frontend() string { return md[10] }
func (md LineData) backend() string { return md[11] }
func (md LineData) server() string { return md[12] }
func (md LineData) tq() string { return md[13] }
func (md LineData) tw() string { return md[14] }
func (md LineData) tc() string { return md[15] }
func (md LineData) tr() string { return md[16] }
func (md LineData) totalTime() int { i, _ := strconv.Atoi(md[17]); return i }
func (md LineData) status() string { return md[18] }
func (md LineData) bytes() string { return md[19] }
func (md LineData) terminationState() string { return md[20] }
func (md LineData) actconn() string { return md[21] }
func (md LineData) feconn() string { return md[22] }
func (md LineData) beconn() string { return md[23] }
func (md LineData) srvConn() string { return md[24] }
func (md LineData) retries() string { return md[25] }
func (md LineData) srvQueue() string { return md[26] }
func (md LineData) backendQueue() string { return md[27] }
func (md LineData) httpMethod() string { return md[28] }
func (md LineData) path() string { return md[29] }

type Node interface {
  Update(LineData)
  Collect()         map[string]interface{}
  Merge(Node)
  Children()        map[string]Node
  Data()            map[string]interface{}
  Terminal()        Node
}

type NamedAggregate struct {
  _children map[string]Node
}

type MethodAggregate struct {
  _children       map[string]Node
  childGenerator func()Node
}

type FrontendAggregate struct {
  _children       map[string]Node
  childGenerator func()Node
}

type TimeBucketerAggregate struct {
  _children       map[int]Node
  childGenerator func()Node
}

type PathAggregate struct {
  count          int
  terminal       Node
  _children       map[string]Node
  terminalGenerator func()Node
}

type StatisticsTerminal struct {
  count           int
  totalDuration   int
  maxDuration     int
  statusCounts    map[string]int
}

type ConcurrencyTerminal struct {
  maxConcurrency int
  liveRequests   []int
}


// NamedAggregate

func newNamedAggregate(_children map[string]Node) *NamedAggregate {
  return &NamedAggregate{_children}
}

func (n *NamedAggregate) Children() map[string]Node { return n._children }
func (n *NamedAggregate) Data() map[string]interface{} { return nil }
func (n *NamedAggregate) Terminal() Node { return nil }

func (n *NamedAggregate) Update(l LineData) {
  for _, child := range n._children {
    child.Update(l)
  }
}

func (n *NamedAggregate) Collect() map[string]interface{} {
  result := make(map[string]interface{})
  for name, child := range n._children {
    result[name] = child.Collect()
  }
  return result
}

func (n *NamedAggregate) Merge(other Node) {
  for name, otherChild := range(other.Children()) {
    thisChild, ok := n._children[name]
    if ok {
      thisChild.Merge(otherChild)
    } else {
      n._children[name] = otherChild
    }
  }
}

// MethodAggregate

func newMethodAggregate(childGenerator func()Node) *MethodAggregate {
  return &MethodAggregate{make(map[string]Node), childGenerator}
}

func (n *MethodAggregate) Children() map[string]Node        { return n._children }
func (n *MethodAggregate) Data()     map[string]interface{} { return nil }
func (n *MethodAggregate) Terminal() Node { return nil }

func (n *MethodAggregate) Update(l LineData) {
  child, ok := n._children[l.httpMethod()]
  if !ok {
    child = n.childGenerator()
    n._children[l.httpMethod()] = child
  }
  child.Update(l)
}

func (n *MethodAggregate) Collect() map[string]interface{} {
  result := make(map[string]interface{})
  for method, child := range n._children {
    result[method] = child.Collect()
  }
  return result
}

func (n *MethodAggregate) Merge(other Node) {
  for method, otherChild := range(other.Children()) {
    thisChild, ok := n._children[method]
    if ok {
      thisChild.Merge(otherChild)
    } else {
      n._children[method] = otherChild
    }
  }
}

// PathAggregate

func newPathAggregate(terminalGenerator func()Node) *PathAggregate {
  return &PathAggregate{0, terminalGenerator(), make(map[string]Node), terminalGenerator}
}

func (n *PathAggregate) Children() map[string]Node        { return n._children }
func (n *PathAggregate) Data()     map[string]interface{} { return map[string]interface{} {"count": n.count} }
func (n *PathAggregate) Terminal() Node                  { return n.terminal }

func (n *PathAggregate) Update(l LineData) {
  path := l.path()
  bits := strings.Split(path, "/")[1:]
  n.Update1(bits, l)
}

func (n *PathAggregate) Update1(bits []string, l LineData) {
  n.count++
  if len(bits) > 1 {
    name := bits[0]
    node, ok := n._children[name].(*PathAggregate)
    if !ok {
      node = newPathAggregate(n.terminalGenerator)
      n._children[name] = node
    }
    node.Update1(bits[1:], l)
  } else {
    n.terminal.Update(l)
  }
}

func (n *PathAggregate) Collect() map[string]interface{} {
  for _, child := range(n._children) {
    child.(*PathAggregate).Reduce()
  }
  result := map[string]interface{} {}
  n.Collect1("", result)
  return result
}

func (n *PathAggregate) Collect1(path string, result map[string]interface{}) {
  for slug, child := range(n._children) {
    child.(*PathAggregate).Collect1(path + "/" + slug, result)
  }
  result[path] = n.terminal.Collect()
}

func (n *PathAggregate) Reduce() {
  if len(n._children) > 15 {
    newChildren := map[string]Node { "*": newPathAggregate(n.terminalGenerator) }
    for _, child := range(n._children) {
      newChildren["*"].Merge(child)
    }
    n._children = newChildren
  }
  for _, child := range(n._children) {
    child.(*PathAggregate).Reduce()
  }
}

func (n *PathAggregate) Merge(other Node) {
  n.count += other.Data()["count"].(int)
  for slug, otherChild := range(other.Children()) {
    thisChild, ok := n._children[slug]
    if !ok {
      thisChild = otherChild.(*PathAggregate)
      n._children[slug] = thisChild
    }
    thisChild.Merge(otherChild)
  }
  if other.Terminal() != nil {
    n.terminal.Merge(other.Terminal())
  }
}

// StatisticsTerminal

func newStatisticsTerminal() *StatisticsTerminal {
  return &StatisticsTerminal{0, 0, 0, make(map[string]int)}
}

func (n *StatisticsTerminal) Children() map[string]Node        { return nil }
func (n *StatisticsTerminal) Data()     map[string]interface{} { return nil }
func (n *StatisticsTerminal) Terminal() Node                  { return nil }

func (n *StatisticsTerminal) Update(l LineData) {
  n.count++
  dur := l.totalTime()
  n.totalDuration += dur
  if dur > n.maxDuration {
    n.maxDuration = dur
  }
  n.statusCounts[l.status()] += 1
}

func (n *StatisticsTerminal) Collect() map[string]interface{} {
  if n.count == 0 {
    return map[string]interface{} {
      "count": 0,
    }
  } else {
    return map[string]interface{} {
      "count": n.count,
      "status": n.statusCounts,
      "duration": map[string]interface{} {
        "mean": n.totalDuration/n.count,
        "max": n.maxDuration,
      },
    }
  }
}

func (n *StatisticsTerminal) Merge(otherNode Node) {
  other := otherNode.(*StatisticsTerminal)
  n.count += other.count
  n.totalDuration += other.totalDuration
  if other.maxDuration > n.maxDuration {
    n.maxDuration = other.maxDuration
  }
  for status, otherCount := range(other.statusCounts) {
    thisCount, ok := n.statusCounts[status]
    if !ok {
      thisCount = 0
    }
    thisCount += otherCount
    n.statusCounts[status] = thisCount
  }
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




