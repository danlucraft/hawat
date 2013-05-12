
package main

import (
  "bufio"
  "encoding/json"
  "flag"
  "fmt"
  "io"
  "math/rand"
  "os"
  "regexp"
  "runtime/pprof"
  "strconv"
  "strings"
  "time"
  "ring"

  "github.com/glenn-brown/golang-pkg-pcre/src/pkg/pcre"
)

// example 
// Apr 28 00:00:15 dc1-live-lb1.srv.songkick.net haproxy[32647]: 10.32.75.139:53757 [28/Apr/2013:00:00:15.885] skweb skweb/dc1-live-frontend6_3000 0/0/9/9/20 200 5732 - - ---- 104/39/39/5/0 0/0 \"GET /favicon.ico HTTP/1.1\"\n"
//LINE_RE = /^(\w+ \d+ \d+:\d+:\d+) (\S+) haproxy\[(\d+)\]: ([\d\.]+):(\d+) \[(\d+)\/(\w+)\/(\d+):(\d+:\d+:\d+\.\d+)\] ([^ ]+) ([^ ]+)\/([^ ]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+) (\d+) - - ([\w-]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+)\/(\d+) "(\w+) ([^ ]+)/

var LineRegexSource = "^(\\w+\\s+\\d+ \\d+:\\d+:\\d+) (\\S+) haproxy\\[(\\d+)\\]: ([\\d\\.]+):(\\d+) \\[(\\d+)\\/(\\w+)\\/(\\d+):(\\d+:\\d+:\\d+\\.\\d+)\\] ([^ ]+) ([^ ]+)\\/([^ ]+) (-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+) (-?\\d+) (-?\\d+) - - ([\\w-]+) (-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+)\\/(-?\\d+) (\\d+)\\/(\\d+) \"(\\w+) ([^ ]+)"
var LineRegex = regexp.MustCompile(LineRegexSource)
var LineRegexPCRE = pcre.MustCompile(LineRegexSource, 0)

type Hawat struct {
  filePath string
  node     Node
}

type Line interface {
  haproxyHost() string
  haproxyPid() string
  haproxyIp() string
  haproxyPort() string
  day() string
  month() string
  year() string
  timestamp() string
  frontend() string
  backend() string
  server() string
  tq() string
  tw() string
  tc() string
  tr() string
  totalTimeDuration() time.Duration
  totalTime() int
  status() string
  bytes() string
  terminationState() string
  actconn() string
  feconn() string
  beconn() string
  srvConn() string
  retries() string
  srvQueue() string
  backendQueue() string
  httpMethod() string
  path() string
  Accepted() time.Time
  Closed() time.Time
}

type LineDataPCRE pcre.Matcher

func (md *LineDataPCRE) GroupString(i int) string {
  matcher := pcre.Matcher(*md)
  return matcher.GroupString(i)
}
func (md *LineDataPCRE) haproxyHost() string { return md.GroupString(2) }
func (md *LineDataPCRE) haproxyPid() string { return  md.GroupString(3) }
func (md *LineDataPCRE) haproxyIp() string { return  md.GroupString(4) }
func (md *LineDataPCRE) haproxyPort() string { return  md.GroupString(5) }
func (md *LineDataPCRE) day() string { return md.GroupString(6) }
func (md *LineDataPCRE) month() string { return md.GroupString(7) }
func (md *LineDataPCRE) year() string { return md.GroupString(8) }
func (md *LineDataPCRE) timestamp() string { return md.GroupString(9) }
func (md *LineDataPCRE) frontend() string { return md.GroupString(10) }
func (md *LineDataPCRE) backend() string { return md.GroupString(11) }
func (md *LineDataPCRE) server() string { return md.GroupString(12) }
func (md *LineDataPCRE) tq() string { return md.GroupString(13) }
func (md *LineDataPCRE) tw() string { return md.GroupString(14) }
func (md *LineDataPCRE) tc() string { return md.GroupString(15) }
func (md *LineDataPCRE) tr() string { return md.GroupString(16) }
func (md *LineDataPCRE) totalTimeDuration() time.Duration { d,_ := time.ParseDuration(md.GroupString(17) + "ms"); return d }
func (md *LineDataPCRE) totalTime() int { i, _ := strconv.Atoi(md.GroupString(17)); return i }
func (md *LineDataPCRE) status() string { return md.GroupString(18) }
func (md *LineDataPCRE) bytes() string { return md.GroupString(19) }
func (md *LineDataPCRE) terminationState() string { return md.GroupString(20) }
func (md *LineDataPCRE) actconn() string { return md.GroupString(21) }
func (md *LineDataPCRE) feconn() string { return md.GroupString(22) }
func (md *LineDataPCRE) beconn() string { return md.GroupString(23) }
func (md *LineDataPCRE) srvConn() string { return md.GroupString(24) }
func (md *LineDataPCRE) retries() string { return md.GroupString(25) }
func (md *LineDataPCRE) srvQueue() string { return md.GroupString(26) }
func (md *LineDataPCRE) backendQueue() string { return md.GroupString(27) }
func (md *LineDataPCRE) httpMethod() string { return md.GroupString(28) }
func (md *LineDataPCRE) path() string { return md.GroupString(29) }

func (md *LineDataPCRE) Accepted() time.Time {
  t,_ := time.Parse("02/Jan/2006:15:04:05.000", md.day() + "/" + md.month() + "/" + md.year() + ":" + md.timestamp())
  return t
}

func (md *LineDataPCRE) Closed() time.Time {
  a := md.Accepted()
  return a.Add(md.totalTimeDuration())
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
func (md LineData) totalTimeDuration() time.Duration { d,_ := time.ParseDuration(md[17] + "ms"); return d }
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

func (md LineData) Accepted() time.Time {
  t,_ := time.Parse("02/Jan/2006:15:04:05.000", md.day() + "/" + md.month() + "/" + md.year() + ":" + md.timestamp())
  return t
}

func (md LineData) Closed() time.Time {
  a := md.Accepted()
  return a.Add(md.totalTimeDuration())
}

type Node interface {
  Update(Line)
  Collect()         map[string]interface{}
  Merge(Node)
  Children()        map[string]Node
}

type NamedAggregate struct {
  _children map[string]Node
}

type SplitterAggregate struct {
  splitter       func(Line)string
  _children       map[string]Node
  childGenerator func()Node
}

type FrontendAggregate struct {
  _children       map[string]Node
  childGenerator func()Node
}

type PathAggregate struct {
  count             int
  terminal          Node
  _children         map[string]Node
  terminalGenerator func()Node
  depth             int
}

type TimeBucket struct {
  start   time.Time
  end     time.Time
  child   Node
}

type TimeBucketerAggregate struct {
  bucketLength   int
  buckets        map[int]TimeBucket
  childGenerator func()Node
  startOfDay     time.Time
}

type StatisticsTerminal struct {
  count           int
  totalDuration   int
  maxDuration     int
  statusCounts    map[string]int
}

type ConcurrencyTerminal struct {
  maxConcurrency   int
  liveRequests     *ring.RingInt64
  //liveRequests     map[time.Time]int
}

// NamedAggregate

func newNamedAggregate(_children map[string]Node) *NamedAggregate {
  return &NamedAggregate{_children}
}

func (n *NamedAggregate) Children() map[string]Node { return n._children }

func (n *NamedAggregate) Update(l Line) {
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

func newMethodAggregate(childGenerator func()Node) *SplitterAggregate {
  return newSplitterAggregate(func(ld Line)string { return ld.httpMethod() }, childGenerator)
}

// FrontendAggregate

func newFrontendAggregate(childGenerator func()Node) *SplitterAggregate {
  return newSplitterAggregate(func(ld Line)string { return ld.frontend() }, childGenerator)
}

// SplitterAggregate

func newSplitterAggregate(splitter func(Line)string, childGenerator func()Node) *SplitterAggregate {
  return &SplitterAggregate{splitter, make(map[string]Node), childGenerator}
}

func (n *SplitterAggregate) Children() map[string]Node { return n._children }

func (n *SplitterAggregate) Update(l Line) {
  child, ok := n._children[n.splitter(l)]
  if !ok {
    child = n.childGenerator()
    n._children[n.splitter(l)] = child
  }
  child.Update(l)
}

func (n *SplitterAggregate) Collect() map[string]interface{} {
  result := make(map[string]interface{})
  for method, child := range n._children {
    result[method] = child.Collect()
  }
  return result
}

func (n *SplitterAggregate) Merge(other Node) {
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
  return newPathAggregateWithDepth(terminalGenerator, 0)
}

func newPathAggregateWithDepth(terminalGenerator func()Node, depth int) *PathAggregate {
  return &PathAggregate{0, terminalGenerator(), make(map[string]Node), terminalGenerator, depth}
}

func (n *PathAggregate) Children() map[string]Node        { return n._children }

func (n *PathAggregate) Update(l Line) {
  path := l.path()
  bits := strings.Split(path, "/")[1:]
  n.Update1(bits, l)
}

func (n *PathAggregate) Update1(bits []string, l Line) {
  n.count++
  if len(bits) > 1 {
    name := bits[0]
    node, ok := n._children["*"]
    if !ok {
      node, ok = n._children[name]
      if rand.Int31n(100) < 10 {
        n.Reduce()
      }
    }

    var child *PathAggregate
    if !ok {
      child = newPathAggregateWithDepth(n.terminalGenerator, n.depth + 1)
      n._children[name] = child
    } else {
      child = node.(*PathAggregate)
    }
    child.Update1(bits[1:], l)
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
  if n.depth == 0 {
    return
  }
  if _, ok := n._children["*"]; !ok {
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
}

func (n *PathAggregate) Merge(otherNode Node) {
  other := otherNode.(*PathAggregate)
  n.count += other.count
  for slug, otherChild := range(other.Children()) {
    thisChild, ok := n._children[slug]
    if !ok {
      thisChild = otherChild.(*PathAggregate)
      n._children[slug] = thisChild
    }
    thisChild.Merge(otherChild)
  }
  if other.terminal != nil {
    n.terminal.Merge(other.terminal)
  }
}

// TimeBucketerAggregate

func newTimeBucketerAggregate(bucketLength int, childGenerator func()Node ) *TimeBucketerAggregate {
  return &TimeBucketerAggregate{bucketLength, make(map[int]TimeBucket), childGenerator, time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)}
}

func (n *TimeBucketerAggregate) Children() map[string]Node  { return nil }

func (n *TimeBucketerAggregate) Update(l Line) {
  closed := l.Closed()
  startOfDay := n.startOfDay
  if startOfDay.Year() == 1970 {
    startOfDay = time.Date(closed.Year(), closed.Month(), closed.Day(), 0, 0, 0, 0, startOfDay.Location())
    n.startOfDay = startOfDay
  }

  closedSecsToday := closed.Unix() - startOfDay.Unix()
  bucketIx := int(int(closedSecsToday)/n.bucketLength)
  bucket, ok := n.buckets[bucketIx]
  if !ok {
    start, _ := time.ParseDuration(strconv.Itoa(bucketIx*n.bucketLength) + "s")
    end, _ := time.ParseDuration(strconv.Itoa((bucketIx + 1)*n.bucketLength) + "s")
    bucket = TimeBucket{startOfDay.Add(start),
                        startOfDay.Add(end),
                        n.childGenerator()}
    n.buckets[bucketIx] = bucket
  }
  bucket.child.Update(l)
}

func (n *TimeBucketerAggregate) Collect() map[string]interface{} {
  result := map[string]interface{} {}
  for _, bucket := range(n.buckets) {
    result[bucket.start.Format(time.RubyDate)] = bucket.child.Collect()
  }
  return result
}

func (n *TimeBucketerAggregate) Merge(otherNode Node) {
  other := otherNode.(*TimeBucketerAggregate)
  for bucketIx, otherBucket := range other.buckets {
    if thisBucket, ok := n.buckets[bucketIx]; ok {
      thisBucket.Merge(&otherBucket)
    } else {
      n.buckets[bucketIx] = otherBucket
    }
  }
}

func (b TimeBucket) Merge(other *TimeBucket) {
  if !b.start.Equal(other.start) || !b.end.Equal(other.end) {
    panic("bucket start or end aren't equal")
  }
  b.child.Merge(other.child)
}

// StatisticsTerminal

func newStatisticsTerminal() *StatisticsTerminal {
  return &StatisticsTerminal{0, 0, 0, make(map[string]int)}
}

func (n *StatisticsTerminal) Children() map[string]Node        { return nil }

func (n *StatisticsTerminal) Update(l Line) {
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

// ConcurrencyTerminal

func newConcurrencyTerminal() *ConcurrencyTerminal {
  return &ConcurrencyTerminal{0, ring.NewInt64(10000)}
  //return &ConcurrencyTerminal{0, make(map[time.Time]int)}
}

func (n *ConcurrencyTerminal) Children() map[string]Node { return nil }

func (n *ConcurrencyTerminal) Update(l Line) {
  accepted := l.Accepted()
  closed   := l.Closed()

  n.liveRequests.DeleteLessEq(-1*closed.UnixNano())
  n.liveRequests.Add(-1*accepted.UnixNano())
  if n.liveRequests.Length() > n.maxConcurrency {
    n.maxConcurrency = n.liveRequests.Length()
  }

  //conc := 0
  //for t, count := range(n.liveRequests) {
    //if t.After(closed) {
      //delete(n.liveRequests, t)
    //} else {
      //conc += count
    //}
  //}
  //n.liveRequests[accepted]++
  //if conc > n.maxConcurrency {
    //n.maxConcurrency = conc
  //}
}

func (n *ConcurrencyTerminal) Collect() map[string]interface{} {
  return map[string]interface{} {"max": n.maxConcurrency}
}

func (n *ConcurrencyTerminal) Merge(otherNode Node) {
  other := otherNode.(*ConcurrencyTerminal)
  if other.maxConcurrency > n.maxConcurrency {
    n.maxConcurrency = other.maxConcurrency
  }
}
func usage() {
  fmt.Printf("usage: hawat LOG_FILE\n")
}

func newHawat(filePath string) *Hawat {
  h := &Hawat{filePath, nil}
  return h
}

func newDefaultTerminal() *NamedAggregate {
  return newNamedAggregate(map[string]Node {
            "stats": newStatisticsTerminal(),
            "conc": newConcurrencyTerminal(),
         })
}

const TimeBucketLength = 300

func (h *Hawat) process() {
  file, _ := os.Open(h.filePath)
  reader := bufio.NewReader(file)

  frontends := newFrontendAggregate(func()Node {
    return newNamedAggregate(map[string]Node {
      "global": newNamedAggregate(map[string]Node {
        "all": newDefaultTerminal(),
        "series": newTimeBucketerAggregate(TimeBucketLength, func()Node { return newDefaultTerminal() })}),
      "paths": newPathAggregate(func()Node {
        return newMethodAggregate(func() Node {
          return newNamedAggregate(map[string]Node {
            "all": newDefaultTerminal(),
            "series": newTimeBucketerAggregate(TimeBucketLength, func()Node { return newStatisticsTerminal()})})})})})})

  node := newNamedAggregate(map[string]Node {
                "global": newNamedAggregate(map[string]Node {
                  "all": newDefaultTerminal(),
                  "series": newTimeBucketerAggregate(TimeBucketLength, func()Node { return newDefaultTerminal() })}),
                "frontends": frontends})
  i := 0

  for {
    i++
    line, err := reader.ReadString('\n')
    if err == io.EOF {
      break
    } else {
      processLine(line, node)
    }
  }
  b, _ := json.MarshalIndent(node.Collect(), "", "  ")
  fmt.Print(string(b) + "\n")
}

func processLine(line string, node Node) {
  defer func() {
    if x := recover(); x != nil {
      //fmt.Println("panic")
      //fmt.Println(line)
    }
  }()
  processLinePCRE(line, node)
}

func processLineNative(line string, node Node) {
  match := LineRegex.FindStringSubmatch(line)
  if match != nil {
    ld := LineData(match)
    ld.day()
    //node.Update(ld)
  } else {
    //fmt.Println("didn't match:")
    //fmt.Println(line)
  }
}

func processLinePCRE(line string, node Node) {
  if matcher := LineRegexPCRE.MatcherString(line, 0); matcher != nil {
    ld := LineDataPCRE(*matcher)
    node.Update(&ld)
  }
}

func main() {
  var cpuprofile = flag.String("cpuprofile", "", "write cpu profile to file")
  var memprofile = flag.String("memprofile", "", "write memory profile to this file")

  flag.Parse()
  if *cpuprofile != "" {
    fmt.Println("profiling")
    f, err := os.Create(*cpuprofile)
    if err != nil {
      fmt.Println(err)
    }
    pprof.StartCPUProfile(f)
    defer pprof.StopCPUProfile()
  }

  if len(flag.Args()) < 1 {
    usage()
  } else {
    path := flag.Args()[0]
    h := newHawat(path)

    if *memprofile != "" {
      f, err := os.Create(*memprofile)
      if err != nil {
        fmt.Println(err)
      }
      h.process()
      pprof.WriteHeapProfile(f)
      f.Close()
      return
    } else {
      h.process()
    }

  }
}




